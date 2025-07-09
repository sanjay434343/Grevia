import 'package:flutter/material.dart';

class TreeGrowthModel {
  static const List<String> stageNames = [
    'Seed',
    'Small Sprout',
    'Sprout',
    'Mini Plant',
    'Plant',
    'Longer Plant',
    'Large Plant',
    'Mini Tree',
    'Longer Tree',
    'Larger Tree with Flowers',
    'Mature Tree',
    'Mature Tree with Flowers',
    'Full Grown Tree',
  ];

  // Base durations for each stage - these scale with user level
  static const List<int> baseStageDurations = [
    1,   // Seed: 1 minute base (super quick start)
    2,   // Small Sprout: 2 minutes base
    3,   // Sprout: 3 minutes base
    5,   // Mini Plant: 5 minutes base
    8,   // Plant: 8 minutes base
    10,  // Longer Plant: 10 minutes base
    15,  // Large Plant: 15 minutes base
    20,  // Mini Tree: 20 minutes base
    25,  // Longer Tree: 25 minutes base
    30,  // Larger Tree with Flowers: 30 minutes base
    35,  // Mature Tree: 35 minutes base
    40,  // Mature Tree with Flowers: 40 minutes base
    45,  // Full Grown Tree: 45 minutes base
  ];

  // Duration multipliers based on user level
  static const Map<int, double> levelMultipliers = {
    1: 0.5,   // Level 1: half duration (very quick growth)
    2: 0.8,   // Level 2: 20% shorter
    3: 1.0,   // Level 3: base duration
    4: 1.2,   // Level 4: 20% longer
    5: 1.5,   // Level 5: 50% longer
    6: 2.0,   // Level 6+: double duration
  };

  // Special quick trees that grow completely in 1-3 minutes
  static const Map<String, int> quickTreeTypes = {
    'Fast Cherry Blossom': 1,  // Grows completely in 1 minute
    'Speed Bamboo': 2,         // Grows completely in 2 minutes
    'Quick Mint': 3,           // Grows completely in 3 minutes
  };

  static int getStageForLevel(int userLevel) {
    if (userLevel <= 0) return 0;
    if (userLevel >= stageNames.length) return stageNames.length - 1;
    return userLevel - 1;
  }

  static int getDurationForStage(int stage, {int userLevel = 1, String? treeType}) {
    // Handle special quick trees
    if (treeType != null && quickTreeTypes.containsKey(treeType)) {
      return quickTreeTypes[treeType]!;
    }
    
    if (stage < 0 || stage >= baseStageDurations.length) return 25;
    
    int baseDuration = baseStageDurations[stage];
    double multiplier = levelMultipliers[userLevel] ?? 
                       (userLevel > 6 ? 2.0 : 1.0);
    
    int finalDuration = (baseDuration * multiplier).round();
    
    // Ensure minimum of 1 minute and maximum of 90 minutes
    return finalDuration.clamp(1, 90);
  }

  static String getStageDescription(int stage) {
    if (stage < 0 || stage >= stageNames.length) return 'Unknown';
    return stageNames[stage];
  }

  static double calculateGrowthProgress(int completedMinutes, int totalMinutes) {
    if (totalMinutes <= 0) return 0.0;
    double progress = completedMinutes / totalMinutes;
    return progress.clamp(0.0, 1.0);
  }

  static int calculateCurrentStage(double overallProgress) {
    if (overallProgress >= 1.0) return stageNames.length - 1;
    
    double stageProgress = overallProgress * (stageNames.length - 1);
    return stageProgress.floor();
  }

  static double calculateStageProgress(double overallProgress, int currentStage) {
    if (currentStage >= stageNames.length - 1) return 1.0;
    
    double stageSize = 1.0 / (stageNames.length - 1);
    double stageStart = currentStage * stageSize;
    double progressInStage = (overallProgress - stageStart) / stageSize;
    
    return progressInStage.clamp(0.0, 1.0);
  }

  // Calculate growth progress for quick trees (1-3 minute complete growth)
  static double calculateQuickTreeGrowthProgress(int completedSeconds, int totalMinutes) {
    if (totalMinutes <= 3) {
      // For very quick trees, calculate progress based on seconds
      int totalSeconds = totalMinutes * 60;
      double progress = completedSeconds / totalSeconds;
      return progress.clamp(0.0, 1.0);
    }
    
    // For normal trees, use minute-based calculation
    int completedMinutes = (completedSeconds / 60).floor();
    return calculateGrowthProgress(completedMinutes, totalMinutes);
  }

