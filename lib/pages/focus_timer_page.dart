import 'dart:async';
import 'dart:math';
import 'dart:ui';  // Add this import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/weather_service.dart';
import '../widgets/tree_landscape_painter.dart';
import 'tree_completion_success_page.dart';

class FocusTimerPage extends StatefulWidget {
  final int totalMinutes;
  final int completedMinutes;
  final int treeStage;
  final int userLevel;
  final String treeType;
  final Function(int completedMinutes, bool isCompleted)? onSessionUpdate;

  const FocusTimerPage({
    super.key,
    required this.totalMinutes,
    this.completedMinutes = 0,
    this.treeStage = 1,
    this.userLevel = 1,
    required this.treeType,
    this.onSessionUpdate,
  });

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final WeatherService _weatherService = WeatherService();
  
  // Timer variables
  Timer? _timer;
  int _currentMinutes = 0;
  int _currentSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  
  // Session data
  late int _totalSessionSeconds;
  late int _completedSessionSeconds;
  late int _remainingSeconds;
  
  // Tree growth
  late AnimationController _treeAnimationController;
  late Animation<double> _treeGrowthAnimation;
  double _treeGrowthProgress = 0.0;
  
  // UI animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Session tracking
  DateTime? _sessionStartTime;
  bool _hasStarted = false;
  String _sessionId = '';

  // Weather and time
  WeatherCondition _currentWeather = WeatherCondition.clear;
  String _cityName = '';
  TimeOfDay _currentTime = TimeOfDay.now();
  Timer? _weatherUpdateTimer;
  Timer? _timeUpdateTimer;

  // Background wallpaper
  String _currentWallpaper = 'bg.jpg';
  
  // Tree data from Firebase
  Map<String, dynamic>? _treeData;

  @override
  void initState() {
    super.initState();
    _initializeSession();
    _setupAnimations();
    _initWeatherAndTime();
    _loadWallpaper();
    _loadTreeData();
  }

