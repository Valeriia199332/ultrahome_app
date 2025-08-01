// ---------------------------------------------------------
// main.dart
// Полный Flutter-код с:
//  - логином под любым пользователем
//  - автоматическим выходом при истечении JWT
//  - обработкой 401/403 и авто-лог-аутом
//  - логированием и SnackBar для ошибок
//  - опциональной схемой refresh-token
// ---------------------------------------------------------

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Константы приложения
const String baseUrl = 'https://ultrahomeservices.net';

/// MethodChannel для установки куки в iOS WKWebView
const MethodChannel _cookieChannel =
    MethodChannel('net.ultrahomeservices/cookie');

/// Локальное хранилище для JWT и refresh-token
final FlutterSecureStorage _storage = FlutterSecureStorage();

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
      theme: ThemeData(primarySwatch: Colors.amber),
      home: const EntryPoint(),
    );
  }
}

/// Парсим exp из payload JWT (универсальный, без внешних пакетов).
int _parseExpiry(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return 0;
    final payload = utf8
        .decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(payload) as Map<String, dynamic>;
    return map['exp'] as int? ?? 0;
  } catch (_) {
    return 0;
  }
}

/// Показываем SnackBar в любом месте
void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// Точка входа: если токен есть и валиден — WebView, иначе — экран логина
class EntryPoint extends StatefulWidget {
  const EntryPoint({Key? key}) : super(key: key);

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  bool? _hasValidToken;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final token = await _storage.read(key: 'jwt');
    if (token == null) {
      setState(() => _hasValidToken = false);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = _parseExpiry(token);
    if (exp == 0 || now >= exp) {
      await _storage.delete(key: 'jwt');
      await _storage.delete(key: 'refresh_token');
      setState(() => _hasValidToken = false);
    } else {
      setState(() => _hasValidToken = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasValidToken == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _hasValidToken == true
        ? const AutoLoginWebView()
        : const LoginPage();
  }
}

/// Экран логина
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/wp-json/jwt-auth/v1/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _userController.text.trim(),
          'password': _passController.text,
        }),
      );
      if (res.statusCode != 200) {
        _showSnackBar(context, 'Неправильные логин/пароль (${res.statusCode})');
        return;
      }
      final body = jsonDecode(res.body);
      final token = body['token'] as String?;
      final refresh = body['refresh_token'] as String?;
      if (token == null) throw 'No token in response';
      await _storage.write(key: 'jwt', value: token);
      if (refresh != null) {
        await _storage.write(key: 'refresh_token', value: refresh);
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AutoLoginWebView(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );
    } catch (e) {
      _showSnackBar(context, 'Ошибка логина: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'Username or Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            const Spacer(),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

/// WebView с автологином и кнопкой Logout
class AutoLoginWebView extends StatefulWidget {
  const AutoLoginWebView({Key? key}) : super(key: key);
  @override
  State<AutoLoginWebView> createState() => _AutoLoginWebViewState();
}

class _AutoLoginWebViewState extends State<AutoLoginWebView> {
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  /// Инициализация: проверка токена и синхронизация куки
  Future<void> _initAndLoad() async {
    final token = await _storage.read(key: 'jwt');
    if (token == null) {
      await _logout();
      return;
    }

    // Проверяем срок жизни токена
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now >= _parseExpiry(token)) {
      final didRefresh = await _tryRefresh(token);
      if (!didRefresh) {
        await _logout();
        return;
      }
    }

final freshTokenNullable = await _storage.read(key: 'jwt');
if (freshTokenNullable != null) {
  // Явно приводим к non-nullable локальной переменной
  final freshToken = freshTokenNullable;
  await _syncCookiesAndLoad(freshToken);
} else {
  await _logout();
}
  }

  /// Попытка обновить токен по схеме refresh-token
  Future<bool> _tryRefresh(String oldToken) async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/wp-json/jwt-auth/v1/token/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body);
      final newToken = body['token'] as String?;
      final newRefresh = body['refresh_token'] as String?;
      if (newToken == null) return false;
      await _storage.write(key: 'jwt', value: newToken);
      if (newRefresh != null) {
        await _storage.write(key: 'refresh_token', value: newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Синхронизация куки и загрузка WebView
  Future<void> _syncCookiesAndLoad(String jwtToken) async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/wp-json/custom/v1/get-auth-cookies'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 401 || res.statusCode == 403) {
        _showSnackBar(context, 'Сессия истекла, повторный вход…');
        await _logout();
        return;
      }
      if (res.statusCode != 200) {
        throw 'Ошибка получения куки: ${res.statusCode}';
      }

      final raw = jsonDecode(res.body) as List<dynamic>;
      final cookies = <Map<String, String>>[];
      for (final item in raw) {
        cookies.add({
          'name':   item['name']   as String,
          'value':  item['value']  as String,
          'domain': item['domain'] as String,
          'path':   item['path']   as String,
        });
      }
      final unique = {
        for (var c in cookies) '${c['name']}:${c['path']}': c
      }.values.toList();

      await _cookieChannel.invokeMethod('setCookies', {
        'cookies': unique,
      });

      final ctrl = WebViewController();
      ctrl
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(onPageFinished: (_) {
            setState(() => _loading = false);
          }),
        )
        ..loadRequest(Uri.parse('$baseUrl/mobile-app-home-subscriber/'));

      setState(() => _controller = ctrl);
    } catch (e) {
      _showSnackBar(context, 'Ошибка: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'refresh_token');
    await _cookieChannel.invokeMethod('setCookies', {'cookies': []});
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UltraHome Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