  // Calculate which stage based on time progress for quick trees
  static int calculateQuickTreeCurrentStage(int completedSeconds, int totalMinutes) {
    if (totalMinutes <= 3) {
      // For quick trees, show all growth stages within the short duration
      double timeProgress = completedSeconds / (totalMinutes * 60);
      double stageProgress = timeProgress * (stageNames.length - 1);
      return stageProgress.floor().clamp(0, stageNames.length - 1);
    }
    
    // For normal trees, use standard calculation
    double overallProgress = calculateQuickTreeGrowthProgress(completedSeconds, totalMinutes);
    return calculateCurrentStage(overallProgress);
  }

  // Get growth intervals for quick trees (when to advance to next stage)
  static List<int> getQuickTreeStageIntervals(int totalMinutes) {
    if (totalMinutes <= 3) {
      int totalSeconds = totalMinutes * 60;
      int intervalSeconds = totalSeconds ~/ stageNames.length;
      
      List<int> intervals = [];
      for (int i = 0; i < stageNames.length; i++) {
        intervals.add(i * intervalSeconds);
      }
      return intervals;
    }
    
    // For normal trees, return minute-based intervals
    List<int> intervals = [];
    int intervalMinutes = totalMinutes ~/ stageNames.length;
    for (int i = 0; i < stageNames.length; i++) {
      intervals.add(i * intervalMinutes * 60); // Convert to seconds
    }
    return intervals;
  }

  // Check if a tree type is a quick-growing tree
  static bool isQuickTree(String? treeType) {
    return treeType != null && quickTreeTypes.containsKey(treeType);
  }

  // Get quick tree duration
  static int getQuickTreeDuration(String treeType) {
    return quickTreeTypes[treeType] ?? 25;
  }

  // Get all available quick trees
  static List<Map<String, dynamic>> getQuickTrees() {
    return quickTreeTypes.entries.map((entry) => {
      'name': entry.key,
      'duration': entry.value,
      'description': 'Grows completely in ${entry.value} minute${entry.value > 1 ? 's' : ''}',
      'type': 'quick',
    }).toList();
  }

  // Get recommended focus duration based on user level and stage
  static int getRecommendedDuration(int userLevel, {String? treeType}) {
    // Handle quick trees
    if (treeType != null && quickTreeTypes.containsKey(treeType)) {
      return quickTreeTypes[treeType]!;
    }
    
    int stage = getStageForLevel(userLevel);
    return getDurationForStage(stage, userLevel: userLevel, treeType: treeType);
  }

  // Get stage info including duration and description
  static Map<String, dynamic> getStageInfo(int stage, {int userLevel = 1, String? treeType}) {
    return {
      'stage': stage,
      'name': getStageDescription(stage),
      'duration': getDurationForStage(stage, userLevel: userLevel, treeType: treeType),
      'userLevel': userLevel,
      'isQuickTree': isQuickTree(treeType),
      'treeType': treeType,
    };
  }

  // Calculate total time needed to complete all stages for a user level
  static int getTotalTimeForAllStages(int userLevel, {String? treeType}) {
    // Handle quick trees
    if (treeType != null && quickTreeTypes.containsKey(treeType)) {
      return quickTreeTypes[treeType]!;
    }
    
    int totalTime = 0;
    for (int i = 0; i < stageNames.length; i++) {
      totalTime += getDurationForStage(i, userLevel: userLevel, treeType: treeType);
    }
    return totalTime;
  }

  // Get next milestone information
  static Map<String, dynamic>? getNextMilestone(int currentStage, int userLevel, {String? treeType}) {
    if (currentStage >= stageNames.length - 1) return null;
    
    int nextStage = currentStage + 1;
    return {
      'stage': nextStage,
      'name': getStageDescription(nextStage),
      'duration': getDurationForStage(nextStage, userLevel: userLevel, treeType: treeType),
      'description': 'Complete this stage to unlock ${getStageDescription(nextStage)}',
      'isQuickTree': isQuickTree(treeType),
    };
  }

  // Calculate experience points based on completed duration and stage
  static int calculateExperiencePoints(int completedMinutes, int stage, int userLevel, {String? treeType}) {
    int baseDuration = getDurationForStage(stage, userLevel: userLevel, treeType: treeType);
    double completionRatio = (completedMinutes / baseDuration).clamp(0.0, 1.0);
    
    // Base XP increases with stage difficulty
    int baseXP = 10 + (stage * 5);
    
    // Quick trees give bonus XP for rapid completion
    if (isQuickTree(treeType)) {
      baseXP = (baseXP * 1.5).round(); // 50% bonus for quick trees
    }
    
    // Bonus for completion
    int completionBonus = completionRatio >= 1.0 ? (baseXP * 0.5).round() : 0;
    
    // Level scaling bonus
    int levelBonus = userLevel * 2;
    
    return ((baseXP * completionRatio) + completionBonus + levelBonus).round();
  }

