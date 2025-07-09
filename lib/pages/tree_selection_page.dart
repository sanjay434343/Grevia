import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../services/auth_service.dart';

class TreeSelectionPage extends StatefulWidget {
  const TreeSelectionPage({super.key});

  @override
  State<TreeSelectionPage> createState() => _TreeSelectionPageState();
}

class _TreeSelectionPageState extends State<TreeSelectionPage> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _trees = [];
  List<Map<String, dynamic>> _unlockedTrees = [];
  bool _isLoading = true;
  String? _selectedTreeId;
  
  // Background and color variables
  String _currentWallpaper = 'bg_trees.jpg';
  Color _adaptiveCardColor = Colors.white.withOpacity(0.15);
  Color _adaptiveTextColor = Colors.white;
  Color _adaptiveHighlightColor = Colors.green.shade400;

  @override
  void initState() {
    super.initState();
    _loadTrees();
    _loadWallpaper();
  }
  
  Future<void> _loadWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wallpaper = prefs.getString('selected_background') ?? 'bg.jpg';
      if (mounted) {
        setState(() {
          _currentWallpaper = wallpaper;
        });
        
        // Apply wallpaper colors directly
        _applyWallpaperColors(wallpaper);
      }
    } catch (e) {
      debugPrint('Error loading wallpaper: $e');
    }
  }
  
  // Direct color application without async extraction
  void _applyWallpaperColors(String wallpaperName) {
    // Force specific colors based on wallpaper name
    if (wallpaperName.contains('dark') || wallpaperName == 'bg.jpg') {
      // Dark backgrounds get white cards with green accents
      setState(() {
        _adaptiveCardColor = Colors.white.withOpacity(0.08); // Reduced from 0.15
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
        _adaptiveCardColor = Colors.green.withOpacity(0.08); // Reduced from 0.15
        _adaptiveHighlightColor = Colors.green.shade400;
        _adaptiveTextColor = Colors.white;
      });
      debugPrint('Applied green theme colors for $wallpaperName');
    }
    else if (wallpaperName.contains('light')) {
      // Light backgrounds get subtle white cards
      setState(() {
        _adaptiveCardColor = Colors.white.withOpacity(0.06); // Reduced from 0.12
        _adaptiveHighlightColor = Colors.green.shade600;
        _adaptiveTextColor = Colors.white;
      });
      debugPrint('Applied light theme colors for $wallpaperName');
    }
    else {
      // Default to white cards for any other case
      setState(() {
        _adaptiveCardColor = Colors.white.withOpacity(0.08); // Reduced from 0.15
        _adaptiveHighlightColor = Colors.green.shade500;
        _adaptiveTextColor = Colors.white;
      });
      debugPrint('Applied default theme colors for $wallpaperName');
    }
  }

  Future<void> _loadTrees() async {
    try {
      final trees = await _authService.getTrees();
      final unlockedTrees = await _authService.getUnlockedTrees();
      
      if (mounted) {
        setState(() {
          _trees = trees;
          _unlockedTrees = unlockedTrees;
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
            content: Text('Error loading trees: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTreeCard(Map<String, dynamic> tree) {
    final bool isUnlocked = _unlockedTrees.any((t) => t['id'] == tree['id']);
    final bool isSelected = _selectedTreeId == tree['id'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected 
            ? _adaptiveHighlightColor.withOpacity(0.08) // Reduced from 0.15
            : _adaptiveCardColor,
        border: Border.all(
          color: isSelected 
              ? _adaptiveHighlightColor.withOpacity(0.3) // Reduced from 0.5
              : Colors.white.withOpacity(0.08), // Reduced from 0.15
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: _adaptiveHighlightColor.withOpacity(0.1), // Reduced from 0.2
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ] : [],
      ),
      child: InkWell( // Removed ClipRRect and BackdropFilter
        onTap: isUnlocked ? () {
          setState(() {
            _selectedTreeId = tree['id'];
          });
          // Add haptic feedback when selecting a tree
          HapticFeedback.lightImpact();
        } : null,
        borderRadius: BorderRadius.circular(12), // Match container border radius
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced from 16 to 12
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42, // Reduced from 50 to 42
                    height: 42, // Reduced from 50 to 42
                    decoration: BoxDecoration(
                      color: isUnlocked 
                          ? _adaptiveHighlightColor.withOpacity(0.2) 
                          : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.park,
                      color: isUnlocked 
                          ? _adaptiveHighlightColor 
                          : Colors.grey.withOpacity(0.5),
                      size: 24, // Reduced from 28 to 24
                    ),
                  ),
                  const SizedBox(width: 12), // Reduced from 16 to 12
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tree['common_name'] ?? 'Unknown Tree',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked 
                                ? _adaptiveTextColor 
                                : _adaptiveTextColor.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          tree['name'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: isUnlocked 
                                ? _adaptiveTextColor.withOpacity(0.7) 
                                : _adaptiveTextColor.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _adaptiveHighlightColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: _adaptiveHighlightColor,
                        size: 20,
                      ),
                    ),
                  if (!isUnlocked)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (tree['description'] != null && isUnlocked) ...[
                Text(
                  tree['description'],
                  style: TextStyle(
                    color: _adaptiveTextColor.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!isUnlocked) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_open,
                        color: Colors.white.withOpacity(0.6),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Unlock at level ${tree['unlock_level']}',
                        style: TextStyle(
                          color: _adaptiveTextColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (tree['health_benefits'] != null && isUnlocked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _adaptiveHighlightColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Colors.pink.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Health Benefits',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _adaptiveTextColor.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tree['health_benefits']['primary'] ?? '',
                        style: TextStyle(
                          color: _adaptiveTextColor.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isUnlocked 
                          ? _adaptiveHighlightColor.withOpacity(0.2) 
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUnlocked 
                            ? _adaptiveHighlightColor.withOpacity(0.3) 
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: isUnlocked 
                              ? _adaptiveHighlightColor 
                              : Colors.grey.withOpacity(0.5),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${tree['unlock_level'] ?? 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isUnlocked 
                                ? _adaptiveTextColor 
                                : _adaptiveTextColor.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isUnlocked 
                          ? Colors.blue.withOpacity(0.2) 
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUnlocked 
                            ? Colors.blue.withOpacity(0.3) 
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer,
                          color: isUnlocked 
                              ? Colors.blue.shade300 
                              : Colors.grey.withOpacity(0.5),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tree['growth_duration_minutes'] ?? 60}min',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isUnlocked 
                                ? _adaptiveTextColor 
                                : _adaptiveTextColor.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUnlocked && tree['growth_difficulty'] != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber.shade300,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tree['growth_difficulty'] ?? 'Easy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _adaptiveTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: null, // Remove app bar completely
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/$_currentWallpaper',
              fit: BoxFit.cover,
            ),
          ),
          // Semi-transparent overlay with a more subtle neutral tint
          Positioned.fill(
            child: Container(
              color: Color(0x4D1A2420), // More neutral dark overlay with 30% opacity
            ),
          ),
          // Content
          _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: Column(
                children: [
                  // Header with back button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Select Your Tree',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _trees.length,
                      itemBuilder: (context, index) {
                        return _buildTreeCard(_trees[index]);
                      },
                    ),
                  ),
                  if (_selectedTreeId != null)
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              // Return selected tree to previous screen
                              final selectedTree = _trees.firstWhere(
                                (tree) => tree['id'] == _selectedTreeId,
                              );
                              Navigator.pop(context, selectedTree);
                              HapticFeedback.mediumImpact();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _adaptiveHighlightColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 8,
                              shadowColor: _adaptiveHighlightColor.withOpacity(0.5),
                            ),
                            child: const Text(
                              'Select This Tree',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
}
