import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/library/library_screen.dart';
import '../../features/rooms/rooms_screen.dart';
import '../../features/voice/voice_screen.dart';
import '../../features/profile/profile_screen.dart';
import 'mini_player_stub.dart';

/// The root scaffold that hosts the bottom navigation and all tab screens.
/// The mini-player sits above the bottom nav and persists across all tabs.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // All tab screens — indexed to match the nav bar destinations.
  static const List<Widget> _screens = [
    LibraryScreen(),
    RoomsScreen(),
    VoiceScreen(),
    ProfileScreen(),
  ];

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We handle our own bottom padding to fit the mini-player above the nav.
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mini-player slot — floats above the nav bar.
        const MiniPlayerStub(),

        // The actual navigation bar.
        NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          animationDuration: const Duration(milliseconds: 400),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_alt_rounded),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.mic_none_rounded),
              selectedIcon: Icon(Icons.mic_rounded),
              label: 'AI Voice',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ],
    );
  }
}
