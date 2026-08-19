import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'services/auth_service.dart';
import 'services/mesh_service.dart';
import 'services/system_service.dart';
import 'services/tab_lock_service.dart';

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
        fontFamily: 'Orbitron',
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
      return OnboardingScreen(
          onCompleted: () => setState(() => _isSetUp = true));
    }
    if (_isLocked) {
      return LockScreen(onUnlocked: () => setState(() => _isLocked = false));
    }
    return const MainDashboard();
  }
}

enum JarvisVisualState { idle, listening, thinking, talking }

class HolographicCore extends StatefulWidget {
  final double size;
  final JarvisVisualState state;
  final double intensity;

  const HolographicCore({
    Key? key,
    this.size = 220,
    this.state = JarvisVisualState.idle,
    this.intensity = 0.55,
  }) : super(key: key);

  @override
  State<HolographicCore> createState() => _HolographicCoreState();
}

class _HolographicCoreState extends State<HolographicCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  Color get _accent {
    switch (widget.state) {
      case JarvisVisualState.listening:
        return const Color(0xFF32F5FF);
      case JarvisVisualState.thinking:
        return const Color(0xFFA970FF);
      case JarvisVisualState.talking:
        return const Color(0xFFFFB86B);
      case JarvisVisualState.idle:
        return const Color(0xFF00F5FF);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * math.pi * 2;
        final pulse =
            1 + math.sin(phase * 2) * (0.028 + widget.intensity * 0.045);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * (0.96 + math.sin(phase) * 0.025),
                height: widget.size * (0.96 + math.sin(phase) * 0.025),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_accent.withOpacity(0.20), Colors.transparent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          _accent.withOpacity(0.20 + widget.intensity * 0.18),
                      blurRadius: 42,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ParticleSpherePainter(
                  phase: phase,
                  color: _accent,
                  intensity: widget.intensity,
                ),
              ),
              Transform.rotate(
                angle: phase * 0.22,
                child: CustomPaint(
                  size: Size(widget.size * 0.94, widget.size * 0.94),
                  painter: _OrbitRingPainter(color: _accent, phase: phase),
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: widget.size * 0.18,
                  height: widget.size * 0.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white,
                        _accent,
                        _accent.withOpacity(0.12),
                      ],
                      stops: const [0.0, 0.22, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.72),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.96),
                        blurRadius: 34 + widget.intensity * 20,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.state == JarvisVisualState.listening
                        ? Icons.mic_none_rounded
                        : Icons.bolt_rounded,
                    color: const Color(0xFF03101A),
                    size: widget.size * 0.075,
                  ),
                ),
              ),
              Positioned(
                bottom: widget.size * 0.045,
                child: Text(
                  widget.state == JarvisVisualState.listening
                      ? 'LISTENING'
                      : widget.state == JarvisVisualState.thinking
                          ? 'PROCESSING'
                          : widget.state == JarvisVisualState.talking
                              ? 'RESPONDING'
                              : 'CORE ONLINE',
                  style: TextStyle(
                    color: _accent.withOpacity(0.95),
                    fontSize: math.max(8, widget.size * 0.043),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParticleSpherePainter extends CustomPainter {
  final double phase;
  final Color color;
  final double intensity;

  const _ParticleSpherePainter({
    required this.phase,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.37;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.22 + intensity * 0.12),
          color.withOpacity(0.045),
          Colors.transparent,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.55));
    canvas.drawCircle(center, radius * 1.32, glow);

    for (var i = 0; i < 420; i++) {
      final seed = (i * 0.6180339887) % 1.0;
      final latitude = math.asin(-1.0 + 2.0 * seed);
      final longitude = i * 2.3999632297 + phase * (0.34 + seed * 0.30);
      final shell = radius * (0.88 + (math.sin(i * 7.13) + 1) * 0.035);
      final depth = math.cos(latitude) * math.cos(longitude);
      final x = math.cos(latitude) * math.sin(longitude) * shell;
      final y = math.sin(latitude) * shell;
      final perspective = 0.52 + 0.48 * ((depth + 1) / 2);
      final point = Offset(center.dx + x, center.dy + y);
      final opacity = (0.12 + perspective * 0.76) *
          (0.70 + intensity * 0.55) *
          (0.72 + math.sin(phase * 3.0 + i * 0.17) * 0.18);
      final sizeFactor = 0.45 +
          perspective * 1.45 +
          math.max(0, math.sin(phase * 4 + i * 0.71)) * 0.65;
      final particle = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(point, sizeFactor, particle);

      if (i % 31 == 0 && depth > -0.2) {
        final trail = Offset(
          point.dx + math.cos(longitude) * 5.0,
          point.dy + math.sin(latitude) * 5.0,
        );
        canvas.drawLine(point, trail, particle..strokeWidth = 0.8);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleSpherePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.intensity != intensity;
}

class _OrbitRingPainter extends CustomPainter {
  final Color color;
  final double phase;

  const _OrbitRingPainter({required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.39;
    final paint = Paint()
      ..color = color.withOpacity(0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 3; i++) {
      final tilt = 0.18 + i * 0.19 + math.sin(phase + i) * 0.04;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(phase * (i.isEven ? 0.14 : -0.10));
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: radius * 2.2, height: radius * tilt),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({Key? key, required this.onCompleted})
      : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _recoveryController = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final success = await _authService.signInWithGoogle();
      final email = await _authService.registeredEmail;
      if (success && email != null && email.isNotEmpty) {
        setState(() {
          _emailController.text = email;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Account Connected: $email')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Google Sign-In canceled or unavailable. Please enter email manually.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final recovery = _recoveryController.text.trim();
    if (email.isEmpty || pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid email and a 4+ digit PIN.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await AuthService.completeSetupStatic(
        email: email, pin: pin, recoveryEmail: recovery);
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
                  const HolographicCore(size: 190),
                  const SizedBox(height: 18),
                  const Text(
                    'J.A.R.V.I.S. 2080',
                    style: TextStyle(
                      color: Color(0xFF00F5FF),
                      fontFamily: 'Orbitron',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PRO EXPERT SYSTEMS ONBOARDING',
                    style: TextStyle(
                        color: Color(0xFFFF007F),
                        fontSize: 11,
                        letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Sign in with Google (Account Picker)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF00F5FF),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'User Email / Google Account',
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
                      prefixIcon:
                          Icon(Icons.security, color: Color(0xFF00F5FF)),
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
                    child: const Text('ACTIVATE JARVIS',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
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

  Future<void> _attemptBiometric() async {
    final success = await AuthService.promptBiometric();
    if (success) {
      widget.onUnlocked();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Biometric authentication failed or cancelled.')),
      );
    }
  }

  Future<void> _verifyPin() async {
    final success =
        await AuthService.verifyPinStatic(_pinController.text.trim());
    if (success) {
      widget.onUnlocked();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid PIN. Please try again.')),
      );
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
                const Icon(Icons.fingerprint,
                    size: 80, color: Color(0xFF00F5FF)),
                const SizedBox(height: 16),
                const Text('JARVIS SECURITY LOCK',
                    style: TextStyle(
                        color: Color(0xFF00F5FF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Enter PIN', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _verifyPin,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F5FF),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50)),
                  child: const Text('UNLOCK',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _attemptBiometric,
                  child: const Text('Use Biometric (Fingerprint / Face)',
                      style: TextStyle(color: Color(0xFFFF007F))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class JarvisGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const JarvisGlass({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF091321).withOpacity(0.78),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFF32F5FF).withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF00F5FF).withOpacity(0.06),
              blurRadius: 24,
              spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

class _HudBackdropPainter extends CustomPainter {
  const _HudBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF32F5FF).withOpacity(0.045)
      ..strokeWidth = 0.5;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, const Color(0xFF02050C).withOpacity(0.78)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _HudBackdropPainter oldDelegate) => false;
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    AssistantPage(),
    TerminalPage(),
    MeshRelayPage(),
    GpsViewerPage(),
    TabLockPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050C),
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            height: 70,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            backgroundColor: const Color(0xFF07101D).withOpacity(0.96),
            indicatorColor: const Color(0xFF00F5FF).withOpacity(0.18),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.bolt_outlined),
                  selectedIcon: Icon(Icons.bolt),
                  label: 'Core'),
              NavigationDestination(
                  icon: Icon(Icons.terminal_outlined),
                  selectedIcon: Icon(Icons.terminal),
                  label: 'Terminal'),
              NavigationDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub),
                  label: 'Mesh'),
              NavigationDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: 'GPS'),
              NavigationDestination(
                  icon: Icon(Icons.lock_outline),
                  selectedIcon: Icon(Icons.lock),
                  label: 'Tab Lock'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}

class AssistantPage extends StatefulWidget {
  const AssistantPage({Key? key}) : super(key: key);

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage>
    with SingleTickerProviderStateMixin {
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'text': 'Core online. Real device actions are ready; ask or speak a task.'
    }
  ];
  final _inputController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  late AnimationController _pulseController;
  JarvisVisualState _visualState = JarvisVisualState.idle;
  bool _speechReady = false;
  bool _isListening = false;
  String _lastMissingPackage = '';

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.microphone,
    ].request();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    _inputController.dispose();
    super.dispose();
  }

  void _addAssistant(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'assistant', 'text': text});
      _visualState = JarvisVisualState.talking;
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _visualState = JarvisVisualState.idle);
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted)
        setState(() {
          _isListening = false;
          _visualState = JarvisVisualState.idle;
        });
      return;
    }
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _addAssistant('Microphone permission is required for voice commands.');
      return;
    }
    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && mounted) {
          setState(() {
            _isListening = false;
            _visualState = JarvisVisualState.idle;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _visualState = JarvisVisualState.idle;
          });
          _addAssistant('Speech recognition error: ${error.errorMsg}');
        }
      },
    );
    if (!_speechReady) {
      _addAssistant('Speech recognition is unavailable on this device.');
      return;
    }
    setState(() {
      _isListening = true;
      _visualState = JarvisVisualState.listening;
    });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _inputController.text = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _speech.stop();
          setState(() {
            _isListening = false;
            _visualState = JarvisVisualState.thinking;
          });
          _handleSubmit(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty) return;
    final prompt = text.trim();
    _inputController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
      _visualState = JarvisVisualState.thinking;
    });

    final lower = prompt.toLowerCase();
    if (lower == 'show commands' ||
        lower == 'help' ||
        lower == 'command center') {
      _addAssistant(
          'Command Center online: ${jarvisCommandCatalog.length}+ routed capabilities. Scroll the catalog from the command menu.');
      return;
    }
    if (lower.contains('prank') ||
        lower.contains('hacking dashboard') ||
        lower == 'simulation') {
      _addAssistant(
          'That visual simulation module has been removed. I can help with real device, mesh, terminal, GPS, and assistant tasks.');
      return;
    }
    if (lower.startsWith('open ') || lower.startsWith('launch ')) {
      final appName =
          lower.replaceFirst('open ', '').replaceFirst('launch ', '').trim();
      await _executeAppCommand(appName);
      return;
    }
    if (lower.startsWith('y- open ')) {
      await _launchPackageDirect(lower.substring(8).trim());
      return;
    }
    if (lower == 'y- install' || lower.startsWith('y- install ')) {
      await _openInstallPage(lower.replaceFirst('y- install', '').trim());
      return;
    }
    if (lower.contains('device status') ||
        lower == 'status' ||
        lower.contains('battery')) {
      await _readDeviceStatus();
      return;
    }
    if (lower.contains('wifi settings') || lower == 'open wifi') {
      final opened = await SystemService.openWifiSettings();
      _addAssistant(opened
          ? 'Wi-Fi settings opened.'
          : 'Android could not open Wi-Fi settings.');
      return;
    }
    if (lower.contains('hotspot')) {
      final opened = await SystemService.openHotspotSettings();
      _addAssistant(opened
          ? 'Hotspot settings opened.'
          : 'Android could not open hotspot settings.');
      return;
    }
    if (lower.contains('bluetooth settings') || lower == 'open bluetooth') {
      final opened = await SystemService.openBluetoothSettings();
      _addAssistant(opened
          ? 'Bluetooth settings opened.'
          : 'Android could not open Bluetooth settings.');
      return;
    }
    if (lower.startsWith('call ')) {
      final result = await SystemService.dial(prompt.substring(5).trim());
      _addAssistant('Dialer result: ${result['status'] ?? 'unknown'}.');
      return;
    }
    if (lower.contains('location') || lower.contains('where am i')) {
      final result = await SystemService.location();
      _addAssistant('Location result: ${_formatNativeResult(result)}');
      return;
    }
    if (lower.startsWith('create file ') ||
        lower.startsWith('delete file ') ||
        lower == 'pwd' ||
        lower == 'ls') {
      await _runSafeFileAction(prompt);
      return;
    }
    await _queryAiApi(prompt);
  }

  String _formatNativeResult(Map<String, dynamic> result) {
    if (result.isEmpty) return 'No data returned.';
    return result.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
  }

  Future<void> _readDeviceStatus() async {
    final battery = await SystemService.batteryStatus();
    final wifi = await SystemService.wifiState();
    final bluetooth = await SystemService.bluetoothState();
    _addAssistant(
        'Battery ${battery['percent'] ?? 'unknown'}% (${battery['chargingState'] ?? 'unknown'}). Wi-Fi ${wifi['enabled'] == true ? 'on' : 'off'}. Bluetooth ${bluetooth['enabled'] == true ? 'on' : 'off'}.');
  }

  Future<void> _runSafeFileAction(String prompt) async {
    final lower = prompt.toLowerCase();
    final dir = await getApplicationDocumentsDirectory();
    if (lower == 'pwd') {
      _addAssistant('Working directory: ${dir.path}');
      return;
    }
    if (lower == 'ls') {
      final entries =
          dir.listSync().map((entry) => entry.path.split('/').last).toList();
      _addAssistant(entries.isEmpty
          ? 'Directory is empty.'
          : 'Files: ${entries.join(', ')}');
      return;
    }
    final create =
        RegExp(r'^create file (.+)$', caseSensitive: false).firstMatch(prompt);
    final delete =
        RegExp(r'^delete file (.+)$', caseSensitive: false).firstMatch(prompt);
    final match = create ?? delete;
    if (match == null) {
      _addAssistant(
          'Safe file commands: ls, pwd, create file <name>, delete file <name>. Recursive deletion is blocked.');
      return;
    }
    final name = match.group(1)!.trim().split('/').last;
    if (name.isEmpty || name == '.' || name == '..' || name.contains('..')) {
      _addAssistant(
          'Unsafe filename blocked. Use a simple file name inside the app directory.');
      return;
    }
    final file = File('${dir.path}/$name');
    try {
      if (create != null) {
        await file.create();
        _addAssistant('Created file: $name');
      } else {
        if (await file.exists()) {
          await file.delete();
          _addAssistant('Deleted file: $name');
        } else {
          _addAssistant('File not found: $name');
        }
      }
    } catch (error) {
      _addAssistant('File operation failed: $error');
    }
  }

  Future<void> _executeAppCommand(String appName) async {
    final resolution = await SystemService.resolvePackage(appName);
    final status = resolution['status']?.toString() ?? 'unknown';
    final packageName = resolution['packageName']?.toString() ?? '';
    final label = resolution['label']?.toString() ?? appName;
    if (status == 'installed' && packageName.isNotEmpty) {
      final launch = await SystemService.launchPackage(packageName);
      _addAssistant(launch['status'] == 'launched'
          ? 'Found installed app $label and launched it. Package: $packageName.'
          : 'I found $label ($packageName), but Android could not launch it.');
      return;
    }
    if (status == 'not_found') {
      final suggestions = (resolution['suggestions'] as List?)
              ?.map((item) => item is Map
                  ? '${item['label']} (${item['packageName']})'
                  : item.toString())
              .join(', ') ??
          '';
      _addAssistant(suggestions.isEmpty
          ? 'No installed launcher app matched "$appName". I will not guess or launch an unrelated package.'
          : 'No exact installed app matched "$appName". Possible installed matches: $suggestions. Say the exact app name or package.');
      return;
    }
    if (status == 'not_installed' && packageName.isNotEmpty) {
      _lastMissingPackage = packageName;
      _addAssistant(
          '$appName is not installed. Package: $packageName. Type “y- install $packageName” to open its official store page.');
      return;
    }
    _addAssistant(
        'The installed-app scan returned no launchable match for "$appName".');
  }

  Future<void> _launchPackageDirect(String packageName) async {
    final result = await SystemService.launchPackage(packageName);
    _addAssistant('Package launch result: ${_formatNativeResult(result)}');
  }

  Future<void> _openInstallPage(String value) async {
    final packageName = value.isNotEmpty ? value : _lastMissingPackage;
    if (packageName.isEmpty) {
      _addAssistant('No pending package. First ask me to open an app.');
      return;
    }
    final uri =
        Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    _addAssistant(opened
        ? 'Official Play Store page opened for $packageName.'
        : 'Could not open the Play Store page.');
  }

  Future<void> _queryAiApi(String prompt) async {
    final prefs = await AuthService.getPrefs();
    final url = prefs.getString('api_endpoint') ??
        'https://api.groq.com/openai/v1/chat/completions';
    final key = prefs.getString('api_key') ?? '';
    final model = prefs.getString('api_model') ?? 'llama-3.3-70b-versatile';
    if (key.isEmpty) {
      _addAssistant(
          'API key not configured. Add an endpoint, key, and model in Settings.');
      return;
    }
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key'
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are JARVIS 2080, a concise mobile AI assistant. Answer naturally. Never claim a real device action happened unless the native command result confirms it. For unsupported device operations, explain the limitation and give a safe next step.'
            },
            {'role': 'user', 'content': prompt}
          ],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _addAssistant(
            '${data['choices']?[0]?['message']?['content'] ?? 'No response content.'}');
      } else {
        _addAssistant('API error ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      _addAssistant('Connection error: $error');
    }
  }

  void _openCommandCatalog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF06101C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('COMMAND CENTER',
                  style: TextStyle(
                      color: Color(0xFF32F5FF),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              const SizedBox(height: 6),
              Text(
                  '${jarvisCommandCatalog.length}+ routed capabilities · real actions stay permission-gated',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.62), fontSize: 12)),
              const SizedBox(height: 14),
              ...jarvisCommandCatalog.map((spec) => ListTile(
                    dense: true,
                    leading: Icon(
                        spec.real
                            ? Icons.verified_outlined
                            : Icons.auto_awesome_outlined,
                        color: spec.real
                            ? const Color(0xFF32F5FF)
                            : const Color(0xFFA970FF),
                        size: 18),
                    title: Text(spec.phrase,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                    subtitle: Text(spec.area,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.48),
                            fontSize: 10)),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050C),
      body: Stack(
        children: [
          const Positioned.fill(
              child: CustomPaint(painter: _HudBackdropPainter())),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                  child: Row(
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('J.A.R.V.I.S. // 2080',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.96),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                    fontSize: 15)),
                            Text('PRO EXPERT SYSTEMS',
                                style: TextStyle(
                                    color: const Color(0xFF32F5FF)
                                        .withOpacity(0.72),
                                    fontSize: 9,
                                    letterSpacing: 2.6)),
                          ]),
                      const Spacer(),
                      Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF57F287))),
                      const SizedBox(width: 6),
                      Text('ONLINE',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.60),
                              fontSize: 10,
                              letterSpacing: 1.4)),
                      IconButton(
                          onPressed: _openCommandCatalog,
                          icon: const Icon(Icons.grid_view_rounded,
                              color: Color(0xFF32F5FF))),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final coreSize =
                          math.min(constraints.maxWidth * 0.84, 300.0);
                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                    _visualState == JarvisVisualState.listening
                                        ? 'SPEAK A COMMAND'
                                        : 'READY FOR INPUT',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.52),
                                        letterSpacing: 2.3,
                                        fontSize: 10)),
                                SizedBox(height: 4, width: double.infinity),
                                HolographicCore(
                                    size: coreSize,
                                    state: _visualState,
                                    intensity:
                                        0.56 + _pulseController.value * 0.22),
                                Text(
                                    _isListening
                                        ? 'Listening — tap the mic to stop'
                                        : 'Tap the mic, type, or say “Jarvis”',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.52),
                                        fontSize: 11)),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 34,
                                  child: ListView(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18),
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      _quickChip('Open YouTube',
                                          () => _handleSubmit('Open YouTube')),
                                      _quickChip('Device status',
                                          () => _handleSubmit('Device status')),
                                      _quickChip(
                                          'Scan mesh',
                                          () => _handleSubmit(
                                              'Scan nearby devices')),
                                      _quickChip(
                                          'Commands', _openCommandCatalog),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                            sliver: SliverList.builder(
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final user = message['role'] == 'user';
                                return Align(
                                  alignment: user
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.88),
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: user
                                          ? const Color(0xFF00F5FF)
                                              .withOpacity(0.13)
                                          : const Color(0xFF0A1726)
                                              .withOpacity(0.84),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: user
                                              ? const Color(0xFF32F5FF)
                                                  .withOpacity(0.64)
                                              : const Color(0xFFA970FF)
                                                  .withOpacity(0.38)),
                                    ),
                                    child: Text(message['text'] ?? '',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.90),
                                            fontSize: 12,
                                            height: 1.35)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                  child: JarvisGlass(
                    padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                    borderRadius: BorderRadius.circular(24),
                    child: Row(
                      children: [
                        Expanded(
                            child: TextField(
                                controller: _inputController,
                                onSubmitted: _handleSubmit,
                                minLines: 1,
                                maxLines: 3,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                    hintText: 'Give the task or chat...',
                                    hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.42),
                                        fontSize: 12),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8)))),
                        IconButton(
                            onPressed: _toggleListening,
                            icon: Icon(
                                _isListening
                                    ? Icons.stop_circle
                                    : Icons.mic_none_rounded,
                                color: _isListening
                                    ? const Color(0xFFFFB86B)
                                    : const Color(0xFF32F5FF))),
                        IconButton(
                            onPressed: () =>
                                _handleSubmit(_inputController.text),
                            icon: const Icon(Icons.arrow_upward_rounded,
                                color: Color(0xFF32F5FF))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        backgroundColor: const Color(0xFF0C1B2B).withOpacity(0.88),
        side: BorderSide(color: const Color(0xFF32F5FF).withOpacity(0.25)),
        label: Text(label,
            style: const TextStyle(color: Color(0xFFB8F7FF), fontSize: 10)),
      ),
    );
  }
}

