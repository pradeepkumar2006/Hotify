import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'init_status.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // 2-second logo entry animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );

    _controller.forward();

    // Navigate after splash animation. If Firebase failed to init, skip AuthGate and go straight to HomeScreen.
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      if (firebaseInitialized) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } else {
        // Firebase not ready, go directly to HomeScreen (or Guest mode)
        debugPrint('⚠️ Firebase not initialized, navigating to HomeScreen directly');
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Matching custom theme background
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Centered melting Spotify logo
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Hero(
                tag: 'logo',
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          
          // Pulsing status text at bottom
          Positioned(
            bottom: 60,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.2, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: Column(
                children: [
                  Text(
                    'Vibeflow',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary, // Sleek black/charcoal
                      letterSpacing: 6.0,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'OPEN AUDIO & AI MIXING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Temporary placeholder screen to land on after the splash screen
class MainPlaceholder extends StatelessWidget {
  const MainPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Vibeflow Home', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating small logo
            ClipOval(
              child: Image.asset(
                'assets/logo.png',
                width: 100,
                height: 100,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Welcome to Vibeflow!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            SizedBox(height: 8),
            Text(
              'Splash transition complete. Ready for step 2.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ),
      ),
    );
  }
}
