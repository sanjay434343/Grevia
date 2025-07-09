import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _dailySummaries;
  Map<String, dynamic>? _dailySessions;
  Map<String, dynamic>? _focusStats;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _currentTreeGrowth;
  List<Map<String, dynamic>> _recentSessions = [];
  bool _isLoading = true;
  
  // Background and color variables
  String _currentWallpaper = 'bg.jpg';
  Color _adaptiveCardColor = Colors.white.withOpacity(0.15);
  Color _adaptiveTextColor = Colors.white;
  Color _adaptiveHighlightColor = Colors.green.shade400;

  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  
  @override
  void initState() {
    super.initState();
    _loadUserStats();
    _loadCurrentWallpaper();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
  
  // Pull to refresh functionality
  void _onRefresh() async {
    await _loadUserStats();
    _refreshController.refreshCompleted();
  }

  Future<void> _loadCurrentWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wallpaper = prefs.getString('selected_background') ?? 'bg.jpg';
      
      if (mounted) {
        setState(() {
          _currentWallpaper = wallpaper;
        });
        
        // Apply colors immediately based on wallpaper name
        _applyWallpaperColors(wallpaper);
      }
    } catch (e) {
      debugPrint('Error loading wallpaper: $e');
    }
  }
  
  // Direct color application without async extraction
  void _applyWallpaperColors(String wallpaperName) {
    // Improved color adaptation based on wallpaper name
    if (wallpaperName.contains('dark') || wallpaperName == 'bg.jpg') {
      // Dark backgrounds get white cards with green accents
      setState(() {
        _adaptiveCardColor = Colors.white.withOpacity(0.15);
        _adaptiveHighlightColor = Colors.green.shade300;
        _adaptiveTextColor = Colors.white;
      });
      debugPrint('Applied dark theme colors for $wallpaperName');
    } 
    else if (wallpaperName.contains('green') || 
        wallpaperName.contains('forest') || 
        wallpaperName.contains('tree')) {
      // Green backgrounds get green-tinted cards
      setState(() {
        _adaptiveCardColor = Colors.green.withOpacity(0.15);
        _adaptiveHighlightColor = Colors.green.shade400;
        _adaptiveTextColor = Colors.white;
      });
      debugPrint('Applied green theme colors for $wallpaperName');
    }
    else if (wallpaperName.contains('white') || 
        wallpaperName.contains('light')) {
      // White/light backgrounds get white cards with stronger borders
      setState(() {
        _adaptiveCardColor = Colors.white.withOpacity(0.2);
        _adaptiveHighlightColor = Colors.green.shade600;
        _adaptiveTextColor = Colors.white;
      });
      debugPrint('Applied white/light theme colors for $wallpaperName');
    }
    else {
      // Default to white cards for any other case
      setState(() {
        _adaptiveCardColor = Colors.white.withOpacity(0.15);
        _adaptiveHighlightColor = Colors.green.shade500;
        _adaptiveTextColor = Colors.white;
      });
      debugPrint('Applied default theme colors for $wallpaperName');
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final userData = await _authService.getUserDataFromFirestore();
      
      // Parse data according to the structure
      if (userData != null) {
        // Safely cast maps using Map.from() to ensure proper Map<String, dynamic> conversion
        final dailySessions = userData['daily_sessions'] != null ? 
            Map<String, dynamic>.from(userData['daily_sessions']) : <String, dynamic>{};
        final dailySummaries = userData['daily_summaries'] != null ? 
            Map<String, dynamic>.from(userData['daily_summaries']) : <String, dynamic>{};
        final focusStats = userData['focusStats'] != null ? 
            Map<String, dynamic>.from(userData['focusStats']) : <String, dynamic>{};
        final profile = userData['profile'] != null ? 
            Map<String, dynamic>.from(userData['profile']) : <String, dynamic>{};
        final currentTreeGrowth = userData['currentTreeGrowth'] != null ? 
            Map<String, dynamic>.from(userData['currentTreeGrowth']) : <String, dynamic>{};
        
        // Process recent sessions from daily_sessions
        List<Map<String, dynamic>> sessions = [];
        
        if (dailySessions.isNotEmpty) {
          // For each date in daily_sessions
          dailySessions.forEach((date, dateItems) {
            if (dateItems is Map) {
              // Ensure proper casting of date items
              final dateItemsMap = Map<String, dynamic>.from(dateItems);
              // For each session in that date
              dateItemsMap.forEach((sessionId, sessionData) {
                if (sessionData is Map) {
                  // Cast each session to ensure it's Map<String, dynamic>
                  final Map<String, dynamic> session = Map<String, dynamic>.from(sessionData);
                  
                  // Add common fields needed for display
                  session['date'] = date;
                  session['sessionId'] = sessionId;
                  
                  // Add to sessions list
                  sessions.add(session);
                }
              });
            }
          });
        }
        
        // Sort by start_time (newest first)
        sessions.sort((a, b) {
          final aTime = a['start_time'] ?? '';
          final bTime = b['start_time'] ?? '';
          return bTime.compareTo(aTime);
        });
        
        if (mounted) {
          setState(() {
            _userData = Map<String, dynamic>.from(userData);
            _dailySessions = dailySessions;
            _dailySummaries = dailySummaries;
            _focusStats = focusStats;
            _profile = profile;
            _currentTreeGrowth = currentTreeGrowth;
            _recentSessions = sessions;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Stats loading error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOverviewTab() {
    if (_userData == null) {
      return Center(
        child: Text(
          'No data available', 
          style: TextStyle(color: _adaptiveTextColor)
        )
      );
    }
    
    final focusStats = _focusStats ?? {};
    final profile = _profile ?? {};
    
    // Calculate additional stats
    final int totalSessions = focusStats['totalSessions'] ?? 0;
    final int totalFocusTime = focusStats['totalFocusTime'] ?? 0; // in minutes
    final int treesPlanted = focusStats['treesPlanted'] ?? 0;
    final int treesCompleted = focusStats['treesCompleted'] ?? 0;
    
    // Level progression calculations
    final int currentLevel = profile['level'] ?? 1;
    final int treesToNextLevel = 5; // Trees needed per level
    final int treesCompleteThisLevel = (profile['treesCompleted'] ?? 0) % treesToNextLevel;
    final double levelProgress = treesCompleteThisLevel / treesToNextLevel;
    
    // Calculate completion rate and daily average
    final double completionRate = treesPlanted > 0 
        ? ((treesCompleted / treesPlanted) * 100).roundToDouble()
        : 0.0;
    
    // Calculate daily average focus time (assuming data from past 30 days)
    final int daysActive = _dailySummaries?.length ?? 1;
    final double dailyAverageMins = daysActive > 0
        ? (totalFocusTime / daysActive).roundToDouble()
        : 0.0;
    
    // Format total focus time for display
    final String formattedTotalTime = totalFocusTime >= 60
        ? '${(totalFocusTime / 60).floor()}h ${totalFocusTime % 60}m'
        : '$totalFocusTime mins';

    // Simple achievements based on user stats
    final achievements = [
      if (treesCompleted >= 1)
        {
          'title': 'First Tree',
          'description': 'Completed your first tree',
          'icon': Icons.park,
          'color': Colors.green,
          'earned': true,
        },
      if (totalSessions >= 5)
        {
          'title': 'Focus Enthusiast',
          'description': 'Completed 5 focus sessions',
          'icon': Icons.auto_awesome,
          'color': Colors.amber,
          'earned': totalSessions >= 5,
        },
      if (totalFocusTime >= 60)
        {
          'title': 'Dedicated Grower',
          'description': 'Accumulated 60 minutes of focus time',
          'icon': Icons.timer,
          'color': Colors.blue,
          'earned': totalFocusTime >= 60,
        },
    ];
    
    // Upcoming achievements
    final upcomingAchievements = [
      {
        'title': 'Focus Master',
        'description': 'Complete 10 focus sessions',
        'current': totalSessions,
        'target': 10,
        'icon': Icons.military_tech,
      },
      {
        'title': 'Green Thumb',
        'description': 'Grow 5 trees successfully',
        'current': treesCompleted,
        'target': 5,
        'icon': Icons.eco,
      },
      {
        'title': 'Time Wizard',
        'description': 'Accumulate 120 minutes of focus time',
        'current': totalFocusTime,
        'target': 120,
        'icon': Icons.hourglass_bottom,
      },
    ];
    
    return SmartRefresher(
      enablePullDown: true,
      header: const WaterDropHeader(
        waterDropColor: Colors.green,
        complete: Icon(Icons.check, color: Colors.green),
      ),
      controller: _refreshController,
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            // Level Card - Detailed version
            _buildTransparentCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _adaptiveHighlightColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$currentLevel',
                          style: TextStyle(
                            color: _adaptiveHighlightColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level $currentLevel Gardener',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _adaptiveTextColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep growing to unlock achievements',
                            style: TextStyle(
                              color: _adaptiveTextColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(
                        Icons.emoji_events,
                        color: Colors.amber.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level Progress',
                              style: TextStyle(
                                fontSize: 12,
                                color: _adaptiveTextColor.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: levelProgress,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(_adaptiveHighlightColor),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$treesCompleteThisLevel/$treesToNextLevel trees to level ${currentLevel + 1}',
                              style: TextStyle(
                                color: _adaptiveHighlightColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Stats Grid
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Focus Stats',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _adaptiveTextColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Sessions',
                  '$totalSessions',
                  Icons.play_circle_filled,
                  Colors.blue.shade300,
                ),
                _buildStatCard(
                  'Focus Time',
                  formattedTotalTime,
                  Icons.timer,
                  _adaptiveHighlightColor,
                ),
                _buildStatCard(
                  'Trees Planted',
                  '$treesPlanted',
                  Icons.park,
                  Colors.orange.shade300,
                  subtitle: '$completionRate% completed',
                ),
                _buildStatCard(
                  'Daily Average',
                  '$dailyAverageMins mins',
                  Icons.trending_up,
                  Colors.purple.shade300,
                  subtitle: '$daysActive days active',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Current Tree Growth (if active)
            if (_currentTreeGrowth != null && (_currentTreeGrowth?['hasActiveSession'] == true)) 
              _buildTransparentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_florist, color: _adaptiveHighlightColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Current Tree Growth',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _adaptiveTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTreeStageIcon(_currentTreeGrowth?['treeStage'] ?? 0),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (_currentTreeGrowth?['completedMinutes'] ?? 0) / 
                                        (_currentTreeGrowth?['totalMinutes'] ?? 1),
                                  backgroundColor: Colors.white.withOpacity(0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(_adaptiveHighlightColor),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_currentTreeGrowth?['completedMinutes'] ?? 0}/${_currentTreeGrowth?['totalMinutes'] ?? 0} minutes',
                                    style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7)),
                                  ),
                                  Text(
                                    '${((_currentTreeGrowth?['completedMinutes'] ?? 0) / (_currentTreeGrowth?['totalMinutes'] ?? 1) * 100).round()}% complete',
                                    style: TextStyle(
                                      color: _adaptiveHighlightColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Weekly Progress
            _buildTransparentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bar_chart, color: _adaptiveHighlightColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'This Week\'s Focus Time',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _adaptiveTextColor,
                            ),
                          ),
                        ],
                      ),
                      _buildWeeklyTotal(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildEnhancedWeeklyChart(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Achievements Section
            _buildTransparentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: _adaptiveHighlightColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Your Achievements',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _adaptiveTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (achievements.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 48,
                            color: _adaptiveTextColor.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete focus sessions to earn achievements',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...achievements.map((achievement) => _buildAchievementCard(achievement)),
                  
                  if (achievements.isNotEmpty && upcomingAchievements.any((a) => (a['current'] as int) < (a['target'] as int))) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Upcoming Achievements',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _adaptiveTextColor.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...upcomingAchievements
                        .where((a) => (a['current'] as int) < (a['target'] as int))
                        .take(3) // Show only top 3 upcoming
                        .map((a) => _buildUpcomingAchievement(
                              a['title'].toString(),
                              a['description'].toString(),
                              a['current'] as int,
                              a['target'] as int,
                              icon: a['icon'] as IconData,
                            )),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Daily Summary History
            _buildTransparentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: _adaptiveHighlightColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Daily Focus Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _adaptiveTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_dailySummaries != null && _dailySummaries!.isNotEmpty)
                    _buildDailySummariesList()
                  else
                    Center(
                      child: Text(
                        'No daily summaries available yet',
                        style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7)),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Recent Sessions History
            _buildTransparentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: _adaptiveHighlightColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Recent Sessions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _adaptiveTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_recentSessions.isEmpty)
                    Center(
                      child: Text(
                        'No sessions recorded yet',
                        style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7)),
                      ),
                    )
                  else
                    ..._recentSessions.take(5).map((session) => _buildSessionTile(session)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Get weekly total minutes - Fixed calculation
  Widget _buildWeeklyTotal() {
    final today = DateTime.now();
    int totalWeeklyMinutes = 0;
    
    // Sum up all minutes in the current week - Fix to use proper week calculation
    if (_dailySummaries != null) {
      _dailySummaries!.forEach((dateStr, summary) {
        try {
          final date = DateTime.parse(dateStr);
          
          // Check if date is from current week (within the last 7 days)
          final difference = today.difference(date).inDays;
          if (difference >= 0 && difference < 7) {
            if (summary is Map) {
              final int seconds = summary['total_focus_time_seconds'] ?? 0;
              totalWeeklyMinutes += (seconds / 60).round();
            }
          }
        } catch (e) {
          // Skip invalid dates
        }
      });
    }
    
    // Format weekly time
    final String weeklyTimeText = totalWeeklyMinutes >= 60
        ? '${(totalWeeklyMinutes / 60).floor()}h ${totalWeeklyMinutes % 60}m'
        : '${totalWeeklyMinutes}min';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _adaptiveHighlightColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        weeklyTimeText,
        style: TextStyle(
          color: _adaptiveHighlightColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildEnhancedWeeklyChart() {
    // Generate dates for the past week
    final today = DateTime.now();
    final weekdays = <String>[];
    final sessionCounts = <int>[];
    final percentages = <int>[];
    
    // Create a map to hold daily summary data
    Map<String, int> dailyFocusMinutes = {};
    
    // Debug log daily summaries to identify the issue
    debugPrint('Daily summaries available: ${_dailySummaries?.keys.toList()}');
    
    if (_dailySummaries != null) {
      _dailySummaries!.forEach((dateStr, summary) {
        if (summary is Map) {
          final totalFocusSeconds = summary['total_focus_time_seconds'] ?? 0;
          final focusMinutes = (totalFocusSeconds / 60).round();
          dailyFocusMinutes[dateStr] = focusMinutes;
          debugPrint('Date: $dateStr, seconds: $totalFocusSeconds, minutes: $focusMinutes');
        }
      });
    }
    
    // Build weekly data for the past 7 days
    int maxValue = 0;
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final weekday = DateFormat('E').format(date).substring(0, 1); // First letter only
      
      final value = dailyFocusMinutes[dateStr] ?? 0;
      debugPrint('Chart - Date: $dateStr ($weekday), Value: $value minutes');
      maxValue = value > maxValue ? value : maxValue;
      
      weekdays.add(weekday);
      sessionCounts.add(value);
    }
    
    // Set minimum scale to avoid tiny bars (30 minutes minimum scale)
    maxValue = maxValue < 30 ? 30 : maxValue;
    
    // Calculate percentages for labels
    for (final count in sessionCounts) {
      percentages.add(count > 0 ? ((count / maxValue) * 100).round() : 0);
    }
    
    // Log the collected data
    debugPrint('Week days: $weekdays');
    debugPrint('Session counts (minutes): $sessionCounts');
    debugPrint('Max value: $maxValue minutes');
    debugPrint('Percentages: $percentages');
    
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          weekdays.length,
          (index) {
            final value = sessionCounts[index];
            final percent = percentages[index];
            // Normalize height between 0.05 and 1.0
            final height = value > 0 ? 0.05 + (value / maxValue * 0.95) : 0.05;
            
            // Determine if this is today
            final isToday = index == (weekdays.length - 1);
            final barColor = isToday 
                ? _adaptiveHighlightColor
                : value > 0 
                    ? _adaptiveHighlightColor.withOpacity(0.8)
                    : _adaptiveHighlightColor.withOpacity(0.2);
            
            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Value label - show minutes if > 0
                  if (value > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: barColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${value}m',
                        style: TextStyle(
                          fontSize: 9,
                          color: _adaptiveTextColor,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 18), // Placeholder for spacing
                  
                  // Bar with gradient
                  Container(
                    height: 130 * height,
                    width: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          barColor,
                          barColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // Show percentage for bars with values
                    child: value > 0 && percent > 10 ? Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          '$percent%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ) : null,
                  ),
                  const SizedBox(height: 8),
                  
                  // Day label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isToday ? barColor.withOpacity(0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      weekdays[index],
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday ? _adaptiveHighlightColor : _adaptiveTextColor,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Enhanced stat card implementation with optional subtitle - fixed missing closing parenthesis
  Widget _buildStatCard(
    String title, 
    String value, 
    IconData icon, 
    Color color, 
    {String? subtitle}
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _adaptiveCardColor,
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: _adaptiveTextColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _adaptiveTextColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Add the missing method for achievement cards
  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _adaptiveCardColor,
        border: Border.all(
          color: (achievement['color'] as Color?)?.withOpacity(0.3) ?? 
                 Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (achievement['color'] as Color?)?.withOpacity(0.2) ?? 
                   Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            achievement['icon'] as IconData? ?? Icons.emoji_events,
            color: (achievement['color'] as Color?) ?? Colors.amber.shade300,
          ),
        ),
        title: Text(
          achievement['title'] ?? 'Achievement',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _adaptiveTextColor,
          ),
        ),
        subtitle: Text(
          achievement['description'] ?? '',
          style: TextStyle(
            color: _adaptiveTextColor.withOpacity(0.7),
          ),
        ),
        trailing: Text(
          'Unlocked',
          style: TextStyle(
            color: _adaptiveHighlightColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Add the missing method for upcoming achievements
  Widget _buildUpcomingAchievement(
    String title, 
    String description, 
    int current, 
    int target, 
    {IconData icon = Icons.emoji_events_outlined}
  ) {
    double progress = current / target;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _adaptiveTextColor.withOpacity(0.6)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _adaptiveTextColor,
                  ),
                ),
              ),
              Text(
                '$current/$target',
                style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: _adaptiveTextColor.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 1.0 ? 1.0 : progress,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_adaptiveHighlightColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // Add the missing method for daily summaries list
  Widget _buildDailySummariesList() {
    List<Widget> summaryWidgets = [];
    
    // Sort dates to show most recent first
    final sortedEntries = _dailySummaries!.entries.toList()
      ..sort((a, b) {
        try {
          final dateA = DateTime.parse(a.key);
          final dateB = DateTime.parse(b.key);
          return dateB.compareTo(dateA); // Most recent first
        } catch (e) {
          return 0;
        }
      });
    
    for (final entry in sortedEntries.take(5)) { // Show only latest 5
      final date = entry.key;
      final summary = entry.value;
      
      if (summary is Map) {
        final int totalFocusTimeSeconds = summary['total_focus_time_seconds'] ?? 0;
        final int completedSessions = summary['completed_sessions'] ?? 0;
        final int totalSessions = summary['total_sessions'] ?? 0;
        final double completionRate = (summary['average_completion_rate'] ?? 0).toDouble();
        final List<dynamic> treeTypes = summary['tree_types'] ?? [];
        
        // Format date
        DateTime? parsedDate;
        try {
          parsedDate = DateTime.parse(date);
        } catch (e) {
          // Handle date parsing error
        }
        
        final String formattedDate = parsedDate != null 
            ? DateFormat('MMM d, yyyy').format(parsedDate)
            : date;
            
        // Calculate focus time in minutes
        final int focusMinutes = (totalFocusTimeSeconds / 60).round();
        final String focusTimeText = focusMinutes >= 60
            ? '${(focusMinutes / 60).floor()}h ${focusMinutes % 60}m'
            : '${focusMinutes}min';
        
        summaryWidgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _adaptiveHighlightColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _adaptiveHighlightColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _adaptiveTextColor,
                      ),
                    ),
                    Text(
                      '$completedSessions/$totalSessions sessions',
                      style: TextStyle(
                        color: _adaptiveTextColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer,
                          size: 16,
                          color: _adaptiveHighlightColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          focusTimeText,
                          style: TextStyle(
                            color: _adaptiveTextColor.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: _adaptiveHighlightColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${completionRate.round()}% completion',
                          style: TextStyle(
                            color: _adaptiveTextColor.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (treeTypes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.park,
                        size: 16,
                        color: _adaptiveHighlightColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Trees: ${treeTypes.join(", ")}',
                          style: TextStyle(
                            color: _adaptiveTextColor.withOpacity(0.9),
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }
    
    return Column(children: summaryWidgets);
  }

  Widget _buildTransparentCard({
    required Widget child, 
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
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

  Widget _buildTreeStageIcon(int stage) {
    IconData icon;
    String label;
    
    switch (stage) {
      case 0:
        icon = Icons.spa;
        label = 'Seed';
        break;
      case 1:
        icon = Icons.grass;
        label = 'Sprout';
        break;
      case 2:
        icon = Icons.eco;
        label = 'Sapling';
        break;
      default:
        icon = Icons.park;
        label = 'Growing';
    }
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _adaptiveHighlightColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: _adaptiveHighlightColor,
            size: 32,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _adaptiveTextColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTile(Map<String, dynamic> session) {
    final bool completed = session['was_completed'] ?? false;
    final String treeType = session['tree_type'] ?? 'Unknown';
    final int durationMinutes = session['planned_duration_minutes'] ?? 0;
    final String startTime = session['start_time'] ?? '';
    final int actualFocusSeconds = session['actual_focus_time_seconds'] ?? 0;
    final int actualFocusMinutes = (actualFocusSeconds / 60).round();
    
    // Format date 
    String formattedTime = 'Recent';
    try {
      final DateTime parsedTime = DateTime.parse(startTime);
      formattedTime = DateFormat.jm().format(parsedTime); // Format as 2:05 PM
    } catch (e) {
      // Use default if parsing fails
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withOpacity(0.1),
      ),
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : Icons.cancel,
          color: completed ? _adaptiveHighlightColor : Colors.red.shade300,
        ),
        title: Text(
          '$actualFocusMinutes/${durationMinutes} minutes',
          style: TextStyle(color: _adaptiveTextColor),
        ),
        subtitle: Text(
          'Tree: $treeType • ${completed ? 'Completed' : 'Interrupted'}',
          style: TextStyle(color: _adaptiveTextColor.withOpacity(0.7)),
        ),
        trailing: Text(
          formattedTime,
          style: TextStyle(
            color: _adaptiveTextColor.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Remove the section navigation methods completely
  Widget _buildCurrentSectionContent() {
    return _buildOverviewTab();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/$_currentWallpaper',
              fit: BoxFit.cover,
            ),
          ),
          // Semi-transparent overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          // Content
          _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          // Back button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: _adaptiveTextColor,
                                size: 20,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title
                          Text(
                            'Your Progress',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _adaptiveTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Main content area - removed section buttons
                    Expanded(
                      child: _buildCurrentSectionContent(),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
