import 'dart:async';

import 'package:flutter/material.dart';

import '../services/presence_service.dart';

/// App-bar title showing a name, a green dot when online, and a
/// last-seen line underneath.
///
/// Refreshes its own clock every thirty seconds. Without that, someone
/// who went offline would keep showing "Online" until some unrelated
/// event happened to rebuild the widget — the timestamp would be stale
/// but nothing would re-evaluate it.
class PresenceTitle extends StatefulWidget {
  final String name;
  final String? otherUid;

  /// Shown instead of a presence line when [otherUid] is null.
  final String fallbackSubtitle;

  final IconData icon;

  const PresenceTitle({
    super.key,
    required this.name,
    required this.otherUid,
    this.fallbackSubtitle = '',
    this.icon = Icons.person_outline,
  });

  @override
  State<PresenceTitle> createState() => _PresenceTitleState();
}

class _PresenceTitleState extends State<PresenceTitle> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.otherUid;

    if (uid == null) return _layout(online: false, subtitle: widget.fallbackSubtitle);

    return StreamBuilder<DateTime?>(
      stream: PresenceService.instance.watchLastSeen(uid),
      builder: (context, snap) {
        final seen = snap.data;
        return _layout(
          online: PresenceService.isOnline(seen),
          subtitle: PresenceService.describe(seen),
        );
      },
    );
  }

  Widget _layout({required bool online, required String subtitle}) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(widget.icon, color: Colors.white, size: 18),
              ),
            ),
            if (online)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    // Ring in the app-bar colour so the dot reads as
                    // sitting on top of the avatar.
                    border: Border.all(
                        color: const Color(0xFF1A3C6E), width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: online
                        ? const Color(0xFFA5D6A7)
                        : Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
