import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import '../services/auth_service.dart';
import '../services/weather_service.dart';
import '../widgets/tree_landscape_painter.dart';
import 'focus_timer_page.dart';
import 'forest_page.dart';
import 'stats_page.dart';
import 'tree_selection_page.dart';
import 'settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class HomePage extends StatefulWidget {
  final String userName;
  final int focusTime;
  final String treeType;

  const HomePage({
    super.key,
    required this.userName,
    required this.focusTime,
    required this.treeType,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final WeatherService _weatherService = WeatherService();
  
  // User data variables
  String _userName = '';
  int _userLevel = 1;
  String _userRank = 'Seedling';
  int _treesPlanted = 0;
  int _totalSessions = 0;
  int _totalFocusTime = 0;
  int _treesCompleted = 0;
  int _currentStreak = 0;
  
  // Today's data
  int _todayFocusTime = 0;
  int _todayCompletedSessions = 0;
  double _todayCompletionRate = 0.0;
  
  // Tree growth data
  Map<String, dynamic>? _currentTreeGrowth;
  int _currentTreeMinutes = 0;
  int _totalTreeMinutes = 25;
  double _treeGrowthProgress = 0.0;
  bool _hasActiveSession = false;
  
  // Active session variables
  double _activeSessionProgress = 0.0;
  int _activeSessionMinutes = 0;
  int _activeSessionTotalMinutes = 25;
  
  // Weather variables
  WeatherCondition _currentWeather = WeatherCondition.clear;
  int _temperature = 20;
  
  // Current level tree info
  String _currentLevelTreeName = 'Oak Seedling';
  String _currentLevelTreeDescription = 'A tiny oak seed beginning its journey';
  int _currentLevelDuration = 15;
  
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Wallpaper state
  String _currentWallpaper = 'bg.jpg';
  final ValueNotifier<String> _wallpaperNotifier = ValueNotifier<String>('bg.jpg');

  // Color analysis variables
  Color _adaptiveCardColor = Colors.white.withOpacity(0.15);
  Color _adaptiveIconColor = Colors.white.withOpacity(0.7);
  bool _isAnalyzingColor = false;
  String _lastAnalyzedWallpaper = '';
  Timer? _wallpaperListener;

  // Animation controllers for smooth updates
  late AnimationController _dataUpdateController;
  late Animation<double> _dataUpdateAnimation;
  late AnimationController _progressUpdateController;
  late Animation<double> _progressUpdateAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userName = widget.userName;
    _setupAnimations();
    _dataUpdateController.forward();  // start with full opacity once loaded
    _loadAllData();
    _loadCurrentWallpaper();
    _listenToWallpaperChanges();
  }

  void _setupAnimations() {
    _dataUpdateController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _dataUpdateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dataUpdateController,
      curve: Curves.easeInOut,
    ));

    _progressUpdateController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _progressUpdateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressUpdateController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wallpaperListener?.cancel();
    _dataUpdateController.dispose();
    _progressUpdateController.dispose();
    super.dispose();
  }

  // Add wallpaper loading and analysis methods
  Future<void> _loadCurrentWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
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
      
      _wallpaperNotifier.value = wallpaper;
      
      if (_currentWallpaper != wallpaper) {
        setState(() {
          _currentWallpaper = wallpaper;
        });
        // Only analyze if wallpaper actually changed
        await _analyzeWallpaperColors(wallpaper);
      }
    } catch (e) {
      debugPrint('Error loading wallpaper: $e');
      // Fallback to default if there's an error
      setState(() {
        _currentWallpaper = 'bg.jpg';
      });
    }
  }

  void _listenToWallpaperChanges() {
    _wallpaperListener = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final preview = prefs.getString('preview_background');
        final selected = prefs.getString('selected_background') ?? 'bg.jpg';

        String targetWallpaper = preview ?? selected;
        
        // Only update if wallpaper actually changed and we're not currently analyzing
        if (targetWallpaper != _currentWallpaper && !_isAnalyzingColor) {
          debugPrint('Wallpaper change detected: $_currentWallpaper -> $targetWallpaper');
          
          // Update the notifier
          _wallpaperNotifier.value = targetWallpaper;
          
          // Update current wallpaper and analyze colors
          setState(() {
            _currentWallpaper = targetWallpaper;
          });
          
          // Analyze colors for the new wallpaper
          await _analyzeWallpaperColors(targetWallpaper);
        }
      } catch (e) {
        debugPrint('Error in wallpaper listener: $e');
      }
    });
  }

  // Clear preview when setting permanent wallpaper
  Future<void> _clearPreviewWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('preview_background');
      debugPrint('Preview wallpaper cleared');
    } catch (e) {
      debugPrint('Error clearing preview wallpaper: $e');
    }
  }

  Future<void> _analyzeWallpaperColors(String wallpaperName) async {
    // Prevent analysis if already analyzing or wallpaper hasn't changed
    if (_isAnalyzingColor || _lastAnalyzedWallpaper == wallpaperName) {
      debugPrint('Skipping analysis - already analyzing: $_isAnalyzingColor, same wallpaper: ${_lastAnalyzedWallpaper == wallpaperName}');
      return;
    }
    
    setState(() {
      _isAnalyzingColor = true;
    });

    try {
      debugPrint('Starting color analysis for: $wallpaperName');
      
      // Load the image
      final ByteData data = await rootBundle.load('assets/images/$wallpaperName');
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 100, targetHeight: 100);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      // Get pixel data
      final ByteData? pixelData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      
      if (pixelData != null) {
        final colorAnalysis = _analyzeImageColors(pixelData);
        final newCardColor = _determineCardColorFromAnalysis(colorAnalysis);
        final newIconColor = _determineIconColorFromAnalysis(colorAnalysis);
        
        debugPrint('Color analysis complete - White: ${colorAnalysis['whitePercentage']?.toStringAsFixed(2)}%, Green: ${colorAnalysis['greenPercentage']?.toStringAsFixed(2)}%, Bright: ${colorAnalysis['brightPercentage']?.toStringAsFixed(2)}%');
        
        if (mounted) {
          setState(() {
            _adaptiveCardColor = newCardColor;
            _adaptiveIconColor = newIconColor;
            _lastAnalyzedWallpaper = wallpaperName;
          });
          debugPrint('Applied new colors for wallpaper: $wallpaperName');
        }
      }
    } catch (e) {
      debugPrint('Error analyzing wallpaper colors: $e');
      // Set fallback colors based on wallpaper name patterns
      if (mounted) {
        setState(() {
          if (wallpaperName.contains('bg2') || wallpaperName.contains('bg3') || wallpaperName.contains('bg4')) {
            _adaptiveCardColor = Colors.white.withOpacity(0.2);
            _adaptiveIconColor = Colors.white.withOpacity(0.8);
          } else {
            _adaptiveCardColor = Colors.green.withOpacity(0.15);
            _adaptiveIconColor = Colors.white.withOpacity(0.7);
          }
          _lastAnalyzedWallpaper = wallpaperName;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingColor = false;
        });
      }
    }
  }

  Map<String, double> _analyzeImageColors(ByteData pixelData) {
    int whitePixels = 0;
    int greenPixels = 0;
    int brightPixels = 0;
    int totalPixels = 0;
    
    // Sample every 16th pixel for better performance
    for (int i = 0; i < pixelData.lengthInBytes; i += 16) {
      if (i + 3 < pixelData.lengthInBytes) {
        final r = pixelData.getUint8(i);
        final g = pixelData.getUint8(i + 1);
        final b = pixelData.getUint8(i + 2);
        final a = pixelData.getUint8(i + 3);
        
        // Skip transparent pixels
        if (a < 128) continue;
        
        totalPixels++;
        
        // Calculate brightness
        final brightness = (r + g + b) / 3;
        
        // Check for white/light pixels (high brightness + low color variance)
        if (brightness > 200 && (r - g).abs() < 30 && (g - b).abs() < 30 && (r - b).abs() < 30) {
          whitePixels++;
        }
        
        // Check for green pixels (green dominance)
        else if (g > r + 20 && g > b + 20 && g > 80) {
          greenPixels++;
        }
        
        // Check for bright pixels
        if (brightness > 180) {
          brightPixels++;
        }
      }
    }
    
    if (totalPixels == 0) totalPixels = 1; // Prevent division by zero
    
    return {
      'whitePercentage': (whitePixels / totalPixels) * 100,
      'greenPercentage': (greenPixels / totalPixels) * 100,
      'brightPercentage': (brightPixels / totalPixels) * 100,
      'totalPixels': totalPixels.toDouble(),
    };
  }

  Color _determineCardColorFromAnalysis(Map<String, double> analysis) {
    final whitePercentage = analysis['whitePercentage'] ?? 0;
    final greenPercentage = analysis['greenPercentage'] ?? 0;
    final brightPercentage = analysis['brightPercentage'] ?? 0;
    
    // Priority order: bright/white > green > default
    if (brightPercentage > 40 || whitePercentage > 25) {
      // Bright/white dominant - use white transparency
      return Colors.white.withOpacity(0.25);
    } else if (greenPercentage > 15) {
      // Green dominant - use green transparency
      return Colors.green.withOpacity(0.2);
    } else if (brightPercentage > 20) {
      // Moderately bright - use light white
      return Colors.white.withOpacity(0.18);
    } else {
      // Dark/other - use green with lower opacity
      return Colors.green.withOpacity(0.12);
    }
  }

  Color _determineIconColorFromAnalysis(Map<String, double> analysis) {
    final brightPercentage = analysis['brightPercentage'] ?? 0;
    
    // Adjust icon opacity based on background brightness
    if (brightPercentage > 30) {
      return Colors.white.withOpacity(0.9); // More opaque on bright backgrounds
    } else {
      return Colors.white.withOpacity(0.75); // Standard opacity on darker backgrounds
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, refresh data
      _smoothRefreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentRefreshData();
    });
  }

  // Smooth data refresh with animations
  Future<void> _smoothRefreshData() async {
    try {
      // Start fade out animation
      await _dataUpdateController.reverse();
      
      // Load comprehensive data
      await _loadAllDataComprehensively();
      
      // Fade in with new data
      await _dataUpdateController.forward();
      _progressUpdateController.forward(from: 0);
      
    } catch (e) {
      debugPrint('Smooth refresh error: $e');
      _dataUpdateController.forward(); // Ensure UI stays visible
    }
  }

  // Enhanced comprehensive data refresh
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      HapticFeedback.lightImpact();
      
      // Comprehensive data refresh with parallel loading
      await _loadAllDataComprehensively();
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('All data refreshed successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error during comprehensive refresh: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Refresh failed, please try again'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // Comprehensive data loading method
  Future<void> _loadAllDataComprehensively() async {
    debugPrint('Starting comprehensive data refresh...');
    
    try {
      // Force reload user data from Firebase with timeout
      await Future.wait([
        _loadCompleteUserData(),
        _loadCompleteFocusStats(),
        _loadCompleteTodayData(),
        _loadCompleteTreeGrowth(),
        _loadWeatherData(),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Comprehensive data loading timed out');
          throw TimeoutException('Data loading timed out');
        },
      );
      
      // Update animations
      _dataUpdateController.forward();
      _progressUpdateController.forward(from: 0);
      
      debugPrint('Comprehensive data refresh completed successfully');
    } catch (e) {
      debugPrint('Error in comprehensive data loading: $e');
      rethrow;
    }
  }

  // Complete user data loading
  Future<void> _loadCompleteUserData() async {
    try {
      debugPrint('Loading complete user data...');
      
      // Force fresh data from Firebase
      final userData = await _authService.getUserDataFromFirestore();
      if (userData == null) {
        debugPrint('No user data received');
        return;
      }

      debugPrint('Raw user data received: ${userData.keys}');
      
      // Parse all user data sections
      final profile = userData['profile'] != null 
          ? Map<String, dynamic>.from(userData['profile'] as Map<Object?, Object?>)
          : <String, dynamic>{};
      final status = userData['status'] != null 
          ? Map<String, dynamic>.from(userData['status'] as Map<Object?, Object?>)
          : <String, dynamic>{};
      final focusStats = userData['focusStats'] != null 
          ? Map<String, dynamic>.from(userData['focusStats'] as Map<Object?, Object?>)
          : <String, dynamic>{};

      debugPrint('Profile data: $profile');
      debugPrint('Status data: $status');
      debugPrint('FocusStats data: $focusStats');

      if (mounted) {
        setState(() {
          // Update user profile info
          if (profile.isNotEmpty) {
            _userName = profile['name']?.toString() ?? widget.userName;
            
            // Also check profile for level/trees data
            final profileLevel = (profile['level'] as num?)?.toInt();
            final profileTreesCompleted = (profile['treesCompleted'] as num?)?.toInt();
            
            if (profileLevel != null && profileLevel > _userLevel) {
              _userLevel = profileLevel;
            }
            if (profileTreesCompleted != null && profileTreesCompleted > _treesCompleted) {
              _treesCompleted = profileTreesCompleted;
            }
          }
          
          // Update focus statistics
          if (focusStats.isNotEmpty) {
            _treesPlanted = (focusStats['treesPlanted'] as num?)?.toInt() ?? _treesPlanted;
            _totalSessions = (focusStats['totalSessions'] as num?)?.toInt() ?? _totalSessions;
            _totalFocusTime = (focusStats['totalFocusTime'] as num?)?.toInt() ?? _totalFocusTime;
            _treesCompleted = (focusStats['treesCompleted'] as num?)?.toInt() ?? _treesCompleted;
            _currentStreak = (focusStats['currentStreak'] as num?)?.toInt() ?? _currentStreak;
            
            // Calculate level from trees completed
            final calculatedLevel = _treesCompleted + 1;
            if (calculatedLevel > _userLevel) {
              _userLevel = calculatedLevel;
            }
          }
          
          // Update status info
          if (status.isNotEmpty) {
            final statusLevel = (status['level'] as num?)?.toInt();
            final statusTreesCompleted = (status['treesCompleted'] as num?)?.toInt();
            
            if (statusLevel != null && statusLevel > _userLevel) {
              _userLevel = statusLevel;
            }
            if (statusTreesCompleted != null && statusTreesCompleted > _treesCompleted) {
              _treesCompleted = statusTreesCompleted;
            }
          }
          
          // Ensure minimum level
          if (_userLevel < 1) _userLevel = 1;
          
          // Update rank
          _userRank = _getRankForLevel(_userLevel);
        });
      }

      debugPrint('User data updated: Level $_userLevel, Trees: $_treesCompleted, Rank: $_userRank');
    } catch (e) {
      debugPrint('Error loading complete user data: $e');
    }
  }

  // Complete focus stats loading
  Future<void> _loadCompleteFocusStats() async {
    try {
      debugPrint('Loading complete focus stats...');
      
      final user = _authService.currentUser;
      if (user == null) return;

      // Get focus stats directly from Firebase
      final statsRef = _authService.database.ref('users/${user.uid}/focusStats');
      final snapshot = await statsRef.get();
      
      if (snapshot.exists) {
        final stats = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('Focus stats from Firebase: $stats');
        
        if (mounted) {
          setState(() {
            _totalFocusTime = (stats['totalFocusTime'] as num?)?.toInt() ?? _totalFocusTime;
            _totalSessions = (stats['totalSessions'] as num?)?.toInt() ?? _totalSessions;
            _treesCompleted = (stats['treesCompleted'] as num?)?.toInt() ?? _treesCompleted;
            _treesPlanted = (stats['treesPlanted'] as num?)?.toInt() ?? _treesPlanted;
            _currentStreak = (stats['currentStreak'] as num?)?.toInt() ?? _currentStreak;
          });
        }
        
        debugPrint('Focus stats updated: Sessions: $_totalSessions, Time: $_totalFocusTime, Trees: $_treesCompleted');
      }
    } catch (e) {
      debugPrint('Error loading complete focus stats: $e');
    }
  }

  // Complete today's data loading
  Future<void> _loadCompleteTodayData() async {
    try {
      debugPrint('Loading complete today data...');
      
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Get both summary and individual sessions for accuracy
      final Future<Map<String, dynamic>?> summaryFuture = _authService.getUserDailySummaryForDate(today);
      final Future<List<Map<String, dynamic>>> sessionsFuture = _authService.getUserDailySessionsForDate(today);
      
      final results = await Future.wait([summaryFuture, sessionsFuture]);
      final todaySummary = results[0] as Map<String, dynamic>?;
      final todaySessions = results[1] as List<Map<String, dynamic>>;
      
      debugPrint('Today summary: $todaySummary');
      debugPrint('Today sessions count: ${todaySessions.length}');
      
      int focusTime = 0;
      int completedSessions = 0;
      double completionRate = 0.0;
      
      // Prefer summary data if available
      if (todaySummary != null && todaySummary.isNotEmpty) {
        focusTime = (todaySummary['total_focus_minutes'] as num?)?.toInt() ?? 0;
        completedSessions = (todaySummary['completed_sessions'] as num?)?.toInt() ?? 0;
        final totalSessions = (todaySummary['total_sessions'] as num?)?.toInt() ?? 0;
        completionRate = totalSessions > 0 ? ((completedSessions / totalSessions) * 100) : 0.0;
      } else {
        // Calculate from individual sessions
        int totalSessions = todaySessions.length;
        
        for (var session in todaySessions) {
          final actualMinutes = (session['actual_duration_minutes'] as num?)?.toInt() ?? 0;
          final wasCompleted = session['was_completed'] as bool? ?? false;
          
          focusTime += actualMinutes;
          if (wasCompleted) {
            completedSessions++;
          }
        }
        
        completionRate = totalSessions > 0 ? ((completedSessions / totalSessions) * 100) : 0.0;
      }
      
      if (mounted) {
        setState(() {
          _todayFocusTime = focusTime;
          _todayCompletedSessions = completedSessions;
          _todayCompletionRate = completionRate;
        });
      }
      
      debugPrint('Today data updated: ${focusTime}min, $completedSessions sessions, ${completionRate.toInt()}%');
    } catch (e) {
      debugPrint('Error loading complete today data: $e');
    }
  }

  // Complete tree growth loading
  Future<void> _loadCompleteTreeGrowth() async {
    try {
      debugPrint('Loading complete tree growth...');
      
      // Get current tree growth data
      final growthData = await _authService.getUserCurrentTreeGrowth();
      debugPrint('Current tree growth data: $growthData');
      
      if (growthData != null && growthData.isNotEmpty) {
        final completedMinutes = (growthData['completedMinutes'] as num?)?.toInt() ?? 0;
        final totalMinutes = (growthData['totalMinutes'] as num?)?.toInt() ?? 25;
        final hasActiveSession = growthData['hasActiveSession'] as bool? ?? false;
        final treeStage = (growthData['treeStage'] as num?)?.toInt() ?? _userLevel;
        
        // Update tree info for current level
        await _updateCurrentLevelTreeInfoFromDatabase();
        
        if (mounted) {
          setState(() {
            _currentTreeMinutes = completedMinutes;
            _totalTreeMinutes = _currentLevelDuration; // Use current level duration
            _hasActiveSession = hasActiveSession;
            _treeGrowthProgress = _totalTreeMinutes > 0 ? _currentTreeMinutes / _totalTreeMinutes : 0.0;
          });
        }
        
        debugPrint('Tree growth updated: $_currentTreeMinutes/$_totalTreeMinutes min, active: $_hasActiveSession, progress: ${(_treeGrowthProgress * 100).toInt()}%');
      } else {
        // No current growth, set defaults
        await _updateCurrentLevelTreeInfoFromDatabase();
        
        if (mounted) {
          setState(() {
            _currentTreeMinutes = 0;
            _totalTreeMinutes = _currentLevelDuration;
            _hasActiveSession = false;
            _treeGrowthProgress = 0.0;
          });
        }
        
        debugPrint('No current tree growth, using defaults for level $_userLevel');
      }
    } catch (e) {
      debugPrint('Error loading complete tree growth: $e');
    }
  }

  Future<void> _updateCurrentLevelTreeInfoFromDatabase() async {
    try {
      // Get unlocked trees for current user level
      final unlockedTrees = await _authService.getUnlockedTrees();
      
      if (unlockedTrees.isNotEmpty) {
        // Find the highest level tree that user has unlocked
        Map<String, dynamic>? currentLevelTree;
        
        for (var tree in unlockedTrees) {
          final treeUnlockLevel = (tree['unlock_level'] as num?)?.toInt() ?? 1;
          if (treeUnlockLevel <= _userLevel) {
            if (currentLevelTree == null || treeUnlockLevel > ((currentLevelTree['unlock_level'] as num?)?.toInt() ?? 0)) {
              currentLevelTree = tree;
            }
          }
        }
        
        if (currentLevelTree != null) {
          _currentLevelTreeName = currentLevelTree['common_name']?.toString() ?? 'Oak Tree';
          _currentLevelTreeDescription = currentLevelTree['description']?.toString() ?? 
              'A beautiful tree that grows with your focus sessions';
          _currentLevelDuration = (currentLevelTree['growth_duration_minutes'] as num?)?.toInt() ?? 25;
          
          debugPrint('Selected tree for level $_userLevel: $_currentLevelTreeName (${_currentLevelDuration}min)');
        } else {
          // Fallback to default if no tree found
          _setDefaultTreeInfo();
        }
      } else {
        // Fallback if no unlocked trees found
        _setDefaultTreeInfo();
      }
      
    } catch (e) {
      debugPrint('Error updating tree info from database: $e');
      _setDefaultTreeInfo();
    }
  }

  void _setDefaultTreeInfo() {
    // Fallback tree information based on level
    final treeInfo = _getTreeInfoForLevel(_userLevel);
    _currentLevelTreeName = treeInfo['name'];
    _currentLevelTreeDescription = treeInfo['description'];
    _currentLevelDuration = treeInfo['duration'];
  }

  Map<String, dynamic> _getTreeInfoForLevel(int level) {
    switch (level) {
      case 1:
        return {
          'name': 'Oak Seedling',
          'description': 'A tiny oak seed beginning its journey to become a mighty tree',
          'duration': 15,
        };
      case 2:
        return {
          'name': 'Young Sprout',
          'description': 'Fresh green shoots reaching toward the light',
          'duration': 20,
        };
      case 3:
        return {
          'name': 'Growing Sapling',
          'description': 'A sturdy young tree developing its first branches',
          'duration': 25,
        };
      case 4:
        return {
          'name': 'Juvenile Tree',
          'description': 'A strong tree with spreading branches and vibrant leaves',
          'duration': 30,
        };
      case 5:
        return {
          'name': 'Mature Oak',
          'description': 'A magnificent oak tree providing shade and shelter',
          'duration': 40,
        };
      case 6:
        return {
          'name': 'Ancient Oak',
          'description': 'A centuries-old oak, wise and enduring through time',
          'duration': 50,
        };
      default:
        if (level > 6) {
          return {
            'name': 'Legendary Ancient Tree',
            'description': 'A mythical tree of incredible age and wisdom',
            'duration': 60,
          };
        }
        return {
          'name': 'Oak Seedling',
          'description': 'A tiny oak seed beginning its journey',
          'duration': 15,
        };
    }
  }

  Future<void> _checkAndUpdateLevel() async {
    try {
      final userData = await _authService.getUserDataFromFirestore();
      if (userData == null) return;
      
      final focusStats = userData['focusStats'] != null 
          ? Map<String, dynamic>.from(userData['focusStats'] as Map<Object?, Object?>)
          : <String, dynamic>{};
      final treesCompleted = (focusStats['treesCompleted'] as num?)?.toInt() ?? 0;
      
      // Calculate new level based on trees completed (Level = trees + 1)
      int newLevel = treesCompleted + 1;
      
      debugPrint('Checking level: Current $_userLevel, Trees completed: $treesCompleted, Calculated level: $newLevel');
      
      if (newLevel > _userLevel) {
        debugPrint('Level up! From $_userLevel to $newLevel');
        
        // Update user level in Firebase
        await _authService.updateUserStatus({
          'level': newLevel,
          'experience': treesCompleted * 100,
          'rank': _getRankForLevel(newLevel),
          'treesCompleted': treesCompleted,
          'treesForNextLevel': 1,
          'lastLevelUp': DateTime.now().toIso8601String(),
        });
        
        // Update profile level as well
        await _authService.updateUserProfile({
          'level': newLevel,
          'treesCompleted': treesCompleted,
        });
        
        // Update local state
        setState(() {
          _userLevel = newLevel;
          _userRank = _getRankForLevel(newLevel);
          _treesCompleted = treesCompleted;
        });
        
        // Show level up dialog
        if (mounted) {
          _showLevelUpDialog(newLevel);
        }
        
        // Reload all data to refresh tree info for new level
        await _loadAllData();
      } else if (newLevel < _userLevel) {
        // This shouldn't happen, but fix inconsistency if it does
        debugPrint('Level inconsistency detected. Fixing...');
        setState(() {
          _userLevel = newLevel;
          _userRank = _getRankForLevel(newLevel);
          _treesCompleted = treesCompleted;
        });
      }
    } catch (e) {
      debugPrint('Error checking/updating level: $e');
    }
  }

  String _getRankForLevel(int level) {
    switch (level) {
      case 1:
        return 'Seedling';
      case 2:
        return 'Sprout';
      case 3:
        return 'Sapling';
      case 4:
        return 'Young Tree';
      case 5:
        return 'Mature Tree';
      case 6:
        return 'Ancient Tree';
      default:
        return level > 6 ? 'Forest Guardian' : 'Seedling';
    }
  }

  void _showLevelUpDialog(int newLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber.shade600, size: 32),
            const SizedBox(width: 12),
            const Text('Level Up!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.amber.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Level $newLevel',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _getRankForLevel(newLevel),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Congratulations! You\'ve reached level $newLevel and unlocked new trees to grow!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $_userName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getRandomQuote(),  // Get a random motivational quote
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withOpacity(0.9),
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber.shade400,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Level $_userLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRandomQuote() {
    final quotes = [
      "Growth happens one focus at a time",
      "Plant seeds of success today",
      "Nurture your mind like a garden",
      "Every moment of focus counts",
      "Small steps lead to big changes",
    ];
    return quotes[DateTime.now().microsecond % quotes.length];
  }

  Widget _buildTodayProgressCard() {
    return AnimatedBuilder(
      animation: _progressUpdateAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _adaptiveCardColor,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(0, 12),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.today_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Today\'s Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_isRefreshing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                        onPressed: () async {
                          await _smoothRefreshData();
                        },
                        splashRadius: 12,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAnimatedProgressStat(
                      'Focus Time',
                      '${_todayFocusTime}min',
                      Icons.timer_outlined,
                      Colors.green,
                    ),
                    _buildAnimatedProgressStat(
                      'Completed',
                      '$_todayCompletedSessions',
                      Icons.check_circle_outline,
                      Colors.blue,
                    ),
                    _buildAnimatedProgressStat(
                      'Success Rate',
                      '${_todayCompletionRate.toInt()}%',
                      Icons.trending_up_rounded,
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedProgressStat(String title, String value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _progressUpdateAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * _progressUpdateAnimation.value),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withOpacity(0.8),
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0, end: 1),
                builder: (context, animValue, child) {
                  return Opacity(
                    opacity: animValue,
                    child: Text(
                      value, // Fixed: use value parameter instead of animValue
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTreeGrowthCard() {
    return AnimatedBuilder(
      animation: _progressUpdateAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _adaptiveCardColor,
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.eco,
                        color: _adaptiveIconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentLevelTreeName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Unlocked at Level $_userLevel',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _hasActiveSession 
                            ? Colors.orange.withOpacity(0.2) 
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${_currentLevelDuration}min',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currentLevelTreeDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Growth Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$_currentTreeMinutes / $_currentLevelDuration minutes',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween(begin: 0, end: _treeGrowthProgress),
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _hasActiveSession ? Colors.orange.shade400 : Colors.green.shade400,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0, end: _treeGrowthProgress * 100),
                      builder: (context, value, child) {
                        return Text(
                          '${value.toInt()}% Complete',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                    if (_hasActiveSession)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Growing...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${_currentLevelDuration - _currentTreeMinutes} min remaining',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOpenContainerActionCard(
                'Forest',
                Icons.forest,
                Colors.green,
                const ForestPage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOpenContainerActionCard(
                'Trees',
                Icons.nature,
                Colors.lightGreen,
                const TreeSelectionPage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOpenContainerActionCard(
                'Stats',
                Icons.analytics,
                Colors.blue,
                const StatsPage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOpenContainerActionCard(
                'Settings',
                Icons.settings,
                Colors.grey,
                const SettingsPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpenContainerActionCard(
    String title,
    IconData icon,
    Color color,
    Widget destination,
  ) {
    // Update for Stats page to pass refresh controller if it's StatsPage
    if (destination is StatsPage) {
      return OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (context, _) => destination,
        closedElevation: 0,
        closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        closedColor: Colors.transparent,
        openColor: Colors.white,
        closedBuilder: (context, openContainer) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _adaptiveCardColor.withOpacity(_adaptiveCardColor.opacity * 0.8),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(icon, color: _adaptiveIconColor, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Original implementation for other destinations
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      openBuilder: (context, _) => destination,
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      closedColor: Colors.transparent,
      openColor: Colors.white,
      closedBuilder: (context, openContainer) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _adaptiveCardColor.withOpacity(_adaptiveCardColor.opacity * 0.8),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: openContainer,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, color: _adaptiveIconColor, size: 32),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusButton() {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      openBuilder: (context, _) => FocusTimerPage(
        totalMinutes: _currentLevelDuration,
        completedMinutes: _currentTreeMinutes,
        treeStage: _userLevel,
        userLevel: _userLevel,
        treeType: _currentLevelTreeName,
        onSessionUpdate: (completedMinutes, isCompleted) async {
          await _authService.saveUserCurrentTreeGrowth({
            'completedMinutes': completedMinutes,
            'totalMinutes': _currentLevelDuration,
            'hasActiveSession': !isCompleted,
            'treeStage': _userLevel,
          });
          if (isCompleted) {
            await _checkAndUpdateLevel();
          }
        },
      ),
      onClosed: (result) async {
        if (result != null && result is Map) {
          final completed = result['completed'] as bool? ?? false;
          final shouldReload = result['reload'] as bool? ?? false;
          
          if (completed && shouldReload) {
            await _loadAllDataComprehensively();  // Change to use comprehensive load
          } else if (shouldReload) {
            await _loadAllDataSilently();
          }
        } else {
          await _loadAllDataSilently();
        }
      },
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      closedColor: Colors.transparent,
      openColor: Colors.green.shade50,
      closedBuilder: (context, openContainer) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _hasActiveSession 
                ? [Colors.orange.withOpacity(0.6), Colors.orange.withOpacity(0.8)]
                : [Colors.green.withOpacity(0.6), Colors.green.withOpacity(0.8)],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _hasActiveSession ? Icons.play_arrow : Icons.eco,
                    size: 24,
                    color: _adaptiveIconColor,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text(
                        _hasActiveSession 
                            ? 'Continue Growing'
                            : 'Start Growing $_currentLevelTreeName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$_currentLevelDuration minute session',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Add missing methods
  Future<void> _loadWeatherData() async {
    try {
      final userData = await _authService.getUserProfile();
      final cityName = userData?['city'] ?? 'London';
      
      final weatherData = await _weatherService.getWeather(cityName);
      if (weatherData['weather'] != null && weatherData['weather'].length > 0 && mounted) {
        final weatherCode = weatherData['weather'][0]['icon'];
        final temperature = weatherData['main']['temp']?.round() ?? 20;
        
        setState(() {
          _currentWeather = getWeatherCondition(weatherCode);
          _temperature = temperature;
        });
      }
    } catch (e) {
      debugPrint('Error loading weather: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = await _authService.getUserProfile();
      if (userData != null && mounted) {
        setState(() {
          _userName = userData['name'] ?? 'User';
          _userLevel = userData['level'] ?? 1;
          _treesCompleted = userData['treesCompleted'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final statsRef = _authService.database.ref('users/${user.uid}/focusStats');
      final snapshot = await statsRef.get();
      
      if (snapshot.exists && mounted) {
        final stats = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _totalFocusTime = stats['totalFocusTime'] ?? 0;
          _totalSessions = stats['totalSessions'] ?? 0;
          _treesCompleted = stats['treesCompleted'] ?? 0;
          _currentStreak = stats['currentStreak'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _loadCurrentTreeGrowthSilent() async {
    try {
      final growthData = await _authService.getUserCurrentTreeGrowth();
      if (growthData != null && mounted) {
        setState(() {
          _hasActiveSession = growthData['hasActiveSession'] ?? false;
          _activeSessionProgress = (growthData['progressPercentage'] ?? 0).toDouble();
          _activeSessionMinutes = growthData['completedMinutes'] ?? 0;
          _activeSessionTotalMinutes = growthData['totalMinutes'] ?? 25;
          _currentTreeMinutes = _activeSessionMinutes;
          _totalTreeMinutes = _activeSessionTotalMinutes;
          _treeGrowthProgress = _totalTreeMinutes > 0 ? _currentTreeMinutes / _totalTreeMinutes : 0.0;
        });
      }
    } catch (e) {
      debugPrint('Error loading tree growth: $e');
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _adaptiveCardColor.withOpacity(_adaptiveCardColor.opacity * 0.8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: _adaptiveIconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Add these to satisfy calls in initState, didChangeDependencies, onClosed, etc.
  Future<void> _loadAllData() async {
    setState(() { _isLoading = true; });
    try {
      await _loadCompleteUserData();
      await _loadCompleteFocusStats();
      await _loadCompleteTodayData();
      await _loadCompleteTreeGrowth();
      await _loadWeatherData();
    } catch (e) {
      debugPrint('Error loading all data: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _silentRefreshData() async {
    try {
      await _loadCompleteUserData();
      await _loadCompleteTodayData();
      await _loadCurrentTreeGrowthSilent();
      await _loadWeatherData();
    } catch (e) {
      debugPrint('Error silently refreshing data: $e');
    }
  }

  Future<void> _loadAllDataSilently() => _silentRefreshData();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<String>(
        valueListenable: _wallpaperNotifier,
        builder: (context, wallpaper, child) {
          return Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/$wallpaper'),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        debugPrint('Error loading wallpaper: $wallpaper - $exception');
                      },
                    ),
                  ),
                ),
              ),
              
              // Overlay
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                ),
              ),
              
              // Content with RefreshIndicator
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Loading your garden...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: Colors.green.shade600,
                  backgroundColor: Colors.white,
                  strokeWidth: 2.0,
                  displacement: 80.0,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: FadeTransition(
                      opacity: _dataUpdateAnimation,
                      child: Column(
                        children: [
                          _buildHeader(),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildTodayProgressCard(),
                                const SizedBox(height: 16),
                                _buildStatsRow(),
                                const SizedBox(height: 16),
                                _buildTreeGrowthCard(),
                                const SizedBox(height: 16),
                                _buildQuickActions(),
                                const SizedBox(height: 20),
                                _buildFocusButton(),
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Trees',
            value: '$_treesCompleted',
            icon: Icons.park,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Sessions',
            value: '$_totalSessions',
            icon: Icons.play_circle_filled,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Focus Time',
            value: '${_totalFocusTime} min',
            icon: Icons.timer,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}