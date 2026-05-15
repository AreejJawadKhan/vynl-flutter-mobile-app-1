import 'package:flutter/material.dart';
import '../models/room_models.dart';

/// Renders floating emoji reactions that animate upward and fade out.
/// Positioned as an overlay above the room content.
class EmojiReactionOverlay extends StatelessWidget {
  final List<EmojiReaction> reactions;

  const EmojiReactionOverlay({super.key, required this.reactions});

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: reactions
            .map((r) => _FloatingEmoji(key: ValueKey(r.id), reaction: r))
            .toList(),
      ),
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  final EmojiReaction reaction;
  const _FloatingEmoji({super.key, required this.reaction});

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _yAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Float upward by 140px
    _yAnim = Tween<double>(begin: 0, end: -140).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    // Fade in quickly, hold, then fade out
    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0),           weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final startX      = screenWidth * widget.reaction.xFraction;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left:   startX - 18,
        bottom: 80 - _yAnim.value, // bottom-anchored, floats upward
        child: Opacity(
          opacity: _fadeAnim.value,
          child: Text(
            widget.reaction.emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}