  Future<void> _loadTreeData() async {
    try {
      final treeRef = _authService.database.ref('trees');
      final snapshot = await treeRef.get();
      
      if (snapshot.exists) {
        final allTrees = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Find the tree that matches our tree type (common name)
        for (final treeEntry in allTrees.entries) {
          final tree = Map<String, dynamic>.from(treeEntry.value as Map);
          if (tree['common_name'] == widget.treeType) {
            setState(() {
              _treeData = tree;
            });
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading tree data: $e');
    }
  }

  void _initializeSession() {
    _totalSessionSeconds = widget.totalMinutes * 60;
    _completedSessionSeconds = widget.completedMinutes * 60;
    _remainingSeconds = _totalSessionSeconds - _completedSessionSeconds;
    
    _currentMinutes = _remainingSeconds ~/ 60;
    _currentSeconds = _remainingSeconds % 60;
    
    _treeGrowthProgress = _completedSessionSeconds / _totalSessionSeconds;
    
    // Generate session ID
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    debugPrint('Session initialized: ${widget.totalMinutes}min, completed: ${widget.completedMinutes}min');
    debugPrint('Remaining: $_currentMinutes:${_currentSeconds.toString().padLeft(2, '0')}');
  }

  void _setupAnimations() {
    // Tree growth animation
    _treeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _treeGrowthAnimation = Tween<double>(
      begin: _treeGrowthProgress,
      end: _treeGrowthProgress,
    ).animate(CurvedAnimation(
      parent: _treeAnimationController,
      curve: Curves.easeInOut,
    ));

    // Pulse animation for timer
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startTimer() {
    if (_isCompleted || _remainingSeconds <= 0) return;
    
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _hasStarted = true;
    });
    
    _sessionStartTime ??= DateTime.now();
    
    _pulseController.repeat(reverse: true);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _currentMinutes = _remainingSeconds ~/ 60;
          _currentSeconds = _remainingSeconds % 60;
          _completedSessionSeconds = _totalSessionSeconds - _remainingSeconds;
          _treeGrowthProgress = _completedSessionSeconds / _totalSessionSeconds;
        });
        
        // Update tree growth animation
        _treeGrowthAnimation = Tween<double>(
          begin: _treeGrowthAnimation.value,
          end: _treeGrowthProgress,
        ).animate(CurvedAnimation(
          parent: _treeAnimationController,
          curve: Curves.easeInOut,
        ));
        _treeAnimationController.forward(from: 0);
        
        // Save progress periodically
        if (_completedSessionSeconds % 60 == 0) {
          _saveProgress();
        }
      } else {
        _completeSession();
      }
    });
    
    debugPrint('Timer started');
  }

  void _pauseTimer() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
    
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
    
    _pulseController.stop();
    _saveProgress();
    
    debugPrint('Timer paused');
  }

  void _resetTimer() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
    
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _hasStarted = false;
      _isCompleted = false;
      _remainingSeconds = _totalSessionSeconds;
      _currentMinutes = widget.totalMinutes;
      _currentSeconds = 0;
      _completedSessionSeconds = 0;
      _treeGrowthProgress = 0.0;
    });
    
    _pulseController.stop();
    _sessionStartTime = null;
    
    debugPrint('Timer reset');
  }

  void _completeSession() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
    
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isCompleted = true;
      _treeGrowthProgress = 1.0;
    });
    
    _pulseController.stop();
    
    // Final tree growth animation
    _treeGrowthAnimation = Tween<double>(
      begin: _treeGrowthAnimation.value,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _treeAnimationController,
      curve: Curves.easeInOut,
    ));
    _treeAnimationController.forward(from: 0);
    
    // Save completed session
    _saveCompletedSession();
    
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // Navigate to success page instead of showing dialog
    _navigateToSuccessPage();
    
    debugPrint('Session completed!');
  }

  void _navigateToSuccessPage() {
    // Small delay to ensure animations complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => TreeCompletionSuccessPage(
              treeType: widget.treeType,
              totalMinutes: widget.totalMinutes,
              userLevel: widget.userLevel,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  void _stopSession() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
    
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });
    
    _pulseController.stop();
    
    // Save the stopped session with all data
    _saveStoppedSession();
    
    debugPrint('Session stopped and data saved');
  }

  Future<void> _saveStoppedSession() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      final completedMinutes = (_completedSessionSeconds / 60).round();
      final completionPercentage = ((_completedSessionSeconds / _totalSessionSeconds) * 100).round();
      
      // Generate unique session ID if not already set
      if (_sessionId.isEmpty) {
        _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      final sessionData = {
        'session_id': _sessionId,
        'user_id': user.uid,
        'tree_type': widget.treeType,
        'planned_duration_minutes': widget.totalMinutes,
        'actual_duration_minutes': completedMinutes,
        'completion_percentage': completionPercentage,
        'was_completed': false, // This was stopped, not completed
        'was_stopped': true, // Mark as stopped
        'start_time': _sessionStartTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'focus_breaks': 0,
        'tree_stage': widget.treeStage,
        'user_level': widget.userLevel,
        'stopped_at_minutes': completedMinutes,
        'remaining_minutes': widget.totalMinutes - completedMinutes,
      };
      
      // Save to daily sessions
      final today = DateTime.now().toIso8601String().split('T')[0];
      final sessionRef = _authService.database.ref('users/${user.uid}/daily_sessions/$today/$_sessionId');
      await sessionRef.set(sessionData);
      
      // Update focus stats (count partial sessions too)
      final focusStatsRef = _authService.database.ref('users/${user.uid}/focusStats');
      await focusStatsRef.update({
        'totalSessions': ServerValue.increment(1),
        'totalFocusTime': ServerValue.increment(completedMinutes),
        'partialSessions': ServerValue.increment(1), // Track partial sessions
        'lastSessionDate': today,
        'lastSessionType': 'stopped',
        'lastUpdated': ServerValue.timestamp,
      });
      
      // Update current tree growth with progress
      await _authService.saveUserCurrentTreeGrowth({
        'completedMinutes': completedMinutes,
        'totalMinutes': widget.totalMinutes,
        'hasActiveSession': false, // No longer active since stopped
        'treeStage': widget.treeStage,
        'sessionId': _sessionId,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'progressPercentage': completionPercentage,
      });
      
      // Update daily summary
      await _updateDailySummary(completedMinutes, false); // false = not completed
      
      // Show stop confirmation dialog
      _showStopConfirmationDialog(completedMinutes, completionPercentage);
      
      debugPrint('Stopped session saved successfully: ${completedMinutes}min ($completionPercentage%)');
    } catch (e) {
      debugPrint('Error saving stopped session: $e');
      // Still show dialog even if save failed
      _showStopConfirmationDialog((_completedSessionSeconds / 60).round(), 
                                 ((_completedSessionSeconds / _totalSessionSeconds) * 100).round());
    }
  }

  Future<void> _updateDailySummary(int completedMinutes, bool wasCompleted) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      final today = DateTime.now().toIso8601String().split('T')[0];
      final summaryRef = _authService.database.ref('users/${user.uid}/daily_summaries/$today');
      
      // Get existing summary or create new one
      final snapshot = await summaryRef.get();
      Map<String, dynamic> summaryData = {};
      
      if (snapshot.exists) {
        summaryData = Map<String, dynamic>.from(snapshot.value as Map);
      } else {
        summaryData = {
          'date': today,
          'total_focus_minutes': 0,
          'completed_sessions': 0,
          'partial_sessions': 0,
          'total_sessions': 0,
          'trees_completed': 0,
          'average_completion_rate': 0,
        };
      }
      
      // Update summary data
      summaryData['total_focus_minutes'] = (summaryData['total_focus_minutes'] ?? 0) + completedMinutes;
      summaryData['total_sessions'] = (summaryData['total_sessions'] ?? 0) + 1;
      
      if (wasCompleted) {
        summaryData['completed_sessions'] = (summaryData['completed_sessions'] ?? 0) + 1;
        summaryData['trees_completed'] = (summaryData['trees_completed'] ?? 0) + 1;
      } else {
        summaryData['partial_sessions'] = (summaryData['partial_sessions'] ?? 0) + 1;
      }
      
      // Calculate average completion rate
      final totalSessions = summaryData['total_sessions'] ?? 1;
      final completedSessions = summaryData['completed_sessions'] ?? 0;
      summaryData['average_completion_rate'] = ((completedSessions / totalSessions) * 100).round();
      
      summaryData['last_updated'] = ServerValue.timestamp;
      
      await summaryRef.set(summaryData);
      
      debugPrint('Daily summary updated for $today');
    } catch (e) {
      debugPrint('Error updating daily summary: $e');
    }
  }

  void _showStopConfirmationDialog(int completedMinutes, int completionPercentage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Leave Session?'),
        content: Text(
          _hasStarted 
              ? 'Your progress will be saved, but the tree won\'t be completed. Are you sure you want to leave?'
              : 'Are you sure you want to leave this focus session?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              if (_hasStarted) {
                _saveProgress();
              }
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to home
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCompletedSession() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      final sessionData = {
        'session_id': _sessionId,
        'user_id': user.uid,
        'tree_type': widget.treeType,
        'planned_duration_minutes': widget.totalMinutes,
        'actual_duration_minutes': widget.totalMinutes,
        'completion_percentage': 100,
        'was_completed': true,
        'was_stopped': false,
        'start_time': _sessionStartTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'focus_breaks': 0,
        'tree_stage': widget.treeStage,
        'user_level': widget.userLevel,
      };
      
      // Save to daily sessions
      final today = DateTime.now().toIso8601String().split('T')[0];
      final sessionRef = _authService.database.ref('users/${user.uid}/daily_sessions/$today/$_sessionId');
      await sessionRef.set(sessionData);
      
      // Get current focus stats first
      final focusStatsRef = _authService.database.ref('users/${user.uid}/focusStats');
      final focusStatsSnapshot = await focusStatsRef.get();
      
      int currentTreesCompleted = 0;
      if (focusStatsSnapshot.exists) {
        final stats = Map<String, dynamic>.from(focusStatsSnapshot.value as Map);
        currentTreesCompleted = stats['treesCompleted'] ?? 0;
      }
      
      // Increment trees completed
      final newTreesCompleted = currentTreesCompleted + 1;
      
      // Update focus stats with completed tree
      await focusStatsRef.update({
        'totalSessions': ServerValue.increment(1),
        'totalFocusTime': ServerValue.increment(widget.totalMinutes),
        'treesPlanted': ServerValue.increment(1),
        'treesCompleted': newTreesCompleted, // Set exact value
        'completedSessions': ServerValue.increment(1),
        'lastTreeCompleted': DateTime.now().toIso8601String(),
        'lastTreeType': widget.treeType,
        'lastSessionDate': today,
        'lastSessionType': 'completed',
        'lastUpdated': ServerValue.timestamp,
      });
      
      // Calculate new level based on trees completed (Level = trees + 1)
      final newLevel = newTreesCompleted + 1;
      
      // Update user status with new level
      final statusRef = _authService.database.ref('users/${user.uid}/status');
      await statusRef.update({
        'level': newLevel,
        'experience': newTreesCompleted * 100,
        'rank': _getRankForLevel(newLevel),
        'treesCompleted': newTreesCompleted,
        'treesForNextLevel': 1,
        'lastLevelUp': newLevel > widget.userLevel ? DateTime.now().toIso8601String() : null,
        'lastUpdated': ServerValue.timestamp,
      });
      
      // Update profile level
      final profileRef = _authService.database.ref('users/${user.uid}/profile');
      await profileRef.update({
        'level': newLevel,
        'treesCompleted': newTreesCompleted,
        'lastUpdated': ServerValue.timestamp,
      });
      
      // Clear current tree growth (tree is complete)
      await _authService.saveUserCurrentTreeGrowth({
        'completedMinutes': 0,
        'totalMinutes': 25,
        'hasActiveSession': false,
        'treeStage': 0,
        'sessionId': '',
        'progressPercentage': 0,
      });
      
      // Update daily summary
      await _updateDailySummary(widget.totalMinutes, true);
      
      debugPrint('Completed session saved successfully. Trees completed: $newTreesCompleted, New level: $newLevel');
    } catch (e) {
      debugPrint('Error saving completed session: $e');
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

  Future<void> _saveProgress() async {
    try {
      final completedMinutes = (_completedSessionSeconds / 60).round();
      final completionPercentage = ((_completedSessionSeconds / _totalSessionSeconds) * 100).round();
      
      final progressData = {
        'completedMinutes': completedMinutes,
        'totalMinutes': widget.totalMinutes,
        'hasActiveSession': !_isCompleted,
        'treeStage': widget.treeStage,
        'sessionId': _sessionId,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'progressPercentage': completionPercentage,
        'isPaused': _isPaused,
        'isRunning': _isRunning,
      };
      
      await _authService.saveUserCurrentTreeGrowth(progressData);
      
      // Call the callback if provided
      if (widget.onSessionUpdate != null) {
        widget.onSessionUpdate!(completedMinutes, _isCompleted);
      }
      
      debugPrint('Progress saved: ${completedMinutes}min ($completionPercentage%)');
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  Future<void> _initWeatherAndTime() async {
    // Start periodic time updates
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _currentTime = TimeOfDay.now();
      });
    });

    // Get initial weather
    await _updateWeather();

    // Start periodic weather updates
    _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _updateWeather();
    });
  }

  Future<void> _updateWeather() async {
    try {
      if (_cityName.isEmpty) {
        // Get user's city from profile or use default
        final userData = await _authService.getUserProfile();
        _cityName = userData?['city'] ?? 'London';
      }

      final weatherData = await _weatherService.getWeather(_cityName);
      if (weatherData['weather'] != null && weatherData['weather'].length > 0) {
        final weatherCode = weatherData['weather'][0]['icon'];
        setState(() {
          _currentWeather = getWeatherCondition(weatherCode);
        });
      }
    } catch (e) {
      debugPrint('Error updating weather: $e');
      // Keep existing weather condition on error
    }
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

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Session?'),
        content: Text(
          _hasStarted 
              ? 'Your progress will be saved, but the tree won\'t be completed. Are you sure you want to leave?'
              : 'Are you sure you want to leave this focus session?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              if (_hasStarted) {
                _saveProgress();
              }
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to home
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _weatherUpdateTimer?.cancel();
    _timeUpdateTimer?.cancel();
    // Safely dispose timer
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
    
    // Dispose animation controllers
    _treeAnimationController.dispose();
    _pulseController.dispose();
    
    // Save progress if session was started but not completed
    if (_hasStarted && !_isCompleted) {
      _saveProgress();
    }
    
    super.dispose();
  }

  // Modify the _buildTreeLandscape method to paint clouds in TreeLandscapePainter
  Widget _buildTreeLandscape() {
    return CustomPaint(
      painter: TreeLandscapePainter(
        isDaytime: _currentTime.hour >= 6 && _currentTime.hour < 18,
        treeGrowthProgress: _treeGrowthProgress,
        treeStage: widget.treeStage,
        currentTime: _currentTime,
      ),
      child: Container(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showExitDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/$_currentWallpaper',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading background: $error');
                  return Container(
                    color: Colors.green.shade900,
                  );
                },
              ),
            ),

            // Tinted overlay
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),

            // Main Content with BackdropFilter
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: SafeArea(
                child: Column(
                  children: [
                    // App Bar with transparent background
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              color: Colors.white,
                              onPressed: _showExitDialog,
                            ),
                          ),
                          const Text(
                            'FOCUS SESSION',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.more_vert),
                              color: Colors.white,
                              onPressed: () {}, 
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cloud Layer (Outside Card)
                    Expanded(
                      flex: 1,
                      child: Container(), // Removed cloud painter
                    ),

                    // Tree Visualization Area (With Rounded Card)
                    Expanded(
                      flex: 4,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: _buildTreeLandscape(),
                        ),
                      ),
                    ),

                    // Session Info
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            widget.treeType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_treeData != null && _treeData!['health_benefits'] != null)
                            Text(
                              _treeData!['health_benefits']['usage'] ?? 
                              _treeData!['health_benefits']['primary'] ?? 
                              'Medicinal tree with health benefits',
                              style: TextStyle(
                                color: Colors.green.shade200,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Text(
                              'Loading tree benefits...',
                              style: TextStyle(
                                color: Colors.green.shade200,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Timer Display
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        '${_currentMinutes.toString().padLeft(2, '0')}:${_currentSeconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: _isCompleted 
                              ? Colors.green.shade300 
                              : Colors.white,
                          letterSpacing: 8.0, // Increase width spacing between characters
                          fontFeatures: const [
                            FontFeature.tabularFigures(), // Makes numbers monospaced for consistent width
                          ],
                        ),
                      ),
                    ),

                    // Progress Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _treeGrowthProgress,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade300),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(_completedSessionSeconds / 60).round()} min',
                                style: TextStyle(color: Colors.green.shade200),
                              ),
                              Text(
                                '${widget.totalMinutes} min',
                                style: TextStyle(color: Colors.green.shade200),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Control Buttons
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!_isCompleted) ...[
                            IconButton(
                              icon: const Icon(Icons.replay),
                              color: Colors.white,
                              iconSize: 32,
                              onPressed: _resetTimer,
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: IconButton(
                                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                                color: Colors.green.shade800,
                                iconSize: 48,
                                onPressed: _isRunning ? _pauseTimer : _startTimer,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.stop),
                              color: Colors.white,
                              iconSize: 32,
                              onPressed: _hasStarted ? _stopSession : null,
                            ),
                          ] else ...[
                            Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.home),
                                color: Colors.green.shade800,
                                iconSize: 48,
                                onPressed: () => Navigator.pop(context, true), // Return true for completion
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}