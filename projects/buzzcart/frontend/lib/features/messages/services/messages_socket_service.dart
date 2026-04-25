import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';

class MessagesSocketService {
  final ApiService _apiService;
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  String? _activeConversationId;

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
      if (_activeConversationId != null && _activeConversationId!.isNotEmpty) {
        openConversation(_activeConversationId!);
      }
      return;
    }

    _reconnectTimer?.cancel();
    _isConnecting = true;
    _shouldReconnect = true;
    try {
      final token = await _apiService.getAuthToken();
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      final uri = Uri.parse('${AppConfig.wsBaseUrl}/messages').replace(
        queryParameters: {
          'token': token,
          if (_activeConversationId != null && _activeConversationId!.isNotEmpty)
            'conversation_id': _activeConversationId,
        },
      );

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (event) {
          if (event is String) {
            final decoded = jsonDecode(event);
            if (decoded is Map<String, dynamic>) {
              _eventsController.add(decoded);
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
      _isConnected = true;
      _reconnectAttempts = 0;

      if (_activeConversationId != null && _activeConversationId!.isNotEmpty) {
        openConversation(_activeConversationId!);
      }
    } catch (error) {
      debugPrint('Failed to connect messages socket: $error');
      _isConnected = false;
      _channel = null;
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

  void setTyping(String conversationId, bool isTyping) {
    _send({
      'type': 'typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
    });
  }

  void _send(Map<String, dynamic> payload) {
    if (!_isConnected || _channel == null) {
      return;
    }
    _channel!.sink.add(jsonEncode(payload));
  }

  void _handleSocketClosed() {
    _isConnected = false;
    _channel = null;
    if (_shouldReconnect && !_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || !_shouldReconnect || _isConnected || _isConnecting) {
      return;
    }

    _reconnectTimer?.cancel();
    final delaySeconds = (_reconnectAttempts + 1).clamp(1, 5);
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, 10);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed) {
        connect(conversationId: _activeConversationId);
      }
    });
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _eventsController.close();
  }
}
