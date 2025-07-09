import 'dart:math' as math;

class LevelService {
  static const int maxLevel = 100;
  static const int baseExperiencePerTree = 100;
  static const double experienceMultiplier = 1.5;

  // Calculate trees required for a specific level
  static int getTreesRequiredForLevel(int level, {bool includeCurrentLevel = false}) {
    if (level <= 1) return 0;
    if (level > maxLevel) level = maxLevel;
    
    // Each level requires more trees than the previous
    int treesRequired = (level - 1) * 2;
    
    // If we want total trees including current level
    if (includeCurrentLevel) {
      treesRequired += getTreesForNextLevel(level);
    }
    
    return treesRequired;
  }

  // Calculate experience required for a level
  static int getExperienceForLevel(int level) {
    if (level <= 1) return 0;
    if (level > maxLevel) level = maxLevel;
    
    return (baseExperiencePerTree * math.pow(experienceMultiplier, level - 1)).round();
  }

  // Calculate total experience required up to a level
  static int getTotalExperienceForLevel(int level) {
    if (level <= 1) return 0;
    if (level > maxLevel) level = maxLevel;
    
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += getExperienceForLevel(i);
    }
    return total;
  }

  // Get trees needed for next level
  static int getTreesForNextLevel(int currentLevel) {
    if (currentLevel >= maxLevel) return 0;
    return (currentLevel * 2) + 1;
  }

  // Calculate progress percentage to next level
  static double calculateLevelProgress(int completedTrees, int currentLevel) {
    final treesNeeded = getTreesForNextLevel(currentLevel);
    if (treesNeeded == 0) return 1.0;
    return (completedTrees / treesNeeded).clamp(0.0, 1.0);
  }

  // Get rank title for level
  static String getRankForLevel(int level) {
    if (level <= 1) return 'Seedling';
    if (level <= 5) return 'Sprout';
    if (level <= 10) return 'Sapling';
    if (level <= 20) return 'Young Tree';
    if (level <= 35) return 'Mature Tree';
    if (level <= 50) return 'Ancient Tree';
    if (level <= 75) return 'Forest Guardian';
    return 'Forest Master';
  }

  // Get next milestone information
  static Map<String, dynamic> getNextMilestone(int currentLevel, int completedTrees) {
    final nextLevel = currentLevel + 1;
    final treesNeeded = getTreesForNextLevel(currentLevel);
    final remainingTrees = treesNeeded - completedTrees;
    
    return {
      'nextLevel': nextLevel,
      'nextRank': getRankForLevel(nextLevel),
      'treesNeeded': treesNeeded,
      'remainingTrees': remainingTrees,
      'progress': calculateLevelProgress(completedTrees, currentLevel),
    };
  }

  // Calculate rewards for a level
  static Map<String, dynamic> getLevelRewards(int level) {
    return {
      'newTrees': level > 1 ? [(level - 1) * 2] : [],
      'bonusMinutes': level * 5,
      'specialReward': _getSpecialReward(level),
    };
  }

  // Get special reward for level
  static String _getSpecialReward(int level) {
    if (level == 5) return 'Cherry Blossom Tree Unlocked';
    if (level == 10) return 'Quick Growth Feature Unlocked';
    if (level == 20) return 'Forest Guardian Badge';
    if (level == 50) return 'Golden Tree Skin';
    return '';
  }

  // Check if user can level up
  static bool canLevelUp(int completedTrees, int currentLevel) {
    return completedTrees >= getTreesForNextLevel(currentLevel);
  }

  // Calculate level stats
  static Map<String, dynamic> calculateLevelStats(int completedTrees) {
    int currentLevel = 1;
    int accumulatedTrees = 0;
    
    // Find current level based on completed trees
    while (currentLevel < maxLevel) {
      final treesForNextLevel = getTreesForNextLevel(currentLevel);
      if (completedTrees < accumulatedTrees + treesForNextLevel) {
        break;
      }
      accumulatedTrees += treesForNextLevel;
      currentLevel++;
    }
    
    final treesInCurrentLevel = completedTrees - accumulatedTrees;
    final progressToNext = calculateLevelProgress(treesInCurrentLevel, currentLevel);
    
    return {
      'currentLevel': currentLevel,
      'rank': getRankForLevel(currentLevel),
      'treesInCurrentLevel': treesInCurrentLevel,
      'treesForNextLevel': getTreesForNextLevel(currentLevel),
      'progressToNext': progressToNext,
      'canLevelUp': canLevelUp(treesInCurrentLevel, currentLevel),
    };
  }
}
