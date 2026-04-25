import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../services/messages_socket_service.dart';

class MessagesProvider extends ChangeNotifier {
  static const Duration _presenceFreshness = Duration(seconds: 7);

  final ApiService _apiService;
  late final MessagesSocketService _socketService;

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  Timer? _presencePruneTimer;
  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _didLoadInitialData = false;
  bool _isMessagesScreenVisible = false;

  List<ConversationModel> _conversations = [];
  List<MessageConnectionModel> _connections = [];
  final Map<String, List<ChatMessageModel>> _messagesByConversation = {};
  final Map<String, Set<String>> _typingUsersByConversation = {};
  final Map<String, Map<String, Timer>> _typingExpiryTimersByConversation = {};
  final Map<String, Set<String>> _activeUsersByConversation = {};
  final Map<String, Map<String, DateTime>> _activePresenceSeenAtByConversation =
      {};
  Timer? _presenceHeartbeatTimer;

  String? _selectedConversationId;
  MessageParticipantModel? _selectedParticipant;
  MessageComposerDraft? _draft;
  bool _isLoadingConversations = false;
  bool _isLoadingConnections = false;
  bool _isLoadingThread = false;
  bool _isSending = false;

  MessagesProvider({required ApiService apiService})
      : _apiService = apiService {
    _socketService = MessagesSocketService(apiService);
    _presencePruneTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pruneStalePresence(),
    );
  }

  List<ConversationModel> get conversations => _conversations;
  List<MessageConnectionModel> get connections => _connections;
  List<ChatMessageModel> get selectedMessages => _selectedConversationId == null
      ? const []
      : (_messagesByConversation[_selectedConversationId] ?? const []);
  String? get selectedConversationId => _selectedConversationId;
  MessageParticipantModel? get selectedParticipant => _selectedParticipant;
  MessageComposerDraft? get draft => _draft;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingConnections => _isLoadingConnections;
  bool get isLoadingThread => _isLoadingThread;
  bool get isSending => _isSending;
  int get totalUnreadCount =>
      _conversations.fold<int>(0, (sum, item) => sum + item.unreadCount);

  bool get hasSelectedConversation =>
      _selectedParticipant != null || _selectedConversationId != null;

  bool get isOtherUserTyping {
    final participant = _selectedParticipant;
    final conversationId = _selectedConversationId;
    if (participant == null || conversationId == null) {
      return false;
    }
    return _typingUsersByConversation[conversationId]
            ?.contains(participant.id) ??
        false;
  }

  bool get isOtherUserActiveInChat {
    final participant = _selectedParticipant;
    final conversationId = _selectedConversationId;
    if (participant == null || conversationId == null) {
      return false;
    }
    final lastSeen =
        _activePresenceSeenAtByConversation[conversationId]?[participant.id];
    if (lastSeen == null) {
      return false;
    }
    return DateTime.now().difference(lastSeen) <= _presenceFreshness;
  }

  void setMessagesScreenVisible(bool isVisible) {
    if (_isMessagesScreenVisible == isVisible) {
      return;
    }

    _isMessagesScreenVisible = isVisible;
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return;
    }

    if (isVisible) {
      _resumeConversationPresence(conversationId);
      return;
    }

    _deactivateConversationPresence(
      conversationId,
      clearCachedPresence: true,
    );
  }

  void updateAuthState({
    required bool isAuthenticated,
    required UserModel? user,
  }) {
    final authChanged =
        _isAuthenticated != isAuthenticated || _currentUser?.id != user?.id;

    _isAuthenticated = isAuthenticated;
    _currentUser = user;

    if (!isAuthenticated || user == null) {
      _didLoadInitialData = false;
      _isMessagesScreenVisible = false;
      _conversations = [];
      _connections = [];
      _messagesByConversation.clear();
      _typingUsersByConversation.clear();
      _clearTypingExpiryTimers();
      _activeUsersByConversation.clear();
      _activePresenceSeenAtByConversation.clear();
      _stopPresenceHeartbeat();
      _selectedConversationId = null;
      _selectedParticipant = null;
      _draft = null;
      _disconnectSocket();
      notifyListeners();
      return;
    }

    if (authChanged) {
      _connectSocket();
    }
  }

  Future<void> initialize({MessagesRouteIntent? intent}) async {
    if (!_isAuthenticated || _currentUser == null) {
      return;
    }

    await _connectSocket();

    if (!_didLoadInitialData) {
      await Future.wait([
        refreshConversations(),
        loadConnections(),
      ]);
      _didLoadInitialData = true;
    }

    if (intent != null) {
      await applyIntent(intent);
    }
  }

  Future<void> refreshConversations() async {
    if (!_isAuthenticated) {
      return;
    }

    _isLoadingConversations = true;
    notifyListeners();
    try {
      _conversations = await _apiService.getConversations();
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> loadConnections() async {
    if (!_isAuthenticated) {
      return;
    }

    _isLoadingConnections = true;
    notifyListeners();
    try {
      _connections = await _apiService.getMessageConnections();
    } finally {
      _isLoadingConnections = false;
      notifyListeners();
    }
  }

  Future<void> applyIntent(MessagesRouteIntent intent) async {
    _draft = intent.draft;

    if (intent.conversationId != null && intent.conversationId!.isNotEmpty) {
      await openConversationById(
        intent.conversationId!,
        fallbackParticipant: intent.participant,
      );
      return;
    }

    if (intent.participant != null) {
      final existingConversationId = _findConversationIdForParticipant(
        intent.participant!.id,
      );
      if (existingConversationId != null) {
        await openConversationById(
          existingConversationId,
          fallbackParticipant: intent.participant,
        );
        return;
      }

      await startDraftConversation(intent.participant!);
      return;
    }

    notifyListeners();
  }

  Future<void> openConversation(ConversationModel conversation) async {
    await openConversationById(
      conversation.id,
      fallbackParticipant: conversation.participant,
    );
  }

  Future<void> openConversationById(
    String conversationId, {
    MessageParticipantModel? fallbackParticipant,
  }) async {
    if (!_isAuthenticated) {
      return;
    }

    final previousConversationId = _selectedConversationId;
    _selectedConversationId = conversationId;
    _selectedParticipant = fallbackParticipant ??
        _conversations
            .cast<ConversationModel?>()
            .firstWhere(
              (conversation) => conversation?.id == conversationId,
              orElse: () => null,
            )
            ?.participant;
    _isLoadingThread = true;
    notifyListeners();

    if (previousConversationId != null &&
        previousConversationId != conversationId) {
      _deactivateConversationPresence(
        previousConversationId,
        clearCachedPresence: true,
      );
    }

    try {
      final thread = await _apiService.getConversationThread(conversationId);
      _messagesByConversation[conversationId] = thread.messages;
      _selectedParticipant = thread.participant;
      _upsertConversation(
        ConversationModel(
          id: thread.conversationId,
          participant: thread.participant,
          lastMessage: thread.messages.isNotEmpty ? thread.messages.last : null,
          unreadCount: 0,
          updatedAt: thread.messages.isNotEmpty
              ? thread.messages.last.createdAt
              : DateTime.now().toIso8601String(),
        ),
      );
      await _connectSocket(conversationId: conversationId);
      _activateConversationPresenceIfVisible(conversationId);
    } finally {
      _isLoadingThread = false;
      notifyListeners();
    }
  }

  Future<void> startDraftConversation(
      MessageParticipantModel participant) async {
    if (_selectedConversationId != null) {
      _deactivateConversationPresence(
        _selectedConversationId!,
        clearCachedPresence: true,
      );
    }
    _selectedConversationId = null;
    _selectedParticipant = participant;
    notifyListeners();
  }

  Future<void> openConnection(MessageConnectionModel connection) async {
    final participant = MessageParticipantModel(
      id: connection.id,
      name: connection.name,
      avatar: connection.avatar,
    );
    if (connection.conversationId != null &&
        connection.conversationId!.isNotEmpty) {
      await openConversationById(
        connection.conversationId!,
        fallbackParticipant: participant,
      );
      return;
    }
    await startDraftConversation(participant);
  }

  Future<void> sendMessage(String inputText) async {
    final participant = _selectedParticipant;
    if (participant == null) {
      return;
    }

    final text = inputText.trim();
    final draft = _draft;
    if (text.isEmpty && draft == null) {
      return;
    }

    _isSending = true;
    notifyListeners();
    try {
      final createdMessage = await _apiService.createMessage(
        receiverId: participant.id,
        content: text.isNotEmpty ? text : (draft?.content ?? ''),
        messageType: draft?.messageType ?? 'text',
        productId: draft?.productId,
        metadata: draft?.metadata,
      );

      _selectedConversationId = createdMessage.conversationId;
      _messagesByConversation.putIfAbsent(
        createdMessage.conversationId,
        () => <ChatMessageModel>[],
      );
      _appendMessage(createdMessage);
      _draft = null;
      await refreshConversations();
      await loadConnections();
      await _connectSocket(conversationId: createdMessage.conversationId);
      _activateConversationPresenceIfVisible(createdMessage.conversationId);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void setDraft(MessageComposerDraft? draft) {
    _draft = draft;
    notifyListeners();
  }

  void clearSelection() {
    final conversationId = _selectedConversationId;
    if (conversationId != null) {
      _deactivateConversationPresence(
        conversationId,
        clearCachedPresence: true,
      );
    }
    _selectedConversationId = null;
    _selectedParticipant = null;
    _draft = null;
    notifyListeners();
  }

  void setTyping(bool isTyping) {
    final conversationId = _selectedConversationId;
    if (conversationId == null || !_socketService.isConnected) {
      return;
    }
    _socketService.setTyping(conversationId, isTyping);
  }

  Future<void> _connectSocket({String? conversationId}) async {
    if (!_isAuthenticated) {
      return;
    }

    await _socketService.connect(conversationId: conversationId);
    _socketSubscription ??= _socketService.events.listen(_handleSocketEvent);
  }

  void _disconnectSocket() {
    _stopPresenceHeartbeat();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socketService.disconnect();
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'message_created':
        final message = ChatMessageModel.fromJson(
          event['message'] as Map<String, dynamic>,
        );
        _appendMessage(message);
        _touchConversationFromMessage(message);
        notifyListeners();
        break;
      case 'typing':
        final conversationId = event['conversation_id'] as String?;
        final userId = event['user_id'] as String?;
        final isTyping = event['is_typing'] as bool? ?? false;
        if (conversationId == null ||
            userId == null ||
            userId == _currentUser?.id) {
          return;
        }
        final typingUsers = _typingUsersByConversation.putIfAbsent(
          conversationId,
          () => <String>{},
        );
        if (isTyping) {
          typingUsers.add(userId);
          _refreshTypingExpiry(conversationId, userId);
        } else {
          typingUsers.remove(userId);
          _cancelTypingExpiry(conversationId, userId);
        }
        notifyListeners();
        break;
      case 'conversation_presence':
        final conversationId = event['conversation_id'] as String?;
        if (conversationId == null) {
          return;
        }
        final activeUsers = (event['active_user_ids'] as List? ?? [])
            .whereType<String>()
            .toSet();
        _activeUsersByConversation[conversationId] = activeUsers;
        final now = DateTime.now();
        final presenceMap = _activePresenceSeenAtByConversation.putIfAbsent(
          conversationId,
          () => <String, DateTime>{},
        );
        presenceMap.removeWhere((userId, _) => !activeUsers.contains(userId));
        for (final userId in activeUsers) {
          presenceMap[userId] = now;
        }
        if (activeUsers.isEmpty) {
          _activePresenceSeenAtByConversation.remove(conversationId);
        }
        notifyListeners();
        break;
    }
  }

  void _appendMessage(ChatMessageModel message) {
    final messages = _messagesByConversation.putIfAbsent(
      message.conversationId,
      () => <ChatMessageModel>[],
    );
    final alreadyExists = messages.any((item) => item.id == message.id);
    if (!alreadyExists) {
      messages.add(message);
    }
  }

  void _touchConversationFromMessage(ChatMessageModel message) {
    final existing = _conversations.cast<ConversationModel?>().firstWhere(
          (conversation) => conversation?.id == message.conversationId,
          orElse: () => null,
        );

    if (existing == null) {
      if (_selectedParticipant == null) {
        return;
      }
      _upsertConversation(
        ConversationModel(
          id: message.conversationId,
          participant: _selectedParticipant!,
          lastMessage: message,
          unreadCount: message.senderId == _currentUser?.id ||
                  _selectedConversationId == message.conversationId
              ? 0
              : 1,
          updatedAt: message.createdAt,
        ),
      );
      return;
    }

    final unreadCount = message.senderId == _currentUser?.id ||
            _selectedConversationId == message.conversationId
        ? 0
        : existing.unreadCount + 1;

    _upsertConversation(
      existing.copyWith(
        lastMessage: message,
        unreadCount: unreadCount,
        updatedAt: message.createdAt,
      ),
    );
  }

  void _upsertConversation(ConversationModel conversation) {
    _conversations = [
      conversation,
      ..._conversations.where((item) => item.id != conversation.id),
    ];
  }

  String? _findConversationIdForParticipant(String participantId) {
    final existingConversation =
        _conversations.cast<ConversationModel?>().firstWhere(
              (conversation) => conversation?.participant.id == participantId,
              orElse: () => null,
            );
    if (existingConversation != null) {
      return existingConversation.id;
    }

    final existingConnection =
        _connections.cast<MessageConnectionModel?>().firstWhere(
              (connection) =>
                  connection?.id == participantId &&
                  (connection?.conversationId?.isNotEmpty ?? false),
              orElse: () => null,
            );
    return existingConnection?.conversationId;
  }

  void _refreshTypingExpiry(String conversationId, String userId) {
    final timers = _typingExpiryTimersByConversation.putIfAbsent(
      conversationId,
      () => <String, Timer>{},
    );

    timers[userId]?.cancel();
    timers[userId] = Timer(const Duration(seconds: 3), () {
      final typingUsers = _typingUsersByConversation[conversationId];
      typingUsers?.remove(userId);
      if (typingUsers != null && typingUsers.isEmpty) {
        _typingUsersByConversation.remove(conversationId);
      }

      final conversationTimers =
          _typingExpiryTimersByConversation[conversationId];
      conversationTimers?.remove(userId);
      if (conversationTimers != null && conversationTimers.isEmpty) {
        _typingExpiryTimersByConversation.remove(conversationId);
      }
      notifyListeners();
    });
  }

  void _cancelTypingExpiry(String conversationId, String userId) {
    final timers = _typingExpiryTimersByConversation[conversationId];
    timers?[userId]?.cancel();
    timers?.remove(userId);
    if (timers != null && timers.isEmpty) {
      _typingExpiryTimersByConversation.remove(conversationId);
    }
  }

  void _clearTypingExpiryTimers() {
    for (final entry in _typingExpiryTimersByConversation.values) {
      for (final timer in entry.values) {
        timer.cancel();
      }
    }
    _typingExpiryTimersByConversation.clear();
  }

  void _startPresenceHeartbeat(String conversationId) {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (_selectedConversationId != conversationId) {
          _stopPresenceHeartbeat();
          return;
        }
        if (!_isMessagesScreenVisible) {
          _stopPresenceHeartbeat();
          return;
        }
        _socketService.openConversation(conversationId);
      },
    );
  }

  void _stopPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
  }

  void _pruneStalePresence() {
    final now = DateTime.now();
    var changed = false;

    final emptyConversations = <String>[];
    _activePresenceSeenAtByConversation.forEach((conversationId, userTimes) {
      userTimes.removeWhere((userId, lastSeen) {
        final stale = now.difference(lastSeen) > _presenceFreshness;
        if (stale) {
          changed = true;
          _activeUsersByConversation[conversationId]?.remove(userId);
        }
        return stale;
      });

      if (userTimes.isEmpty) {
        emptyConversations.add(conversationId);
      }
    });

    for (final conversationId in emptyConversations) {
      _activePresenceSeenAtByConversation.remove(conversationId);
      _activeUsersByConversation.remove(conversationId);
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _activateConversationPresenceIfVisible(String conversationId) {
    if (!_isMessagesScreenVisible) {
      _clearConversationPresenceState(conversationId);
      return;
    }

    _resumeConversationPresence(conversationId);
  }

  void _resumeConversationPresence(String conversationId) {
    _connectSocket(conversationId: conversationId).then((_) {
      if (!_isMessagesScreenVisible ||
          _selectedConversationId != conversationId) {
        return;
      }
      _socketService.openConversation(conversationId);
      _startPresenceHeartbeat(conversationId);
    });
  }

  void _deactivateConversationPresence(
    String conversationId, {
    required bool clearCachedPresence,
  }) {
    if (_socketService.isConnected) {
      _socketService.closeConversation(conversationId);
    }
    _stopPresenceHeartbeat();
    if (clearCachedPresence) {
      _clearConversationPresenceState(conversationId);
    }
  }

  void _clearConversationPresenceState(String conversationId) {
    _activeUsersByConversation.remove(conversationId);
    _activePresenceSeenAtByConversation.remove(conversationId);
  }

  @override
  void dispose() {
    _stopPresenceHeartbeat();
    _presencePruneTimer?.cancel();
    _clearTypingExpiryTimers();
    _disconnectSocket();
    _socketService.dispose();
    super.dispose();
  }
}
