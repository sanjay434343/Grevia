import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/tree_growth_model.dart';

class TreeLandscapePainter extends CustomPainter {
  final bool isDaytime;
  final double treeGrowthProgress;
  final int treeStage;
  final TimeOfDay currentTime;
  final math.Random _random = math.Random(42); // Fixed seed for consistent positions

  TreeLandscapePainter({
    required this.isDaytime,
    required this.treeGrowthProgress,
    required this.treeStage,
    required this.currentTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint the background gradient sky
    _drawBackground(canvas, size);
    
    // Draw celestial bodies
    if (isDaytime) {
      _drawSun(canvas, size);
    } else {
      _drawMoon(canvas, size);
      _drawStars(canvas, size);
    }

    // Draw ground and tree
    _drawGround(canvas, size);
    _drawTree(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    late List<Color> gradientColors;
    
    // Time-based colors
    final hour = currentTime.hour;
    if (hour >= 5 && hour < 7) {
      // Dawn colors
      gradientColors = [
        const Color(0xFFFFA07A), // Light salmon
        const Color(0xFFFFE4B5), // Moccasin
        const Color(0xFFB0E0E6), // Powder blue
      ];
    } else if (hour >= 7 && hour < 17) {
      // Daytime colors
      gradientColors = [
        const Color(0xFF87CEEB), // Sky blue
        const Color(0xFFE0F6FF), // Light blue
        const Color(0xFFF0F8FF), // Alice blue
      ];
    } else if (hour >= 17 && hour < 19) {
      // Sunset colors
      gradientColors = [
        const Color(0xFFFF6B6B), // Coral
        const Color(0xFFFFB6C1), // Light pink
        const Color(0xFFFFE4E1), // Misty rose
      ];
    } else {
      // Night colors
      gradientColors = [
        const Color(0xFF191970), // Midnight blue
        const Color(0xFF483D8B), // Dark slate blue
        const Color(0xFF2F4F4F), // Dark slate gray
      ];
    }

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gradientColors,
    );
    
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawSun(Canvas canvas, Size size) {
    final sunCenter = Offset(size.width * 0.85, size.height * 0.15);
    
    // Sun rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final startX = sunCenter.dx + math.cos(angle) * 25;
      final startY = sunCenter.dy + math.sin(angle) * 25;
      final endX = sunCenter.dx + math.cos(angle) * 35;
      final endY = sunCenter.dy + math.sin(angle) * 35;
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), rayPaint);
    }
    
