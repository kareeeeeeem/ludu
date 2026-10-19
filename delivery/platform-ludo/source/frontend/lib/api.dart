import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'theme/game_feedback.dart';
import 'platform_launch_stub.dart'
    if (dart.library.html) 'platform_launch_web.dart' as launch;

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class Api extends ChangeNotifier {
  static const bool mockPlatform = bool.fromEnvironment('USE_MOCK_PLATFORM');
  static const MethodChannel platformChannel = MethodChannel(
    'ludo.club/platform',
  );
  // Default local routes: iOS Simulator reaches the Mac over loopback;
  // Android Emulator reaches it through its host alias. Override for devices.
  static const _configuredBase = String.fromEnvironment('API_URL');
  static final String base =
      _configuredBase.isNotEmpty
          ? _configuredBase
          : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:3107'
          : 'http://127.0.0.1:3107';
  final storage = const FlutterSecureStorage();
  String? token;
  Map<String, dynamic>? user;
  Map<String, dynamic>? game;
  io.Socket? socket;
  bool online = false;
  bool soundEnabled = true;
  bool hapticsEnabled = true;
  int serverOffset = 0;
  String? sessionError;
  final List<Map<String, dynamic>> chats = [];
  Api() {
    if (!kIsWeb) {
      platformChannel.setMethodCallHandler((call) async {
        if (call.method == 'sessionAvailable') await restore();
      });
    }
  }
  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$base/api$path'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 15)),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 &&
          !['/auth/admin-login', '/auth/refresh'].contains(path)) {
        token = null;
        user = null;
        game = null;
        socket?.dispose();
        await storage.delete(key: 'token');
        notifyListeners();
      }
      throw ApiException(
        response.statusCode,
        data is Map
            ? data['error']?.toString() ?? 'Request failed'
            : 'Request failed',
      );
    }
    return data;
  }

  Future<void> restore() async {
    soundEnabled = await storage.read(key: 'soundEnabled') != 'false';
    hapticsEnabled = await storage.read(key: 'hapticsEnabled') != 'false';
    GameFeedback.soundEnabled = soundEnabled;
    GameFeedback.hapticsEnabled = hapticsEnabled;
    try {
      String? session;
      if (mockPlatform && kDebugMode) {
        session = 'mock:local_player';
      } else if (kIsWeb) {
        session = launch.takeWebLaunchSession();
      } else {
        session = await platformChannel.invokeMethod<String>('getSession');
      }
      if (session == null || session.isEmpty) {
        token = await storage.read(key: 'token');
        if (token != null) {
          await refresh();
          connect();
          sessionError = null;
          notifyListeners();
          return;
        }
        throw StateError('Open Ludo Club from the gaming platform.');
      }
      final data = await call(
        '/v1/platform/session/exchange',
        method: 'POST',
        body: {'sessionToken': session},
      );
      token = data['token'];
      await storage.write(key: 'token', value: token);
      user = Map<String, dynamic>.from(data['user']);
      connect();
      await refresh();
      sessionError = null;
    } catch (e) {
      sessionError = e.toString();
      user = null;
    }
    notifyListeners();
  }

  Future<void> setSound(bool enabled) async {
    soundEnabled = enabled;
    GameFeedback.soundEnabled = enabled;
    notifyListeners();
    await storage.write(key: 'soundEnabled', value: '$enabled');
  }

  Future<void> setHaptics(bool enabled) async {
    hapticsEnabled = enabled;
    GameFeedback.hapticsEnabled = enabled;
    notifyListeners();
    await storage.write(key: 'hapticsEnabled', value: '$enabled');
  }

  Future<void> adminLogin(String email, String password) async {
    final data = await call(
      '/auth/admin-login',
      method: 'POST',
      body: {'email': email.trim(), 'password': password},
    );
    token = data['token'];
    user = Map<String, dynamic>.from(data['user']);
    await storage.write(key: 'token', value: token);
    await storage.delete(key: 'refreshToken');
    connect();
    await refresh();
    notifyListeners();
  }

  Future<void> refresh() async {
    user = Map<String, dynamic>.from(await call('/auth/me'));
    final id = user?['activeGame'];
    if (id != null && id != 'queue') await loadGame(id);
    notifyListeners();
  }

  void acceptGame(dynamic data) {
    final incoming = Map<String, dynamic>.from(data);
    if (incoming['serverTime'] is int) {
      serverOffset =
          incoming['serverTime'] - DateTime.now().millisecondsSinceEpoch;
    }
    if (game?['id'] == incoming['id'] &&
        (game?['state']?['revision'] ?? -1) >
            (incoming['state']?['revision'] ?? -1)) {
      return;
    }
    if (game?['id'] != incoming['id']) chats.clear();
    game = incoming;
    if (user != null) {
      user!['activeGame'] =
          ['waiting', 'active'].contains(game!['status']) ? game!['id'] : null;
    }
    notifyListeners();
  }

  void connect() {
    socket?.dispose();
    socket = io.io(
      base,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    socket!.onConnect((_) {
      online = true;
      socket!.emitWithAck(
        'sync',
        {},
        ack: (dynamic response) {
          if (response is Map &&
              response['ok'] == true &&
              response['data'] is Map &&
              response['data']['id'] != null) {
            acceptGame(response['data']);
          }
        },
      );
      notifyListeners();
    });
    socket!.onDisconnect((_) {
      online = false;
      notifyListeners();
    });
    socket!.onConnectError((_) {
      online = false;
      notifyListeners();
    });
    socket!.on('game_state', acceptGame);
    socket!.on('chat_message', acceptChat);
    socket!.connect();
  }

  void acceptChat(dynamic data) {
    if (data['game'] == game?['id'] &&
        !chats.any((c) => c['_id'] == data['_id'])) {
      chats.add(Map<String, dynamic>.from(data));
      notifyListeners();
    }
  }

  Future<void> loadGame(String id) async {
    acceptGame(await call('/games/$id'));
    final data = await call('/games/$id/chat') as List;
    chats
      ..clear()
      ..addAll(data.map((d) => Map<String, dynamic>.from(d)));
    notifyListeners();
  }

  Future<void> action(String type, {int? tokenIndex}) async {
    final id = game!['id'];
    try {
      acceptGame(
        await call(
          '/games/$id/action',
          method: 'POST',
          body: {
            'type': type,
            'revision': game!['state']['revision'],
            if (tokenIndex != null) 'token': tokenIndex,
          },
        ),
      );
    } catch (_) {
      await loadGame(id);
      rethrow;
    }
  }

  Future<void> logout() async {
    await call('/auth/logout', method: 'POST');
    socket?.dispose();
    token = null;
    user = null;
    game = null;
    chats.clear();
    await storage.delete(key: 'token');
    await storage.delete(key: 'refreshToken');
    notifyListeners();
    sessionError = 'Open Ludo Club from the gaming platform.';
  }

  Future<void> returnToPlatform() async {
    try {
      if (token != null) await call('/v1/game/session/end', method: 'POST');
    } finally {
      socket?.dispose();
      token = null;
      user = null;
      game = null;
      await storage.delete(key: 'token');
      notifyListeners();
      if (kIsWeb) {
        launch.returnToPlatform();
      } else {
        await platformChannel.invokeMethod<void>('returnToPlatform');
      }
    }
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }
}
