import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  int _defaultFocusTime = 25;
  String _selectedTreeType = 'Oak';

  // Background and color variables - Initialize with default values
  String _currentWallpaper = 'bg.jpg'; // Default wallpaper
  Color _adaptiveCardColor = Colors.white.withOpacity(0.15);
  Color _adaptiveTextColor = Colors.white;
  Color _adaptiveHighlightColor = Colors.green.shade400;

  final List<int> _focusTimeOptions = [15, 25, 30, 45, 60];
  final List<String> _treeTypeOptions = ['Oak', 'Pine', 'Maple', 'Birch', 'Cherry'];

  // Add new loading state
  bool _isBackgroundLoaded = false;

  // Add new controller for parallax
  final ScrollController _wallpaperScrollController = ScrollController();
  
  // New flag to prevent multiple precaching
  bool _imagesArePrecached = false;

  // Add new method to create wallpaper images
  Widget _buildWallpaperImage(String bg) {
    return Image.asset(
      'assets/images/$bg',
      fit: BoxFit.cover,
      width: 120,
      height: 160,
      gaplessPlayback: true,
      cacheWidth: 240, // 2x for better quality
      cacheHeight: 320,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return Container(
          width: 120,
          height: 160,
          color: _adaptiveHighlightColor.withOpacity(0.1),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_adaptiveHighlightColor),
            ),
          ),
        );
      },
    );
  }

  // Update wallpaper section to use direct image loading
  Widget _buildWallpaperSection() {
    final backgrounds = [
      'bg.jpg', 'bg2.jpg', 'bg3.jpg', 'bg4.jpg', 'bg5.jpg',
      'bg6.jpg', 'bg7.jpg', 'bg8.jpg', 'bg9.jpg', 'bg10.jpg'
    ];

    return _buildTransparentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Background',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _adaptiveTextColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.builder(
              controller: _wallpaperScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: backgrounds.length,
              itemBuilder: (context, index) {
                final bg = backgrounds[index];
                final isSelected = bg == _currentWallpaper;
                
                return GestureDetector(
                  onTap: () => _setBackground(bg),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? 
                                _adaptiveHighlightColor : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    isSelected ? 
                                      Colors.black.withOpacity(0.3) : 
                                      Colors.black.withOpacity(0.5),
                                  ],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.darken,
                              child: _buildWallpaperImage(bg),
                            ),
                          ),
                        ),
                        // Selection indicator
                        if (isSelected)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _adaptiveHighlightColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: _adaptiveTextColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeWallpaperFromPrefs();
    _loadUserData();
    
    // Pre-cache all wallpapers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAllImages();
      _autoSelectWallpaper();
    });
  }

  // Modified to handle loading state properly
  Future<void> _precacheBackgroundImages() async {
    final backgrounds = [
      'bg.jpg', 'bg2.jpg', 'bg3.jpg', 'bg4.jpg', 'bg5.jpg',
      'bg6.jpg', 'bg7.jpg', 'bg8.jpg', 'bg9.jpg', 'bg10.jpg',
    ];
    
    try {
      for (final bg in backgrounds) {
        await precacheImage(AssetImage('assets/images/$bg'), context);
      }
      
      if (mounted) {
        setState(() {
          _imagesArePrecached = true;
          _isBackgroundLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error pre-caching images: $e');
      if (mounted) {
        setState(() {
          _isBackgroundLoaded = true; // Still mark as loaded to show fallback
        });
      }
    }
  }

  // Remove _cachedImages map and update _precacheAllImages
  Future<void> _precacheAllImages() async {
    final backgrounds = [
      'bg.jpg', 'bg2.jpg', 'bg4.jpg','bg8.jpg', 'bg9.jpg'
    ];
    
    for (final bg in backgrounds) {
      await precacheImage(
        AssetImage('assets/images/$bg'),
        context,
      );
    }
    
    if (mounted) {
      setState(() {
        _isBackgroundLoaded = true;
      });
    }
  }

  // Add new method for auto-selection
  void _autoSelectWallpaper() {
    final backgrounds = [
      'bg.jpg', 'bg2.jpg', 'bg4.jpg','bg8.jpg', 'bg9.jpg'
    ];
    
    final currentIndex = backgrounds.indexOf(_currentWallpaper);
    if (currentIndex != -1 && _wallpaperScrollController.hasClients) {
      _wallpaperScrollController.animateTo(
        currentIndex * 120.0, // Width of each item
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // Immediately initialize wallpaper from preferences synchronously first
  void _initializeWallpaperFromPrefs() async {
    SharedPreferences.getInstance().then((prefs) async {
      // Check if this is the first time opening the app
      final isFirstTime = prefs.getBool('is_first_time') ?? true;
      
      String wallpaper;
      if (isFirstTime) {
        // Set default background for first time users
        wallpaper = 'bg.jpg';
        await prefs.setString('selected_background', wallpaper);
        await prefs.setBool('is_first_time', false);
        debugPrint('First time app launch - setting default background: $wallpaper');
      } else {
        // Get existing wallpaper for returning users
        wallpaper = prefs.getString('selected_background') ?? 'bg.jpg';
      }
      
      if (mounted) {
        setState(() {
          _currentWallpaper = wallpaper;
        });
        
        // Apply colors based on wallpaper name
        _applyWallpaperColors(wallpaper);
      }
    });
  }

  // Direct color application without async extraction
  void _applyWallpaperColors(String wallpaperName) {
    Color cardColor;
    Color highlightColor;
    Color textColor;
    
    // Group backgrounds by dominant color
    final isGreenBg = wallpaperName.contains('green') || 
        wallpaperName.contains('forest') || 
        wallpaperName.contains('bg6') ||  // Add specific green backgrounds
        wallpaperName.contains('bg7');
    
    if (isGreenBg) {
      // Green theme with proper green accents
      cardColor = Colors.green.withOpacity(0.2);
      highlightColor = Colors.green.shade300;
      textColor = Colors.white;
      debugPrint('Applied green theme for $wallpaperName');
    } 
    else {
      // Default white/neutral theme
      cardColor = Colors.white.withOpacity(0.15);
      highlightColor = Colors.green.shade400;
      textColor = Colors.white;
      debugPrint('Applied default theme for $wallpaperName');
    }
    
    // Apply colors in a single update
    setState(() {
      _adaptiveCardColor = cardColor;
      _adaptiveHighlightColor = highlightColor;
      _adaptiveTextColor = textColor;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserDataFromFirestore();
      if (userData != null && mounted) {
        setState(() {
          _userData = userData;
          final preferences = userData['preferences'] as Map<String, dynamic>?;
          if (preferences != null) {
            _notificationsEnabled = preferences['notificationsEnabled'] ?? true;
            _defaultFocusTime = preferences['focusTime'] ?? 25;
            _selectedTreeType = preferences['treeType'] ?? 'Oak';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePreferences() async {
    try {
      // Update preferences in Firebase
      final user = _authService.currentUser;
      if (user != null) {
        final userRef = await _authService.getUserDataFromFirestore();
        // In a real implementation, you'd update the preferences in Firebase
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating preferences: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _adaptiveCardColor,
        title: Text('Logout', style: TextStyle(color: _adaptiveTextColor)),
        content: Text('Are you sure you want to logout?', style: TextStyle(color: _adaptiveTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _adaptiveTextColor.withOpacity(0.8))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error logging out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _userData?['profile']?['name']?.toString() ?? '');
    final TextEditingController cityController = TextEditingController(
      text: _userData?['profile']?['city']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: _adaptiveCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _adaptiveHighlightColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog title with icon
              Row(
                children: [
                  Icon(Icons.edit, color: _adaptiveHighlightColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _adaptiveTextColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Name field with improved styling
              TextField(
                controller: nameController,
                style: TextStyle(color: _adaptiveTextColor),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: _adaptiveTextColor.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.person_outline, color: _adaptiveHighlightColor.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _adaptiveTextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _adaptiveHighlightColor),
                  ),
                  filled: true,
                  fillColor: _adaptiveHighlightColor.withOpacity(0.05),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // City field with improved styling
              TextField(
                controller: cityController,
                style: TextStyle(color: _adaptiveTextColor),
                decoration: InputDecoration(
                  labelText: 'City',
                  labelStyle: TextStyle(color: _adaptiveTextColor.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.location_on_outlined, color: _adaptiveHighlightColor.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _adaptiveTextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _adaptiveHighlightColor),
                  ),
                  filled: true,
                  fillColor: _adaptiveHighlightColor.withOpacity(0.05),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons with improved styling
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: _adaptiveTextColor.withOpacity(0.8)),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Save button
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Update profile in Firebase
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _adaptiveHighlightColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      )
      );
  }

  Widget _buildTransparentCard({
    required Widget child, 
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _adaptiveCardColor,
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  // Add preview functionality - This method was missing
  void _previewBackground(String backgroundName) {
    // Update current wallpaper temporarily for real-time preview
    setState(() {
      _currentWallpaper = backgroundName;
    });
    _applyWallpaperColors(backgroundName);
    
    // Save the preview state to preferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('preview_background', backgroundName);
    });
  }

  Widget _buildProfileSection() {
    if (_userData == null) return const SizedBox.shrink();
    
    final profile = _userData!['profile'] != null 
        ? Map<String, dynamic>.from(_userData!['profile'] as Map)
        : <String, dynamic>{};
    
    final focusStats = _userData!['focusStats'] != null 
        ? Map<String, dynamic>.from(_userData!['focusStats'] as Map)
        : <String, dynamic>{};
    
    // Extract stats for enhanced profile card
    final int level = profile['level'] ?? 1;
    final String name = profile['name']?.toString() ?? 'User';
    final String email = profile['email']?.toString() ?? '';
    final String city = profile['city']?.toString() ?? '';
    final int treesCompleted = focusStats['treesCompleted'] ?? 0;
    final int totalSessions = focusStats['totalSessions'] ?? 0;
    
    return _buildTransparentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            children: [
              Icon(Icons.person, color: _adaptiveHighlightColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Profile Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _adaptiveTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Main profile row with improved styling
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with gradient background instead of solid color
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _adaptiveHighlightColor,
                      _adaptiveHighlightColor.withBlue(_adaptiveHighlightColor.blue + 40),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _adaptiveHighlightColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // User details with improved text hierarchy
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _adaptiveTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: _adaptiveTextColor.withOpacity(0.7),
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: _adaptiveTextColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            city,
                            style: TextStyle(
                              fontSize: 14,
                              color: _adaptiveTextColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  
                  ],
                ),
              ),
              
              // Badge with level information
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _adaptiveHighlightColor.withOpacity(0.2),
                      _adaptiveHighlightColor.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _adaptiveHighlightColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.eco,
                      size: 16,
                      color: _adaptiveHighlightColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Level $level',
                      style: TextStyle(
                        color: _adaptiveHighlightColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Add stats summary to profile card
          Row(
            children: [
              Expanded(
                child: _buildProfileStatItem(
                  Icons.park_outlined, 
                  '$treesCompleted', 
                  'Trees Grown',
                ),
              ),
              Expanded(
                child: _buildProfileStatItem(
                  Icons.timer_outlined, 
                  '$totalSessions', 
                  'Sessions',
                ),
              ),
              Expanded(
                child: _buildProfileStatItem(
                  Icons.trending_up_rounded, 
                  level > 1 ? '+${level-1}' : '0', 
                  'Level Ups',
                ),
              ),
            ],
          ),
          
          // Edit profile button
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _showEditProfileDialog,
              icon: Icon(
                Icons.edit_outlined, 
                size: 16, 
                color: _adaptiveHighlightColor,
              ),
              label: Text(
                'Edit Profile',
                style: TextStyle(
                  color: _adaptiveHighlightColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: _adaptiveHighlightColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _adaptiveHighlightColor.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // New helper method for profile stats
  Widget _buildProfileStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _adaptiveHighlightColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: _adaptiveHighlightColor,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _adaptiveTextColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _adaptiveTextColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _setBackground(String backgroundName) async {
    try {
      setState(() {
        _currentWallpaper = backgroundName;
      });
      _applyWallpaperColors(backgroundName);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_background', backgroundName);
      await prefs.remove('preview_background');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Background updated!'),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'VIEW',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting background: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Modified to ensure images load without delay
  Widget _buildDeveloperSection() {
    precacheImage(const AssetImage('assets/images/dev.png'), context);
    
    const String websiteUrl = 'https://sanjaywork.netlify.app/';
    const String emailAddress = 'sanjay13649@gmail.com';
    const String githubUrl = 'https://github.com/sanjay434343';
    const String linkedinUrl = 'https://www.linkedin.com/in/sanjay-sanjay-b69390287';
    
    return _buildTransparentCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: _adaptiveHighlightColor.withOpacity(0.1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/dev.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sanjay',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _adaptiveTextColor,
                    ),
                  ),
                  Text(
                    'Mobile Developer',
                    style: TextStyle(
                      fontSize: 14,
                      color: _adaptiveHighlightColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Added About Me section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _adaptiveHighlightColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _adaptiveHighlightColor.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: _adaptiveHighlightColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'About Me',
                      style: TextStyle(
                        color: _adaptiveHighlightColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'A passionate Flutter developer focused on creating beautiful and functional applications. I love building apps that make a positive impact on people\'s lives.',
                  style: TextStyle(
                    color: _adaptiveTextColor.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                Icons.language, 'Website',
                url: websiteUrl,
                onTap: () => _launchUrl(websiteUrl),
              ),
              _buildSocialButton(
                Icons.email, 'Email',
                url: 'mailto:$emailAddress',
                onTap: () => _launchUrl('mailto:$emailAddress'),
              ),
              _buildSocialButton(
                Icons.link, 'LinkedIn',
                url: linkedinUrl,
                onTap: () => _launchUrl(linkedinUrl),
              ),
              _buildSocialButton(
                Icons.code, 'GitHub',
                url: githubUrl,
                onTap: () => _launchUrl(githubUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Add URL launcher method
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $urlString')),
        );
      }
    }
  }

  // Update social button to handle taps
  Widget _buildSocialButton(IconData icon, String label, {String? url, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {
        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $url')),
          );
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _adaptiveHighlightColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              color: _adaptiveHighlightColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _adaptiveTextColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Add the missing method for account section
  Widget _buildAccountSection() {
    return _buildTransparentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.manage_accounts, color: _adaptiveHighlightColor),
              const SizedBox(width: 8),
              Text(
                'Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _adaptiveTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ListTile(
            leading: Icon(Icons.person_outline, color: _adaptiveTextColor),
            title: Text('Edit Profile', style: TextStyle(color: _adaptiveTextColor)),
            subtitle: Text('Update your name and location', 
                style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7))),
            trailing: Icon(Icons.arrow_forward_ios, color: _adaptiveTextColor.withOpacity(0.7)),
            onTap: _showEditProfileDialog,
          ),
          
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: _adaptiveTextColor),
            title: Text('Privacy & Data', style: TextStyle(color: _adaptiveTextColor)),
            subtitle: Text('Manage your data and privacy settings', 
                style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7))),
            trailing: Icon(Icons.arrow_forward_ios, color: _adaptiveTextColor.withOpacity(0.7)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy settings coming soon!')),
              );
            },
          ),
          
          ListTile(
            leading: Icon(Icons.help_outline, color: _adaptiveTextColor),
            title: Text('Help & Support', style: TextStyle(color: _adaptiveTextColor)),
            subtitle: Text('Get help and contact support', 
                style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7))),
            trailing: Icon(Icons.arrow_forward_ios, color: _adaptiveTextColor.withOpacity(0.7)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & support coming soon!')),
              );
            },
          ),
          
          ListTile(
            leading: Icon(Icons.info_outline, color: _adaptiveTextColor),
            title: Text('About Grevia', style: TextStyle(color: _adaptiveTextColor)),
            subtitle: Text('App version and information', 
                style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7))),
            trailing: Icon(Icons.arrow_forward_ios, color: _adaptiveTextColor.withOpacity(0.7)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: _adaptiveCardColor,
                  title: Text('About Grevia', style: TextStyle(color: _adaptiveTextColor)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Version: 1.0.0', style: TextStyle(color: _adaptiveTextColor)),
                      const SizedBox(height: 8),
                      Text('Turn your focus into growth.', style: TextStyle(color: _adaptiveTextColor)),
                      const SizedBox(height: 8),
                      Text(
                        'Every completed focus session helps plant real trees and build a greener world.',
                        style: TextStyle(color: _adaptiveTextColor.withOpacity(0.8)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: TextStyle(color: _adaptiveHighlightColor)),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const Divider(color: Colors.white24),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            subtitle: Text('Sign out of your account', 
                style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7))),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: _adaptiveTextColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _adaptiveTextColor),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background image with direct loading
          Positioned.fill(
            child: Image.asset(
              'assets/images/$_currentWallpaper',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading background: $error');
                return const SizedBox.shrink();
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          
          // Content with fade animation
          SafeArea(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isBackgroundLoaded && !_isLoading ? 1.0 : 0.0,
              child: SingleChildScrollView(
                physics: (_isLoading || !_isBackgroundLoaded) 
                    ? const NeverScrollableScrollPhysics() 
                    : null,
                child: Column(
                  children: [
                    if (!_isLoading) _buildProfileSection(),
                    _buildWallpaperSection(),
                    if (!_isLoading) ...[
                      _buildAccountSection(),
                      _buildDeveloperSection(),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          
          // Loading indicator with transparent background
          if (_isLoading || !_isBackgroundLoaded)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
