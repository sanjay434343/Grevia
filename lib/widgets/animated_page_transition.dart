import 'package:flutter/material.dart';

class AnimatedPageTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AnimationType animationType;

  const AnimatedPageTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.animationType = AnimationType.slideFromRight,
  });

  @override
  Widget build(BuildContext context) {
    // Return the child widget directly since we're using this in routes
    return child;
  }
}

enum AnimationType {
  slideFromRight,
  slideFromLeft,
  slideFromBottom,
  slideFromTop,
  fade,
  scale,
  rotation,
}

// Helper function to create animated route
Route<T> createAnimatedRoute<T extends Object?>(
  Widget page, {
  AnimationType animationType = AnimationType.slideFromRight,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeInOut,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, _) => page,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (animationType) {
        case AnimationType.slideFromRight:
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                CurveTween(curve: curve),
              ),
            ),
            child: child,
          );
        case AnimationType.slideFromLeft:
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(-1.0, 0.0), end: Offset.zero).chain(
                CurveTween(curve: curve),
              ),
            ),
            child: child,
          );
        case AnimationType.slideFromBottom:
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(
                CurveTween(curve: curve),
              ),
            ),
            child: child,
          );
        case AnimationType.slideFromTop:
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0.0, -1.0), end: Offset.zero).chain(
                CurveTween(curve: curve),
              ),
            ),
            child: child,
          );
        case AnimationType.fade:
          return FadeTransition(
            opacity: animation.drive(
              Tween(begin: 0.0, end: 1.0).chain(
                CurveTween(curve: curve),
              ),
            ),
            child: child,
          );
        case AnimationType.scale:
          return ScaleTransition(
            scale: animation.drive(
              Tween(begin: 0.0, end: 1.0).chain(
                CurveTween(curve: curve),
              ),
            ),
            child: child,
          );
        case AnimationType.rotation:
          return RotationTransition(
            turns: animation.drive(
              Tween(begin: 0.0, end: 1.0).chain(
                CurveTween(curve: curve),
              ),
            ),
            child: child,
          );
      }
    },
  );
}

// Animated transition wrapper for easier use
class AnimatedPageWrapper extends StatelessWidget {
  final Widget child;
  final AnimationType animationType;
  final Duration duration;
  final Curve curve;

  const AnimatedPageWrapper({
    super.key,
    required this.child,
    this.animationType = AnimationType.slideFromRight,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }

  // Method to create route with animation
  static Route<T> createRoute<T extends Object?>(
    Widget page, {
    AnimationType animationType = AnimationType.slideFromRight,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return createAnimatedRoute<T>(
      page,
      animationType: animationType,
      duration: duration,
      curve: curve,
    );
  }
}
