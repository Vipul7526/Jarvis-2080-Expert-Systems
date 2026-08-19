import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'services/auth_service.dart';
import 'services/mesh_service.dart';
import 'services/mesh_relay_service.dart';
import 'services/system_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  await SystemService.init();
  await MeshService.init();
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
        scaffoldBackgroundColor: const Color(0xFF030712),
        primaryColor: const Color(0xFF00F5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F5FF),
          secondary: Color(0xFFFF007F),
          surface: Color(0xFF0A0F1D),
        ),
        fontFamily: 'monospace',
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
  bool _isSetUp = false;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final setUp = await AuthService.isSetUp();
    final locked = await AuthService.isLocked();
    setState(() {
      _isSetUp = setUp;
      _isLocked = locked;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00F5FF)),
        ),
      );
    }
    if (!_isSetUp) {
      return OnboardingScreen(onCompleted: () => setState(() => _isSetUp = true));
    }
    if (_isLocked) {
      return LockScreen(onUnlocked: () => setState(() => _isLocked = false));
    }
    return const MainDashboard();
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
  bool _googleSignedIn = false;
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final email = await AuthService.simulateGoogleSignIn();
      setState(() {
        if (email != null) {
          _emailController.text = email;
          _googleSignedIn = true;
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final recovery = _recoveryController.text.trim();
    if (email.isEmpty || pin.length < 4) {
      ScaffoldAbbBarHelper.showSnack(context, 'Please enter a valid email and at least a 4-digit PIN.');
      return;
    }
    setState(() => _isLoading = true);
    await AuthService.completeSetup(email: email, pin: pin, recoveryEmail: recovery);
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF030712), Color(0xFF0A1128), Color(0xFF130A24)],
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
                  const Text(
                    'J.A.R.V.I.S. 2080',
                    style: TextStyle(
                      color: Color(0xFF00F5FF),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PRO EXPERT SYSTEMS SETUP',
                    style: TextStyle(color: Color(0xFFFF007F), fontSize: 12, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: Text(_googleSignedIn ? 'Google Account Connected' : 'Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _googleSignedIn ? Colors.green[800] : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Google / User Email',
                      prefixIcon: Icon(Icons.email, color: Color(0xFF00F5FF)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Security PIN (4+ digits)',
                      prefixIcon: Icon(Icons.lock, color: Color(0xFF00F5FF)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _recoveryController,
                    decoration: const InputDecoration(
                      labelText: 'Recovery Email (for OTP)',
                      prefixIcon: Icon(Icons.security, color: Color(0xFF00F5FF)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F5FF),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: const Text('ACTIVATE JARVIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
  bool _useBiometric = true;

  @override
  void initState() {
    super.initState();
    _attemptBiometric();
  }

  Future<void> _attemptBiometric() async {
    if (!_useBiometric) return;
    final success = await AuthService.promptBiometric();
    if (success) {
      widget.onUnlocked();
    }
  }

  Future<void> _verifyPin() async {
    final success = await AuthService.verifyPin(_pinController.text.trim());
    if (success) {
      widget.onUnlocked();
    } else {
      ScaffoldAbbBarHelper.showSnack(context, 'Invalid PIN. Try again or use Recovery Email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF030712), Color(0xFF1C0A28)],
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
                const Icon(Icons.fingerprint, size: 80, color: Color(0xFF00F5FF)),
                const SizedBox(height: 16),
                const Text('JARVIS SECURITY LOCK', style: TextStyle(color: Color(0xFF00F5FF), fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Enter PIN', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _verifyPin,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5FF), foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                  child: const Text('UNLOCK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _attemptBiometric,
                  child: const Text('Use Biometric (Fingerprint / Face)', style: TextStyle(color: Color(0xFFFF007F))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const AssistantPage(),
    const TerminalPage(),
    const MeshRelayPage(),
    const GpsViewerPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0A0F1D),
        selectedItemColor: const Color(0xFF00F5FF),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Assistant'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'Terminal'),
          BottomNavigationBarItem(icon: Icon(Icons.hub), label: 'Mesh'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'GPS'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class AssistantPage extends StatefulWidget {
  const AssistantPage({Key? key}) : super(key: key);

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> with SingleTickerProviderStateMixin {
  final List<Map<String, String>> _messages = [
    {'role': 'assistant', 'text': 'J.A.R.V.I.S. 2080 online. Awaiting your command or query.'}
  ];
  final _inputController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    SystemService.requestPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty) return;
    final prompt = text.trim();
    _inputController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
    });

    // Check explicit command
    final lower = prompt.toLowerCase();
    if (lower.startsWith('open ') || lower.startsWith('launch ') || lower == 'open youtube') {
      final appName = lower.replaceFirst('open ', '').replaceFirst('launch ', '').trim();
      await _executeAppCommand(appName);
      return;
    }

    // Otherwise route to AI API
    await _queryAiApi(prompt);
  }

  Future<void> _executeAppCommand(String appName) async {
    const system = MethodChannel('com.ultimate.jarvis/system');
    try {
      final resolution = await system.invokeMethod<Map<dynamic, dynamic>>('resolvePackage', {'appName': appName});
      final status = resolution?['status']?.toString() ?? 'unknown';
      final packageName = resolution?['packageName']?.toString() ?? '';
      if (status == 'installed' && packageName.isNotEmpty) {
        final launch = await system.invokeMethod<Map<dynamic, dynamic>>('launchPackage', {'packageName': packageName});
        final launchStatus = launch?['status']?.toString() ?? 'failed';
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': launchStatus == 'launched' ? 'Executing: Launched $appName ($packageName).' : 'Found $packageName, but Android failed to launch it.',
          });
        });
      } else if (status == 'not_installed' && packageName.isNotEmpty) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': '$appName is not installed. Package: $packageName. Write "y- install" to initiate setup.',
          });
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'text': 'Could not resolve package for "$appName".'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Command execution error: $e'});
      });
    }
  }

  Future<void> _queryAiApi(String prompt) async {
    final prefs = await AuthService.getPrefs();
    final url = prefs.getString('api_endpoint') ?? 'https://api.groq.com/openai/v1/chat/completions';
    final key = prefs.getString('api_key') ?? '';
    final model = prefs.getString('api_model') ?? 'llama-3.3-70b-versatile';

    if (key.isEmpty) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'API key not configured. Please add your API key in Settings.'});
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': 'You are JARVIS 2080, an advanced cyberpunk AI assistant created by Prince Singh. Respond concisely and efficiently.'},
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'] ?? 'No response content.';
        setState(() {
          _messages.add({'role': 'assistant', 'text': reply});
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'text': 'API Error (${response.statusCode}): ${response.body}'});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Connection error: $e'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('J.A.R.V.I.S. HELD', style: TextStyle(color: Color(0xFF00F5FF), letterSpacing: 1.5)),
        backgroundColor: const Color(0xFF0A0F1D),
      ),
      body: Column(
        children: [
          // Holographic Spherical Visualizer
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00F5FF).withOpacity(0.25 + 0.1 * _pulseController.value),
                      const Color(0xFF130A24).withOpacity(0.9),
                    ],
                    radius: 0.85,
                  ),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100 + (20 * _pulseController.value),
                        height: 100 + (20 * _pulseController.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.6), width: 2),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFF00F5FF), Color(0xFFFF007F)]),
                          boxShadow: [BoxShadow(color: const Color(0xFF00F5FF).withOpacity(0.8), blurRadius: 20)],
                        ),
                        child: const Center(
                          child: Icon(Icons.remove_red_eye, color: Colors.black, size: 32),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00F5FF).withOpacity(0.15) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isUser ? const Color(0xFF00F5FF) : const Color(0xFFFF007F), width: 0.8),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onSubmitted: _handleSubmit,
                    decoration: const InputDecoration(
                      hintText: 'Give the task or chat with JARVIS...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _handleSubmit(_inputController.text),
                  icon: const Icon(Icons.send, color: Color(0xFF00F5FF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final List<String> _logs = ['JARVIS Terminal v2080 active.', 'Type command (e.g. ls, mkdir, rm, uptime, files).'];
  final _ctrl = TextEditingController();

  void _runCommand(String cmd) {
    setState(() {
      _logs.add('> $cmd');
      if (cmd == 'ls') {
        _logs.addAll(['/storage/emulated/0/Jarvis', 'Documents/', 'Downloads/', 'mesh_payloads/']);
      } else if (cmd == 'uptime') {
        _logs.add('System uptime: 42 hours, core stable.');
      } else {
        _logs.add('Executed "$cmd" successfully.');
      }
    });
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SYSTEM TERMINAL', style: TextStyle(color: Color(0xFF00F5FF)))),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (c, i) => Text(_logs[i], style: const TextStyle(color: Color(0xFF00F5FF), fontFamily: 'monospace', fontSize: 13)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _ctrl,
              onSubmitted: _runCommand,
              decoration: const InputDecoration(hintText: 'Enter terminal command...', border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
    );
  }
}

class MeshRelayPage extends StatelessWidget {
  const MeshRelayPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MESH NETWORK RELAY', style: TextStyle(color: Color(0xFF00F5FF)))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nearby Bluetooth & LAN Devices', style: TextStyle(color: Color(0xFF00F5FF), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.phone_android, color: Color(0xFF00F5FF)),
                    title: Text('JARVIS-TARGET-GALAXY'),
                    subtitle: Text('Distance: 3.8m | Signal: Strong'),
                    trailing: Text('PAIRED', style: TextStyle(color: Colors.green)),
                  ),
                ],
              ),
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
      appBar: AppBar(title: const Text('GPS VIEWER & TELEMETRY', style: TextStyle(color: Color(0xFF00F5FF)))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target Device Location', style: TextStyle(color: Color(0xFF00F5FF), fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Latitude: 28.6139° N'),
                  Text('Longitude: 77.2090° E'),
                  Text('Battery: 92% (Charging)'),
                  Text('Real-time Distance: 3.8 meters'),
                ],
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
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  String _selectedModel = 'llama-3.3-70b-versatile';
  final List<String> _fetchedModels = [
    'llama-3.3-70b-versatile',
    'llama3-8b-8192',
    'mixtral-8x7b-32768',
    'gemini-1.5-pro',
    'gpt-4o-mini'
  ];
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await AuthService.getPrefs();
    setState(() {
      _urlCtrl.text = prefs.getString('api_endpoint') ?? 'https://api.groq.com/openai/v1/chat/completions';
      _keyCtrl.text = prefs.getString('api_key') ?? '';
      _selectedModel = prefs.getString('api_model') ?? 'llama-3.3-70b-versatile';
    });
  }

  Future<void> _fetchModelsFromApi() async {
    setState(() => _fetching = true);
    try {
      final key = _keyCtrl.text.trim();
      final response = await http.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {'Authorization': 'Bearer $key'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List?)?.map((e) => e['id'].toString()).toList();
        if (list != null && list.isNotEmpty) {
          setState(() {
            _fetchedModels.clear();
            _fetchedModels.addAll(list);
          });
          ScaffoldAbbBarHelper.showSnack(context, 'Successfully fetched ${list.length} models!');
        }
      } else {
        ScaffoldAbbBarHelper.showSnack(context, 'Failed to fetch models: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldAbbBarHelper.showSnack(context, 'Error fetching models: $e');
    } finally {
      setState(() => _fetching = false);
    }
  }

  Future<void> _save() async {
    final prefs = await AuthService.getPrefs();
    await prefs.setString('api_endpoint', _urlCtrl.text.trim());
    await prefs.setString('api_key', _keyCtrl.text.trim());
    await prefs.setString('api_model', _selectedModel);
    ScaffoldAbbBarHelper.showSnack(context, 'Settings saved successfully.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JARVIS SETTINGS & API', style: TextStyle(color: Color(0xFF00F5FF)))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'API Endpoint URL', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _keyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'API Key (Groq / Gemini / OpenAI)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _fetchedModels.contains(_selectedModel) ? _selectedModel : _fetchedModels.first,
                  dropdownColor: const Color(0xFF0A0F1D),
                  items: _fetchedModels.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _selectedModel = val ?? _selectedModel),
                  decoration: const InputDecoration(labelText: 'Select AI Model', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _fetching ? null : _fetchModelsFromApi,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5FF), foregroundColor: Colors.black),
                child: _fetching ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Fetch'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5FF), foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
            child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class ScaffoldAbbBarHelper {
  static void showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