    // Sun body
    final sunPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(sunCenter, 20, sunPaint);
  }

  void _drawMoon(Canvas canvas, Size size) {
    final moonCenter = Offset(size.width * 0.85, size.height * 0.15);
    
    // Moon body
    final moonPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(moonCenter, 20, moonPaint);
    
    // Moon craters
    final craterPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(moonCenter.dx - 6, moonCenter.dy - 4), 3, craterPaint);
    canvas.drawCircle(Offset(moonCenter.dx + 4, moonCenter.dy + 2), 2, craterPaint);
    canvas.drawCircle(Offset(moonCenter.dx - 2, moonCenter.dy + 5), 2, craterPaint);
  }

  void _drawStars(Canvas canvas, Size size) {
    if (isDaytime) return;
    
    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 100; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * (size.height * 0.7);
      final starSize = _random.nextDouble() * 2;
      
      canvas.drawCircle(Offset(x, y), starSize, starPaint);
      
      // Occasional twinkle effect
      if (_random.nextDouble() < 0.1) {
        canvas.drawCircle(
          Offset(x, y),
          starSize * 2,
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _drawGround(Canvas canvas, Size size) {
    final groundHeight = size.height * 0.25;
    final groundRect = Rect.fromLTWH(
      0, 
      size.height - groundHeight, 
      size.width, 
      groundHeight
    );
    
    // Ground gradient
    const groundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF8FBC8F), // Dark sea green
        Color(0xFF556B2F), // Dark olive green
        Color(0xFF2F4F2F), // Dark forest green
      ],
    );
    
    final groundPaint = Paint()..shader = groundGradient.createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);
    
    // Add grass texture
    _drawGrass(canvas, size, groundHeight);
  }

  void _drawGrass(Canvas canvas, Size size, double groundHeight) {
    final grassPaint = Paint()
      ..color = const Color(0xFF90EE90)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final groundY = size.height - groundHeight;
    
    for (int i = 0; i < size.width.toInt(); i += 3) {
      final grassHeight = 8 + _random.nextDouble() * 12;
      final path = Path();
      path.moveTo(i.toDouble(), groundY);
      path.quadraticBezierTo(
        i + 1.0, 
        groundY - grassHeight * 0.7, 
        i + _random.nextDouble() * 2, 
        groundY - grassHeight
      );
      canvas.drawPath(path, grassPaint);
    }
  }

  void _drawTree(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.75;
    
    // Calculate current stage based on growth progress (0.0 to 1.0)
    // Map treeGrowthProgress to stages 0-14
    int currentStage;
    if (treeGrowthProgress <= 0.0) {
      currentStage = 0; // Always start with seed
    } else if (treeGrowthProgress >= 1.0) {
      currentStage = 14; // Ancient tree at 100%
    } else {
      // Map progress 0.0-1.0 to stages 0-14
      currentStage = (treeGrowthProgress * 14).floor();
      // Ensure we don't exceed stage 14
      currentStage = math.min(currentStage, 14);
      // If there's any progress at all, we should be at least stage 1
      if (treeGrowthProgress > 0.0 && currentStage == 0) {
        currentStage = 1;
      }
    }
    
    // Draw tree based on calculated stage
    switch (currentStage) {
      case 0: // Seed
        _drawSeed(canvas, Offset(centerX, groundY));
        break;
      case 1: // Germinating
        _drawGerminating(canvas, Offset(centerX, groundY));
        break;
      case 2: // Small Sprout
        _drawSmallSprout(canvas, Offset(centerX, groundY));
        break;
      case 3: // Sprout
        _drawSprout(canvas, Offset(centerX, groundY));
        break;
      case 4: // Tiny Plant
        _drawTinyPlant(canvas, Offset(centerX, groundY));
        break;
      case 5: // Small Plant
        _drawSmallPlant(canvas, Offset(centerX, groundY));
        break;
      case 6: // Growing Plant
        _drawGrowingPlant(canvas, Offset(centerX, groundY));
        break;
      case 7: // Medium Plant
        _drawMediumPlant(canvas, Offset(centerX, groundY));
        break;
      case 8: // Large Plant
        _drawLargePlant(canvas, Offset(centerX, groundY));
        break;
      case 9: // Small Tree
        _drawSmallTree(canvas, Offset(centerX, groundY));
        break;
      case 10: // Young Tree
        _drawYoungTree(canvas, Offset(centerX, groundY));
        break;
      case 11: // Medium Tree
        _drawMediumTree(canvas, Offset(centerX, groundY));
        break;
      case 12: // Large Tree
        _drawLargeTree(canvas, Offset(centerX, groundY));
        break;
      case 13: // Mature Tree
        _drawMatureTree(canvas, Offset(centerX, groundY));
        break;
      case 14: // Ancient Tree
        _drawAncientTree(canvas, Offset(centerX, groundY));
        break;
      default:
        _drawSeed(canvas, Offset(centerX, groundY));
    }
  }

  void _drawSeed(Canvas canvas, Offset center) {
    final seedPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, -5), width: 15, height: 20),
      seedPaint,
    );
    
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(-3, -8), width: 6, height: 8),
      highlightPaint,
    );
  }

  void _drawGerminating(Canvas canvas, Offset center) {
    _drawSeed(canvas, center);
    
    final rootPaint = Paint()
      ..color = const Color(0xFFDCCDC6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(center.translate(0, -2), center.translate(0, 8), rootPaint);
    
    final crackPaint = Paint()
      ..color = const Color(0xFFAED581)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(center.translate(0, -8), center.translate(0, -12), crackPaint);
  }

  void _drawSmallSprout(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 1);
    
    final stemPaint = Paint()
      ..color = const Color(0xFF7FCC82)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -15), stemPaint);
    
    final budPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(center.translate(0, -15), 2, budPaint);
  }

  void _drawSprout(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 1);
    
    final stemPaint = Paint()
      ..color = const Color(0xFF7FCC82)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -20), stemPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;
    
    _drawLeafPair(canvas, center.translate(0, -15), leafPaint, 8);
  }

  void _drawTinyPlant(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 2);
    
    final stemPaint = Paint()
      ..color = const Color(0xFF8BC34A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -30), stemPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 2; i++) {
      final height = -18 - i * 8.0;
      _drawLeafPair(canvas, center.translate(0, height), leafPaint, 10);
    }
  }

  void _drawSmallPlant(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 3);
    
    final stemPaint = Paint()
      ..color = const Color(0xFF8BC34A)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -40), stemPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 3; i++) {
      final height = -20 - i * 10.0;
      _drawLeafPair(canvas, center.translate(0, height), leafPaint, 12);
    }
  }

  void _drawGrowingPlant(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 4);
    
    final stemPaint = Paint()
      ..color = const Color(0xFF7CB342)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -50), stemPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 4; i++) {
      final height = -25 - i * 10.0;
      _drawLeafPair(canvas, center.translate(0, height), leafPaint, 14);
    }
    
    final budPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center.translate(0, -50), 3, budPaint);
  }

  void _drawMediumPlant(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 5);
    
    final stemPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -60), stemPaint);
    
    final branchPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center.translate(0, -45), center.translate(-12, -55), branchPaint);
    canvas.drawLine(center.translate(0, -50), center.translate(10, -58), branchPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    
    _drawLeafCluster(canvas, center.translate(-12, -55), leafPaint, size: 6, count: 4);
    _drawLeafCluster(canvas, center.translate(10, -58), leafPaint, size: 6, count: 4);
    _drawLeafCluster(canvas, center.translate(0, -60), leafPaint, size: 6, count: 3);
  }

  void _drawLargePlant(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 6);
    
    final trunkPaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -70), trunkPaint);
    
    final branchPaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center.translate(0, -35), center.translate(-18, -50), branchPaint);
    canvas.drawLine(center.translate(0, -45), center.translate(15, -60), branchPaint);
    canvas.drawLine(center.translate(0, -60), center.translate(-10, -70), branchPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    
    _drawLeafCluster(canvas, center.translate(-18, -50), leafPaint, size: 8, count: 5);
    _drawLeafCluster(canvas, center.translate(15, -60), leafPaint, size: 8, count: 5);
    _drawLeafCluster(canvas, center.translate(-10, -70), leafPaint, size: 8, count: 5);
    _drawLeafCluster(canvas, center.translate(0, -70), leafPaint, size: 8, count: 4);
  }

  void _drawSmallTree(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 7);
    
    final trunkPaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -80), trunkPaint);
    
    final branchPaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center.translate(0, -40), center.translate(-25, -60), branchPaint);
    canvas.drawLine(center.translate(0, -55), center.translate(20, -70), branchPaint);
    canvas.drawLine(center.translate(0, -70), center.translate(-15, -85), branchPaint);
    canvas.drawLine(center.translate(0, -75), center.translate(12, -90), branchPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    
    _drawLeafCluster(canvas, center.translate(-25, -60), leafPaint, size: 10, count: 6);
    _drawLeafCluster(canvas, center.translate(20, -70), leafPaint, size: 10, count: 6);
    _drawLeafCluster(canvas, center.translate(-15, -85), leafPaint, size: 10, count: 6);
    _drawLeafCluster(canvas, center.translate(12, -90), leafPaint, size: 10, count: 6);
  }

  void _drawYoungTree(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 8);
    
    final trunkPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -90), trunkPaint);
    
    final branchPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center.translate(0, -45), center.translate(-30, -70), branchPaint);
    canvas.drawLine(center.translate(0, -60), center.translate(25, -80), branchPaint);
    canvas.drawLine(center.translate(0, -75), center.translate(-20, -95), branchPaint);
    canvas.drawLine(center.translate(0, -85), center.translate(18, -105), branchPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    
    _drawLeafCluster(canvas, center.translate(-30, -70), leafPaint, size: 12, count: 7);
    _drawLeafCluster(canvas, center.translate(25, -80), leafPaint, size: 12, count: 7);
    _drawLeafCluster(canvas, center.translate(-20, -95), leafPaint, size: 12, count: 7);
    _drawLeafCluster(canvas, center.translate(18, -105), leafPaint, size: 12, count: 7);
  }

  void _drawMediumTree(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 9);
    
    final trunkPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -100), trunkPaint);
    
    final branchPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center.translate(0, -50), center.translate(-35, -80), branchPaint);
    canvas.drawLine(center.translate(0, -70), center.translate(30, -95), branchPaint);
    canvas.drawLine(center.translate(0, -85), center.translate(-25, -110), branchPaint);
    canvas.drawLine(center.translate(0, -95), center.translate(22, -120), branchPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    
    _drawLeafCluster(canvas, center.translate(-35, -80), leafPaint, size: 15, count: 8);
    _drawLeafCluster(canvas, center.translate(30, -95), leafPaint, size: 15, count: 8);
    _drawLeafCluster(canvas, center.translate(-25, -110), leafPaint, size: 15, count: 8);
    _drawLeafCluster(canvas, center.translate(22, -120), leafPaint, size: 15, count: 8);
    _drawLeafCluster(canvas, center.translate(0, -100), leafPaint, size: 12, count: 6);
  }

  void _drawLargeTree(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 10);
    
    final trunkPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -110), trunkPaint);
    
    final branchPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center.translate(0, -55), center.translate(-40, -90), branchPaint);
    canvas.drawLine(center.translate(0, -75), center.translate(35, -105), branchPaint);
    canvas.drawLine(center.translate(0, -95), center.translate(-30, -125), branchPaint);
    canvas.drawLine(center.translate(0, -105), center.translate(25, -135), branchPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    
    _drawLeafCluster(canvas, center.translate(-40, -90), leafPaint, size: 18, count: 9);
    _drawLeafCluster(canvas, center.translate(35, -105), leafPaint, size: 18, count: 9);
    _drawLeafCluster(canvas, center.translate(-30, -125), leafPaint, size: 18, count: 9);
    _drawLeafCluster(canvas, center.translate(25, -135), leafPaint, size: 18, count: 9);
    _drawLeafCluster(canvas, center.translate(0, -110), leafPaint, size: 15, count: 7);
  }

  void _drawMatureTree(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 11);
    
    final trunkPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -120), trunkPaint);
    
    final branchPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center.translate(0, -60), center.translate(-45, -100), branchPaint);
    canvas.drawLine(center.translate(0, -80), center.translate(40, -115), branchPaint);
    canvas.drawLine(center.translate(0, -100), center.translate(-35, -140), branchPaint);
    canvas.drawLine(center.translate(0, -115), center.translate(30, -150), branchPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    
    _drawLeafCluster(canvas, center.translate(-45, -100), leafPaint, size: 20, count: 10);
    _drawLeafCluster(canvas, center.translate(40, -115), leafPaint, size: 20, count: 10);
    _drawLeafCluster(canvas, center.translate(-35, -140), leafPaint, size: 20, count: 10);
    _drawLeafCluster(canvas, center.translate(30, -150), leafPaint, size: 20, count: 10);
    _drawLeafCluster(canvas, center.translate(0, -120), leafPaint, size: 18, count: 8);
    
    _drawFlowers(canvas, center, 5);
  }

  void _drawAncientTree(Canvas canvas, Offset center) {
    _drawBasicRoots(canvas, center, 12, isAncient: true);
    
    final trunkPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, center.translate(0, -130), trunkPaint);
    
    final branchPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center.translate(0, -65), center.translate(-50, -110), branchPaint);
    canvas.drawLine(center.translate(0, -85), center.translate(45, -125), branchPaint);
    canvas.drawLine(center.translate(0, -105), center.translate(-40, -150), branchPaint);
    canvas.drawLine(center.translate(0, -125), center.translate(35, -160), branchPaint);
    
    final leafPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.fill;
    
    _drawLeafCluster(canvas, center.translate(-50, -110), leafPaint, size: 25, count: 12);
    _drawLeafCluster(canvas, center.translate(45, -125), leafPaint, size: 25, count: 12);
    _drawLeafCluster(canvas, center.translate(-40, -150), leafPaint, size: 25, count: 12);
    _drawLeafCluster(canvas, center.translate(35, -160), leafPaint, size: 25, count: 12);
    _drawLeafCluster(canvas, center.translate(0, -130), leafPaint, size: 22, count: 10);
    
    _drawFlowers(canvas, center, 10);
  }

  void _drawLeafPair(Canvas canvas, Offset center, Paint paint, double size) {
    // Left leaf
    final leftLeafPath = Path();
    leftLeafPath.moveTo(center.dx, center.dy);
    leftLeafPath.quadraticBezierTo(
      center.dx - size, center.dy - size * 0.7, 
      center.dx - size * 0.3, center.dy - size
    );
    leftLeafPath.quadraticBezierTo(
      center.dx - size * 0.1, center.dy - size * 0.3, 
      center.dx, center.dy
    );
    canvas.drawPath(leftLeafPath, paint);
    
    // Right leaf
    final rightLeafPath = Path();
    rightLeafPath.moveTo(center.dx, center.dy);
    rightLeafPath.quadraticBezierTo(
      center.dx + size, center.dy - size * 0.7, 
      center.dx + size * 0.3, center.dy - size
    );
    rightLeafPath.quadraticBezierTo(
      center.dx + size * 0.1, center.dy - size * 0.3, 
      center.dx, center.dy
    );
    canvas.drawPath(rightLeafPath, paint);
  }

  void _drawBasicRoots(Canvas canvas, Offset center, int complexity, {bool isAncient = false}) {
    final rootPaint = Paint()
      ..color = isAncient ? const Color(0xFF3E2723) : const Color(0xFF5D4037)
      ..strokeWidth = 1.5 + (complexity * 0.3)
      ..strokeCap = StrokeCap.round;
    
    final rootCount = math.min(4, 1 + (complexity ~/ 3));
    final rootSpread = isAncient ? 1.3 : 1.0;
    final rootDepth = isAncient ? 1.2 : 1.0;
    
    for (int i = 0; i < rootCount; i++) {
      final angle = (i / rootCount) * math.pi + math.pi;
      final rootLength = (8.0 + complexity * 2.0) * rootSpread;
      final startX = center.dx;
      final startY = center.dy + 5;
      final endX = startX + math.cos(angle) * rootLength;
      final endY = startY + math.sin(angle) * rootLength * rootDepth;
      
      if (endY > center.dy + 8) {
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          rootPaint,
        );
      }
    }
  }

  void _drawFlowers(Canvas canvas, Offset center, int count) {
    final flowerPaint = Paint()
      ..color = Colors.pink.shade300
      ..style = PaintingStyle.fill;
    
    // Use fixed seed based on center position for consistent flower placement
    final flowerRandom = math.Random(center.dx.toInt() + center.dy.toInt());
    
    for (int i = 0; i < count; i++) {
      // Calculate fixed positions based on branch structure
      final branchIndex = i % 4; // Distribute among 4 main branches
      late double x, y;
      
      switch (branchIndex) {
        case 0: // Left upper branch
          x = center.dx - 35 - flowerRandom.nextDouble() * 15;
          y = center.dy - 100 - flowerRandom.nextDouble() * 20;
          break;
        case 1: // Right upper branch
          x = center.dx + 25 + flowerRandom.nextDouble() * 15;
          y = center.dy - 115 - flowerRandom.nextDouble() * 20;
          break;
        case 2: // Left lower branch
          x = center.dx - 25 - flowerRandom.nextDouble() * 15;
          y = center.dy - 140 - flowerRandom.nextDouble() * 15;
          break;
        case 3: // Right lower branch
          x = center.dx + 20 + flowerRandom.nextDouble() * 15;
          y = center.dy - 150 - flowerRandom.nextDouble() * 15;
          break;
      }
      
      // Draw flower petals in a fixed pattern
      final petalColors = [
        Colors.pink.shade300,
        Colors.pink.shade200,
        Colors.purple.shade200,
      ];
      
      final petalColor = petalColors[i % petalColors.length];
      final petalPaint = Paint()
        ..color = petalColor
        ..style = PaintingStyle.fill;
      
      // Draw 5 petals in a circle
      for (int j = 0; j < 5; j++) {
        final angle = j * (2 * math.pi / 5);
        final petalX = x + math.cos(angle) * 3;
        final petalY = y + math.sin(angle) * 3;
        canvas.drawCircle(Offset(petalX, petalY), 2, petalPaint);
      }
      
      // Flower center
      canvas.drawCircle(
        Offset(x, y), 
        1.5, 
        Paint()..color = Colors.yellow.shade400
      );
      
      // Small stem connecting to branch
      final stemPaint = Paint()
        ..color = const Color(0xFF4CAF50)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(x, y + 1.5),
        Offset(x + (flowerRandom.nextDouble() - 0.5) * 4, y + 6),
        stemPaint,
      );
    }
  }

  void _drawLeafCluster(Canvas canvas, Offset center, Paint paint, {required double size, required int count}) {
    final random = math.Random(center.dx.toInt() + center.dy.toInt());
    
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      final distance = size * (0.6 + random.nextDouble() * 0.4);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      canvas.drawCircle(Offset(x, y), size * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
