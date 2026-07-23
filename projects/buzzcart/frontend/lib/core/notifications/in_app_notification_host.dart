import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/network_media.dart';
import 'in_app_notification_center.dart';

/// Wraps the whole app (via MaterialApp.builder) and floats Instagram-style
/// message banners over whatever page is showing. Tap opens the chat; swipe
/// up dismisses.
class InAppNotificationHost extends StatelessWidget {
  final GoRouter router;
  final Widget child;

  const InAppNotificationHost({
    super.key,
    required this.router,
    required this.child,
  });

  void _openConversation(InAppMessageBanner banner) {
    InAppNotificationCenter.instance.dismissCurrent();
    router.push(
      '/messages',
      extra: MessagesRouteIntent(
        conversationId: banner.conversationId,
        participant: banner.participant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: ValueListenableBuilder<InAppMessageBanner?>(
              valueListenable: InAppNotificationCenter.instance.current,
              builder: (context, banner, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (widget, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -1.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: widget),
                    );
                  },
                  child: banner == null
                      ? const SizedBox.shrink()
                      : _MessageBannerCard(
                          key: ValueKey(
                            '${banner.conversationId}-${banner.preview}-'
                            '${identityHashCode(banner)}',
                          ),
                          banner: banner,
                          onTap: () => _openConversation(banner),
                          onDismiss: InAppNotificationCenter
                              .instance.dismissCurrent,
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBannerCard extends StatelessWidget {
  final InAppMessageBanner banner;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _MessageBannerCard({
    super.key,
    required this.banner,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GestureDetector(
            onTap: onTap,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -180) {
                onDismiss();
              }
            },
            child: Material(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    AppAvatar(
                      name: banner.senderName,
                      avatarUrl: banner.senderAvatar,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            banner.senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            banner.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: AppColors.electricBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
