import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/room_models.dart';

/// Circular avatar showing a participant's initial letter.
/// Border uses their unique pastel color.
/// Active participants show a tiny animated sound-wave dot.
class ParticipantAvatar extends StatefulWidget {
  final RoomParticipant participant;
  final double size;

  const ParticipantAvatar({
    super.key,
    required this.participant,
    this.size = 44,
  });

  @override
  State<ParticipantAvatar> createState() => _ParticipantAvatarState();
}

class _ParticipantAvatarState extends State<ParticipantAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  late final Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _waveAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
    if (widget.participant.isActive) {
      _waveController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ParticipantAvatar old) {
    super.didUpdateWidget(old);
    if (widget.participant.isActive != old.participant.isActive) {
      if (widget.participant.isActive) {
        _waveController.repeat(reverse: true);
      } else {
        _waveController.stop();
        _waveController.value = 0.5;
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p        = widget.participant;
    final size     = widget.size;
    final isActive = p.isActive;

    return SizedBox(
      width:  size + 4,
      height: size + 16, // extra height for the name label below
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Avatar circle ───────────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width:  size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.color.withOpacity(0.25),
                  border: Border.all(color: p.color, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    p.initial,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.color,
                      fontSize: size * 0.38,
                    ),
                  ),
                ),
              ),

              // Active sound-wave dot — bottom-right corner
              if (isActive)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _waveAnim,
                    builder: (_, __) => Container(
                      width:  10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sage,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5),
                      ),
                      child: Center(
                        child: Container(
                          width:  10 * _waveAnim.value * 0.5,
                          height: 10 * _waveAnim.value * 0.5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Away indicator dot — bottom-right corner
              if (!isActive)
                Positioned(
                  right:  0,
                  bottom: 0,
                  child: Container(
                    width:  10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.stone,
                      border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),

          // ── Name label ──────────────────────────────────────────────────
          SizedBox(
            width: size + 4,
            child: Text(
              p.username,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