class JarvisCommandSpec {
  final String phrase;
  final String area;
  final bool real;

  const JarvisCommandSpec(this.phrase, this.area, {this.real = false});
}

const List<JarvisCommandSpec> jarvisCommandCatalog = <JarvisCommandSpec>[
  JarvisCommandSpec('Open YouTube / Chrome / Gmail / Maps', 'Native app launch',
      real: true),
  JarvisCommandSpec('Open WhatsApp / Instagram / Facebook', 'Native app launch',
      real: true),
  JarvisCommandSpec(
      'Open Spotify / Telegram / Discord / Netflix', 'Native app launch',
      real: true),
  JarvisCommandSpec('Use y- open <package>', 'Native package launch',
      real: true),
  JarvisCommandSpec('Use y- install after a missing-app result',
      'Official Play Store handoff',
      real: true),
  JarvisCommandSpec('Call a phone number', 'Android dialer handoff',
      real: true),
  JarvisCommandSpec('Open Wi-Fi settings', 'Android settings', real: true),
  JarvisCommandSpec('Open hotspot settings', 'Android settings', real: true),
  JarvisCommandSpec('Open Bluetooth settings', 'Android settings', real: true),
  JarvisCommandSpec('Show Wi-Fi state and SSID', 'Native telemetry',
      real: true),
  JarvisCommandSpec('Show Bluetooth state', 'Native telemetry', real: true),
  JarvisCommandSpec('Show battery and charging status', 'Native telemetry',
      real: true),
  JarvisCommandSpec('Read current location', 'Native GPS permission flow',
      real: true),
  JarvisCommandSpec('Open accessibility settings', 'Android settings',
      real: true),
  JarvisCommandSpec('Open JARVIS app settings', 'Android settings', real: true),
  JarvisCommandSpec('List app files with ls', 'Real app document directory',
      real: true),
  JarvisCommandSpec(
      'Show working directory with pwd', 'Real app document directory',
      real: true),
  JarvisCommandSpec('Create file <name>', 'Real app document directory',
      real: true),
  JarvisCommandSpec('Delete file <name>', 'Real app document directory',
      real: true),
  JarvisCommandSpec('Show safe terminal help', 'Real terminal guardrails',
      real: true),
  JarvisCommandSpec('Scan nearby mesh devices', 'Native mesh permission flow',
      real: true),
  JarvisCommandSpec('Show paired mesh peers', 'Mesh service', real: true),
  JarvisCommandSpec('Open GPS viewer', 'JARVIS telemetry surface', real: true),
  JarvisCommandSpec('Open terminal', 'JARVIS terminal surface', real: true),
  JarvisCommandSpec('Open settings', 'JARVIS settings surface', real: true),
  JarvisCommandSpec(
      'Fetch AI models from configured endpoint', 'Settings API flow',
      real: true),
  JarvisCommandSpec('Save endpoint, API key, and model', 'Settings persistence',
      real: true),
  JarvisCommandSpec('Ask for a concise explanation', 'Configured AI endpoint'),
  JarvisCommandSpec('Summarize text or pasted notes', 'Configured AI endpoint'),
  JarvisCommandSpec('Rewrite an email or message', 'Configured AI endpoint'),
  JarvisCommandSpec('Translate a sentence', 'Configured AI endpoint'),
  JarvisCommandSpec('Extract tasks from notes', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a checklist', 'Configured AI endpoint'),
  JarvisCommandSpec('Draft a professional reply', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain an error message', 'Configured AI endpoint'),
  JarvisCommandSpec('Compare two options', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a study plan', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a workout outline', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a meal outline', 'Configured AI endpoint'),
  JarvisCommandSpec('Brainstorm project names', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate Flutter ideas', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate Android test cases', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain Dart code', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain Kotlin code', 'Configured AI endpoint'),
  JarvisCommandSpec('Review a command safely', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a JSON schema', 'Configured AI endpoint'),
  JarvisCommandSpec('Convert notes to JSON', 'Configured AI endpoint'),
  JarvisCommandSpec('Convert JSON to a table', 'Configured AI endpoint'),
  JarvisCommandSpec('Extract names and dates', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a meeting agenda', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate meeting minutes', 'Configured AI endpoint'),
  JarvisCommandSpec('Make a release checklist', 'Configured AI endpoint'),
  JarvisCommandSpec('Write a README section', 'Configured AI endpoint'),
  JarvisCommandSpec('Write a commit message', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a bug report draft', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a feature specification', 'Configured AI endpoint'),
  JarvisCommandSpec('Suggest UI copy', 'Configured AI endpoint'),
  JarvisCommandSpec('Suggest accessibility labels', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain a privacy setting', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain a networking concept', 'Configured AI endpoint'),
  JarvisCommandSpec(
      'Explain a security concept safely', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a Mermaid diagram', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a SQL query draft', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a regex draft', 'Configured AI endpoint'),
  JarvisCommandSpec('Format a log excerpt', 'Configured AI endpoint'),
  JarvisCommandSpec('Find likely causes of an error', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a troubleshooting tree', 'Configured AI endpoint'),
  JarvisCommandSpec('Suggest battery-saving steps', 'Configured AI endpoint'),
  JarvisCommandSpec('Suggest offline-first behavior', 'Configured AI endpoint'),
  JarvisCommandSpec('Plan a local mesh test', 'Configured AI endpoint'),
  JarvisCommandSpec('Plan a permission checklist', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain Google Sign-In setup', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain SHA-1 and SHA-256', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a Firebase checklist', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain release signing', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a QA matrix', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a smoke-test plan', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a regression-test plan', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a Dart test outline', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate Kotlin test ideas', 'Configured AI endpoint'),
  JarvisCommandSpec('Draft a product changelog', 'Configured AI endpoint'),
  JarvisCommandSpec('Draft a privacy notice', 'Configured AI endpoint'),
  JarvisCommandSpec('Draft a permission explanation', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain safe file operations', 'Configured AI endpoint'),
  JarvisCommandSpec(
      'Explain why recursive delete is blocked', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a safe terminal alias', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a command cheat sheet', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a study flashcard set', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate interview questions', 'Configured AI endpoint'),
  JarvisCommandSpec('Practice a language dialogue', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain a difficult paragraph', 'Configured AI endpoint'),
  JarvisCommandSpec('Turn a paragraph into bullets', 'Configured AI endpoint'),
  JarvisCommandSpec('Turn bullets into a paragraph', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a polite reminder', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a travel checklist', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a packing list', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate a shopping list', 'Configured AI endpoint'),
  JarvisCommandSpec(
      'Generate a personal goals review', 'Configured AI endpoint'),
  JarvisCommandSpec(
      'Create a weekly review template', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a daily focus plan', 'Configured AI endpoint'),
  JarvisCommandSpec('Suggest focus timers', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a learning roadmap', 'Configured AI endpoint'),
  JarvisCommandSpec(
      'Create a project milestone plan', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a risk register', 'Configured AI endpoint'),
  JarvisCommandSpec('Create an assumption list', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a decision log', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a status update', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a support response', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a test-data description without real data',
      'Configured AI endpoint'),
  JarvisCommandSpec('Explain a code diff', 'Configured AI endpoint'),
  JarvisCommandSpec('Suggest refactoring steps', 'Configured AI endpoint'),
  JarvisCommandSpec(
      'Generate documentation headings', 'Configured AI endpoint'),
  JarvisCommandSpec('Generate API request examples', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain an HTTP status code', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain a JSON error', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a monitoring checklist', 'Configured AI endpoint'),
  JarvisCommandSpec('Create an incident timeline', 'Configured AI endpoint'),
  JarvisCommandSpec('Create a rollback checklist', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain a build failure', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain a Gradle task', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain a Flutter asset', 'Configured AI endpoint'),
  JarvisCommandSpec(
      'Create a release verification checklist', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain a package name', 'Configured AI endpoint'),
  JarvisCommandSpec('Explain an Android permission', 'Configured AI endpoint'),
  JarvisCommandSpec(
      'Create a user onboarding script', 'Configured AI endpoint'),
  JarvisCommandSpec('Draft a help response', 'Configured AI endpoint'),
  JarvisCommandSpec('Show what JARVIS can do', 'Command catalog', real: true),
];

class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final List<String> _logs = [
    'JARVIS sandbox terminal ready.',
    'Real commands: help, ls, pwd, uptime, mkdir <name>, touch <name>, cat <name>, write <name> <text>, rm <name>, stat <name>, clear.',
    'Safety: recursive deletion, absolute paths, shell execution, and unsupported commands are blocked.',
  ];
  final _ctrl = TextEditingController();

  void _log(String line) {
    if (!mounted) return;
    setState(() => _logs.add(line));
  }

  String? _safeName(String raw) {
    final name = raw.trim();
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.startsWith('-') ||
        name.contains('..') ||
        name.contains('/') ||
        name.contains('\\')) {
      return null;
    }
    return name;
  }

  Future<Directory> _workingDirectory() => getApplicationDocumentsDirectory();

  Future<void> _runCommand(String cmd) async {
    final command = cmd.trim();
    _ctrl.clear();
    if (command.isEmpty) return;
    _log('> $command');
    final lower = command.toLowerCase();
    try {
      if (lower == 'clear') {
        setState(() => _logs.clear());
        return;
      }
      if (lower == 'help') {
        _log(
            'help | ls | pwd | uptime | mkdir <name> | touch <name> | cat <name> | write <name> <text> | rm <name> | stat <name> | clear');
        return;
      }
      final dir = await _workingDirectory();
      if (lower == 'pwd') {
        _log(dir.path);
        return;
      }
      if (lower == 'ls' || lower.startsWith('ls ')) {
        final entries = dir
            .listSync()
            .map((entry) => entry.path.split('/').last)
            .toList()
          ..sort();
        _log(entries.isEmpty ? '(empty)' : entries.join('  '));
        return;
      }
      if (lower == 'uptime') {
        final raw = await File('/proc/uptime').readAsString();
        final seconds = double.tryParse(raw.split(RegExp(r'\s+')).first) ?? 0;
        _log('Android kernel uptime: ${seconds.toStringAsFixed(1)} seconds');
        return;
      }
      final mkdir =
          RegExp(r'^mkdir\s+(.+)$', caseSensitive: false).firstMatch(command);
      if (mkdir != null) {
        final name = _safeName(mkdir.group(1)!);
        if (name == null) {
          _log('Blocked: unsafe directory name.');
          return;
        }
        await Directory('${dir.path}/$name').create();
        _log('Created directory: $name');
        return;
      }
      final touch =
          RegExp(r'^touch\s+(.+)$', caseSensitive: false).firstMatch(command);
      if (touch != null) {
        final name = _safeName(touch.group(1)!);
        if (name == null) {
          _log('Blocked: unsafe file name.');
          return;
        }
        await File('${dir.path}/$name').create();
        _log('Created file: $name');
        return;
      }
      final cat =
          RegExp(r'^cat\s+(.+)$', caseSensitive: false).firstMatch(command);
      if (cat != null) {
        final name = _safeName(cat.group(1)!);
        if (name == null) {
          _log('Blocked: unsafe file name.');
          return;
        }
        final file = File('${dir.path}/$name');
        if (!await file.exists()) {
          _log('Not found: $name');
          return;
        }
        _log(await file.readAsString());
        return;
      }
      final write = RegExp(r'^write\s+(\S+)\s+(.+)$', caseSensitive: false)
          .firstMatch(command);
      if (write != null) {
        final name = _safeName(write.group(1)!);
        if (name == null) {
          _log('Blocked: unsafe file name.');
          return;
        }
        await File('${dir.path}/$name').writeAsString(write.group(2)!);
        _log('Wrote ${write.group(2)!.length} characters to $name');
        return;
      }
      final rm =
          RegExp(r'^rm\s+(.+)$', caseSensitive: false).firstMatch(command);
      if (rm != null) {
        if (lower.contains('-rf') ||
            lower.contains('-r') ||
            lower.contains('--recursive')) {
          _log('Blocked: recursive deletion is not allowed.');
          return;
        }
        final name = _safeName(rm.group(1)!);
        if (name == null) {
          _log('Blocked: unsafe file name.');
          return;
        }
        final entity = File('${dir.path}/$name');
        if (!await entity.exists()) {
          _log('Not found: $name');
          return;
        }
        await entity.delete();
        _log('Deleted: $name');
        return;
      }
      final stat =
          RegExp(r'^stat\s+(.+)$', caseSensitive: false).firstMatch(command);
      if (stat != null) {
        final name = _safeName(stat.group(1)!);
        if (name == null) {
          _log('Blocked: unsafe file name.');
          return;
        }
        final entity = File('${dir.path}/$name');
        if (!await entity.exists()) {
          _log('Not found: $name');
          return;
        }
        final info = await entity.stat();
        _log(
            'type=${info.type} size=${info.size} modified=${info.modified.toIso8601String()}');
        return;
      }
      _log(
          'Unsupported command. Nothing was executed. Type help for the safe command list.');
    } catch (error) {
      _log('Command failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050C),
      appBar: AppBar(
        title: const Text('REAL TERMINAL // SANDBOX',
            style: TextStyle(
                color: Color(0xFF32F5FF), fontSize: 14, letterSpacing: 1.1)),
        actions: [
          IconButton(
              onPressed: () => _runCommand('help'),
              icon: const Icon(Icons.help_outline, color: Color(0xFF32F5FF)))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF32F5FF).withOpacity(0.42))),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (c, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(_logs[i],
                        style: TextStyle(
                            color: i == 0
                                ? const Color(0xFFFFB86B)
                                : const Color(0xFF8CF8FF),
                            fontFamily: 'Orbitron',
                            fontSize: 11,
                            height: 1.35))),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 96),
            child: JarvisGlass(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                  controller: _ctrl,
                  onSubmitted: _runCommand,
                  style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontSize: 12),
                  decoration: const InputDecoration(
                      prefixText: '> ',
                      prefixStyle: TextStyle(color: Color(0xFF32F5FF)),
                      hintText: 'help or safe file command...',
                      border: InputBorder.none)),
            ),
          ),
        ],
      ),
    );
  }
}

class MeshRelayPage extends StatefulWidget {
  const MeshRelayPage({Key? key}) : super(key: key);

  @override
  State<MeshRelayPage> createState() => _MeshRelayPageState();
}

class _MeshRelayPageState extends State<MeshRelayPage> {
  final MeshService _mesh = MeshService();
  final TextEditingController _codeController = TextEditingController();
  StreamSubscription<MeshEvent>? _events;
  List<MeshDevice> _discovered = <MeshDevice>[];
  List<Map<String, dynamic>> _paired = <Map<String, dynamic>>[];
  MeshEvent? _pendingRequest;
  bool _scanning = false;
  bool _allowAnytime = false;
  String _status = 'LAN transport idle';

  @override
  void initState() {
    super.initState();
    _events = _mesh.events.listen(_onMeshEvent);
    _startMesh();
  }

  Future<void> _startMesh() async {
    try {
      await _mesh.start();
      if (!mounted) return;
      setState(() => _status = 'LAN transport listening on TCP 45455');
      await _refreshPaired();
    } catch (error) {
      if (mounted) setState(() => _status = 'Mesh start error: $error');
    }
  }

  void _onMeshEvent(MeshEvent event) {
    if (!mounted) return;
    if (event.type == 'pair_request') {
      setState(() {
        _pendingRequest = event;
        _status = 'Pair request received — approval required';
      });
    }
  }

  Future<void> _refreshPaired() async {
    final peers = await _mesh.pairedPeers();
    if (mounted) setState(() => _paired = peers);
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _status = 'Broadcasting LAN discovery packets...';
    });
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    try {
      final discovered = await _mesh.discover();
      final paired = await _mesh.pairedPeers();
      if (!mounted) return;
      setState(() {
        _discovered = discovered;
        _paired = paired;
        _scanning = false;
        _status = discovered.isEmpty
            ? 'No JARVIS nodes answered on the local network.'
            : '${discovered.length} node(s) answered over LAN.';
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _scanning = false;
          _status = 'Discovery error: $error';
        });
    }
  }

  Future<void> _pairWith(MeshDevice device) async {
    _codeController.clear();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1726),
        title: Text('Pair with ${device.name}',
            style: const TextStyle(color: Color(0xFF32F5FF), fontSize: 16)),
        content: TextField(
          controller: _codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(color: Colors.white, letterSpacing: 5),
          decoration: const InputDecoration(
              labelText: 'Enter the 6-digit code shown on target device',
              counterText: '',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _codeController.text.trim()),
              child: const Text('SEND REQUEST')),
        ],
      ),
    );
    if (code == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      if (mounted)
        setState(() => _status = 'Pairing cancelled or invalid code format.');
      return;
    }
    setState(() =>
        _status = 'Sending code to ${device.name} — waiting for approval...');
    try {
      final response = await _mesh.connect(device: device, pairingCode: code);
      final status = '${response['status'] ?? 'unknown'}';
      if (status == 'approved') {
        await _refreshPaired();
        if (mounted)
          setState(
              () => _status = 'Pairing approved. LAN control is available.');
      } else if (mounted) {
        setState(() => _status = status == 'pending_approval'
            ? 'Target approval is still pending.'
            : 'Pairing result: $status');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Pairing transport error: $error');
    }
  }

  Future<void> _approve(bool approved) async {
    final request = _pendingRequest;
    if (request == null) return;
    final ok = await _mesh.approvePair(
        requestId: request.requestId,
        approved: approved,
        anytime: _allowAnytime);
    if (!mounted) return;
    setState(() {
      _pendingRequest = null;
      _status = ok
          ? (approved ? 'Pair request approved.' : 'Pair request rejected.')
          : 'Approval response failed.';
    });
    if (approved) await _refreshPaired();
  }

  @override
  void dispose() {
    _events?.cancel();
    _codeController.dispose();
    _mesh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050C),
      appBar: AppBar(
        title: const Text('NEARBY YOU // REAL LAN MESH',
            style: TextStyle(
                color: Color(0xFF32F5FF), fontSize: 14, letterSpacing: 1.1)),
        actions: [
          IconButton(
              onPressed: _startScan,
              icon: const Icon(Icons.radar, color: Color(0xFF32F5FF)))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          JarvisGlass(
            child: FutureBuilder<List<String>>(
              future: Future.wait([_mesh.deviceName, _mesh.pairingCode]),
              builder: (context, snapshot) {
                final values = snapshot.data ?? const <String>[];
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('THIS DEVICE',
                          style: TextStyle(
                              color: Color(0xFF32F5FF),
                              fontSize: 10,
                              letterSpacing: 1.6)),
                      const SizedBox(height: 8),
                      Text(values.isEmpty ? 'Loading identity...' : values[0],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          values.length < 2
                              ? 'Pair code loading...'
                              : 'Pair code: ${values[1]}',
                          style: const TextStyle(
                              color: Color(0xFFFFB86B),
                              fontSize: 18,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          'Share this code only with a device you trust. LAN discovery does not use the fake simulation tab.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.52),
                              fontSize: 10,
                              height: 1.35)),
                    ]);
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_pendingRequest != null)
            JarvisGlass(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INCOMING PAIR REQUEST',
                        style: TextStyle(
                            color: Color(0xFFFFB86B),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Text(
                        '${_pendingRequest!.deviceName} wants to connect over LAN.',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _allowAnytime,
                        onChanged: (value) =>
                            setState(() => _allowAnytime = value),
                        title: const Text('Allow access anytime',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                        subtitle: const Text(
                            'Keep this approval local and explicit.',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 10))),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => _approve(false),
                              child: const Text('REJECT'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: FilledButton(
                              onPressed: () => _approve(true),
                              child: const Text('APPROVE')))
                    ]),
                  ]),
            ),
          if (_pendingRequest != null) const SizedBox(height: 12),
          Text(_status,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.58), fontSize: 11)),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: const Icon(Icons.wifi_find),
              label: Text(_scanning
                  ? 'DISCOVERING LAN NODES...'
                  : 'DISCOVER NEARBY JARVIS DEVICES'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF32F5FF),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48))),
          const SizedBox(height: 18),
          const Text('DISCOVERED NODES',
              style: TextStyle(
                  color: Color(0xFF32F5FF),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          if (_discovered.isEmpty)
            Text('No unpaired LAN nodes in this session.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.42), fontSize: 11)),
          ..._discovered.map((device) => JarvisGlass(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android,
                        color: Color(0xFF32F5FF)),
                    title: Text(device.name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text(
                        '${device.host}:${device.port} · ${device.transport}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                    trailing: TextButton(
                        onPressed: () => _pairWith(device),
                        child: const Text('PAIR'))),
              )),
          const SizedBox(height: 18),
          const Text('PAIRED NODES',
              style: TextStyle(
                  color: Color(0xFF32F5FF),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          if (_paired.isEmpty)
            Text('No approved peers stored by this native transport.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.42), fontSize: 11)),
          ..._paired.map((peer) => JarvisGlass(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_user_outlined,
                        color: Color(0xFF57F287)),
                    title: Text('${peer['name'] ?? 'JARVIS Device'}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text(
                        '${peer['host'] ?? ''}:${peer['port'] ?? ''} · ${peer['transport'] ?? 'LAN'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                    trailing: IconButton(
                        onPressed: () async {
                          await _mesh.revoke('${peer['peerId'] ?? ''}');
                          await _refreshPaired();
                        },
                        icon: const Icon(Icons.link_off,
                            color: Colors.redAccent))),
              )),
          const SizedBox(height: 14),
          Text(
              'Real transport note: the current native bridge uses LAN UDP discovery and TCP approval. Bluetooth permissions are requested for Android compatibility, but this screen does not claim a Bluetooth link unless the native transport reports one.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 10,
                  height: 1.35)),
        ],
      ),
    );
  }
}

