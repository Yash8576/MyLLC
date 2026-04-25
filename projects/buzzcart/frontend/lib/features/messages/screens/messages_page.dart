import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_helper.dart';
import '../providers/messages_provider.dart';

class MessagesPage extends StatefulWidget {
  final MessagesRouteIntent? intent;

  const MessagesPage({
    super.key,
    this.intent,
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  Timer? _typingTimer;
  String? _initializedForUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MessagesProvider>().setMessagesScreenVisible(true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (!authProvider.isAuthenticated || userId == null || userId.isEmpty) {
      return;
    }

    if (_initializedForUserId == userId) {
      return;
    }

    _initializedForUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MessagesProvider>().initialize(intent: widget.intent);
    });
  }

  @override
  void didUpdateWidget(covariant MessagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.intent == widget.intent || widget.intent == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MessagesProvider>().applyIntent(widget.intent!);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    final provider = context.read<MessagesProvider>();
    provider.setTyping(false);
    provider.setMessagesScreenVisible(false);
    provider.clearSelection();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    final provider = context.read<MessagesProvider>();
    final isVisible = state == AppLifecycleState.resumed;
    if (!isVisible) {
      _typingTimer?.cancel();
      provider.setTyping(false);
    }
    provider.setMessagesScreenVisible(isVisible);
  }

  Future<void> _sendMessage(MessagesProvider provider) async {
    final text = _messageController.text;
    _typingTimer?.cancel();
    provider.setTyping(false);
    await provider.sendMessage(text);
    if (!mounted) {
      return;
    }
    _messageController.clear();
  }

  void _handleTyping(MessagesProvider provider, String value) {
    provider.setTyping(value.trim().isNotEmpty);
    _typingTimer?.cancel();
    _typingTimer = Timer(
      const Duration(milliseconds: 1200),
      () => provider.setTyping(false),
    );
  }

