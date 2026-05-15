import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/audio_provider.dart';
import 'shared/widgets/main_scaffold.dart';
import 'features/library/providers/library_provider.dart';
import 'features/rooms/providers/room_provider.dart';
import 'features/voice/providers/voice_provider.dart';
import 'features/library/providers/playlist_provider.dart';
import 'features/library/screens/playlist_screen.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/now_playing/now_playing_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialising background audio service (must be before runApp).
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId:   'com.example.music_player.channel.audio',
      androidNotificationChannelName: 'Music Player',
      androidNotificationOngoing:     true,
      androidStopForegroundOnPause:   true,
      androidNotificationIcon:        'mipmap/ic_launcher',
    );
  } catch (e) {
    debugPrint('[Main] JustAudioBackground init failed: $e');
  }

  // locking to portrait orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // make the status bar transparent so our blush bg shows through.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme — loaded first so everything else sees the right brightness.
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Library — scans device audio on creation.
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        // Audio engine — depends on LibraryProvider for queue context.
        ChangeNotifierProxyProvider<LibraryProvider, AudioProvider>(
          create: (_) => AudioProvider(),
          update: (_, library, audio) {
            audio!.updateLibrary(library);
            return audio;
          },
        ),
        // Rooms — depends on AudioProvider to start playback when songs are added.
        ChangeNotifierProxyProvider<AudioProvider, RoomProvider>(
          create: (_) => RoomProvider(),
          update: (_, audio, room) {
            room!.updateAudio(audio);
            return room;
          },
        ),
        // Voice search — needs both AudioProvider and LibraryProvider.
        ChangeNotifierProxyProvider2<AudioProvider, LibraryProvider, VoiceProvider>(
          create: (_) => VoiceProvider(),
          update: (_, audio, library, voice) {
            voice!.updateDependencies(audio, library);
            return voice;
          },
        ),
        // Playlists — depends on LibraryProvider to resolve song objects from IDs.
        ChangeNotifierProxyProvider<LibraryProvider, PlaylistProvider>(
          create: (_) => PlaylistProvider()..load(),
          update: (_, library, playlist) {
            playlist!.updateLibrary(library);
            return playlist;
          },
        ),
        // Profile — standalone, no dependencies.
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Vynl',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            initialRoute: AppRoutes.main,
            routes: {
              AppRoutes.main:       (_) => const MainScaffold(),
              AppRoutes.nowPlaying: (_) => const NowPlayingScreen(),
              AppRoutes.playlists:  (_) => const PlaylistScreen(),
            },
          );
        },
      ),
    );
  }
}
