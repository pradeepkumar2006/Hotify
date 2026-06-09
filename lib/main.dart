import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'splash_screen.dart';
import 'init_status.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'services/audio_service.dart';
import 'utils/theme_notifier.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'connectivity_wrapper.dart';

// bool firebaseInitialized = false; // moved to init_status.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── High Refresh Rate ───────────────────────────────────────────────────
  // Tell the Flutter engine to use high-performance latency mode so frames
  // are delivered as fast as possible to match the display's refresh rate.
  // The native side (MainActivity.kt) already picks the highest display mode.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Request a frame immediately to warm up the rendering pipeline
    SchedulerBinding.instance.scheduleFrame();
  });

  // ─── System UI ───────────────────────────────────────────────────────────
  // Transparent status bar for an edge-to-edge, immersive look.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Make status bar and nav bar fully transparent (Android 10+)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Custom Error Widget to show screen-level exceptions instead of a silent white screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E24),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.bug_report_rounded,
                        color: Colors.redAccent,
                        size: 32,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "App Crash Detected",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    details.exceptionAsString(),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Stack Trace:",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.stack?.toString() ?? "No stack trace available",
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  // Start initializations in the background so they don't block runApp and cause a white screen
  debugPrint('Starting service initialization...');
  _initializeServices();
  _preloadSongs();

  // Request notification permissions for Android 13+ is moved to splash screen/home screen to prevent ANR.

  // audio_service MUST be initialized before runApp for notification to work
  try {
    await AudioService().init();
    debugPrint('AudioService initialized before runApp');
  } catch (e) {
    debugPrint('AudioService init failed (non-fatal): $e');
  }

  runApp(const HotifyApp());
}

Future<void> _initializeServices() async {
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAp1gTiffuZ3csxXajLxPL4XPJiKn-HH2Y",
        appId: "1:852924480147:android:6d5a2dd6e31a4b5d36eb66",
        messagingSenderId: "852924480147",
        projectId: "hotify-72e6a",
        storageBucket: "hotify-72e6a.firebasestorage.app",
      ),
    );
    firebaseInitialized = true;
    debugPrint('Firebase initialized successfully.');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
}

Future<void> _preloadSongs() async {
  try {
    debugPrint('Preloading songs in the background...');

    // Load and parse Tamil songs
    final String tamilJson = await rootBundle.loadString(
      'assets/tamil_songs.json',
    );
    final List<Map<String, dynamic>> tamilSongs = await compute(
      parseSongsJson,
      tamilJson,
    );

    // Load and parse English songs
    List<Map<String, dynamic>> englishSongs = [];
    try {
      final String englishJson = await rootBundle.loadString(
        'assets/english_songs.json',
      );
      englishSongs = await compute(parseSongsJson, englishJson);
    } catch (e) {
      debugPrint('Error preloading english songs (non-fatal): $e');
    }

    // Combine both lists
    preloadedSongs = [...tamilSongs, ...englishSongs];
    debugPrint(
      'Preloaded ${preloadedSongs.length} total songs (${tamilSongs.length} Tamil, ${englishSongs.length} English).',
    );
  } catch (e) {
    debugPrint('Error preloading songs: $e');
  }
}

List<Map<String, dynamic>> parseSongsJson(String jsonString) {
  final List<dynamic> jsonList = json.decode(jsonString);
  final allSongs = jsonList
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  final filterKeywords = [
    'remix',
    'theme',
    'instrumental',
    'instru',
    'bgm',
    'score',
    'loop',
    'cut',
    'layer',
    'stem',
    'teaser',
    'trailer',
  ];

  return allSongs.where((song) {
    final title = (song['title'] ?? '').toString().toLowerCase();
    final genre = (song['genre'] ?? '').toString().toLowerCase();

    for (final kw in filterKeywords) {
      if (title.contains(kw) || genre.contains(kw)) {
        return false;
      }
    }
    return true;
  }).toList();
}

class HotifyApp extends StatelessWidget {
  const HotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('Building HotifyApp');
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentThemeMode, child) {
            return MaterialApp(
          title: 'Vibeflow Open Audio',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,
          // Global scroll behavior — makes ALL lists feel smooth & bouncy
          scrollBehavior: const _BouncingScrollBehavior(),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F5F7),
            primaryColor: Colors.black,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.black,
              primary: Colors.black,
              onPrimary: Colors.white,
              secondary: const Color(0xFF1E1E24),
              surface: Colors.white,
              onSurface: const Color(0xFF111111),
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
            iconTheme: const IconThemeData(color: Color(0xFF1E1E24)),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.dark,
              primary: Colors.white,
              onPrimary: Colors.black,
              secondary: const Color(0xFFEBECEF),
              surface: const Color(0xFF1E1E24),
              onSurface: Colors.white,
            ),
            textTheme: GoogleFonts.interTextTheme(
              ThemeData.dark().textTheme,
            ).apply(bodyColor: Colors.white, displayColor: Colors.white),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          home: const SplashScreen(),
        );
      },
    );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showBypass = false;
  bool _bypassed = false;

  @override
  void initState() {
    super.initState();
    debugPrint(' AuthGate: initState start');
    // After 2.5 seconds, if Firebase still hasn't completed initialization (or has empty apps),
    // show a bypass button.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && Firebase.apps.isEmpty) {
        setState(() {
          _showBypass = true;
        });

        // Auto-bypass after 4 seconds total to guarantee they never get stuck!
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && Firebase.apps.isEmpty && !_bypassed) {
            _bypassToHome();
          }
        });
      }
    });
  }

  void _bypassToHome() {
    if (!mounted) return;
    setState(() {
      _bypassed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bypassed) {
      debugPrint('AuthGate: bypassed to HomeScreen');
      return const ConnectivityWrapper(child: HomeScreen());
    }

    if (Firebase.apps.isEmpty) {
      debugPrint('AuthGate: Firebase apps empty, showing loading UI');
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E1E24)),
              ),
              if (_showBypass) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    "Connecting to server taking longer than usual...",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _bypassToHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E24),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text("Enter Guest Mode"),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('AuthGate: auth stream waiting');
          return const Scaffold(
            backgroundColor: Color(0xFFF4F5F7),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E1E24)),
              ),
            ),
          );
        }
        if (snapshot.hasData) {
          debugPrint(' AuthGate: User logged in, navigating to HomeScreen');
          return const ConnectivityWrapper(child: HomeScreen());
        }
        debugPrint('AuthGate: No user, showing LoginScreen');
        return const LoginScreen();
      },
    );
  }
}

/// Global scroll behavior that enables BouncingScrollPhysics on Android
/// giving the app a fluid, premium iOS-like feel everywhere.
class _BouncingScrollBehavior extends ScrollBehavior {
  const _BouncingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
