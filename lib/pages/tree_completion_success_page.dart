import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class TreeCompletionSuccessPage extends StatefulWidget {
  final String treeType;
  final int totalMinutes;
  final int userLevel;

  const TreeCompletionSuccessPage({
    super.key,
    required this.treeType,
    required this.totalMinutes,
    required this.userLevel,
  });

  @override
  State<TreeCompletionSuccessPage> createState() => _TreeCompletionSuccessPageState();
}

class _TreeCompletionSuccessPageState extends State<TreeCompletionSuccessPage>
    with TickerProviderStateMixin {
  String _currentWallpaper = 'bg.jpg';
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
    _setupAnimations();
    _startAnimations();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _scaleController.forward();
  }

  Future<void> _loadWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wallpaper = prefs.getString('selected_background') ?? 'bg.jpg';
      if (mounted) {
        setState(() {
          _currentWallpaper = wallpaper;
        });
      }
    } catch (e) {
      debugPrint('Error loading wallpaper: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/$_currentWallpaper',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey.shade900);
              },
            ),
          ),
          
          // Subtle overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          
          // Light blur for professional feel
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.transparent),
          ),
          
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Clean success icon
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 60,
                            color: Colors.green.shade400,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Professional title
                      const Text(
                        'Session Complete',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Subtitle
                      Text(
                        'Focus session completed successfully',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Clean info card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Tree name
                            Text(
                              widget.treeType,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Divider
                            Container(
                              height: 1,
                              width: 60,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Session stats
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatItem(
                                  'Duration',
                                  '${widget.totalMinutes} min',
                                  Icons.schedule_outlined,
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                _buildStatItem(
                                  'Level',
                                  '${widget.userLevel + 1}',
                                  Icons.trending_up_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Subtle achievement note
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'New level unlocked',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade300,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Clean continue button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.9),
                            foregroundColor: Colors.grey.shade800,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // Return to home page with reload flag
                            Navigator.of(context).pop({'reload': true, 'completed': true});
                          },
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Secondary action
                      TextButton(
                        onPressed: () {
                          // Return to home page with reload flag
                          Navigator.of(context).pop({'reload': true, 'completed': true});
                        },
                        child: Text(
                          'Return to Garden',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Colors.white.withOpacity(0.8),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
