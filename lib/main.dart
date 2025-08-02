// main.dart
// Полный код с экранами Login, Registration и WebView (iOS-only)
// Сохраните в lib/main.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Константы приложения
const String baseUrl = 'https://ultrahomeservices.net';

/// Наша цветовая палитра
const Color kGold  = Color(0xFFD4AF37);
const Color kBlack = Colors.black;
const Color kBeige = Color(0xFFF5F5DC);

/// MethodChannel для установки куки в iOS WKWebView
const MethodChannel _cookieChannel =
    MethodChannel('net.ultrahomeservices/cookie');

/// Локальное хранилище для JWT
final _storage = FlutterSecureStorage();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UltraHomeApp());
}

class UltraHomeApp extends StatelessWidget {
  const UltraHomeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UltraHome Services',
      theme: ThemeData(
        primaryColor: kGold,
        scaffoldBackgroundColor: kBeige,
      ),
      home: const EntryPoint(),
    );
  }
}

/// Проверяем токен и показываем соответствующий экран
class EntryPoint extends StatelessWidget {
  const EntryPoint({Key? key}) : super(key: key);

  Future<bool> _hasToken() async {
    final t = await _storage.read(key: 'jwt');
    return t != null && t.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasToken(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data! ? const AutoLoginWebView() : const AuthScreen();
      },
    );
  }
}

/// Общий декоратор для полей
InputDecoration _fieldDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: kBlack),
      filled: true,
      fillColor: kBeige,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: kGold),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: kGold, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );

/// Экран с двумя вкладками: Login и Registration
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBeige,
      appBar: AppBar(
        backgroundColor: kGold,
        title: const Text('UltraHome Services', style: TextStyle(color: kBlack)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kBlack,
          labelColor: kBlack,
          unselectedLabelColor: kBlack.withOpacity(0.6),
          tabs: const [ Tab(text: 'Login'), Tab(text: 'Register') ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ LoginForm(), RegistrationForm() ],
      ),
    );
  }
}

/// Логотип + приветствие
class _LogoWelcome extends StatelessWidget {
  const _LogoWelcome({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 24),
      Image.asset('assets/images/logo-ultrahome-services.webp', height: 80),
      const SizedBox(height: 16),
      const Text(
        'Welcome to UltraHome Services',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kBlack),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'Please log in or register an account.',
        style: TextStyle(fontSize: 16, color: kBlack),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
    ]);
  }
}

/// Форма логина
class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/wp-json/jwt-auth/v1/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _userCtrl.text.trim(),
          'password': _passCtrl.text,
        }),
      );
      if (res.statusCode != 200) throw 'Invalid credentials';
      final body = jsonDecode(res.body);
      final token = body['token'] as String?;
      if (token == null) throw 'No token';
      await _storage.write(key: 'jwt', value: token);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AutoLoginWebView()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const _LogoWelcome(),
        TextField(
          controller: _userCtrl,
          decoration: _fieldDecoration('Username'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passCtrl,
          decoration: _fieldDecoration('Password'),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGold,
            foregroundColor: kBlack,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _loading ? null : _login,
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Login'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            // TODO: Forgot password flow
          },
          child: const Text('Forgot Password?'),
        ),
      ]),
    );
  }
}

/// Форма регистрации
class RegistrationForm extends StatefulWidget {
  const RegistrationForm({Key? key}) : super(key: key);
  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _first = TextEditingController();
  final _last  = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _addr  = TextEditingController();
  final _city  = TextEditingController();
  final _state = TextEditingController();
  final _zip   = TextEditingController();
  final _pass  = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const _LogoWelcome(),
        TextField(controller: _first, decoration: _fieldDecoration('First Name')),
        const SizedBox(height: 12),
        TextField(controller: _last,  decoration: _fieldDecoration('Last Name')),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          decoration: _fieldDecoration('Phone Number'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          decoration: _fieldDecoration('Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(controller: _addr, decoration: _fieldDecoration('Address')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _city,  decoration: _fieldDecoration('City'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _state, decoration: _fieldDecoration('State'))),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _zip,
          decoration: _fieldDecoration('ZIP Code'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          decoration: _fieldDecoration('Password'),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGold,
            foregroundColor: kBlack,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () {
            // TODO: Registration logic
          },
          child: const Text('Register'),
        ),
      ]),
    );
  }
}

/// Экран WebView с синхронизацией куки (iOS-only)
class AutoLoginWebView extends StatefulWidget {
  const AutoLoginWebView({Key? key}) : super(key: key);
  @override
  State<AutoLoginWebView> createState() => _AutoLoginWebViewState();
}

class _AutoLoginWebViewState extends State<AutoLoginWebView> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final token = await _storage.read(key: 'jwt');
    if (token == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    await _syncCookiesAndLoad(token);
  }

  Future<void> _syncCookiesAndLoad(String jwt) async {
    setState(() { _loading = true; _error = null; });
    try {
      // Сохраняем ещё раз
      await _storage.write(key: 'jwt', value: jwt);

      // Запрашиваем куки с сервера
      final res = await http.get(
        Uri.parse('$baseUrl/wp-json/custom/v1/get-auth-cookies'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (res.statusCode != 200) throw 'Cookie error ${res.statusCode}';

      final raw = jsonDecode(res.body) as List;
      final cookies = raw.map((e) => Map<String,String>.from(e)).toList();
      final unique = {for (var c in cookies) '${c['name']}:${c['path']}': c}.values.toList();

      // Отправляем в iOS WKWebView
      await _cookieChannel.invokeMethod('setCookies', {'cookies': unique});

      // Настраиваем WebView
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
          setState(() => _loading = false);
        }))
        ..loadRequest(Uri.parse('$baseUrl/mobile-app-home-subscriber/'));

      setState(() => _controller = ctrl);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'jwt');
    await _cookieChannel.invokeMethod('setCookies', {'cookies': []});
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UltraHome Dashboard', style: TextStyle(color: kBlack)),
        backgroundColor: kGold,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: kBlack), onPressed: _logout),
        ],
      ),
      body: Stack(children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red))),
      ]),
    );
  }
}
