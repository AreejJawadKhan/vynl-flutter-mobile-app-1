import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/audio_provider.dart';
import 'features/library/providers/library_provider.dart';
import 'features/rooms/providers/room_provider.dart';
import 'features/voice/providers/voice_provider.dart';
import 'features/library/providers/playlist_provider.dart';
import 'features/library/screens/playlist_screen.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/now_playing/now_playing_screen.dart';
import 'features/auth/providers/auth_provider.dart' as auth_provider;
import 'features/auth/auth_gate.dart';
import 'features/social/providers/social_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.music_player.channel.audio',
      androidNotificationChannelName: 'Music Player',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    );
  } catch (e) {
    debugPrint('[Main] JustAudioBackground init failed: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const VynlApp());
}

class VynlApp extends StatelessWidget {
  const VynlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => auth_provider.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProxyProvider<LibraryProvider, AudioProvider>(
          create: (_) => AudioProvider(),
          update: (_, library, audio) {
            audio!.updateLibrary(library);
            return audio;
          },
        ),
        ChangeNotifierProxyProvider2<AudioProvider, LibraryProvider,
            VoiceProvider>(
          create: (_) => VoiceProvider(),
          update: (_, audio, library, voice) {
            voice!.updateDependencies(audio, library);
            return voice;
          },
        ),
        ChangeNotifierProxyProvider<LibraryProvider, PlaylistProvider>(
          create: (_) => PlaylistProvider()..load(),
          update: (_, library, playlist) {
            playlist!.updateLibrary(library);
            return playlist;
          },
        ),
        ChangeNotifierProxyProvider<AudioProvider, RoomProvider>(
          create: (_) => RoomProvider(),
          update: (_, audio, room) {
            room!.updateAudio(audio);
            return room;
          },
        ),
        ChangeNotifierProxyProvider<auth_provider.AuthProvider, SocialProvider>(
          create: (_) => SocialProvider(),
          update: (_, auth, social) {
            social!.updateAuth(auth);
            return social;
          },
        ),
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
            navigatorObservers: [
              FirebaseAnalyticsObserver(
                  analytics: FirebaseAnalytics.instance),
            ],
            // ── KEY FIX: use home OR routes['/']. Never both. ──────────────
            home: const AuthGate(),
            routes: {
              // AppRoutes.main ('/')  ← REMOVED, home handles this
              AppRoutes.nowPlaying: (_) => const NowPlayingScreen(),
              AppRoutes.playlists:  (_) => const PlaylistScreen(),
            },
          );
        },
      ),
    );
  }
}