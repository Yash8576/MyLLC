import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';

class MessagesSocketService {
  static const Duration _defaultHeartbeatInterval = Duration(seconds: 15);
  static const Duration _pongTimeout = Duration(seconds: 40);

  final ApiService _apiService;
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  String? _activeConversationId;
  bool _didReceiveWelcome = false;
  DateTime? _lastPongAt;
  Duration _heartbeatInterval = _defaultHeartbeatInterval;
  final List<Map<String, dynamic>> _pendingOutbound = <Map<String, dynamic>>[];

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
        _enqueueOrSend({
          'type': 'open_conversation',
          'conversation_id': _activeConversationId!,
        });
      }
      return;
    }

    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
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
      await channel.ready;
      _channel = channel;
      _subscription = channel.stream.listen(
        (event) {
          if (event is String) {
            final decoded = jsonDecode(event);
            if (decoded is Map<String, dynamic>) {
              _handleInboundEvent(decoded);
            }
          }
        },
        onDone: _handleSocketClosed,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Messages socket error: $error');
          _handleSocketClosed();
        },
        cancelOnError: true,
      );
      _reconnectAttempts = 0;
    } catch (error) {
      debugPrint('Failed to connect messages socket: $error');
      _resetSocketState();
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void openConversation(String conversationId) {
    _activeConversationId = conversationId;
    _enqueueOrSend({
      'type': 'open_conversation',
      'conversation_id': conversationId,
    });
  }

  void closeConversation(String conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
    _enqueueOrSend({
      'type': 'close_conversation',
      'conversation_id': conversationId,
    });
  }

  void setTyping(String conversationId, bool isTyping) {
    _enqueueOrSend({
      'type': 'typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
    });
  }

  void _enqueueOrSend(Map<String, dynamic> payload) {
    if (!_isConnected || _channel == null || !_didReceiveWelcome) {
      _queuePayload(payload);
      return;
    }
    _sendNow(payload);
  }

  void _queuePayload(Map<String, dynamic> payload) {
    final type = payload['type'];
    final conversationId = payload['conversation_id'];

    if (type == 'typing' && conversationId is String) {
      _pendingOutbound.removeWhere(
        (item) =>
            item['type'] == 'typing' &&
            item['conversation_id'] == conversationId,
      );
    }
    if (type == 'open_conversation' && conversationId is String) {
      _pendingOutbound.removeWhere(
        (item) =>
            item['type'] == 'open_conversation' &&
            item['conversation_id'] == conversationId,
      );
    }

    _pendingOutbound.add(Map<String, dynamic>.from(payload));
    if (_pendingOutbound.length > 50) {
      _pendingOutbound.removeAt(0);
    }
  }

  void _sendNow(Map<String, dynamic> payload) {
    _channel!.sink.add(jsonEncode(payload));
  }

  void _handleInboundEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'welcome':
        _didReceiveWelcome = true;
        _isConnected = true;
        _lastPongAt = DateTime.now();
        final intervalMs = event['heartbeat_interval_ms'];
        if (intervalMs is int && intervalMs > 0) {
          _heartbeatInterval = Duration(milliseconds: intervalMs);
        } else {
          _heartbeatInterval = _defaultHeartbeatInterval;
        }
        _startHeartbeat();
        _eventsController
            .add(const {'type': 'connection_state', 'connected': true});
        _flushPendingOutbound();
        return;
      case 'pong':
        _lastPongAt = DateTime.now();
        return;
    }

    _eventsController.add(event);
  }

  void _flushPendingOutbound() {
    if (!_isConnected || _channel == null || !_didReceiveWelcome) {
      return;
    }

    if (_activeConversationId != null && _activeConversationId!.isNotEmpty) {
      _sendNow({
        'type': 'open_conversation',
        'conversation_id': _activeConversationId!,
      });
    }

    final pending = List<Map<String, dynamic>>.from(_pendingOutbound);
    _pendingOutbound.clear();
    for (final payload in pending) {
      _sendNow(payload);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final now = DateTime.now();
      final lastPongAt = _lastPongAt;
      if (lastPongAt != null && now.difference(lastPongAt) > _pongTimeout) {
        _forceReconnect();
        return;
      }

      if (_channel == null || !_didReceiveWelcome) {
        return;
      }

      _sendNow({
        'type': 'ping',
        'sent_at': now.toUtc().toIso8601String(),
      });
    });
  }

  void _forceReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _handleSocketClosed();
  }

  void _resetSocketState() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isConnected = false;
    _didReceiveWelcome = false;
    _lastPongAt = null;
    _heartbeatInterval = _defaultHeartbeatInterval;
    _channel = null;
  }

  void _handleSocketClosed() {
    final wasConnected = _isConnected;
    _resetSocketState();
    if (wasConnected && !_eventsController.isClosed) {
      _eventsController
          .add(const {'type': 'connection_state', 'connected': false});
    }
    if (_shouldReconnect && !_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || !_shouldReconnect || _isConnected || _isConnecting) {
      return;
    }

    _reconnectTimer?.cancel();
    final attempt = _reconnectAttempts + 1;
    final cappedAttempt = attempt.clamp(1, 6);
    final jitterMs = DateTime.now().millisecondsSinceEpoch % 1000;
    final delayMs = (1000 * (1 << (cappedAttempt - 1))) + jitterMs;
    _reconnectAttempts = attempt.clamp(0, 10);
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_isDisposed) {
        connect(conversationId: _activeConversationId);
      }
    });
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _resetSocketState();
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _eventsController.close();
  }
}
