import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import 'models/room_models.dart';
import 'providers/room_provider.dart';
import 'active_room_screen.dart';

/// Rooms lobby — shown when the user is NOT in a room.
/// Lets the user create a new room or join one by code.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _joinCtrl = TextEditingController();
  bool _joinError = false;

  @override
  void dispose() {
    _joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _openRoom(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider<RoomProvider>.value(
        value: context.read<RoomProvider>(),
        child: const ActiveRoomScreen(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<RoomProvider>();

    // Navigation is handled explicitly now to avoid push-loops.

    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppConstants.spaceM,
          AppConstants.spaceM,
          AppConstants.spaceM,
          AppConstants.miniPlayerCollapsedHeight +
              AppConstants.bottomNavHeight +
              AppConstants.spaceXL,
        ),
        children: [
          // ── Active room shortcut ─────────────────────────────────────
          if (rooms.inRoom) ...[
            _CurrentRoomCard(
              room:   rooms.room!,
              onTap: () => _openRoom(context),
            ),
            const SizedBox(height: AppConstants.spaceL),
          ],

          // ── Create room card ─────────────────────────────────────────
          _CreateRoomCard(onCreated: _openRoom),

          const SizedBox(height: AppConstants.spaceL),

          // ── Join room card ───────────────────────────────────────────
          _JoinRoomCard(
            controller: _joinCtrl,
            hasError:   _joinError,
            onJoin: () async {
              final code = _joinCtrl.text.trim().toUpperCase();
              if (code.length != AppConstants.roomCodeLength) {
                setState(() => _joinError = true);
                return;
              }
              setState(() => _joinError = false);
              final ok = await rooms.joinRoom(code);
              if (ok && context.mounted) {
                _joinCtrl.clear();
                await _openRoom(context);
              } else {
                setState(() => _joinError = true);
              }
            },
          ),

          // ── Room history ─────────────────────────────────────────────
          if (rooms.history.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceL),
            _RoomHistory(
              history: rooms.history,
              onTap:   (code) async {
                final ok = await rooms.joinRoom(code);
                if (ok && context.mounted) await _openRoom(context);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Create room card ──────────────────────────────────────────────────────────

class _CreateRoomCard extends StatefulWidget {
  final Future<void> Function(BuildContext) onCreated;
  const _CreateRoomCard({required this.onCreated});

  @override
  State<_CreateRoomCard> createState() => _CreateRoomCardState();
}

class _CreateRoomCardState extends State<_CreateRoomCard> {
  final _nameCtrl = TextEditingController();
  bool _everyoneCanAdd = true;
  bool _majoritySkip   = true;
  bool _loading        = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    final rooms    = context.read<RoomProvider>();
    final settings = RoomSettings(
      everyoneCanAdd: _everyoneCanAdd,
      majoritySkip:   _majoritySkip,
    );
    await rooms.createRoom(
      name:     _nameCtrl.text,
      settings: settings,
    );
    setState(() => _loading = false);
    if (context.mounted) await widget.onCreated(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
          color: AppColors.sage.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.sage.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    color: AppColors.sage, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create a Room', style: AppTextStyles.headlineSmall),
                  Text('Listen together in real-time',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spaceL),

          // Room name field
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Room name (optional)',
              prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
            ),
          ),

          const SizedBox(height: AppConstants.spaceM),

          // Settings
          _SettingToggle(
            label:    'Everyone can add songs',
            value:    _everyoneCanAdd,
            onChanged: (v) => setState(() => _everyoneCanAdd = v),
          ),
          _SettingToggle(
            label:    'Majority vote to skip',
            value:    _majoritySkip,
            onChanged: (v) => setState(() => _majoritySkip = v),
          ),

          const SizedBox(height: AppConstants.spaceL),

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sage,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.meeting_room_rounded),
              label: const Text('Create Room'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Join room card ────────────────────────────────────────────────────────────

class _JoinRoomCard extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final VoidCallback onJoin;

  const _JoinRoomCard({
    required this.controller,
    required this.hasError,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
      ),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.roseQuartz.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.login_rounded,
                    color: AppColors.roseQuartz, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join a Room', style: AppTextStyles.headlineSmall),
                  Text('Enter a 6-character room code',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spaceL),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:    controller,
                  textCapitalization: TextCapitalization.characters,
                  maxLength:     AppConstants.roomCodeLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted:   (_) => onJoin(),
                  style: AppTextStyles.roomCode.copyWith(fontSize: 18),
                  decoration: InputDecoration(
                    hintText:    'ABC123',
                    counterText: '',
                    errorText:   hasError ? 'Invalid code' : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBerry,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
                child: const Text('Join'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Room history ──────────────────────────────────────────────────────────────

class _RoomHistory extends StatelessWidget {
  final List<String> history;
  final void Function(String code) onTap;

  const _RoomHistory({required this.history, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppConstants.spaceS),
          child: Text('Recent rooms', style: AppTextStyles.label),
        ),
        ...history.map((code) => InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap(code);
          },
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
                vertical:   AppConstants.spaceM),
            child: Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 18, color: AppColors.stone),
                const SizedBox(width: 12),
                Text(code,
                    style: AppTextStyles.roomCode.copyWith(
                        fontSize: 16, letterSpacing: 4)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.stone),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

// ── Current room card (Shortcut) ──────────────────────────────────────────────

class _CurrentRoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const _CurrentRoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusL),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.sage.withOpacity(0.8),
              AppColors.sageDark,
            ],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.sage.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppConstants.spaceL),
        child: Row(
          children: [
            Container(
              width:  48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: AppColors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LIVE ROOM ACTIVE',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    room.name,
                    style: AppTextStyles.headlineSmall.copyWith(color: AppColors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${room.participantCount} participants listening',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