  // Get stage color for UI (enhanced for quick trees)
  static Color getStageColor(int stage, {String? treeType}) {
    final colors = [
      const Color(0xFF8D6E63), // Seed - Brown
      const Color(0xFF81C784), // Small Sprout - Light Green
      const Color(0xFF66BB6A), // Sprout - Green
      const Color(0xFF4CAF50), // Mini Plant - Medium Green
      const Color(0xFF43A047), // Plant - Darker Green
      const Color(0xFF388E3C), // Longer Plant - Dark Green
      const Color(0xFF2E7D32), // Large Plant - Very Dark Green
      const Color(0xFF1B5E20), // Mini Tree - Forest Green
      const Color(0xFF33691E), // Longer Tree - Olive Green
      const Color(0xFFE91E63), // Larger Tree with Flowers - Pink
      const Color(0xFF8BC34A), // Mature Tree - Light Green
      const Color(0xFFFF9800), // Mature Tree with Flowers - Orange
      const Color(0xFF4CAF50), // Full Grown Tree - Rich Green
    ];
    
    // Special colors for quick trees
    if (isQuickTree(treeType)) {
      final quickColors = [
        const Color(0xFFFFE082), // Quick tree - Light Yellow
        const Color(0xFFFFD54F), // Quick tree - Yellow
        const Color(0xFFFFCA28), // Quick tree - Amber
        const Color(0xFFFFC107), // Quick tree - Amber
        const Color(0xFFFFB300), // Quick tree - Orange
        const Color(0xFFFF8F00), // Quick tree - Orange
        const Color(0xFFFF6F00), // Quick tree - Deep Orange
        const Color(0xFFE65100), // Quick tree - Deep Orange
        const Color(0xFFBF360C), // Quick tree - Red Orange
        const Color(0xFFFF5722), // Quick tree - Deep Orange
        const Color(0xFFFF4081), // Quick tree - Pink
        const Color(0xFFE91E63), // Quick tree - Pink
        const Color(0xFFAD1457), // Quick tree - Dark Pink
      ];
      
      if (stage >= 0 && stage < quickColors.length) {
        return quickColors[stage];
      }
      return const Color(0xFFFFCA28); // Default quick tree color
    }
    
    if (stage >= 0 && stage < colors.length) {
      return colors[stage];
    }
    return const Color(0xFF4CAF50); // Default green
  }

  // Get estimated time remaining for current tree (enhanced for quick trees)
  static String getEstimatedTimeRemaining(int completedMinutes, int totalMinutes, {String? treeType}) {
    if (isQuickTree(treeType) && totalMinutes <= 3) {
      // For quick trees, show seconds
      int completedSeconds = completedMinutes * 60;
      int totalSeconds = totalMinutes * 60;
      int remainingSeconds = totalSeconds - completedSeconds;
      
      if (remainingSeconds <= 0) return "Complete!";
      
      if (remainingSeconds < 60) {
        return "${remainingSeconds}s remaining";
      } else {
        int minutes = remainingSeconds ~/ 60;
        int seconds = remainingSeconds % 60;
        return "${minutes}m ${seconds}s remaining";
      }
    }
    
    // Standard time calculation for normal trees
    int remaining = totalMinutes - completedMinutes;
    if (remaining <= 0) return "Complete!";
    
    int hours = remaining ~/ 60;
    int minutes = remaining % 60;
    
    if (hours > 0) {
      return "${hours}h ${minutes}m remaining";
    } else {
      return "${minutes}m remaining";
    }
  }

  // Get tree growth description based on type
  static String getTreeTypeDescription(String? treeType) {
    if (treeType == null) return "A beautiful tree that grows with your focus.";
    
    if (quickTreeTypes.containsKey(treeType)) {
      int duration = quickTreeTypes[treeType]!;
      return "A fast-growing $treeType that reaches full maturity in just $duration minute${duration > 1 ? 's' : ''}! Perfect for quick focus sessions.";
    }
    
    return "A $treeType tree that grows steadily with each focus session, becoming more beautiful over time.";
  }
}
