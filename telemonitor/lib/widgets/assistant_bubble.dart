import 'package:flutter/material.dart';

import '../screens/patient/assistant_screen.dart';

/// A small floating robot that opens the health assistant.
///
/// Draggable, because it necessarily sits on top of whatever is
/// underneath it — a patient reading a value it happens to cover can
/// move it rather than being stuck. Its position is kept for the life of
/// the screen and it snaps to whichever side it was released nearest,
/// which is the behaviour people already expect from floating chat
/// bubbles.
///
/// Place it inside a [Stack] as the last child so it renders above the
/// rest of the screen.
class AssistantBubble extends StatefulWidget {
  const AssistantBubble({super.key});

  static const Color accent = Color(0xFF6B4FBB);

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble>
    with SingleTickerProviderStateMixin {
  static const double _size = 56;
  static const double _margin = 16;

  Offset? _position;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // Default: right-hand side, above the log-reading button so the two
    // controls never overlap.
    _position ??= Offset(
      screen.width - _size - _margin,
      screen.height - _size - padding.bottom - 170,
    );

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (details) {
          setState(() {
            final next = _position! + details.delta;
            // Clamp inside the visible area, allowing for the status bar
            // and the system navigation inset.
            _position = Offset(
              next.dx.clamp(_margin, screen.width - _size - _margin),
              next.dy.clamp(
                padding.top + _margin,
                screen.height - _size - padding.bottom - _margin,
              ),
            );
          });
        },
        onPanEnd: (_) {
          // Snap to the nearer edge.
          final centreX = _position!.dx + _size / 2;
          setState(() {
            _dragging = false;
            _position = Offset(
              centreX < screen.width / 2
                  ? _margin
                  : screen.width - _size - _margin,
              _position!.dy,
            );
          });
        },
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssistantScreen()),
        ),
        child: AnimatedScale(
          scale: _dragging ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: AssistantBubble.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AssistantBubble.accent.withValues(alpha: 0.4),
                  blurRadius: _dragging ? 18 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
