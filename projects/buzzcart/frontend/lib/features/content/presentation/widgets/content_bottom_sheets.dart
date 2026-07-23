import 'package:flutter/material.dart';
import 'package:buzz_social_cart/core/utils/app_snack_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/network_media.dart';

Future<void> showTaggedProductsSheet({
  required BuildContext context,
  required List<ProductModel> products,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaggedProductsSheet(products: products),
  );
}

Future<int?> showContentCommentsSheet({
  required BuildContext context,
  required String title,
  required int initialCount,
  required Future<List<ContentCommentModel>> Function({
    required bool connectionsOnly,
  }) loadComments,
  required Future<ContentCommentModel> Function(String commentText)
      submitComment,
  // Called immediately whenever a comment is posted, in addition to the
  // count this returns when the sheet closes — swipe-to-dismiss/tapping the
  // scrim closes the modal route with a null result (only the explicit "X"
  // button passes the count through), so callers that only look at the
  // return value miss updates whenever the sheet is dismissed any other way.
  ValueChanged<int>? onCountChanged,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContentCommentsSheet(
      title: title,
      initialCount: initialCount,
      loadComments: loadComments,
      submitComment: submitComment,
      onCountChanged: onCountChanged,
    ),
  );
}

Future<void> showContentLikesSheet({
  required BuildContext context,
  required Future<List<ContentLikeUserModel>> Function() loadLikes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContentLikesSheet(loadLikes: loadLikes),
  );
}

class _ContentLikesSheet extends StatefulWidget {
  const _ContentLikesSheet({required this.loadLikes});

  final Future<List<ContentLikeUserModel>> Function() loadLikes;

  @override
  State<_ContentLikesSheet> createState() => _ContentLikesSheetState();
}

class _ContentLikesSheetState extends State<_ContentLikesSheet> {
  List<ContentLikeUserModel> _likes = <ContentLikeUserModel>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLikes();
  }

  Future<void> _loadLikes() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final likes = await widget.loadLikes();
      if (!mounted) {
        return;
      }
      setState(() {
        _likes = likes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Connections who liked this',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_likes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadLikes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No connections have liked this yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLikes,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _likes.length,
        separatorBuilder: (_, __) => const Divider(height: 20),
        itemBuilder: (context, index) {
          final like = _likes[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/profile/${like.userId}');
            },
            leading: AppAvatar(
              name: like.username,
              avatarUrl: like.userAvatar,
              radius: 22,
            ),
            title: Text(
              like.username,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(timeago.format(DateTime.parse(like.likedAt))),
            trailing: const _MiniBadge(label: 'Connection'),
          );
        },
      ),
    );
  }
}

class _ContentCommentsSheet extends StatefulWidget {
  const _ContentCommentsSheet({
    required this.title,
    required this.initialCount,
    required this.loadComments,
    required this.submitComment,
    this.onCountChanged,
  });

  final String title;
  final int initialCount;
  final Future<List<ContentCommentModel>> Function({
    required bool connectionsOnly,
  }) loadComments;
  final Future<ContentCommentModel> Function(String commentText) submitComment;
  final ValueChanged<int>? onCountChanged;

  @override
  State<_ContentCommentsSheet> createState() => _ContentCommentsSheetState();
}

class _ContentCommentsSheetState extends State<_ContentCommentsSheet> {
  late final TextEditingController _commentController;
  List<ContentCommentModel> _comments = <ContentCommentModel>[];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  late int _commentCount;
  bool _connectionsOnly = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _commentCount = widget.initialCount;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final comments = await widget.loadComments(
        connectionsOnly: _connectionsOnly,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submitting) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final comment = await widget.submitComment(text);
      if (!mounted) {
        return;
      }
      setState(() {
        if (!_connectionsOnly || comment.isFollowing) {
          _comments = <ContentCommentModel>[comment, ..._comments];
        }
        _commentCount += 1;
        _commentController.clear();
      });
      widget.onCountChanged?.call(_commentCount);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSingleSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(_commentCount),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.schedule),
                      label: Text('Recent'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.people_outline),
                      label: Text('Connections'),
                    ),
                  ],
                  selected: {_connectionsOnly},
                  onSelectionChanged: (selection) {
                    final nextValue = selection.first;
                    if (nextValue == _connectionsOnly) {
                      return;
                    }
                    setState(() => _connectionsOnly = nextValue);
                    _loadComments();
                  },
                ),
              ),
              Expanded(child: _buildBody()),
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(bottom: viewInsets),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    border: Border(top: BorderSide(color: theme.dividerColor)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Write a comment',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _submitting ? null : _submitComment,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadComments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            const Icon(Icons.mode_comment_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _connectionsOnly
                    ? 'No connection comments yet'
                    : 'No comments yet',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComments,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _comments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) =>
            _ContentCommentTile(comment: _comments[index]),
      ),
    );
  }
}

class _ContentCommentTile extends StatelessWidget {
  const _ContentCommentTile({required this.comment});

  final ContentCommentModel comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            name: comment.username,
            avatarUrl: comment.userAvatar,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.isCurrentUser
                            ? '${comment.username} (You)'
                            : comment.username,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      timeago.format(DateTime.parse(comment.createdAt)),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
                if (comment.isFollowing) ...[
                  const SizedBox(height: 6),
                  const _MiniBadge(label: 'Connection'),
                ],
                const SizedBox(height: 8),
                Text(
                  comment.commentText,
                  style: const TextStyle(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaggedProductsSheet extends StatelessWidget {
  const _TaggedProductsSheet({required this.products});

  final List<ProductModel> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tagged Products',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _TaggedProductCard(
                    product: products[index],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaggedProductCard extends StatelessWidget {
  const _TaggedProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.images.isNotEmpty ? product.images.first : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/shop/${product.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageUrl.isEmpty
                    ? Container(
                        width: 72,
                        height: 72,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.shopping_bag_outlined),
                      )
                    : AppCachedImage(
                        imageUrl: imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.electricBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.electricBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.electricBlue,
        ),
      ),
    );
  }
}
