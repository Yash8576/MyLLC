import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// One Instagram-style message banner: who sent it and a glimpse of what.
class InAppMessageBanner {
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String preview;

  const InAppMessageBanner({
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.preview,
  });

  MessageParticipantModel get participant => MessageParticipantModel(
        id: senderId,
        name: senderName,
        avatar: senderAvatar,
      );
}

/// App-wide queue of in-app message banners. Banners show one at a time for
/// [displayDuration] each, no matter where the user is in the app; while
/// [suppressed] is true (fullscreen video playback) the queue holds and
/// resumes afterwards.
class InAppNotificationCenter {
  InAppNotificationCenter._() {
    suppressed.addListener(_onSuppressionChanged);
  }

  static final InAppNotificationCenter instance = InAppNotificationCenter._();

  /// Per-banner on-screen time (Instagram-style short glimpse).
  static const Duration displayDuration = Duration(seconds: 2);

  /// Small gap so consecutive banners visibly swap instead of blending.
  static const Duration interBannerGap = Duration(milliseconds: 250);

  static const int _maxQueuedBanners = 8;

  final Queue<InAppMessageBanner> _queue = Queue<InAppMessageBanner>();

  /// The banner currently on screen, if any.
  final ValueNotifier<InAppMessageBanner?> current =
      ValueNotifier<InAppMessageBanner?>(null);

  /// True while banners must not appear (fullscreen video player). Held
  /// banners stay queued and play back once suppression lifts.
  final ValueNotifier<bool> suppressed = ValueNotifier<bool>(false);

  Timer? _advanceTimer;
  Timer? _gapTimer;

  void show(InAppMessageBanner banner) {
    if (_queue.length >= _maxQueuedBanners) {
      _queue.removeFirst();
    }
    _queue.add(banner);
    _maybeShowNext();
  }

  /// Dismisses the visible banner immediately (tap or swipe) and moves on.
  void dismissCurrent() {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    if (current.value == null) {
      return;
    }
    current.value = null;
    _scheduleGapThenNext();
  }

  /// Drops everything (e.g. on logout).
  void clear() {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _gapTimer?.cancel();
    _gapTimer = null;
    _queue.clear();
    current.value = null;
  }

  void _onSuppressionChanged() {
    if (suppressed.value) {
      // Hide anything on screen; it already had its moment.
      _advanceTimer?.cancel();
      _advanceTimer = null;
      current.value = null;
      return;
    }
    _maybeShowNext();
  }

  void _maybeShowNext() {
    if (suppressed.value ||
        current.value != null ||
        _gapTimer != null ||
        _queue.isEmpty) {
      return;
    }
    current.value = _queue.removeFirst();
    _advanceTimer?.cancel();
    _advanceTimer = Timer(displayDuration, () {
      _advanceTimer = null;
      current.value = null;
      _scheduleGapThenNext();
    });
  }

  void _scheduleGapThenNext() {
    _gapTimer?.cancel();
    _gapTimer = Timer(interBannerGap, () {
      _gapTimer = null;
      _maybeShowNext();
    });
  }
}
