import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';

class MessagesSocketService {
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _defaultHeartbeatInterval = Duration(seconds: 15);
  static const Duration _pongTimeout = Duration(seconds: 15);
  static const int _maxQueuedMessages = 64;

  final ApiService _apiService;
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> _pendingMessages = <Map<String, dynamic>>[];
  final Random _random = Random();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _pongTimeoutTimer;
  Timer? _welcomeTimeoutTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  bool _isDisposed = false;
  bool _didReceiveWelcome = false;
  int _reconnectAttempts = 0;
  String? _activeConversationId;
  Duration _heartbeatInterval = _defaultHeartbeatInterval;

  MessagesSocketService(this._apiService);

  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect({String? conversationId}) async {
    if (conversationId != null && conversationId.isNotEmpty) {
      _activeConversationId = conversationId;
    }

    if (_isDisposed) {
      return;
    }

    if (_isConnected || _isConnecting) {
      if (_activeConversationId != null &&
          _activeConversationId!.isNotEmpty &&
          _isConnected) {
        openConversation(_activeConversationId!);
      }
      return;
    }

    _reconnectTimer?.cancel();
    _isConnecting = true;
    _shouldReconnect = true;
    _didReceiveWelcome = false;

    try {
      final token = await _apiService.getAuthToken();
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      final uri = Uri.parse('${AppConfig.wsBaseUrl}/messages').replace(
        queryParameters: {
          'token': token,
          if (_activeConversationId != null &&
              _activeConversationId!.isNotEmpty)
            'conversation_id': _activeConversationId,
        },
      );

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription?.cancel();
      _subscription = channel.stream.listen(
        (event) => _handleSocketData(channel, event),
        onDone: () => _handleSocketClosed(channel),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Messages socket error: $error');
          _handleSocketClosed(channel);
        },
        cancelOnError: true,
      );

      await channel.ready.timeout(_connectTimeout);
      _welcomeTimeoutTimer?.cancel();
      _welcomeTimeoutTimer = Timer(_connectTimeout, () {
        if (!_didReceiveWelcome && identical(channel, _channel)) {
          debugPrint('Messages socket welcome handshake timed out');
          _handleSocketClosed(channel);
        }
      });
    } catch (error) {
      debugPrint('Failed to connect messages socket: $error');
      _cleanupConnectionState();
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void openConversation(String conversationId) {
    _activeConversationId = conversationId;
    _send({
      'type': 'open_conversation',
      'conversation_id': conversationId,
    });
  }

  void closeConversation(String conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
    _send({
      'type': 'close_conversation',
      'conversation_id': conversationId,
    });
  }

  /// Acks that the user has seen everything in the conversation right now —
  /// sent when a message arrives while the chat is open on screen, so the
  /// sender's ticks turn blue immediately without any refetch.
  void markConversationRead(String conversationId) {
    _send({
      'type': 'mark_read',
      'conversation_id': conversationId,
    });
  }

  void setTyping(String conversationId, bool isTyping) {
    _send({
      'type': 'typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
    });
  }

  void setAppState(bool isActive) {
    _send({
      'type': 'app_state',
      'is_active': isActive,
    });
  }

  void _handleSocketData(WebSocketChannel channel, dynamic event) {
    if (!identical(channel, _channel) || event is! String) {
      return;
    }

    try {
      final decoded = jsonDecode(event);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final type = decoded['type'] as String?;
      switch (type) {
        case 'welcome':
          _markConnected(decoded);
          return;
        case 'pong':
          _clearPongTimeout();
          return;
        default:
          _eventsController.add(decoded);
      }
    } catch (error) {
      debugPrint('Failed to decode messages socket payload: $error');
    }
  }

  void _markConnected(Map<String, dynamic> event) {
    if (_isDisposed || _didReceiveWelcome) {
      return;
    }

    _didReceiveWelcome = true;
    _isConnected = true;
    _reconnectAttempts = 0;

    final intervalMs = event['heartbeat_interval_ms'];
    if (intervalMs is int && intervalMs > 0) {
      _heartbeatInterval = Duration(milliseconds: intervalMs);
    } else {
      _heartbeatInterval = _defaultHeartbeatInterval;
    }

    _welcomeTimeoutTimer?.cancel();
    _welcomeTimeoutTimer = null;
    _startHeartbeat();
    _flushPendingMessages();

    if (!_eventsController.isClosed) {
      _eventsController
          .add(const {'type': 'connection_state', 'connected': true});
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_isConnected || _channel == null) {
        return;
      }

      _sendNow(const {'type': 'ping'});
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = Timer(_pongTimeout, () {
        debugPrint('Messages socket heartbeat timed out');
        _handleSocketClosed(_channel);
      });
    });
  }

  void _clearPongTimeout() {
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  void _send(Map<String, dynamic> payload) {
    if (_isDisposed) {
      return;
    }

    if (_isConnected && _channel != null) {
      _sendNow(payload);
      return;
    }

    _queuePayload(payload);
    if (!_isConnecting && _shouldReconnect) {
      _scheduleReconnect(immediate: true);
    }
  }

  void _queuePayload(Map<String, dynamic> payload) {
    final type = payload['type'];
    final conversationId = payload['conversation_id'];

    if (type == 'typing' && conversationId is String) {
      _pendingMessages.removeWhere(
        (item) =>
            item['type'] == 'typing' &&
            item['conversation_id'] == conversationId,
      );
    }
    if (type == 'open_conversation' && conversationId is String) {
      _pendingMessages.removeWhere(
        (item) =>
            item['type'] == 'open_conversation' &&
            item['conversation_id'] == conversationId,
      );
    }
    if (type == 'app_state') {
      _pendingMessages.removeWhere((item) => item['type'] == 'app_state');
    }

    if (_pendingMessages.length >= _maxQueuedMessages) {
      _pendingMessages.removeAt(0);
    }
    _pendingMessages.add(Map<String, dynamic>.from(payload));
  }

  void _sendNow(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    try {
      channel.sink.add(jsonEncode(payload));
    } catch (error) {
      debugPrint('Failed to send messages socket payload: $error');
      _handleSocketClosed(channel);
    }
  }

  void _flushPendingMessages() {
    if (!_isConnected || _channel == null || _pendingMessages.isEmpty) {
      return;
    }

    final pending = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final payload in pending) {
      _sendNow(payload);
    }
  }

  void _handleSocketClosed(WebSocketChannel? channel) {
    if (channel != null && !identical(channel, _channel)) {
      return;
    }

    final wasConnected = _isConnected;
    _cleanupConnectionState();

    if (wasConnected && !_eventsController.isClosed) {
      _eventsController
          .add(const {'type': 'connection_state', 'connected': false});
    }

    if (_shouldReconnect && !_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _cleanupConnectionState() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _clearPongTimeout();
    _welcomeTimeoutTimer?.cancel();
    _welcomeTimeoutTimer = null;
    _didReceiveWelcome = false;
    _isConnected = false;
    _heartbeatInterval = _defaultHeartbeatInterval;

    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());

    final channel = _channel;
    _channel = null;
    unawaited(channel?.sink.close());
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (_isDisposed || !_shouldReconnect || _isConnected || _isConnecting) {
      return;
    }

    _reconnectTimer?.cancel();
    final delay =
        immediate ? Duration.zero : _nextReconnectDelay(_reconnectAttempts);
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, 10);
    _reconnectTimer = Timer(delay, () {
      if (!_isDisposed) {
        unawaited(connect(conversationId: _activeConversationId));
      }
    });
  }

  Duration _nextReconnectDelay(int attempt) {
    final cappedAttempt = attempt.clamp(0, 6);
    final baseSeconds = 1 << cappedAttempt;
    final jitterMillis = _random.nextInt(750);
    return Duration(
      seconds: baseSeconds,
      milliseconds: jitterMillis,
    );
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _clearPongTimeout();
    _welcomeTimeoutTimer?.cancel();
    _welcomeTimeoutTimer = null;
    _pendingMessages.clear();

    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _didReceiveWelcome = false;
    _heartbeatInterval = _defaultHeartbeatInterval;

    await subscription?.cancel();
    await channel?.sink.close();
  }

  void dispose() {
    _isDisposed = true;
    unawaited(disconnect());
    _eventsController.close();
  }
}
