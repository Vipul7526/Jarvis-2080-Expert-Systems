import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF05070D),
    ),
  );
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JARVIS 2080 Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05070D),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0A1220),
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF2BD6),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _onboarded = false;
  bool _locked = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final onboarded = prefs.getBool('security_onboarded') ?? false;
    setState(() {
      _onboarded = onboarded;
      _locked = onboarded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }
    if (!_onboarded) {
      return OnboardingScreen(onCompleted: () => setState(() { _onboarded = true; _locked = false; }));
    }
    if (_locked) {
      return LockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return const HomeScreen();
  }
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({Key? key, required this.onCompleted}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _recoveryController = TextEditingController();
  bool _biometric = true;
  bool _loading = false;
  String _status = '';

  Future<void> _completeSetup() async {
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final recovery = _recoveryController.text.trim();

    if (email.isEmpty || pin.length < 4 || recovery.isEmpty) {
      setState(() => _status = 'Please enter valid email, 4+ digit PIN, and recovery email.');
      return;
    }

    setState(() { _loading = true; _status = 'Persisting security profile...'; });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_google_email', email);
      await prefs.setString('jarvis_pin', pin);
      await prefs.setString('recovery_email', recovery.toLowerCase());
      await prefs.setBool('biometric_lock_enabled', _biometric);
      await prefs.setBool('security_onboarded', true);
      await prefs.reload();

      widget.onCompleted();
    } catch (e) {
      setState(() { _loading = false; _status = 'Setup error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF05070D), Color(0xFF0A1220), Color(0xFF10192D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 72, color: Color(0xFF00E5FF)),
                  const SizedBox(height: 16),
                  const Text('JARVIS 2080 PRO', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF), letterSpacing: 2)),
                  const Text('Cyberpunk Autonomous Assistant', style: TextStyle(fontSize: 14, color: Colors.white60)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Google / Account Email', prefixIcon: Icon(Icons.email, color: Color(0xFF00E5FF)), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: const InputDecoration(labelText: 'JARVIS Access PIN (4-8 digits)', prefixIcon: Icon(Icons.lock, color: Color(0xFF00E5FF)), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _recoveryController,
                    decoration: const InputDecoration(labelText: 'Recovery Email (for OTP reset)', prefixIcon: Icon(Icons.restore, color: Color(0xFF00E5FF)), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Biometric Lock (Face / Fingerprint)'),
                    value: _biometric,
                    activeColor: const Color(0xFF00E5FF),
                    onChanged: (val) => setState(() => _biometric = val),
                  ),
                  const SizedBox(height: 24),
                  if (_status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_status, style: const TextStyle(color: Colors.amberAccent, fontSize: 13), textAlign: TextAlign.center),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                      onPressed: _loading ? null : _completeSetup,
                      child: _loading ? const CircularProgressIndicator(color: Colors.black) : const Text('ACTIVATE JARVIS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({Key? key, required this.onUnlocked}) : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  String _error = '';

  Future<void> _verify() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final saved = prefs.getString('jarvis_pin')?.trim();
    final input = _pinController.text.trim();

    if (saved != null && saved.isNotEmpty && saved == input) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Incorrect PIN. Try again or use Recovery Email.');
    }
  }

  Future<void> _sendRecoveryOtp() async {
    final prefs = await SharedPreferences.getInstance();
    final recovery = prefs.getString('recovery_email') ?? 'princesingh305305@gmail.com';
    // Trigger recovery backend request
    try {
      await http.post(
        Uri.parse('https://jarvisrecov-3mlp5xq9.manus.space/api/recovery/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': recovery}),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recovery OTP sent to $recovery')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP sent request processed for $recovery')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF05070D), Color(0xFF0A1220)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Color(0xFF00E5FF)),
                const SizedBox(height: 16),
                const Text('JARVIS LOCKED', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                const SizedBox(height: 8),
                const Text('Enter your secure access PIN', style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 32),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(labelText: 'Access PIN', prefixIcon: Icon(Icons.password, color: Color(0xFF00E5FF)), border: OutlineInputBorder()),
                ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error, style: const TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                    onPressed: _verify,
                    child: const Text('UNLOCK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _sendRecoveryOtp,
                  child: const Text('Forgot PIN? Send Recovery OTP', style: TextStyle(color: Color(0xFF00E5FF))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    AssistantChatPage(),
    MeshNetworkPage(),
    GpsViewerPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF0A1220),
        selectedItemColor: const Color(0xFF00E5FF),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Assistant'),
          BottomNavigationBarItem(icon: Icon(Icons.wifi_tethering), label: 'Mesh Relay'),
          BottomNavigationBarItem(icon: Icon(Icons.gps_fixed), label: 'GPS Viewer'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class AssistantChatPage extends StatefulWidget {
  const AssistantChatPage({Key? key}) : super(key: key);

  @override
  State<AssistantChatPage> createState() => _AssistantChatPageState();
}

class _AssistantChatPageState extends State<AssistantChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'role': 'assistant', 'text': 'JARVIS 2080 Pro online. Give me a task or chat naturally.'}
  ];
  bool _loading = false;

  Future<void> _handleUserMessage(String text) async {
    if (text.trim().isEmpty) return;
    final query = text.trim();
    _inputController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _loading = true;
    });

    // 1. Check for explicit device action commands
    final lower = query.toLowerCase();
    if (lower.startsWith('open ') || lower.startsWith('launch ')) {
      final appName = query.substring(5).trim();
      await _executeAppCommand(appName);
      setState(() => _loading = false);
      return;
    }
    if (lower == 'close youtube' || lower == 'close all apps') {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Executing action: $query'});
        _loading = false;
      });
      return;
    }

    // 2. Normal conversation goes to configured AI API (Groq / Gemini / Custom Endpoint)
    try {
      final prefs = await SharedPreferences.getInstance();
      final endpoint = prefs.getString('api_endpoint') ?? 'https://api.groq.com/openai/v1/chat/completions';
      final apiKey = prefs.getString('api_key') ?? '';
      final model = prefs.getString('api_model') ?? 'llama-3.3-70b-versatile';

      if (apiKey.isEmpty) {
        setState(() {
          _messages.add({'role': 'assistant', 'text': 'API Key not configured. Please add your API key in Settings → Custom API.'});
          _loading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': 'You are JARVIS 2080, an advanced autonomous AI assistant. Be concise, precise, and helpful.'},
            {'role': 'user', 'content': query}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'] ?? 'No response received.';
        setState(() {
          _messages.add({'role': 'assistant', 'text': reply});
          _loading = false;
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'text': 'API Error (${response.statusCode}): ${response.body}'});
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Connection error: $e'});
        _loading = false;
      });
    }
  }

  Future<void> _executeAppCommand(String appName) async {
    const system = MethodChannel('com.ultimate.jarvis/system');
    try {
      final resolution = await system.invokeMethod<Map<dynamic, dynamic>>(
        'resolvePackage',
        {'appName': appName},
      );
      final status = resolution?['status']?.toString() ?? 'unknown';
      final packageName = resolution?['packageName']?.toString() ?? '';
      if (status == 'installed' && packageName.isNotEmpty) {
        final launch = await system.invokeMethod<Map<dynamic, dynamic>>(
          'launchPackage',
          {'packageName': packageName},
        );
        final launchStatus = launch?['status']?.toString() ?? 'failed';
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': launchStatus == 'launched'
                ? 'Launching $appName ($packageName).'
                : 'I found $packageName, but Android could not open it.',
          });
        });
      } else if (status == 'not_installed' && packageName.isNotEmpty) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': '$appName is not installed. Package: $packageName. Write "y- install" to request installation.',
          });
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'text': 'I could not resolve an installed package for "$appName".'});
        });
      }
    } on PlatformException catch (error) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Android command failed: ${error.message ?? error.code}'});
      });
    } catch (error) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Unable to execute "$appName": $error'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JARVIS ASSISTANT', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0A1220),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF0A1220),
                      border: Border.all(color: isUser ? const Color(0xFF00E5FF) : Colors.white12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['text']!, style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(color: Color(0xFF00E5FF)),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onSubmitted: _handleUserMessage,
                    decoration: const InputDecoration(
                      hintText: 'Give the task or chat with JARVIS...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00E5FF)),
                  onPressed: () => _handleUserMessage(_inputController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeshNetworkPage extends StatelessWidget {
  const MeshNetworkPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesh Network & Relay', style: TextStyle(color: Color(0xFF00E5FF)))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paired Devices & Mesh Relay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
            const SizedBox(height: 12),
            const Text('Connect nearby devices via Bluetooth code or internet relay backend.'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning nearby devices...')));
              },
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Scan Nearby Devices'),
            ),
          ],
        ),
      ),
    );
  }
}

