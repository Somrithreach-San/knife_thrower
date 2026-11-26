import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

enum OnlineConnectionState { disconnected, connecting, connected, error }

class OnlineGameService {
  static const String _serverUrlPrefKey = 'online_server_url';
  static const String _envServerUrl = String.fromEnvironment('SERVER_URL');
  static String get defaultServerUrl {
    if (_envServerUrl.isNotEmpty) return _envServerUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  io.Socket? _socket;
  String _serverUrl = defaultServerUrl;

  String? roomCode;
  int? localPlayerNumber; // 1 = Host (Red/Bottom), 2 = Guest (Blue/Top)
  int? matchSeed;

  final ValueNotifier<OnlineConnectionState> connectionState = ValueNotifier(
    OnlineConnectionState.disconnected,
  );
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  // Lobby callbacks
  void Function(String roomCode, int playerNumber, int seed)? onRoomCreated;
  void Function(String roomCode, int seed)? onGameStart;
  void Function(String error)? onRoomError;

  // In-game callbacks
  void Function(int playerNumber, double targetAngle)? onOpponentThrow;
  void Function(double angle, double directionSign)? onTargetSync;
  void Function(int seed)? onRematchStart;
  void Function()? onOpponentRematchReady;
  void Function()? onOpponentDisconnected;

  String get serverUrl => _serverUrl;

  Future<String> loadSavedServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_serverUrlPrefKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _serverUrl = saved.trim();
      }
    } catch (_) {}
    return _serverUrl;
  }

  Future<void> saveServerUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    _serverUrl = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverUrlPrefKey, trimmed);
    } catch (_) {}
  }

  Future<bool> connect([String? customUrl]) async {
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      await saveServerUrl(customUrl);
    } else {
      await loadSavedServerUrl();
    }

    if (_socket != null && _socket!.connected) {
      connectionState.value = OnlineConnectionState.connected;
      return true;
    }

    disconnect();

    connectionState.value = OnlineConnectionState.connecting;
    errorMessage.value = null;

    final completer = Completer<bool>();

    final socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setTimeout(45000)
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      debugPrint('[OnlineGameService] Connected to $_serverUrl');
      connectionState.value = OnlineConnectionState.connected;
      errorMessage.value = null;
      if (!completer.isCompleted) completer.complete(true);
    });

    socket.onConnectError((err) {
      debugPrint('[OnlineGameService] Connect error: $err');
      connectionState.value = OnlineConnectionState.error;
      errorMessage.value = 'Something went wrong. Please try again.';
      if (!completer.isCompleted) completer.complete(false);
    });

    socket.onDisconnect((_) {
      debugPrint('[OnlineGameService] Disconnected');
      if (connectionState.value != OnlineConnectionState.error) {
        connectionState.value = OnlineConnectionState.disconnected;
      }
      if (roomCode != null) {
        roomCode = null;
        onOpponentDisconnected?.call();
      }
    });

    socket.on('room_created', (data) {
      if (data is Map) {
        roomCode = data['roomCode']?.toString();
        localPlayerNumber = (data['playerNumber'] as num?)?.toInt() ?? 1;
        matchSeed = (data['seed'] as num?)?.toInt();
        if (roomCode != null && matchSeed != null) {
          onRoomCreated?.call(roomCode!, localPlayerNumber!, matchSeed!);
        }
      }
    });

    socket.on('game_start', (data) {
      if (data is Map) {
        final code = data['roomCode']?.toString() ?? roomCode;
        final seed = (data['seed'] as num?)?.toInt() ?? matchSeed ?? 1;
        roomCode = code;
        matchSeed = seed;
        if (code != null) {
          onGameStart?.call(code, seed);
        }
      }
    });

    socket.on('room_error', (data) {
      final msg = (data is Map ? data['error']?.toString() : null) ??
          'Unable to join room.';
      errorMessage.value = msg;
      onRoomError?.call(msg);
    });

    socket.on('opponent_throw', (data) {
      if (data is Map) {
        final p = (data['playerNumber'] as num?)?.toInt();
        final angle = (data['targetAngle'] as num?)?.toDouble() ?? 0.0;
        if (p != null) {
          onOpponentThrow?.call(p, angle);
        }
      }
    });

    socket.on('target_sync', (data) {
      if (data is Map) {
        final angle = (data['angle'] as num?)?.toDouble() ?? 0.0;
        final dir = (data['directionSign'] as num?)?.toDouble() ?? 1.0;
        onTargetSync?.call(angle, dir);
      }
    });

    socket.on('rematch_start', (data) {
      if (data is Map) {
        final seed = (data['seed'] as num?)?.toInt() ?? 1;
        matchSeed = seed;
        onRematchStart?.call(seed);
      }
    });

    socket.on('opponent_rematch_ready', (_) {
      onOpponentRematchReady?.call();
    });

    socket.on('opponent_disconnected', (_) {
      onOpponentDisconnected?.call();
    });

    socket.connect();

    // Timeout safety in case socket_io_client doesn't fire onConnectError quickly
    // (45s allows Render free-tier cold starts to wake up if needed)
    Future.delayed(const Duration(seconds: 45), () {
      if (!completer.isCompleted) {
        connectionState.value = OnlineConnectionState.error;
        errorMessage.value = 'Connection timed out. Please try again.';
        completer.complete(false);
      }
    });

    return completer.future;
  }

  Future<void> createRoom() async {
    final ok = await connect();
    if (!ok || _socket == null) return;
    _socket!.emit('create_room', {});
  }

  Future<void> joinRoom(String code) async {
    final normalized = code.trim();
    if (normalized.length < 3) {
      const msg = 'Please enter a valid 3-digit room PIN.';
      errorMessage.value = msg;
      onRoomError?.call(msg);
      return;
    }
    final ok = await connect();
    if (!ok || _socket == null) return;
    localPlayerNumber = 2;
    _socket!.emitWithAck(
      'join_room',
      {'roomCode': normalized},
      ack: (response) {
        if (response is Map) {
          if (response['ok'] == true) {
            roomCode = response['roomCode']?.toString() ?? normalized;
            localPlayerNumber =
                (response['playerNumber'] as num?)?.toInt() ?? 2;
            matchSeed = (response['seed'] as num?)?.toInt();
          } else {
            final msg =
                response['error']?.toString() ?? 'Could not join room.';
            errorMessage.value = msg;
            onRoomError?.call(msg);
          }
        }
      },
    );
  }

  void sendThrow(double targetAngle) {
    if (_socket == null || !_socket!.connected || roomCode == null) return;
    _socket!.emit('throw_knife', {
      'roomCode': roomCode,
      'targetAngle': targetAngle,
    });
  }

  void sendTargetSync(double angle, double directionSign) {
    if (_socket == null ||
        !_socket!.connected ||
        roomCode == null ||
        localPlayerNumber != 1) {
      return;
    }
    _socket!.emit('target_sync', {
      'roomCode': roomCode,
      'angle': angle,
      'directionSign': directionSign,
    });
  }

  void sendRematchRequest() {
    if (_socket == null || !_socket!.connected || roomCode == null) return;
    _socket!.emit('request_rematch', {'roomCode': roomCode});
  }

  void leaveRoom() {
    if (_socket != null && _socket!.connected && roomCode != null) {
      _socket!.emit('leave_room', {'roomCode': roomCode});
    }
    roomCode = null;
    localPlayerNumber = null;
    matchSeed = null;
  }

  void clearInGameCallbacks() {
    onOpponentThrow = null;
    onTargetSync = null;
    onRematchStart = null;
    onOpponentRematchReady = null;
    onOpponentDisconnected = null;
  }

  void disconnect() {
    leaveRoom();
    _socket?.dispose();
    _socket = null;
    connectionState.value = OnlineConnectionState.disconnected;
  }

  void dispose() {
    disconnect();
    connectionState.dispose();
    errorMessage.dispose();
  }
}
