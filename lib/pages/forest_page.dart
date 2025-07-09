import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ForestPage extends StatefulWidget {
  const ForestPage({super.key});

  @override
  State<ForestPage> createState() => _ForestPageState();
}

class _ForestPageState extends State<ForestPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _userTrees = [];
  bool _isLoading = true;
  bool _showGlobalImpact = false;
  bool _showWeatherDetails = false;
  
  // Weather and animation variables
  Map<String, dynamic>? _weatherData;
  DateTime? _lastWeatherUpdate;
  late AnimationController _cloudAnimationController;
  late AnimationController _birdAnimationController;
  late AnimationController _windAnimationController;
  Timer? _weatherTimer;
  String _timeOfDay = 'day'; // day, evening, night
  
  // Weather API key - Replace with your OpenWeatherMap API key
  static const String _weatherApiKey = '0e425a94523e6d3334fa6fb15215480a';
  static const String _baseWeatherUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // Add background image variables
  String _currentBackground = 'bg.jpg';
  Color _adaptiveCardColor = Colors.white.withOpacity(0.15);
  Color _adaptiveIconColor = Colors.white.withOpacity(0.7);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadForestData();
    _startWeatherTimer();
    _updateTimeOfDay();
    _loadCurrentBackground();
  }

  void _initializeAnimations() {
    _cloudAnimationController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    
    _birdAnimationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _windAnimationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  void _startWeatherTimer() {
    // Start with immediate weather load, then every 10 minutes
    _weatherTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      print('Weather timer triggered - loading weather data');
      _loadWeatherData();
    });
  }

  void _updateTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 18) {
      _timeOfDay = 'day';
    } else if (hour >= 18 && hour < 20) {
      _timeOfDay = 'evening';
    } else {
      _timeOfDay = 'night';
    }
  }

  Future<void> _loadWeatherData() async {
    // Check if we already have recent weather data (less than 5 minutes old)
    if (_weatherData != null && _lastWeatherUpdate != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastWeatherUpdate!);
      if (timeSinceLastUpdate.inMinutes < 5) {
        print('Weather data is recent (${timeSinceLastUpdate.inMinutes} minutes old), skipping API call');
        return;
      }
    }

    try {
      print('Loading weather data from API...');
      
      // Get user's city from Firebase profile
      String city = 'Tamil Nadu'; // Set default as Tamil Nadu
      if (_userData != null && _userData!['profile'] != null) {
        final profile = _userData!['profile'];
        if (profile['city'] != null && profile['city'].toString().isNotEmpty) {
          city = profile['city'].toString();
          print('Found city in profile: $city');
        } else if (profile['location'] != null && profile['location'].toString().isNotEmpty) {
          city = profile['location'].toString();
          print('Found location in profile: $city');
        } else {
          print('No city or location found in profile, using default: $city');
        }
      }
      
      print('Fetching weather for city: $city');
      
      final response = await http.get(
        Uri.parse('$_baseWeatherUrl?q=$city&appid=$_weatherApiKey&units=metric'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Weather data loaded successfully: ${data['weather'][0]['main']} for ${data['name']}');
        
        if (mounted) {
          setState(() {
            _weatherData = data;
            _lastWeatherUpdate = DateTime.now();
          });
        }
      } else {
        print('Weather API error: ${response.statusCode} for city: $city');
        // Try with default city as fallback
        const fallbackCity = 'Tamil Nadu';
        print('Trying fallback city: $fallbackCity');
        
        final fallbackResponse = await http.get(
          Uri.parse('$_baseWeatherUrl?q=$fallbackCity&appid=$_weatherApiKey&units=metric'),
        );
        
        if (fallbackResponse.statusCode == 200) {
          final data = json.decode(fallbackResponse.body);
          print('Fallback weather data loaded successfully: ${data['weather'][0]['main']} for ${data['name']}');
          
          if (mounted) {
            setState(() {
              _weatherData = data;
              _lastWeatherUpdate = DateTime.now();
            });
          }
        } else {
          print('Fallback weather API error: ${fallbackResponse.statusCode}');
          // Try with India as final fallback
          final secondFallbackResponse = await http.get(
            Uri.parse('$_baseWeatherUrl?q=India&appid=$_weatherApiKey&units=metric'),
          );
          
          if (secondFallbackResponse.statusCode == 200) {
            final data = json.decode(secondFallbackResponse.body);
            if (mounted) {
              setState(() {
                _weatherData = data;
                _lastWeatherUpdate = DateTime.now();
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error loading weather: $e');
    }
  }

  @override
  void dispose() {
    _cloudAnimationController.dispose();
    _birdAnimationController.dispose();
    _windAnimationController.dispose();
    _weatherTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadForestData() async {
    try {
      final userData = await _authService.getUserDataFromFirestore();
      final userSessions = await _authService.getUserFocusSessions();
      
      print('Loading forest data for user: ${userData?['uid']}');
      
      // Store user data for weather city lookup
      _userData = userData;
      
      // Load weather data only after we have user data
      if (_weatherData == null) {
        await _loadWeatherData();
      }
      
      // Get user level and available trees for that level
      final userLevel = _getUserLevel(userData);
      final availableTreeTypes = await _getAvailableTreesForLevel(userLevel);
      
      print('User level: $userLevel');
      print('Available tree types for level $userLevel: $availableTreeTypes');
      
      // Create trees based on completed sessions
      List<Map<String, dynamic>> trees = [];
      int treeId = 1;
      
      // Parse from focusStats first - this is where your completed trees are
      if (userData != null && userData['focusStats'] != null) {
        try {
          final focusStats = userData['focusStats'] is Map 
            ? Map<String, dynamic>.from(userData['focusStats'] as Map)
            : userData['focusStats'] as Map<String, dynamic>;
          
          print('FocusStats raw: ${userData['focusStats']}'); // Debug raw data
          print('FocusStats parsed: $focusStats'); // Debug parsed data
          
          final treesCompleted = focusStats['treesCompleted'] ?? 0;
          final treesPlanted = focusStats['treesPlanted'] ?? 0;
          final lastTreeType = focusStats['lastTreeType']?.toString() ?? 'Moringa';
          
          print('Trees completed from focusStats: $treesCompleted (type: ${treesCompleted.runtimeType})'); // Debug
          print('Trees planted from focusStats: $treesPlanted (type: ${treesPlanted.runtimeType})'); // Debug
          print('Last tree type: $lastTreeType'); // Debug
          
          // Use treesCompleted if it's a valid number, otherwise use treesPlanted
          int totalTrees = 0;
          if (treesCompleted is num && treesCompleted > 0) {
            totalTrees = treesCompleted.toInt();
            print('Using treesCompleted: $totalTrees');
          } else if (treesPlanted is num && treesPlanted > 0) {
            totalTrees = treesPlanted.toInt();
            print('Using treesPlanted: $totalTrees');
          }
          
          print('Final total trees to create: $totalTrees'); // Debug
          
          // Create trees based on completed count from focusStats with realistic timestamps
          final now = DateTime.now();
          for (int i = 0; i < totalTrees; i++) {
            // Use last tree type if available and unlocked, otherwise get random from available trees
            String treeType;
            if (i == totalTrees - 1 && availableTreeTypes.contains(lastTreeType)) {
              treeType = lastTreeType;
            } else {
              treeType = _getRandomTreeTypeFromLevel(availableTreeTypes);
            }
            
            // Create realistic planting dates - spread trees over time
            // Most recent tree gets current time, older trees get earlier dates
            final daysBack = totalTrees - 1 - i; // Most recent tree = 0 days back
            final hoursVariation = math.Random().nextInt(24); // Random hour within the day
            final plantedDate = now.subtract(Duration(
              days: daysBack, 
              hours: hoursVariation,
              minutes: math.Random().nextInt(60)
            ));
            
            trees.add({
              'id': treeId++,
              'type': treeType,
              'plantedDate': plantedDate.millisecondsSinceEpoch,
              'growthStage': 'Mature', // Completed trees are mature
              'duration': 60, // Default to 60 minutes for completed trees
              'sessionId': 'focusStats_completed_$i',
              'level': userLevel,
            });
            
            print('Added focusStats tree #$i: $treeType, Stage: Mature, Level: $userLevel, Date: ${plantedDate.toIso8601String()}'); // Debug
          }
          
          // If we created trees from focusStats, skip other sources to avoid duplicates
          if (totalTrees > 0) {
            print('Created $totalTrees trees from focusStats, skipping other sources to avoid duplicates');
          }
        } catch (e) {
          print('Error parsing focusStats: $e');
          print('FocusStats type: ${userData['focusStats'].runtimeType}');
        }
      }
      
      // Only check other sources if we didn't create trees from focusStats
      if (trees.isEmpty) {
        // Also check profile for treesCompleted as backup
        if (userData != null && userData['profile'] != null) {
          try {
            final profile = userData['profile'] is Map 
              ? Map<String, dynamic>.from(userData['profile'] as Map)
              : userData['profile'] as Map<String, dynamic>;
            
            final profileTreesCompleted = profile['treesCompleted'] ?? 0;
            print('Trees completed from profile: $profileTreesCompleted'); // Debug
            
            if (profileTreesCompleted > 0) {
              final totalTrees = profileTreesCompleted is num ? profileTreesCompleted.toInt() : 0;
              final now = DateTime.now();
              
              for (int i = 0; i < totalTrees; i++) {
                String treeType;
                if (i == totalTrees - 1 && availableTreeTypes.contains('Moringa')) {
                  treeType = 'Moringa';
                } else {
                  treeType = _getRandomTreeTypeFromLevel(availableTreeTypes);
                }
                
                // Create realistic planting dates
                final daysBack = totalTrees - 1 - i;
                final hoursVariation = math.Random().nextInt(24);
                final plantedDate = now.subtract(Duration(
                  days: daysBack, 
                  hours: hoursVariation,
                  minutes: math.Random().nextInt(60)
                ));
                
                trees.add({
                  'id': treeId++,
                  'type': treeType,
                  'plantedDate': plantedDate.millisecondsSinceEpoch,
                  'growthStage': 'Mature',
                  'duration': 60,
                  'sessionId': 'profile_completed_$i',
                  'level': userLevel,
                });
                
                print('Added profile tree #$i: $treeType, Stage: Mature, Level: $userLevel, Date: ${plantedDate.toIso8601String()}'); // Debug
              }
            }
          } catch (e) {
            print('Error parsing profile: $e');
          }
        }
        
        // Parse from daily_sessions structure only if still no trees
        if (trees.isEmpty && userData != null && userData['daily_sessions'] != null) {
          try {
            final dailySessions = userData['daily_sessions'] is Map 
              ? Map<String, dynamic>.from(userData['daily_sessions'] as Map)
              : userData['daily_sessions'] as Map<String, dynamic>;
            
            print('Daily sessions found: ${dailySessions.keys}'); // Debug
            
            for (var dateEntry in dailySessions.entries) {
              final dateKey = dateEntry.key;
              final sessionsForDate = dateEntry.value is Map 
                ? Map<String, dynamic>.from(dateEntry.value as Map)
                : dateEntry.value as Map<String, dynamic>;
              
              print('Processing date: $dateKey with ${sessionsForDate.length} sessions'); // Debug
              
              for (var sessionEntry in sessionsForDate.entries) {
                final sessionKey = sessionEntry.key;
                final sessionData = sessionEntry.value is Map 
                  ? Map<String, dynamic>.from(sessionEntry.value as Map)
                  : sessionEntry.value as Map<String, dynamic>;
                
                print('Session $sessionKey: ${sessionData['was_completed']}, tree: ${sessionData['tree_type']}'); // Debug
                
                if (sessionData['was_completed'] == true) {
                  final sessionTreeType = sessionData['tree_type']?.toString();
                  // Use session tree type if it's available for user's level, otherwise get random
                  final treeType = (sessionTreeType != null && availableTreeTypes.contains(sessionTreeType))
                    ? sessionTreeType
                    : _getRandomTreeTypeFromLevel(availableTreeTypes);
                  
                  final actualDuration = sessionData['actual_focus_time_seconds'] is num 
                    ? (sessionData['actual_focus_time_seconds'] as num).toInt() 
                    : 60;
                  final durationMinutes = (actualDuration / 60).round();
                  final growthStage = _getGrowthStage(durationMinutes);
                  
                  // Parse timestamp from session - this gives us the actual completion time
                  DateTime? plantedDate;
                  try {
                    final startTime = sessionData['start_time']?.toString();
                    if (startTime != null) {
                      plantedDate = DateTime.parse(startTime);
                    }
                  } catch (e) {
                    print('Error parsing date: $e');
                    // Fallback to current time if parsing fails
                    plantedDate = DateTime.now();
                  }
                  
                  trees.add({
                    'id': treeId++,
                    'type': treeType,
                    'plantedDate': plantedDate?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
                    'growthStage': growthStage,
                    'duration': durationMinutes,
                    'sessionId': sessionData['session_id']?.toString() ?? sessionKey,
                    'isQuickTree': sessionData['is_quick_tree'] ?? false,
                    'level': userLevel,
                  });
                  
                  print('Added session tree: $treeType, Stage: $growthStage, Duration: ${durationMinutes}min, Level: $userLevel, Date: ${plantedDate?.toIso8601String()}'); // Debug
                }
              }
            }
          } catch (e) {
            print('Error parsing daily_sessions: $e');
          }
        }
      }
      
      // Remove duplicates based on sessionId (though this should be less necessary now)
      final uniqueTrees = <Map<String, dynamic>>[];
      final seenSessions = <String>{};
      
      for (var tree in trees) {
        final sessionId = tree['sessionId'] as String;
        if (!seenSessions.contains(sessionId)) {
          seenSessions.add(sessionId);
          uniqueTrees.add(tree);
        }
      }
      
      // Sort trees by planted date (newest first for display)
      uniqueTrees.sort((a, b) {
        final aDate = a['plantedDate'] ?? 0;
        final bDate = b['plantedDate'] ?? 0;
        return bDate.compareTo(aDate);
      });
      
      print('Total unique trees created: ${uniqueTrees.length}'); // Debug
      if (uniqueTrees.isNotEmpty) {
        final oldestTree = uniqueTrees.last;
        final newestTree = uniqueTrees.first;
        print('Forest age range: ${DateTime.fromMillisecondsSinceEpoch(oldestTree['plantedDate']).toIso8601String()} to ${DateTime.fromMillisecondsSinceEpoch(newestTree['plantedDate']).toIso8601String()}');
      }
      
      if (mounted) {
        setState(() {
          _userData = userData;
          _userTrees = uniqueTrees;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading forest data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading forest data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showForestStats() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Colors.orange.shade400, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Forest Statistics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('${_userTrees.length}', 'Trees', Icons.park),
                  _buildStatItem('${_calculateForestAge()}', 'Days', Icons.calendar_today),
                  _buildStatItem('${_getUniqueTreeTypes()}', 'Types', Icons.nature),
                ],
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
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
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  int _getUserLevel(Map<String, dynamic>? userData) {
    if (userData == null) return 1;
    
    // Check profile first
    if (userData['profile'] != null) {
      final profile = userData['profile'] is Map 
        ? Map<String, dynamic>.from(userData['profile'] as Map)
        : userData['profile'] as Map<String, dynamic>;
      
      final level = profile['level'];
      if (level is num) {
        return level.toInt();
      }
    }
    
    // Check focusStats as backup
    if (userData['focusStats'] != null) {
      final focusStats = userData['focusStats'] is Map 
        ? Map<String, dynamic>.from(userData['focusStats'] as Map)
        : userData['focusStats'] as Map<String, dynamic>;
      
      final level = focusStats['level'];
      if (level is num) {
        return level.toInt();
      }
    }
    
    // Default to level 1
    return 1;
  }

  Future<List<String>> _getAvailableTreesForLevel(int level) async {
    try {
      // Fetch tree unlocks from Firebase based on user level
      final treeUnlocksData = await _authService.getTreeUnlocksForLevel(level);
      
      if (treeUnlocksData != null && treeUnlocksData.isNotEmpty) {
        print('Fetched tree unlocks from Firebase: $treeUnlocksData'); // Debug
        
        // Extract tree names from Firebase data
        List<String> unlockedTrees = [];
        
        if (treeUnlocksData is Map) {
          for (var entry in treeUnlocksData.entries) {
            final treeData = entry.value;
            if (treeData is Map && treeData['name'] != null) {
              unlockedTrees.add(treeData['name'].toString());
            }
          }
        } else if (treeUnlocksData is List) {
          for (var treeData in treeUnlocksData) {
            if (treeData is Map && treeData['name'] != null) {
              unlockedTrees.add(treeData['name'].toString());
            } else if (treeData is String) {
              unlockedTrees.add(treeData);
            }
          }
        }
        
        if (unlockedTrees.isNotEmpty) {
          print('Unlocked trees for level $level: $unlockedTrees'); // Debug
          return unlockedTrees;
        }
      }
    } catch (e) {
      print('Error fetching tree unlocks from Firebase: $e');
    }
    
    // Fallback to level-based tree unlocking
    print('Using fallback level-based tree unlocking for level $level'); // Debug
    return _getFallbackTreesForLevel(level);
  }

  List<String> _getFallbackTreesForLevel(int level) {
    // Fallback tree unlocking system based on level
    switch (level) {
      case 1:
        return ['Oak', 'Pine'];
      case 2:
        return ['Oak', 'Pine', 'Birch', 'Moringa'];
      case 3:
        return ['Oak', 'Pine', 'Birch', 'Moringa', 'Maple', 'Cedar'];
      case 4:
        return ['Oak', 'Pine', 'Birch', 'Moringa', 'Maple', 'Cedar', 'Willow', 'Bamboo'];
      case 5:
        return ['Oak', 'Pine', 'Birch', 'Moringa', 'Maple', 'Cedar', 'Willow', 'Bamboo', 'Cherry', 'Redwood'];
      default:
        // Level 6 and above get all trees
        return ['Oak', 'Pine', 'Birch', 'Moringa', 'Maple', 'Cedar', 'Willow', 'Bamboo', 'Cherry', 'Redwood', 'Eucalyptus', 'Mahogany'];
    }
  }

  String _getRandomTreeTypeFromLevel(List<String> availableTypes) {
    if (availableTypes.isEmpty) {
      return 'Oak'; // Default fallback
    }
    return availableTypes[math.Random().nextInt(availableTypes.length)];
  }

  String _getRandomTreeType() {
    // This method is now just a fallback
    final types = ['Oak', 'Pine', 'Birch', 'Maple', 'Cedar', 'Willow'];
    return types[math.Random().nextInt(types.length)];
  }

  String _getGrowthStage(int duration) {
    if (duration >= 60) return 'Mature';
    if (duration >= 45) return 'Growing';
    if (duration >= 25) return 'Young';
    return 'Seedling';
  }

  Color _getTreeColor(String stage) {
    switch (stage) {
      case 'Mature':
        return Colors.green.shade800;
      case 'Growing':
        return Colors.green.shade600;
      case 'Young':
        return Colors.green.shade400;
      default:
        return Colors.green.shade200;
    }
  }

  IconData _getTreeIcon(String stage) {
    switch (stage) {
      case 'Mature':
        return Icons.park;
      case 'Growing':
        return Icons.nature;
      case 'Young':
        return Icons.eco;
      default:
        return Icons.grass;
    }
  }

  IconData _getWeatherIcon(String weather) {
    switch (weather.toLowerCase()) {
      case 'clear':
        return _timeOfDay == 'night' ? Icons.nightlight : Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.grain;
      case 'snow':
        return Icons.ac_unit;
      case 'thunderstorm':
        return Icons.flash_on;
      default:
        return Icons.wb_sunny;
    }
  }

  Widget _buildMyForestTab() {
    return _showGlobalImpact ? _buildGlobalImpactView() : 
           _showWeatherDetails ? _buildWeatherDetailsView() : SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Full screen forest with weather and animations
          AnimatedBuilder(
            animation: Listenable.merge([_cloudAnimationController, _birdAnimationController, _windAnimationController]),
            builder: (context, child) {
              // Only update time of day, don't trigger weather updates here
              _updateTimeOfDay();
              return CustomPaint(
                painter: ForestPainter(
                  _userTrees, 
                  _weatherData, 
                  _timeOfDay, 
                  _cloudAnimationController, 
                  _birdAnimationController,
                  _windAnimationController
                ),
                size: Size.infinite,
                child: Container(),
              );
            },
          ),
          
          // Back button in top-left
          Positioned(
            top: 50,
            left: 20,
            child: FloatingActionButton(
              heroTag: "back",
              onPressed: () {
                Navigator.pop(context);
              },
              backgroundColor: Colors.black.withOpacity(0.7),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
            ),
          ),
          
          // Bottom action buttons row - now with more spacing between fewer buttons
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Weather button
                FloatingActionButton(
                  heroTag: "weather",
                  onPressed: () {
                    setState(() {
                      _showWeatherDetails = true;
                    });
                  },
                  backgroundColor: Colors.blue.shade600,
                  child: Icon(
                    _weatherData != null 
                        ? _getWeatherIcon(_weatherData!['weather'][0]['main'])
                        : Icons.wb_sunny,
                    color: Colors.white,
                  ),
                ),
                
                // Global impact button
                FloatingActionButton(
                  heroTag: "globalImpact",
                  onPressed: () {
                    setState(() {
                      _showGlobalImpact = !_showGlobalImpact;
                    });
                  },
                  backgroundColor: Colors.green.shade600,
                  child: const Icon(
                    Icons.public,
                    color: Colors.white,
                  ),
                ),
                
                // Stats button
                if (_userTrees.isNotEmpty)
                  FloatingActionButton(
                    heroTag: "stats",
                    onPressed: () {
                      _showForestStats();
                    },
                    backgroundColor: Colors.orange.shade600,
                    child: const Icon(
                      Icons.analytics,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailsView() {
    return WillPopScope(
      onWillPop: () async {
        setState(() {
          _showWeatherDetails = false;
        });
        return false;
      },
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/$_currentBackground',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay with blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
          // Weather content
          SafeArea(
            child: Column(
              children: [
                // Compact header with back button
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _adaptiveCardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _showWeatherDetails = false;
                            });
                          },
                          icon: Icon(Icons.arrow_back, color: _adaptiveIconColor),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weather',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                ],
                              ),
                            ),
                            if (_userData != null && _userData!['profile'] != null && _userData!['profile']['city'] != null)
                              Text(
                                '${_userData!['profile']['city']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Weather content with animations
                if (_weatherData != null)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          // Main weather card with floating animation
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 800),
                            transform: Matrix4.translationValues(
                              0,
                              math.sin(_cloudAnimationController.value * math.pi * 2) * 3,
                              0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _adaptiveCardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 1000),
                                        transform: Matrix4.rotationZ(
                                          _windAnimationController.value * math.pi * 0.1,
                                        ),
                                        child: Icon(
                                          _getWeatherIcon(_weatherData!['weather'][0]['main']),
                                          size: 80,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              offset: const Offset(0, 2),
                                              blurRadius: 8,
                                              color: Colors.black.withOpacity(0.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 500),
                                            style: TextStyle(
                                              fontSize: 50,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 4,
                                                  color: Colors.black.withOpacity(0.3),
                                                ),
                                              ],
                                            ),
                                            child: Text('${_weatherData!['main']['temp'].round()}°C'),
                                          ),
                                          Text(
                                            _weatherData!['weather'][0]['description']
                                                .toString()
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white.withOpacity(0.9),
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.location_on, 
                                           color: Colors.white.withOpacity(0.9), 
                                           size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        _weatherData!['name'] ?? 'Unknown Location',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Details grid with staggered animation - more compact 3x2 layout
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            childAspectRatio: 1.1,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              _buildCompactWeatherCard(
                                'Feels Like',
                                '${_weatherData!['main']['feels_like'].round()}°',
                                Icons.thermostat,
                              ),
                              _buildCompactWeatherCard(
                                'Humidity',
                                '${_weatherData!['main']['humidity']}%',
                                Icons.water_drop,
                              ),
                              _buildCompactWeatherCard(
                                'Wind',
                                '${(_weatherData!['wind']?['speed'] ?? 0).toStringAsFixed(1)}m/s',
                                Icons.air,
                              ),
                              _buildCompactWeatherCard(
                                'Pressure',
                                '${_weatherData!['main']['pressure']}',
                                Icons.compress,
                              ),
                              _buildCompactWeatherCard(
                                'Visibility',
                                '${((_weatherData!['visibility'] ?? 10000) / 1000).toStringAsFixed(1)}km',
                                Icons.visibility,
                              ),
                              _buildCompactWeatherCard(
                                'UV Index',
                                _getUVIndex(),
                                Icons.wb_sunny,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Forest conditions card
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 1000),
                            transform: Matrix4.translationValues(
                              0,
                              math.sin(_windAnimationController.value * math.pi * 2 + 1) * 2,
                              0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _adaptiveCardColor.withOpacity(_adaptiveCardColor.opacity * 1.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 800),
                                        transform: Matrix4.rotationZ(
                                          _windAnimationController.value * math.pi * 0.05,
                                        ),
                                        child: const Icon(
                                          Icons.park, 
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Forest Conditions',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _getWindEffectDescription(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white.withOpacity(0.9),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactWeatherCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _adaptiveCardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon, 
            color: _adaptiveIconColor, 
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalImpactView() {
    return WillPopScope(
      onWillPop: () async {
        setState(() {
          _showGlobalImpact = false;
        });
        return false;
      },
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/$_currentBackground',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay with blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
          // Global impact content
          SafeArea(
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _adaptiveCardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _showGlobalImpact = false;
                            });
                          },
                          icon: Icon(Icons.arrow_back, color: _adaptiveIconColor),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Global Impact',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Rest of global impact content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Global Impact Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _adaptiveCardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.public, color: Colors.white, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'Community Statistics',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildGlobalStat(
                                    'Trees Planted',
                                    '12,547',
                                    Icons.forest,
                                  ),
                                  _buildGlobalStat(
                                    'CO₂ Absorbed',
                                    '856 kg',
                                    Icons.air,
                                  ),
                                  _buildGlobalStat(
                                    'Active Users',
                                    '3,421',
                                    Icons.people,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Environmental Benefits
                        const Text(
                          'Environmental Benefits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        _buildGlobalBenefitCard(
                          'Air Purification',
                          'Trees help clean the air by absorbing pollutants and producing oxygen.',
                          Icons.air,
                        ),
                        
                        _buildGlobalBenefitCard(
                          'Climate Change',
                          'Trees absorb CO₂, helping to reduce greenhouse gases in the atmosphere.',
                          Icons.thermostat,
                        ),
                        
                        _buildGlobalBenefitCard(
                          'Biodiversity',
                          'Forests provide homes for countless species and support ecosystem health.',
                          Icons.pets,
                        ),
                        
                        _buildGlobalBenefitCard(
                          'Soil Conservation',
                          'Tree roots prevent soil erosion and help maintain healthy soil.',
                          Icons.landscape,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGlobalBenefitCard(String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _adaptiveCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _adaptiveIconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateForestAge() {
    if (_userTrees.isEmpty) return 0;
    
    // Find the oldest tree based on actual planted date
    final oldestTree = _userTrees.reduce((a, b) {
      final aDate = a['plantedDate'] ?? DateTime.now().millisecondsSinceEpoch;
      final bDate = b['plantedDate'] ?? DateTime.now().millisecondsSinceEpoch;
      return aDate < bDate ? a : b;
    });
    
    final plantedTimestamp = oldestTree['plantedDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final plantedDate = DateTime.fromMillisecondsSinceEpoch(plantedTimestamp);
    
    // Use DateTime.difference to get exact days without fractional parts
    final now = DateTime.now();
    final plantedDay = DateTime(plantedDate.year, plantedDate.month, plantedDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final exactDays = today.difference(plantedDay).inDays;
    
    // Return at least 1 day if trees exist, even if planted today
    return exactDays > 0 ? exactDays : 1;
  }

  int _getUniqueTreeTypes() {
    return _userTrees.map((tree) => tree['type']).toSet().length;
  }

  String _getUVIndex() {
    final hour = DateTime.now().hour;
    if (hour >= 10 && hour <= 16) {
      return 'High';
    } else if (hour >= 8 && hour <= 18) {
      return 'Moderate';
    } else {
      return 'Low';
    }
  }

  String _getWindEffectDescription() {
    final windSpeed = _weatherData?['wind']?['speed'] ?? 0;
    if (windSpeed < 2) {
      return '🍃 Calm conditions - Trees are still and peaceful';
    } else if (windSpeed < 5) {
      return '🌿 Light breeze - Trees gently sway in the wind';
    } else if (windSpeed < 10) {
      return '🌬️ Moderate wind - Trees are swaying noticeably';
    } else {
      return '💨 Strong wind - Trees are bending and moving vigorously';
    }
  }

  // Load the background image from shared preferences
  Future<void> _loadCurrentBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final background = prefs.getString('selected_background') ?? 'bg.jpg';
      if (mounted) {
        setState(() {
          _currentBackground = background;
        });
        
        // Analyze the background colors after setting it
        await _analyzeBackgroundColors(background);
      }
    } catch (e) {
      print('Error loading background: $e');
    }
  }
  
  // Analyze background colors to match home page style
  Future<void> _analyzeBackgroundColors(String backgroundName) async {
    try {
      // Load the image
      final ByteData data = await rootBundle.load('assets/images/$backgroundName');
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
        
        print('Color analysis: White: ${colorAnalysis['whitePercentage']}%, Green: ${colorAnalysis['greenPercentage']}%, Bright: ${colorAnalysis['brightPercentage']}%');
        
        if (mounted) {
          setState(() {
            _adaptiveCardColor = newCardColor;
            _adaptiveIconColor = newIconColor;
          });
        }
      }
    } catch (e) {
      print('Error analyzing background colors: $e');
      // Set fallback colors
      if (mounted) {
        setState(() {
          _adaptiveCardColor = Colors.white.withOpacity(0.15);
          _adaptiveIconColor = Colors.white.withOpacity(0.7);
        });
      }
    }
  }

  Map<String, double> _analyzeImageColors(ByteData pixelData) {
    int whitePixels = 0;
    int greenPixels = 0;
    int brightPixels = 0;
    int totalPixels = 0;
    
    // Sample pixels for efficiency
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
        
        // Check for white/light pixels
        if (brightness > 200 && (r - g).abs() < 30 && (g - b).abs() < 30 && (r - b).abs() < 30) {
          whitePixels++;
        }
        
        // Check for green pixels
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
    };
  }

  Color _determineCardColorFromAnalysis(Map<String, double> analysis) {
    final whitePercentage = analysis['whitePercentage'] ?? 0;
    final greenPercentage = analysis['greenPercentage'] ?? 0;
    final brightPercentage = analysis['brightPercentage'] ?? 0;
    
    if (brightPercentage > 40 || whitePercentage > 25) {
      return Colors.white.withOpacity(0.25);
    } else if (greenPercentage > 15) {
      return Colors.green.withOpacity(0.2);
    } else if (brightPercentage > 20) {
      return Colors.white.withOpacity(0.18);
    } else {
      return Colors.green.withOpacity(0.12);
    }
  }

  Color _determineIconColorFromAnalysis(Map<String, double> analysis) {
    final brightPercentage = analysis['brightPercentage'] ?? 0;
    
    if (brightPercentage > 30) {
      return Colors.white.withOpacity(0.9);
    } else {
      return Colors.white.withOpacity(0.75);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.lightBlue.shade100,
                    Colors.green.shade50,
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            )
          : _buildMyForestTab(),
    );
  }
}

class ForestPainter extends CustomPainter {
  final List<Map<String, dynamic>> trees;
  final Map<String, dynamic>? weatherData;
  final String timeOfDay;
  final Animation<double> cloudAnimation;
  final Animation<double> birdAnimation;
  final Animation<double> windAnimation;
  final math.Random _random = math.Random(42);

  ForestPainter(
    this.trees, 
    this.weatherData, 
    this.timeOfDay, 
    this.cloudAnimation, 
    this.birdAnimation,
    this.windAnimation
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Remove the debug print that was causing constant logging
    // print('Painting forest with ${trees.length} user trees, weather: ${weatherData?['weather']?[0]?['main']}');
    
    // Draw dynamic sky based on time and weather
    _drawDynamicSky(canvas, size);
    
    // Draw ground with weather effects
    _drawGround(canvas, size);
    
    // Draw trees with wind effects
    if (trees.isNotEmpty) {
      _drawForestRows(canvas, size, trees);
    }
    
    // Draw weather-appropriate celestial bodies
    _drawCelestialBodies(canvas, size);
    
    // Draw animated clouds
    _drawAnimatedClouds(canvas, size);
    
    // Draw animated birds
    _drawAnimatedBirds(canvas, size);
    
    // Draw weather effects
    _drawWeatherEffects(canvas, size);
  }

  void _drawDynamicSky(Canvas canvas, Size size) {
    final weather = weatherData?['weather']?[0]?['main']?.toLowerCase() ?? 'clear';
    
    List<Color> skyColors;
    List<double> stops = [0.0, 0.3, 0.6, 1.0];
    
    switch (timeOfDay) {
      case 'night':
        skyColors = [
          const Color(0xFF0B1426), // Dark blue
          const Color(0xFF1B2A4E), // Navy
          const Color(0xFF2C3E6B), // Darker blue
          const Color(0xFF2F4F4F), // Dark slate gray
        ];
        break;
      case 'evening':
        skyColors = [
          const Color(0xFFFF6B35), // Orange
          const Color(0xFFFF8E53), // Light orange
          const Color(0xFF4ECDC4), // Teal
          const Color(0xFF45B7D1), // Light blue
        ];
        break;
      default: // day
        if (weather.contains('rain') || weather.contains('storm')) {
          skyColors = [
            const Color(0xFF6C7B7F), // Gray
            const Color(0xFF85929E), // Light gray
            const Color(0xFF99A3A4), // Lighter gray
            const Color(0xFFABB2B9), // Very light gray
          ];
        } else if (weather.contains('cloud')) {
          skyColors = [
            const Color(0xFF87CEEB), // Sky blue
            const Color(0xFFB0C4DE), // Light steel blue
            const Color(0xFFF0F8FF), // Alice blue
            const Color(0xFFE6F3E6), // Light green
          ];
        } else {
          skyColors = [
            const Color(0xFF87CEEB), // Sky blue
            const Color(0xFFB0E0E6), // Powder blue
            const Color(0xFFF0F8FF), // Alice blue
            const Color(0xFFE6F3E6), // Light green
          ];
        }
    }
    
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: skyColors,
      stops: stops,
    );
    
    final skyPaint = Paint()
      ..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);
  }

  void _drawCelestialBodies(Canvas canvas, Size size) {
    if (timeOfDay == 'night') {
      _drawMoon(canvas, size);
      _drawStars(canvas, size);
    } else {
      _drawSun(canvas, size);
    }
  }

  void _drawMoon(Canvas canvas, Size size) {
    final moonCenter = Offset(size.width * 0.85, size.height * 0.15);
    const moonRadius = 20.0;
    
    // Moon body
    final moonPaint = Paint()
      ..color = const Color(0xFFF5F5DC); // Beige
    
    canvas.drawCircle(moonCenter, moonRadius, moonPaint);
    
    // Moon craters
    final craterPaint = Paint()
      ..color = const Color(0xFFD3D3D3).withOpacity(0.3);
    
    canvas.drawCircle(
      Offset(moonCenter.dx - 5, moonCenter.dy - 3),
      3,
      craterPaint,
    );
    canvas.drawCircle(
      Offset(moonCenter.dx + 4, moonCenter.dy + 2),
      2,
      craterPaint,
    );
  }

  void _drawStars(Canvas canvas, Size size) {
    final starPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    
    // Draw random stars
    for (int i = 0; i < 20; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height * 0.4;
      
      // Simple star shape
      canvas.drawCircle(Offset(x, y), 1, starPaint);
    }
  }

  void _drawSun(Canvas canvas, Size size) {
    final sunCenter = Offset(size.width * 0.85, size.height * 0.15);
    const sunRadius = 25.0;
    
    // Sun visibility based on weather
    final weather = weatherData?['weather']?[0]?['main']?.toLowerCase() ?? 'clear';
    double opacity = weather.contains('cloud') ? 0.6 : 1.0;
    if (weather.contains('rain') || weather.contains('storm')) opacity = 0.3;
    
    // Sun rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(opacity * 0.6)
      ..strokeWidth = 2;
    
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2) / 8;
      final startX = sunCenter.dx + math.cos(angle) * (sunRadius + 5);
      final startY = sunCenter.dy + math.sin(angle) * (sunRadius + 5);
      final endX = sunCenter.dx + math.cos(angle) * (sunRadius + 15);
      final endY = sunCenter.dy + math.sin(angle) * (sunRadius + 15);
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        rayPaint,
      );
    }
    
    // Sun body
    final sunPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(opacity);
    
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);
    
    // Sun highlight
    canvas.drawCircle(
      Offset(sunCenter.dx - 8, sunCenter.dy - 8),
      8,
      Paint()..color = const Color(0x00ffffff).withOpacity(opacity * 0.4),
    );
  }

  void _drawAnimatedClouds(Canvas canvas, Size size) {
    final weather = weatherData?['weather']?[0]?['main']?.toLowerCase() ?? 'clear';
    
    // More clouds in cloudy/rainy weather
    int cloudCount = 3;
    if (weather.contains('cloud')) cloudCount = 5;
    if (weather.contains('rain') || weather.contains('storm')) cloudCount = 7;
    
    double opacity = timeOfDay == 'night' ? 0.3 : 0.8;
    if (weather.contains('storm')) opacity = 0.6;
    
    final cloudPaint = Paint()
      ..color = Colors.white.withOpacity(opacity);
    
    final animationOffset = cloudAnimation.value * size.width * 0.2;
    
    for (int i = 0; i < cloudCount; i++) {
      final baseX = (size.width * (0.1 + i * 0.15)) + animationOffset;
      final x = baseX % (size.width + 100) - 50; // Wrap around
      final y = size.height * (0.1 + i * 0.04);
      final radius = 25 + (i % 3) * 10;
      
      _drawDetailedCloud(canvas, Offset(x, y), radius.toDouble(), cloudPaint);
    }
  }

  void _drawAnimatedBirds(Canvas canvas, Size size) {
    // Fewer birds at night or in bad weather
    final weather = weatherData?['weather']?[0]?['main']?.toLowerCase() ?? 'clear';
    
    if (timeOfDay == 'night') return; // No birds at night
    
    int birdCount = 3;
    if (weather.contains('rain') || weather.contains('storm')) birdCount = 1;
    
    final birdPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final animationOffset = birdAnimation.value * size.width * 0.3;
    
    for (int i = 0; i < birdCount; i++) {
      final baseX = (size.width * (0.2 + i * 0.25)) + animationOffset;
      final x = baseX % (size.width + 50) - 25; // Wrap around
      final y = size.height * (0.15 + i * 0.03);
      
      // Simple bird shape (V) with wing flapping
      final flapOffset = math.sin(birdAnimation.value * math.pi * 4) * 2;
      
      final path = Path();
      path.moveTo(x - 8, y + flapOffset);
      path.lineTo(x, y - 4);
      path.lineTo(x + 8, y + flapOffset);
      
      canvas.drawPath(path, birdPaint);
    }
  }

  void _drawWeatherEffects(Canvas canvas, Size size) {
    final weather = weatherData?['weather']?[0]?['main']?.toLowerCase() ?? 'clear';
    
    if (weather.contains('rain')) {
      _drawRain(canvas, size);
    } else if (weather.contains('snow')) {
      _drawSnow(canvas, size);
    } else if (weather.contains('storm')) {
      _drawLightning(canvas, size);
    }
  }

  void _drawRain(Canvas canvas, Size size) {
    final rainPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 1;
    
    for (int i = 0; i < 100; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2, y + 10),
        rainPaint,
      );
    }
  }

  void _drawSnow(Canvas canvas, Size size) {
    final snowPaint = Paint()
      ..color = Colors.white.withOpacity(0.8);
    
    for (int i = 0; i < 50; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      
      canvas.drawCircle(Offset(x, y), 2, snowPaint);
    }
  }

  void _drawLightning(Canvas canvas, Size size) {
    // Occasional lightning flash
    if (_random.nextDouble() < 0.1) {
      final lightningPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.8)
        ..strokeWidth = 3;
      
      final startX = size.width * 0.3 + _random.nextDouble() * size.width * 0.4;
      final path = Path();
      path.moveTo(startX, 0);
      path.lineTo(startX - 10, size.height * 0.2);
      path.lineTo(startX + 5, size.height * 0.4);
      path.lineTo(startX - 15, size.height * 0.6);
      
      canvas.drawPath(path, lightningPaint);
    }
  }

  double _getTreeScale(String stage) {
    switch (stage) {
      case 'Mature':
        return 1.0;
      case 'Growing':
        return 0.7;
      case 'Young':
        return 0.5;
      default:
        return 0.3;
    }
  }

  void _drawGround(Canvas canvas, Size size) {
    // Base ground
    const groundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF8FBC8F), // Dark sea green
        Color(0xFF90EE90), // Light green
        Color(0xFF9ACD32), // Yellow green
      ],
    );
    
    final groundPaint = Paint()
      ..shader = groundGradient.createShader(
        Rect.fromLTWH(0, size.height * 0.50, size.width, size.height * 0.50)
      );
    
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.50, size.width, size.height * 0.50),
      groundPaint,
    );
    
    // Add grass texture
    final grassPaint = Paint()
      ..color = const Color(0xFF228B22)
      ..strokeWidth = 1.5;
    
    for (int i = 0; i < 60; i++) {
      final x = (i * size.width / 60) + _random.nextDouble() * 12;
      final grassHeight = 6 + _random.nextDouble() * 10;
      canvas.drawLine(
        Offset(x, size.height * 0.50 + 8),
        Offset(x + _random.nextDouble() * 3 - 1.5, size.height * 0.50 + 8 - grassHeight),
        grassPaint,
      );
    }
    
    // Add floating green particles on ground
    _drawFloatingParticles(canvas, size);
    
    // Add some bushes in the background
    _drawBushes(canvas, size);
  }

  void _drawFloatingParticles(Canvas canvas, Size size) {
    final particlePaint = Paint()
      ..color = const Color(0xFF90EE90).withOpacity(0.6);
    
    // Ground particles
    for (int i = 0; i < 15; i++) {
      final baseX = _random.nextDouble() * size.width;
      final baseY = size.height * (0.55 + _random.nextDouble() * 0.35);
      
      // Floating animation
      final floatOffset = math.sin(windAnimation.value * math.pi * 2 + i * 0.5) * 3;
      final x = baseX + floatOffset;
      final y = baseY + floatOffset * 0.5;
      
      canvas.drawCircle(Offset(x, y), 2 + _random.nextDouble() * 2, particlePaint);
    }
    
    // Air particles
    final airParticlePaint = Paint()
      ..color = const Color(0xFF98FB98).withOpacity(0.4);
    
    for (int i = 0; i < 20; i++) {
      final baseX = _random.nextDouble() * size.width;
      final baseY = _random.nextDouble() * size.height * 0.6;
      
      // Floating animation with different speed
      final floatOffset = math.sin(windAnimation.value * math.pi * 1.5 + i * 0.3) * 5;
      final x = baseX + floatOffset;
      final y = baseY + math.cos(windAnimation.value * math.pi * 2 + i * 0.4) * 3;
      
      canvas.drawCircle(Offset(x, y), 1.5 + _random.nextDouble() * 1.5, airParticlePaint);
    }
  }

  void _drawBushes(Canvas canvas, Size size) {
    final bushPaint = Paint()
      ..color = const Color(0xFF556B2F).withOpacity(0.7);
    
    // Draw small bushes in the background
    for (int i = 0; i < 8; i++) {
      final x = size.width * 0.1 + (i * size.width * 0.1) + _random.nextDouble() * 20;
      final y = size.height * (0.45 + _random.nextDouble() * 0.08);
      final radius = 8 + _random.nextDouble() * 6;
      
      canvas.drawCircle(Offset(x, y), radius, bushPaint);
    }
  }

  void _drawForestRows(Canvas canvas, Size size, List<Map<String, dynamic>> treesToDraw) {
    // Distribute trees across multiple rows for depth
    const int treesPerRow = 6;
    const int maxRows = 4;
    
    // Define ground level more precisely
    final groundLevel = size.height * 0.50;
    
    for (int row = 0; row < maxRows; row++) {
      final rowStartIndex = row * treesPerRow;
      final depthFactor = 1.0 - (row * 0.15); // Reduced depth scaling
      // Ensure trees are positioned ON the ground, not floating
      final yPosition = groundLevel - (row * 15 * depthFactor); // Trees closer to ground
      final alpha = math.max(0.5, 1.0 - row * 0.12); // Better visibility for distant trees
      
      for (int col = 0; col < treesPerRow; col++) {
        final treeIndex = rowStartIndex + col;
        if (treeIndex < treesToDraw.length) {
          final tree = treesToDraw[treeIndex];
          _drawTreeAtPosition(canvas, size, tree, row, col, depthFactor, yPosition, alpha);
        }
      }
    }
  }

  void _drawTreeAtPosition(Canvas canvas, Size size, Map<String, dynamic> tree, 
                          int row, int col, double depthFactor, double yPosition, double alpha) {
    // Calculate x position with better spacing
    final baseX = (size.width * 0.05) + (col * size.width * 0.15);
    final randomOffset = (_random.nextDouble() - 0.5) * 20; // Reduced random offset
    final x = baseX + randomOffset;
    
    // Minimal y variation to keep trees grounded
    final randomYOffset = (_random.nextDouble() - 0.5) * 5; // Much smaller variation
    final y = yPosition + randomYOffset;
    
    final scale = depthFactor * _getTreeScale(tree['growthStage']);
    
    // Calculate wind effect
    final windSpeed = weatherData?['wind']?['speed'] ?? 0;
    final windOffset = _calculateWindOffset(windSpeed, row, col);
    
    switch (tree['growthStage']) {
      case 'Seedling':
        _drawSeedling(canvas, x, y, scale, alpha, windOffset);
        break;
      case 'Young':
        _drawYoungTree(canvas, x, y, scale, alpha, windOffset);
        break;
      case 'Growing':
        _drawGrowingTree(canvas, x, y, scale, alpha, windOffset);
        break;
      case 'Mature':
        _drawMatureTree(canvas, x, y, scale, alpha, windOffset);
        break;
    }
  }

  double _calculateWindOffset(double windSpeed, int row, int col) {
    // Calculate wind sway based on wind speed and animation
    final windIntensity = math.min(windSpeed / 10, 1.0); // Normalize to 0-1
    final baseOffset = math.sin(windAnimation.value * math.pi * 2 + (row + col) * 0.5) * windIntensity;
    
    return baseOffset * 15; // Maximum 15 pixel sway
  }

  void _drawSeedling(Canvas canvas, double x, double y, double scale, double alpha, double windOffset) {
    final stemPaint = Paint()
      ..color = const Color(0xFF8B4513).withOpacity(alpha)
      ..strokeWidth = math.max(1, 2 * scale).toDouble();
    
    final leafPaint = Paint()
      ..color = const Color(0xFF90EE90).withOpacity(alpha);
    
    // Ensure stem starts exactly at ground level
    final stemHeight = 15 * scale;
    final stemTop = Offset(x + windOffset * 0.8, y - stemHeight);
    canvas.drawLine(
      Offset(x, y), // Base at ground level
      stemTop,
      stemPaint,
    );
    
    // Small leaves with wind movement
    final leafSize = math.max(2, 4 * scale).toDouble();
    canvas.drawCircle(Offset(stemTop.dx - leafSize, stemTop.dy + 2 * scale), leafSize, leafPaint);
    canvas.drawCircle(Offset(stemTop.dx + leafSize, stemTop.dy), leafSize, leafPaint);
  }

  void _drawYoungTree(Canvas canvas, double x, double y, double scale, double alpha, double windOffset) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF8B4513).withOpacity(alpha);
    
    final canopyPaint = Paint()
      ..color = const Color(0xFF32CD32).withOpacity(alpha);
    
    // Ensure trunk base is at ground level
    final trunkWidth = math.max(2, 4 * scale).toDouble();
    final trunkHeight = 30 * scale;
    
    // Create trunk path starting from ground
    final path = Path();
    path.moveTo(x - trunkWidth/2, y); // Base at ground
    path.quadraticBezierTo(
      x + windOffset * 0.3, y - trunkHeight/2,
      x + windOffset * 0.6 - trunkWidth/2, y - trunkHeight
    );
    path.lineTo(x + windOffset * 0.6 + trunkWidth/2, y - trunkHeight);
    path.quadraticBezierTo(
      x + windOffset * 0.3, y - trunkHeight/2,
      x + trunkWidth/2, y // Base at ground
    );
    path.close();
    
    canvas.drawPath(path, trunkPaint);
    
    // Triangular canopy with wind lean
    final canopyPath = Path();
    final canopyTop = Offset(x + windOffset, y - trunkHeight - 20 * scale);
    canopyPath.moveTo(canopyTop.dx, canopyTop.dy);
    canopyPath.lineTo(x + windOffset * 0.8 - 15 * scale, y - trunkHeight + 8 * scale);
    canopyPath.lineTo(x + windOffset * 0.8 + 15 * scale, y - trunkHeight + 8 * scale);
    canopyPath.close();
    
    canvas.drawPath(canopyPath, canopyPaint);
    
    // Add some leaves on the canopy with shimmer effect
    final leafPaint = Paint()
      ..color = const Color(0xFF228B22).withOpacity(alpha * 0.8);
    
    canvas.drawCircle(Offset(canopyTop.dx - 8 * scale, canopyTop.dy + 10 * scale), 5 * scale, leafPaint);
    canvas.drawCircle(Offset(canopyTop.dx + 8 * scale, canopyTop.dy + 12 * scale), 5 * scale, leafPaint);
  }

  void _drawGrowingTree(Canvas canvas, double x, double y, double scale, double alpha, double windOffset) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF654321).withOpacity(alpha);
    
    final canopyPaint = Paint()
      ..color = const Color(0xFF228B22).withOpacity(alpha);
    
    final shadowPaint = Paint()
      ..color = const Color(0xFF006400).withOpacity(alpha * 0.7);
    
    // Trunk base firmly at ground level
    final trunkWidth = math.max(3, 8 * scale).toDouble();
    final trunkHeight = 45 * scale;
    
    // Draw trunk starting from ground
    final trunkPath = Path();
    trunkPath.moveTo(x - trunkWidth/2, y); // Base at ground
    trunkPath.quadraticBezierTo(
      x + windOffset * 0.4, y - trunkHeight/2,
      x + windOffset * 0.7 - trunkWidth/2, y - trunkHeight
    );
    trunkPath.lineTo(x + windOffset * 0.7 + trunkWidth/2, y - trunkHeight);
    trunkPath.quadraticBezierTo(
      x + windOffset * 0.4, y - trunkHeight/2,
      x + trunkWidth/2, y // Base at ground
    );
    trunkPath.close();
    
    canvas.drawPath(trunkPath, trunkPaint);
    
    // Multi-layered canopy with wind movement
    final canopyRadius = 22 * scale;
    final canopyCenter = Offset(x + windOffset, y - trunkHeight - canopyRadius * 0.5);
    
    // Shadow layer
    canvas.drawCircle(
      Offset(canopyCenter.dx + 2 * scale, canopyCenter.dy + 2 * scale),
      canopyRadius,
      shadowPaint,
    );
    
    // Main canopy
    canvas.drawCircle(canopyCenter, canopyRadius, canopyPaint);
    
    // Highlight clusters with wind shimmer
    final shimmer = math.sin(windAnimation.value * math.pi * 4) * 0.1 + 0.9;
    canvas.drawCircle(
      Offset(canopyCenter.dx - canopyRadius * 0.4, canopyCenter.dy - canopyRadius * 0.3),
      canopyRadius * 0.4,
      Paint()..color = const Color(0xFF90EE90).withOpacity(alpha * 0.8 * shimmer),
    );
    
    canvas.drawCircle(
      Offset(canopyCenter.dx + canopyRadius * 0.3, canopyCenter.dy - canopyRadius * 0.2),
      canopyRadius * 0.3,
      Paint()..color = const Color(0xFF90EE90).withOpacity(alpha * 0.8 * shimmer),
    );
  }

  void _drawMatureTree(Canvas canvas, double x, double y, double scale, double alpha, double windOffset) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF654321).withOpacity(alpha);
    
    final canopyPaint = Paint()
      ..color = const Color(0xFF006400).withOpacity(alpha);
    
    final shadowPaint = Paint()
      ..color = const Color(0xFF004d00).withOpacity(alpha * 0.8);
    
    // Large trunk base firmly planted at ground
    final trunkWidth = math.max(5, 15 * scale).toDouble();
    final trunkHeight = 60 * scale;
    
    // Draw trunk starting from ground level
    final trunkPath = Path();
    trunkPath.moveTo(x - trunkWidth/2, y); // Base at ground
    trunkPath.quadraticBezierTo(
      x + windOffset * 0.2, y - trunkHeight/2,
      x + windOffset * 0.3 - trunkWidth/2, y - trunkHeight
    );
    trunkPath.lineTo(x + windOffset * 0.3 + trunkWidth/2, y - trunkHeight);
    trunkPath.quadraticBezierTo(
      x + windOffset * 0.2, y - trunkHeight/2,
      x + trunkWidth/2, y // Base at ground
    );
    trunkPath.close();
    
    canvas.drawPath(trunkPath, trunkPaint);
    
    // Add trunk texture
    final texturePaint = Paint()
      ..color = const Color(0xFF8B4513).withOpacity(alpha * 0.6)
      ..strokeWidth = math.max(1, 1.5 * scale).toDouble();
    
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(x - trunkWidth/2 + 2, y - trunkHeight + i * 12 * scale),
        Offset(x + windOffset * 0.1 - trunkWidth/2 + 2, y - trunkHeight + i * 12 * scale + 8 * scale),
        texturePaint,
      );
    }
    
    // Large canopy positioned above trunk
    final mainRadius = 35 * scale;
    final canopyCenter = Offset(x + windOffset * 0.5, y - trunkHeight - mainRadius * 0.3);
    
    // Shadow
    canvas.drawCircle(
      Offset(canopyCenter.dx + 3 * scale, canopyCenter.dy + 3 * scale),
      mainRadius,
      shadowPaint,
    );
    
    // Main canopy
    canvas.drawCircle(canopyCenter, mainRadius, canopyPaint);
    
    // Secondary canopy clusters
    final windShimmer = math.sin(windAnimation.value * math.pi * 3) * 0.05 + 0.95;
    canvas.drawCircle(
      Offset(canopyCenter.dx - mainRadius * 0.6, canopyCenter.dy + mainRadius * 0.2),
      mainRadius * 0.7,
      Paint()..color = const Color(0xFF228B22).withOpacity(alpha * 0.9 * windShimmer),
    );
    
    canvas.drawCircle(
      Offset(canopyCenter.dx + mainRadius * 0.6, canopyCenter.dy + mainRadius * 0.2),
      mainRadius * 0.7,
      Paint()..color = const Color(0xFF228B22).withOpacity(alpha * 0.9 * windShimmer),
    );
    
    // Highlight clusters for depth
    final sparkle = math.sin(windAnimation.value * math.pi * 6 + x) * 0.1 + 0.9;
    canvas.drawCircle(
      Offset(canopyCenter.dx - mainRadius * 0.4, canopyCenter.dy - mainRadius * 0.4),
      mainRadius * 0.3,
      Paint()..color = const Color(0xFF32CD32).withOpacity(alpha * 0.7 * sparkle),
    );
    
    canvas.drawCircle(
      Offset(canopyCenter.dx + mainRadius * 0.3, canopyCenter.dy - mainRadius * 0.5),
      mainRadius * 0.25,
      Paint()..color = const Color(0xFF32CD32).withOpacity(alpha * 0.7 * sparkle),
    );
    
    canvas.drawCircle(
      Offset(canopyCenter.dx, canopyCenter.dy - mainRadius * 0.6),
      mainRadius * 0.2,
      Paint()..color = const Color(0xFF90EE90).withOpacity(alpha * 0.6 * sparkle),
    );
  }

  void _drawDetailedCloud(Canvas canvas, Offset center, double radius, Paint paint) {
    // Main cloud body
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(Offset(center.dx - radius * 0.6, center.dy), radius * 0.8, paint);
    canvas.drawCircle(Offset(center.dx + radius * 0.6, center.dy), radius * 0.8, paint);
    canvas.drawCircle(Offset(center.dx, center.dy - radius * 0.4), radius * 0.6, paint);
    canvas.drawCircle(Offset(center.dx - radius * 0.3, center.dy - radius * 0.2), radius * 0.5, paint);
    canvas.drawCircle(Offset(center.dx + radius * 0.3, center.dy - radius * 0.2), radius * 0.5, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true; // Changed to true for wind animation
}