class GpsViewerPage extends StatefulWidget {
  const GpsViewerPage({Key? key}) : super(key: key);

  @override
  State<GpsViewerPage> createState() => _GpsViewerPageState();
}

class _GpsViewerPageState extends State<GpsViewerPage> {
  String _lat = 'Unavailable';
  String _lng = 'Unavailable';
  String _battery = 'Unavailable';
  String _charging = 'Unavailable';
  String _status = 'Waiting for a real permission-approved fix.';
  bool _hasFix = false;

  @override
  void initState() {
    super.initState();
    _fetchTelemetry();
  }

  Future<void> _fetchTelemetry() async {
    final permission = await Permission.location.request();
    if (!permission.isGranted) {
      if (mounted)
        setState(() => _status =
            'Location permission is required; no coordinates are shown.');
      return;
    }
    try {
      final loc = await SystemService.location();
      final bat = await SystemService.batteryStatus();
      final ok = loc['status'] == 'ok' &&
          loc['latitude'] != null &&
          loc['longitude'] != null;
      if (!mounted) return;
      setState(() {
        _hasFix = ok;
        _lat = ok ? '${loc['latitude']}' : 'Unavailable';
        _lng = ok ? '${loc['longitude']}' : 'Unavailable';
        _battery =
            bat['percent'] == null ? 'Unavailable' : '${bat['percent']}%';
        _charging = bat['chargingState']?.toString() ?? 'Unavailable';
        _status = ok
            ? 'Real Android location fix received.'
            : 'Android did not return a current location: ${loc['status'] ?? 'unknown'}.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Telemetry error: $error');
    }
  }

  Future<void> _openMap() async {
    if (!_hasFix) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$_lat,$_lng');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted && !opened)
      setState(() => _status = 'Could not open Google Maps.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050C),
      appBar: AppBar(
        title: const Text('GPS VIEWER // REAL TELEMETRY',
            style: TextStyle(
                color: Color(0xFF32F5FF), fontSize: 14, letterSpacing: 1.1)),
        actions: [
          IconButton(
              onPressed: _fetchTelemetry,
              icon: const Icon(Icons.refresh, color: Color(0xFF32F5FF)))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          JarvisGlass(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CURRENT DEVICE',
                  style: TextStyle(
                      color: Color(0xFF32F5FF),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4)),
              const SizedBox(height: 12),
              Text('Latitude: $_lat',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 5),
              Text('Longitude: $_lng',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 5),
              Text('Battery: $_battery · $_charging',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 12),
              Text(_status,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.56),
                      fontSize: 10,
                      height: 1.35)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _hasFix ? _openMap : null,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('SEE ON GOOGLE MAPS')),
            ]),
          ),
          const SizedBox(height: 14),
          JarvisGlass(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PAIRED DEVICE TELEMETRY',
                  style: TextStyle(
                      color: Color(0xFF32F5FF),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(
                  'Remote latitude, longitude, battery, charging state, and distance appear only after an approved peer sends fresh telemetry over the real mesh transport. No placeholder coordinates are shown.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.52),
                      fontSize: 11,
                      height: 1.4)),
              const SizedBox(height: 8),
              Text('Distance: waiting for paired peer telemetry',
                  style: TextStyle(
                      color: const Color(0xFFFFB86B).withOpacity(0.82),
                      fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }
}

class TabLockPage extends StatefulWidget {
  const TabLockPage({Key? key}) : super(key: key);

  @override
  State<TabLockPage> createState() => _TabLockPageState();
}

class _TabLockPageState extends State<TabLockPage> {
  final TabLockService _service = TabLockService();
  final _domainController = TextEditingController();
  final _secretController = TextEditingController();
  final _pairingController = TextEditingController();
  final _deviceNameController = TextEditingController(text: 'JARVIS Android');
  TabLockSnapshot? _snapshot;
  Map<String, dynamic> _local = const {};
  String _mode = 'block';
  String _failurePage = 'blocked';
  bool _relockOnRefresh = true;
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _domainController.dispose();
    _secretController.dispose();
    _pairingController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final local = await _service.localState();
      TabLockSnapshot? snapshot;
      if (local['registered'] == true) snapshot = await _service.sync();
      if (!mounted) return;
      setState(() {
        _local = local;
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _register() async {
    setState(() => _status = 'Registering this Android controller…');
    try {
      final result = await _service.registerController(
          deviceName: _deviceNameController.text.trim().isEmpty
              ? 'JARVIS Android'
              : _deviceNameController.text.trim());
      final local = await _service.localState();
      if (!mounted) return;
      setState(() {
        _local = local;
        _status =
            'One-time code ready: ${result['pairingCode']}. Enter it in the Chrome extension.';
      });
    } catch (error) {
      if (mounted)
        setState(
            () => _status = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _pair() async {
    final code = _pairingController.text.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(code)) {
      setState(() => _status =
          'Enter the exact 8-digit code shown by the Chrome extension.');
      return;
    }
    setState(() => _status = 'Pairing browser device…');
    try {
      await _service.pairExtension(
        pairingCode: code,
        deviceName: _deviceNameController.text.trim().isEmpty
            ? 'JARVIS Android'
            : _deviceNameController.text.trim(),
      );
      final snapshot = await _service.sync();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _status =
            'Browser paired. Policies will sync every five minutes while the extension is enabled.';
      });
    } catch (error) {
      if (mounted)
        setState(
            () => _status = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _savePolicy() async {
    final domain = _domainController.text.trim();
    if (domain.isEmpty) {
      setState(() => _status = 'Enter a domain such as example.com.');
      return;
    }
    setState(() => _status = 'Saving policy…');
    try {
      final snapshot = await _service.upsertPolicy(
        domain: domain,
        mode: _mode,
        secret: _mode == 'lock' ? _secretController.text : null,
        failurePage: _failurePage,
        relockOnRefresh: _relockOnRefresh,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _domainController.clear();
        _secretController.clear();
        _status =
            'Policy saved for every path under ${domain.toLowerCase()}. Chrome will enforce it after the next sync.';
      });
    } catch (error) {
      if (mounted)
        setState(
            () => _status = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _deletePolicy(String domain) async {
    try {
      final snapshot = await _service.deletePolicy(domain);
      if (mounted)
        setState(() {
          _snapshot = snapshot;
          _status = 'Policy removed for $domain.';
        });
    } catch (error) {
      if (mounted)
        setState(
            () => _status = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _revokeDevice(String deviceId) async {
    try {
      final snapshot = await _service.revokeDevice(deviceId);
      if (mounted)
        setState(() {
          _snapshot = snapshot;
          _status =
              'Device revoked. Its bearer token will no longer sync policies.';
        });
    } catch (error) {
      if (mounted)
        setState(
            () => _status = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: JarvisGlass(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF32F5FF),
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final policies = _snapshot?.policies ?? const <TabLockPolicy>[];
    final devices = _snapshot?.devices ?? const <TabLockDevice>[];
    return Scaffold(
      backgroundColor: const Color(0xFF02050C),
      appBar: AppBar(
        title: const Text('TAB LOCK'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF32F5FF)),
                SizedBox(height: 16),
                Text('CHROME EXTENSION REQUIRED',
                    style: TextStyle(
                        color: Color(0xFF32F5FF),
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('Android cannot block Chrome pages by itself.',
                    style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 96),
              children: [
                _section(
                  'CHROME EXTENSION REQUIRED',
                  const Text(
                    'Android cannot block Chrome pages by itself. Load the included MV3 extension in Chrome, pair it here, and keep the extension enabled. The server stores only policy metadata and hashed verifiers—not plaintext passwords.',
                    style: TextStyle(
                        color: Color(0xFFB3C8D5), height: 1.45, fontSize: 11),
                  ),
                ),
                _section(
                  'PAIR THIS CONTROLLER',
                  Column(
                    children: [
                      TextField(
                        controller: _deviceNameController,
                        decoration: const InputDecoration(
                            labelText: 'Android device name'),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _register,
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('REGISTER / SHOW CODE'),
                          ),
                        ),
                      ]),
                      if ((_local['pairingCode'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('ANDROID CONTROLLER CODE',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                                letterSpacing: 1.1)),
                        SelectableText((_local['pairingCode'] ?? '').toString(),
                            style: const TextStyle(
                                color: Color(0xFFFF65B3),
                                fontSize: 24,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w800)),
                      ],
                      const Divider(height: 24),
                      TextField(
                        controller: _pairingController,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: const InputDecoration(
                            labelText: 'Chrome extension pairing code'),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pair,
                          icon: const Icon(Icons.link),
                          label: const Text('PAIR EXTENSION'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (devices.isNotEmpty)
                  _section(
                    'PAIRED DEVICES',
                    Column(
                      children: devices
                          .map((device) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                    device.deviceType == 'chrome'
                                        ? Icons.language
                                        : Icons.phone_android,
                                    color: const Color(0xFF32F5FF)),
                                title: Text(device.deviceName,
                                    style: const TextStyle(fontSize: 11)),
                                subtitle: Text(
                                    '${device.deviceType} • ${device.deviceId}',
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.white54)),
                                trailing: device.deviceId == _local['deviceId']
                                    ? const Text('THIS DEVICE',
                                        style: TextStyle(
                                            fontSize: 8,
                                            color: Color(0xFF76FFB0)))
                                    : IconButton(
                                        onPressed: () =>
                                            _revokeDevice(device.deviceId),
                                        icon: const Icon(Icons.link_off,
                                            color: Color(0xFFFF65B3))),
                              ))
                          .toList(),
                    ),
                  ),
                _section(
                  'NEW WEBSITE POLICY',
                  Column(
                    children: [
                      TextField(
                          controller: _domainController,
                          decoration: const InputDecoration(
                              labelText: 'Domain (example.com)',
                              hintText: 'Subpaths are included automatically')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _mode,
                        decoration:
                            const InputDecoration(labelText: 'Access mode'),
                        items: const [
                          DropdownMenuItem(
                              value: 'block', child: Text('Fully block')),
                          DropdownMenuItem(
                              value: 'lock',
                              child: Text('Lock behind credential')),
                        ],
                        onChanged: (value) =>
                            setState(() => _mode = value ?? 'block'),
                      ),
                      if (_mode == 'lock') ...[
                        const SizedBox(height: 10),
                        TextField(
                            controller: _secretController,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText:
                                    'Password / PIN / passphrase (4+ characters)')),
                        const SizedBox(height: 5),
                        const Text(
                            'This release uses a client-generated verifier. Hardware WebAuthn passkeys are not claimed as supported yet.',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                                height: 1.35)),
                      ],
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _failurePage,
                        decoration: const InputDecoration(
                            labelText: 'Blocked-page appearance'),
                        items: const [
                          DropdownMenuItem(
                              value: 'blocked', child: Text('JARVIS blocked')),
                          DropdownMenuItem(
                              value: 'not_found', child: Text('404 not found')),
                          DropdownMenuItem(
                              value: 'forbidden', child: Text('Forbidden')),
                          DropdownMenuItem(
                              value: 'aw_snap', child: Text('Aw, snap')),
                        ],
                        onChanged: (value) =>
                            setState(() => _failurePage = value ?? 'blocked'),
                      ),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Relock when the page is refreshed',
                              style: TextStyle(fontSize: 11)),
                          value: _relockOnRefresh,
                          onChanged: (value) =>
                              setState(() => _relockOnRefresh = value)),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                              onPressed: _savePolicy,
                              icon: const Icon(Icons.add_moderator),
                              label: const Text('SAVE POLICY'))),
                    ],
                  ),
                ),
                _section(
                  'ACTIVE POLICIES',
                  policies.isEmpty
                      ? const Text('No policies yet. Add a domain above.',
                          style: TextStyle(color: Colors.white54, fontSize: 11))
                      : Column(
                          children: policies
                              .map((policy) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                        policy.mode == 'lock'
                                            ? Icons.lock
                                            : Icons.block,
                                        color: policy.mode == 'lock'
                                            ? const Color(0xFFFF65B3)
                                            : const Color(0xFFFFD166)),
                                    title: Text(policy.domain,
                                        style: const TextStyle(fontSize: 11)),
                                    subtitle: Text(
                                        '${policy.mode} • ${policy.relockOnRefresh ? 'relocks on refresh' : 'session unlock'}',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 9)),
                                    trailing: IconButton(
                                        onPressed: () =>
                                            _deletePolicy(policy.domain),
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.white54)),
                                  ))
                              .toList()),
                ),
                if (_status.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF9FEFFF),
                              fontSize: 10,
                              height: 1.4))),
              ],
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
      _urlCtrl.text = prefs.getString('api_endpoint') ??
          'https://api.groq.com/openai/v1/chat/completions';
      _keyCtrl.text = prefs.getString('api_key') ?? '';
      _selectedModel =
          prefs.getString('api_model') ?? 'llama-3.3-70b-versatile';
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
        final list =
            (data['data'] as List?)?.map((e) => e['id'].toString()).toList();
        if (list != null && list.isNotEmpty) {
          setState(() {
            _fetchedModels.clear();
            _fetchedModels.addAll(list);
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Successfully fetched ${list.length} models!')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to fetch models: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error fetching models: $e')));
    } finally {
      setState(() => _fetching = false);
    }
  }

  Future<void> _save() async {
    final prefs = await AuthService.getPrefs();
    await prefs.setString('api_endpoint', _urlCtrl.text.trim());
    await prefs.setString('api_key', _keyCtrl.text.trim());
    await prefs.setString('api_model', _selectedModel);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('JARVIS SETTINGS & API',
              style: TextStyle(color: Color(0xFF00F5FF)))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                  labelText: 'API Endpoint URL', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(
              controller: _keyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'API Key (Groq / Gemini / OpenAI)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _fetchedModels.contains(_selectedModel)
                      ? _selectedModel
                      : _fetchedModels.first,
                  dropdownColor: const Color(0xFF0A0F1D),
                  items: _fetchedModels
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedModel = val ?? _selectedModel),
                  decoration: const InputDecoration(
                      labelText: 'Select AI Model',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _fetching ? null : _fetchModelsFromApi,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F5FF),
                    foregroundColor: Colors.black),
                child: _fetching
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Text('Fetch'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F5FF),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50)),
            child: const Text('SAVE SETTINGS',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