  Future<void> _showConnectionsSheet(MessagesProvider provider) async {
    if (!provider.isLoadingConnections && provider.connections.isEmpty) {
      await provider.loadConnections();
    }
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Consumer<MessagesProvider>(
            builder: (context, state, _) {
              if (state.isLoadingConnections) {
                return const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (state.connections.isEmpty) {
                return const SizedBox(
                  height: 220,
                  child: Center(
                    child: Text('No mutual connections available yet'),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: state.connections.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final connection = state.connections[index];
                  return ListTile(
                    leading: _UserAvatar(
                      name: connection.name,
                      avatar: connection.avatar,
                    ),
                    title: Text(connection.name),
                    subtitle: Text(
                      connection.hasExistingConversation
                          ? 'Continue conversation'
                          : 'Start a conversation',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await provider.openConnection(connection);
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagesProvider>();
    final isWide = MediaQuery.of(context).size.width >= 900;
    final showPageAppBar = MediaQuery.of(context).size.width >= 1024;
    final title = provider.hasSelectedConversation && !isWide
        ? (provider.selectedParticipant?.name ?? 'Messages')
        : 'Messages';

    Widget content = isWide
        ? Row(
            children: [
              SizedBox(
                width: 360,
                child: _ConversationList(
                  onStartChat: () => _showConnectionsSheet(provider),
                ),
              ),
              VerticalDivider(
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: provider.hasSelectedConversation
                    ? _ChatThread(
                        controller: _messageController,
                        onChanged: (value) => _handleTyping(provider, value),
                        onSend: () => _sendMessage(provider),
                      )
                    : const _EmptyChatState(),
              ),
            ],
          )
        : provider.hasSelectedConversation
            ? _ChatThread(
                controller: _messageController,
                onChanged: (value) => _handleTyping(provider, value),
                onSend: () => _sendMessage(provider),
              )
            : _ConversationList(
                onStartChat: () => _showConnectionsSheet(provider),
              );

    return Scaffold(
      appBar: showPageAppBar
          ? AppBar(
              title: Text(title),
              leading: provider.hasSelectedConversation && !isWide
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        _typingTimer?.cancel();
                        provider.setTyping(false);
                        provider.clearSelection();
                        _messageController.clear();
                      },
                    )
                  : null,
              actions: [
                IconButton(
                  tooltip: 'New chat',
                  onPressed: () => _showConnectionsSheet(provider),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!showPageAppBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                children: [
                  if (provider.hasSelectedConversation && !isWide)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        _typingTimer?.cancel();
                        provider.setTyping(false);
                        provider.clearSelection();
                        _messageController.clear();
                      },
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'New chat',
                    onPressed: () => _showConnectionsSheet(provider),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  final VoidCallback onStartChat;

  const _ConversationList({required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    return Consumer<MessagesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingConversations && provider.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.conversations.isEmpty) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 64,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start with a mutual connection. Product and gallery shares can plug into this composer later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: onStartChat,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Choose connection'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.refreshConversations,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: provider.conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conversation = provider.conversations[index];
              final isSelected =
                  provider.selectedConversationId == conversation.id;
              final lastMessage = conversation.lastMessage;

              return Material(
                color: isSelected
                    ? AppColors.electricBlue.withValues(alpha: 0.08)
                    : Colors.transparent,
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _UserAvatar(
                        name: conversation.participant.name,
                        avatar: conversation.participant.avatar,
                      ),
                      if (provider.selectedConversationId == conversation.id &&
                          provider.isOtherUserActiveInChat)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.successGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    conversation.participant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _conversationPreview(lastMessage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          provider.selectedConversationId == conversation.id &&
                                  provider.isOtherUserTyping
                              ? AppColors.electricBlue
                              : null,
                      fontStyle:
                          provider.selectedConversationId == conversation.id &&
                                  provider.isOtherUserTyping
                              ? FontStyle.italic
                              : FontStyle.normal,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatConversationTime(conversation.updatedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      if (conversation.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.electricBlue,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            conversation.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () => provider.openConversation(conversation),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _conversationPreview(ChatMessageModel? message) {
    if (message == null) {
      return 'No messages yet';
    }
    if (message.isProductShare) {
      return 'Shared a product';
    }
    return message.content.isEmpty ? 'Attachment' : message.content;
  }
}

class _ChatThread extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _ChatThread({
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagesProvider>();
    final user = context.watch<AuthProvider>().user;
    final participant = provider.selectedParticipant;

    if (participant == null) {
      return const _EmptyChatState();
    }

    final messages = provider.selectedMessages;
    final showTypingIndicator = provider.isOtherUserTyping;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              _UserAvatar(name: participant.name, avatar: participant.avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.isOtherUserActiveInChat
                          ? 'Active in this chat'
                          : (provider.isOtherUserTyping
                              ? 'Typing...'
                              : 'Connection'),
                      style: TextStyle(
                        color: provider.isOtherUserActiveInChat
                            ? AppColors.successGreen
                            : Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty && !showTypingIndicator
              ? const _EmptyMessageTimeline()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: messages.length + (showTypingIndicator ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (showTypingIndicator && index == 0) {
                      return const _TypingBubble();
                    }

                    final offset = showTypingIndicator ? 1 : 0;
                    final message =
                        messages[messages.length - 1 - (index - offset)];
                    final isMe = message.senderId == user?.id;
                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                    );
                  },
                ),
        ),
        if (provider.isOtherUserActiveInChat)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _UserAvatar(
                  name: participant.name,
                  avatar: participant.avatar,
                  radius: 12,
                ),
                const SizedBox(width: 8),
                const Text(
                  'They are in this chat right now',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        if (provider.draft != null)
          _DraftPreviewCard(
            draft: provider.draft!,
            onClear: () => provider.setDraft(null),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: provider.draft?.hasSharePayload == true
                          ? 'Add a note'
                          : 'Message ${participant.name}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: provider.isSending ? null : onSend,
                  icon: provider.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isMe ? AppColors.electricBlue : Theme.of(context).cardColor;
    final foreground = isMe ? Colors.white : null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(22),
            border:
                isMe ? null : Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isProductShare && message.product != null)
                  _ProductShareCard(
                    product: message.product!,
                    inverted: isMe,
                  ),
                if (message.content.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      top: message.isProductShare ? 10 : 0,
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(color: foreground),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  _formatMessageTime(message.createdAt),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : Theme.of(context).hintColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductShareCard extends StatelessWidget {
  final ProductModel product;
  final bool inverted;

  const _ProductShareCard({
    required this.product,
    required this.inverted,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.images.isNotEmpty
        ? UrlHelper.getPlatformUrl(product.images.first)
        : '';
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isOwnProduct =
        currentUserId != null && currentUserId == product.sellerId;

    void openProduct() {
      final route = isOwnProduct
          ? '/shop/${product.id}?own_preview=1'
          : '/shop/${product.id}';
      context.push(route);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openProduct,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: inverted
                ? Colors.white.withValues(alpha: 0.14)
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isEmpty
                    ? Container(
                        width: 56,
                        height: 56,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: inverted ? Colors.white : null,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 10),
              Flexible(
                fit: FlexFit.loose,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: inverted ? Colors.white : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: inverted
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppColors.electricBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: inverted
                    ? Colors.white.withValues(alpha: 0.85)
                    : Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftPreviewCard extends StatelessWidget {
  final MessageComposerDraft draft;
  final VoidCallback onClear;

  const _DraftPreviewCard({
    required this.draft,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final previewImage = draft.previewImage == null
        ? ''
        : UrlHelper.getPlatformUrl(draft.previewImage);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: previewImage.isEmpty
                ? Container(
                    width: 54,
                    height: 54,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.share_outlined),
                  )
                : Image.network(
                    previewImage,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to share',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  draft.previewTitle ?? 'Attachment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (draft.previewSubtitle != null)
                  Text(
                    draft.previewSubtitle!,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(),
            SizedBox(width: 4),
            _TypingDot(),
            SizedBox(width: 4),
            _TypingDot(),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;
  final String? avatar;
  final double radius;

  const _UserAvatar({
    required this.name,
    required this.avatar,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = UrlHelper.getPlatformUrl(avatar);

    return CircleAvatar(
      radius: radius,
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isEmpty
          ? Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            )
          : null,
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a conversation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Open an existing chat or start one from your mutual connections.',
              style: TextStyle(color: Theme.of(context).hintColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessageTimeline extends StatelessWidget {
  const _EmptyMessageTimeline();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No messages yet. Start the conversation.',
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
    );
  }
}

String _formatConversationTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) {
    return '';
  }
  final now = DateTime.now();
  if (DateUtils.isSameDay(now, date)) {
    return DateFormat.jm().format(date);
  }
  return DateFormat.Md().format(date);
}

String _formatMessageTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) {
    return '';
  }
  return DateFormat.jm().format(date);
}
