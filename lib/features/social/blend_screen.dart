import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../auth/providers/auth_provider.dart' as ap;
import 'providers/social_provider.dart';
import 'models/social_models.dart';
import 'widgets/listening_now_strip.dart';

class BlendScreen extends StatefulWidget {
  /// When true, used as the bottom-nav Social tab (extra bottom padding).
  final bool isRootTab;

  const BlendScreen({super.key, this.isRootTab = false});

  @override
  State<BlendScreen> createState() => _BlendScreenState();
}

class _BlendScreenState extends State<BlendScreen>
    with SingleTickerProviderStateMixin {
  final _uidCtrl = TextEditingController();
  BlendResult? _result;
  bool    _loading = false;
  String? _error;
  late AnimationController _animCtrl;
  late Animation<double>   _scoreAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _animCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final input = _uidCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Please enter a user ID.');
      return;
    }
    final myUid = context.read<ap.AuthProvider>().uid;
    if (input == myUid) {
      setState(
              () => _error = "That's your own ID! Enter a friend's.");
      return;
    }

    setState(() {
      _loading = true;
      _error   = null;
      _result  = null;
    });
    _animCtrl.reset();

    try {
      final social = context.read<SocialProvider>();
      final result = await social.calculateBlend(input);
      if (mounted) {
        setState(() => _result = result);
        if (result != null) _animCtrl.forward();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('Permission denied')) {
          setState(() => _error =
          'Permission denied — make sure Firebase rules are published correctly.');
        } else if (msg.contains('network')) {
          setState(() =>
          _error = 'No internet connection. Try again.');
        } else {
          setState(() => _error =
          'Could not find that user. Check the ID and try again.');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<ap.AuthProvider>().uid;

    final bottomPad = widget.isRootTab
        ? AppConstants.miniPlayerCollapsedHeight +
            AppConstants.bottomNavHeight +
            AppConstants.spaceXL
        : AppConstants.spaceL;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRootTab ? 'Social & Blend' : 'Find Your Blend'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppConstants.spaceL,
          AppConstants.spaceL,
          AppConstants.spaceL,
          bottomPad,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isRootTab) ...[
              const ListeningNowStrip(),
            ],

            // ── Your shareable ID ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spaceM),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.1),
                borderRadius:
                BorderRadius.circular(AppConstants.radiusL),
                border: Border.all(
                    color:
                    AppColors.sage.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your User ID',
                      style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          myUid,
                          style: AppTextStyles.bodySmall
                              .copyWith(
                            fontFamily: 'monospace',
                            color: AppColors.stoneDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            size: 18, color: AppColors.sage),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: myUid));
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Your ID copied! Share it with friends.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share this ID with a friend so they can blend with you.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.stoneDark),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spaceXL),

            // ── Info banner ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.darkBerry.withValues(alpha: 0.1),
                  AppColors.roseQuartz.withValues(alpha: 0.1),
                ]),
                borderRadius:
                BorderRadius.circular(AppConstants.radiusL),
              ),
              child: Row(children: [
                const Icon(Icons.merge_type_rounded,
                    color: AppColors.darkBerry, size: 28),
                const SizedBox(width: AppConstants.spaceM),
                Expanded(
                  child: Text(
                    'Paste a friend\'s user ID to see musical compatibility!',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ]),
            ),

            const SizedBox(height: AppConstants.spaceL),

            // ── Input ──────────────────────────────────────────────
            TextField(
              controller: _uidCtrl,
              decoration: const InputDecoration(
                hintText: 'Paste friend\'s user ID here',
                prefixIcon:
                Icon(Icons.person_search_rounded),
              ),
            ),

            const SizedBox(height: AppConstants.spaceM),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBerry,
                ),
                icon: _loading
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2))
                    : const Icon(Icons.merge_type_rounded,
                    color: AppColors.white),
                label: Text(
                  _loading ? 'Calculating…' : 'Calculate Blend',
                  style: AppTextStyles.button,
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppConstants.spaceM),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(AppConstants.spaceM),
                decoration: BoxDecoration(
                  color:
                  AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                      AppConstants.radiusM),
                  border: Border.all(
                      color: AppColors.error
                          .withValues(alpha: 0.3)),
                ),
                child: Text(_error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                    textAlign: TextAlign.center),
              ),
            ],

            // ── Result ────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: AppConstants.spaceXL),
              _buildResult(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BlendResult result) {
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (_, __) {
        final displayPct =
        (_scoreAnim.value * result.compatibilityPct)
            .round();
        return Column(
          children: [
            // Score circle
            Center(
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: const [
                      AppColors.darkBerry,
                      AppColors.roseQuartz,
                      AppColors.sage,
                      AppColors.darkBerry,
                    ],
                    stops: [
                      0,
                      _scoreAnim.value * 0.6,
                      _scoreAnim.value.clamp(0.0, 1.0),
                      1,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.roseQuartz
                          .withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Text('$displayPct%',
                          style: AppTextStyles.display
                              .copyWith(fontSize: 36)),
                      Text('match',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppConstants.spaceL),

            Text(result.label,
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),

            const SizedBox(height: AppConstants.spaceS),

            Text('with ${result.user2Name}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.stoneDark),
                textAlign: TextAlign.center),

            // No history banner
            if (result.noHistoryYet) ...[
              const SizedBox(height: AppConstants.spaceM),
              Container(
                padding:
                const EdgeInsets.all(AppConstants.spaceM),
                decoration: BoxDecoration(
                  color:
                  AppColors.sage.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                      AppConstants.radiusM),
                  border: Border.all(
                      color: AppColors.sage
                          .withValues(alpha: 0.3)),
                ),
                child: Text(
                  '🎵 Play more songs to get an accurate blend! This score updates automatically as you both listen.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            if (result.sharedGenres.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spaceL),
              Text('Shared Genres',
                  style: AppTextStyles.label),
              const SizedBox(height: AppConstants.spaceS),
              Wrap(
                spacing: AppConstants.spaceS,
                runSpacing: AppConstants.spaceS,
                children: result.sharedGenres
                    .map((g) => Chip(
                  label: Text(g),
                  backgroundColor: AppColors.darkBerry
                      .withValues(alpha: 0.1),
                  side: BorderSide(
                      color: AppColors.darkBerry
                          .withValues(alpha: 0.3)),
                ))
                    .toList(),
              ),
            ],

            if (result.sharedArtists.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spaceM),
              Text('Artists you both listen to',
                  style: AppTextStyles.label),
              const SizedBox(height: AppConstants.spaceS),
              Wrap(
                spacing: AppConstants.spaceS,
                runSpacing: AppConstants.spaceS,
                children: result.sharedArtists
                    .map((a) => Chip(
                  label: Text(a),
                  backgroundColor: AppColors.sage
                      .withValues(alpha: 0.1),
                  side: BorderSide(
                      color: AppColors.sage
                          .withValues(alpha: 0.3)),
                ))
                    .toList(),
              ),
            ],

            const SizedBox(height: AppConstants.spaceXL),

            // How it works
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(AppConstants.spaceM),
              decoration: BoxDecoration(
                color:
                AppColors.blush.withValues(alpha: 0.3),
                borderRadius:
                BorderRadius.circular(AppConstants.radiusL),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How Blend Works',
                      style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  Text(
                    'Blend compares your listening history — genres you prefer, artists you play most, and what time of day you listen. Play more songs on both accounts to get a more accurate score.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}