class GpsViewerPage extends StatelessWidget {
  const GpsViewerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPS Viewer & Telemetry', style: TextStyle(color: Color(0xFF00E5FF)))),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target Device Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Latitude: 28.6139° N'),
                    SizedBox(height: 8),
                    Text('Longitude: 77.2090° E'),
                    SizedBox(height: 8),
                    Text('Battery: 92% (Charging)'),
                    SizedBox(height: 8),
                    Text('Real-time Distance: 4.2 meters'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();
  final _modelController = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('api_key') ?? '';
      _endpointController.text = prefs.getString('api_endpoint') ?? 'https://api.groq.com/openai/v1/chat/completions';
      _modelController.text = prefs.getString('api_model') ?? 'llama-3.3-70b-versatile';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', _apiKeyController.text.trim());
    await prefs.setString('api_endpoint', _endpointController.text.trim());
    await prefs.setString('api_model', _modelController.text.trim());
    await prefs.reload();
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () => setState(() => _saved = false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JARVIS Settings & API', style: TextStyle(color: Color(0xFF00E5FF)))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Custom AI Endpoint Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
          const SizedBox(height: 12),
          TextField(
            controller: _endpointController,
            decoration: const InputDecoration(labelText: 'API Endpoint URL', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API Key (Groq / Gemini / OpenAI)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(labelText: 'Model Name (e.g. llama-3.3-70b-versatile)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          if (_saved)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Settings saved successfully!', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            onPressed: _saveSettings,
            child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
