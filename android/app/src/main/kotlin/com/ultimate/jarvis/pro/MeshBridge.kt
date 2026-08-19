package com.ultimate.jarvis.pro

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.Collections
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Real local mesh transport for devices on the same LAN.
 *
 * Discovery uses UDP broadcast and pairing uses a newline-delimited TCP control
 * protocol. A peer is never reported as paired until its six-digit code is
 * accepted by the target and the target approves the pending request.
 */
class MeshBridge(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val DISCOVERY_PORT = 45454
        private const val CONTROL_PORT = 45455
        private const val DISCOVERY_TIMEOUT_MS = 1400
        private const val CONNECT_TIMEOUT_MS = 2500
    }

    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pairedPeers = ConcurrentHashMap<String, MutableMap<String, Any>>()
    private val pendingRequests = ConcurrentHashMap<String, Socket>()
    private val pendingPeerMetadata = ConcurrentHashMap<String, MutableMap<String, Any>>()
    private var serverSocket: ServerSocket? = null
    private var myDeviceId: String = ""
    private var myDeviceName: String = "JARVIS Device"
    private var myPairingCode: String = ""

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                myDeviceId = call.argument<String>("deviceId")?.trim().orEmpty()
                myDeviceName = call.argument<String>("deviceName")?.trim().orEmpty().ifEmpty { "JARVIS Device" }
                myPairingCode = call.argument<String>("pairingCode")?.trim().orEmpty()
                startServer()
                result.success(mapOf("status" to "started", "port" to CONTROL_PORT))
            }
            "startDiscovery" -> discoverAsync(result)
            "getPairedPeers" -> result.success(pairedPeers.values.toList())
            "pairToPeer" -> pairToPeer(call, result)
            "approvePairRequest" -> approvePairRequest(call, result)
            "rejectPairRequest" -> rejectPairRequest(call, result)
            "revokePeer" -> {
                val peerId = call.argument<String>("peerId")?.trim().orEmpty()
                pairedPeers.remove(peerId)
                result.success(mapOf("status" to "revoked", "peerId" to peerId))
            }
            "stop" -> {
                stopTransport()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun startServer() {
        if (serverSocket != null) return
        executor.execute {
            try {
                val server = ServerSocket(CONTROL_PORT)
                serverSocket = server
                while (!server.isClosed) {
                    val socket = server.accept()
                    executor.execute { handleIncoming(socket) }
                }
            } catch (_: Exception) {
                // The transport can be restarted from the Flutter layer.
            }
        }
    }

    private fun stopTransport() {
        pendingRequests.values.forEach { closeQuietly(it) }
        pendingRequests.clear()
        try {
            serverSocket?.close()
        } catch (_: Exception) {
        }
        serverSocket = null
    }

    private fun discoverAsync(result: MethodChannel.Result) {
        executor.execute {
            val peers = discoverPeers()
            mainHandler.post { result.success(peers) }
        }
    }

    private fun discoverPeers(): List<Map<String, Any>> {
        val discovered = linkedMapOf<String, MutableMap<String, Any>>()
        val request = JSONObject()
            .put("type", "jarvis_discover")
            .put("deviceId", myDeviceId)
            .put("deviceName", myDeviceName)
            .put("port", CONTROL_PORT)
            .toString()
            .toByteArray(Charsets.UTF_8)

        try {
            DatagramSocket().use { socket ->
                socket.broadcast = true
                socket.soTimeout = DISCOVERY_TIMEOUT_MS
                broadcastAddresses().forEach { address ->
                    socket.send(DatagramPacket(request, request.size, address, DISCOVERY_PORT))
                }
                val buffer = ByteArray(4096)
                val deadline = System.currentTimeMillis() + DISCOVERY_TIMEOUT_MS
                while (System.currentTimeMillis() < deadline) {
                    try {
                        val packet = DatagramPacket(buffer, buffer.size)
                        socket.receive(packet)
                        val response = JSONObject(String(packet.data, 0, packet.length, Charsets.UTF_8))
                        if (response.optString("type") != "jarvis_announce") continue
                        val peerId = response.optString("deviceId")
                        if (peerId.isEmpty() || peerId == myDeviceId) continue
                        discovered[peerId] = mutableMapOf(
                            "peerId" to peerId,
                            "name" to response.optString("deviceName", "JARVIS Device"),
                            "host" to packet.address.hostAddress.orEmpty(),
                            "port" to response.optInt("port", CONTROL_PORT),
                            "transport" to "lan_discovered",
                            "paired" to (pairedPeers.containsKey(peerId)),
                        )
                    } catch (_: SocketTimeoutException) {
                        break
                    } catch (_: Exception) {
                        // Ignore malformed discovery packets from other apps.
                    }
                }
            }
        } catch (_: Exception) {
            return emptyList()
        }
        return discovered.values.toList()
    }

    private fun broadcastAddresses(): List<InetAddress> {
        val result = mutableListOf<InetAddress>()
        try {
            Collections.list(NetworkInterface.getNetworkInterfaces()).forEach { network ->
                if (!network.isUp || network.isLoopback) return@forEach
                network.interfaceAddresses.forEach { address ->
                    val broadcast = address.broadcast
                    if (broadcast != null && address.address is Inet4Address) result.add(broadcast)
                }
            }
        } catch (_: Exception) {
        }
        if (result.isEmpty()) result.add(InetAddress.getByName("255.255.255.255"))
        return result.distinctBy { it.hostAddress }
    }

    private fun pairToPeer(call: MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("host")?.trim().orEmpty()
        val port = call.argument<Int>("port") ?: CONTROL_PORT
        val pairingCode = call.argument<String>("pairingCode")?.trim().orEmpty()
        val peerId = call.argument<String>("peerId")?.trim().orEmpty()
        if (host.isEmpty() || peerId.isEmpty() || !Regex("^\\d{6}$").matches(pairingCode)) {
            result.success(mapOf("status" to "invalid_request"))
            return
        }
        executor.execute {
            var socket: Socket? = null
            try {
                socket = Socket()
                socket.connect(InetAddress.getByName(host).let { java.net.InetSocketAddress(it, port) }, CONNECT_TIMEOUT_MS)
                socket.soTimeout = 15000
                val requestId = UUID.randomUUID().toString()
                val reader = socket.reader()
                val writer = socket.writer()
                writer.write(
                    JSONObject()
                        .put("type", "pair_request")
                        .put("requestId", requestId)
                        .put("deviceId", myDeviceId)
                        .put("deviceName", myDeviceName)
                        .put("pairingCode", pairingCode)
                        .put("port", CONTROL_PORT)
                        .toString(),
                )
                writer.newLine()
                writer.flush()
                val firstReply = reader.readLine()?.let { JSONObject(it) }
                val status = if (firstReply?.optString("status") == "pending_approval") {
                    reader.readLine()?.let { JSONObject(it) }?.optString("status", "rejected") ?: "rejected"
                } else {
                    firstReply?.optString("status", "rejected") ?: "rejected"
                }
                val finalReply = if (firstReply?.optString("status") == "pending_approval") {
                    // The second line is the target's final approval response.
                    JSONObject().put("status", status)
                } else {
                    firstReply ?: JSONObject().put("status", status)
                }
                if (status == "approved") {
                    pairedPeers[peerId] = mutableMapOf(
                        "peerId" to peerId,
                        "name" to "JARVIS Device",
                        "host" to host,
                        "port" to port,
                        "transport" to "lan_paired",
                        "allowAnytime" to finalReply.optBoolean("allowAnytime", false),
                    )
                }
                val response = mapOf(
                    "status" to status,
                    "peerId" to peerId,
                    "requestId" to requestId,
                    "message" to finalReply.optString("message"),
                )
                mainHandler.post { result.success(response) }
            } catch (error: Exception) {
                mainHandler.post { result.success(mapOf("status" to "transport_error", "message" to (error.message ?: "connection failed"))) }
            } finally {
                closeQuietly(socket)
            }
        }
    }

    private fun handleIncoming(socket: Socket) {
        try {
            socket.soTimeout = CONNECT_TIMEOUT_MS
            val reader = socket.reader()
            val writer = socket.writer()
            val payload = reader.readLine()?.let { JSONObject(it) } ?: return
            when (payload.optString("type")) {
                "jarvis_discover" -> {
                    writer.write(
                        JSONObject()
                            .put("type", "jarvis_announce")
                            .put("deviceId", myDeviceId)
                            .put("deviceName", myDeviceName)
                            .put("port", CONTROL_PORT)
                            .toString(),
                    )
                    writer.newLine()
                    writer.flush()
                }
                "pair_request" -> {
                    val requestId = payload.optString("requestId")
                    val senderCode = payload.optString("pairingCode")
                    val senderId = payload.optString("deviceId")
                    if (senderId.isEmpty() || !senderCode.matches(Regex("^\\d{6}$")) || senderCode != myPairingCode) {
                        writer.write(JSONObject().put("status", "rejected").put("message", "invalid pairing code").toString())
                        writer.newLine()
                        writer.flush()
                        return
                    }
                    pendingRequests[requestId] = socket
                    pendingPeerMetadata[requestId] = mutableMapOf(
                        "peerId" to senderId,
                        "name" to payload.optString("deviceName", "JARVIS Device"),
                        "host" to (socket.inetAddress.hostAddress ?: ""),
                        "port" to payload.optInt("port", CONTROL_PORT),
                        "transport" to "lan_pending",
                    )
                    writer.write(JSONObject().put("status", "pending_approval").put("requestId", requestId).toString())
                    writer.newLine()
                    writer.flush()
                    emit("pair_request", mapOf(
                        "requestId" to requestId,
                        "peerId" to senderId,
                        "name" to payload.optString("deviceName", "JARVIS Device"),
                        "host" to (socket.inetAddress.hostAddress ?: ""),
                        "port" to payload.optInt("port", CONTROL_PORT),
                    ))
                    return
                }
            }
        } catch (_: Exception) {
        } finally {
            // A pending pair request owns the socket until the target decides.
            if (!pendingRequests.containsValue(socket)) closeQuietly(socket)
        }
    }

    private fun approvePairRequest(call: MethodCall, result: MethodChannel.Result) {
        val requestId = call.argument<String>("requestId")?.trim().orEmpty()
        val allowAnytime = call.argument<Boolean>("allowAnytime") ?: false
        val socket = pendingRequests.remove(requestId)
        val metadata = pendingPeerMetadata.remove(requestId)
        if (socket == null) {
            result.success(mapOf("status" to "not_found"))
            return
        }
        try {
            val writer = socket.writer()
            writer.write(JSONObject().put("status", "approved").put("allowAnytime", allowAnytime).toString())
            writer.newLine()
            writer.flush()
            if (metadata != null) {
                metadata["transport"] = "lan_paired"
                metadata["allowAnytime"] = allowAnytime
                pairedPeers[metadata["peerId"].toString()] = metadata
            }
            closeQuietly(socket)
            result.success(mapOf("status" to "approved", "requestId" to requestId, "allowAnytime" to allowAnytime))
        } catch (error: Exception) {
            closeQuietly(socket)
            result.success(mapOf("status" to "transport_error", "message" to (error.message ?: "approval failed")))
        }
    }

    private fun rejectPairRequest(call: MethodCall, result: MethodChannel.Result) {
        val requestId = call.argument<String>("requestId")?.trim().orEmpty()
        val socket = pendingRequests.remove(requestId)
        pendingPeerMetadata.remove(requestId)
        if (socket == null) {
            result.success(mapOf("status" to "not_found"))
            return
        }
        try {
            val writer = socket.writer()
            writer.write(JSONObject().put("status", "rejected").put("message", "target denied access").toString())
            writer.newLine()
            writer.flush()
        } catch (_: Exception) {
        }
        closeQuietly(socket)
        result.success(mapOf("status" to "rejected", "requestId" to requestId))
    }

    private fun emit(method: String, payload: Map<String, Any>) {
        mainHandler.post { channel.invokeMethod(method, payload) }
    }

    private fun Socket.reader(): BufferedReader = BufferedReader(InputStreamReader(getInputStream(), Charsets.UTF_8))
    private fun Socket.writer(): BufferedWriter = BufferedWriter(OutputStreamWriter(getOutputStream(), Charsets.UTF_8))
    private fun closeQuietly(socket: Socket?) {
        if (socket == null) return
        try {
            socket.close()
        } catch (_: Exception) {
        }
    }
}
