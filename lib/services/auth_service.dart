import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseDatabase _database;
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userEmailKey = 'user_email';

  AuthService() {
    // Initialize Firebase Database with proper configuration
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://grevia-7b7af-default-rtdb.firebaseio.com/',
    );
  }

  // Expose database reference for direct access
  FirebaseDatabase get database => _database;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user UID
  String? get currentUserUid => _auth.currentUser?.uid;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Save login state
  Future<void> _saveLoginState(bool isLoggedIn, {String? email}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, isLoggedIn);
      if (email != null) {
        await prefs.setString(_userEmailKey, email);
      }
      debugPrint('Login state saved: $isLoggedIn');
    } catch (e) {
      debugPrint('Error saving login state: $e');
    }
  }

  // Check if user was previously logged in
  Future<bool> isUserPreviouslyLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      final hasFirebaseUser = _auth.currentUser != null;

      debugPrint(
          'Previous login state: $isLoggedIn, Firebase user exists: $hasFirebaseUser');
      return isLoggedIn && hasFirebaseUser;
    } catch (e) {
      debugPrint('Error checking previous login state: $e');
      return false;
    }
  }

  // Clear all stored data
  Future<void> clearStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userEmailKey);
      debugPrint('All stored data cleared');
    } catch (e) {
      debugPrint('Error clearing stored data: $e');
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save login state
      await _saveLoginState(true, email: email);

      // Log successful login with UID
      debugPrint('User signed in successfully. UID: ${credential.user?.uid}');
      debugPrint('User email: ${credential.user?.email}');

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('General Auth Error: $e');
      debugPrint('Error type: ${e.runtimeType}');

      // Check if user was actually created despite the error
      await Future.delayed(const Duration(milliseconds: 500));
      if (_auth.currentUser != null) {
        await _saveLoginState(true, email: _auth.currentUser!.email);
        debugPrint('User exists despite error, proceeding...');
        return null; // Return null but user is logged in
      }

      throw 'Authentication error occurred. Please try again.';
    }
  }

  // Create user with email and password
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save login state
      await _saveLoginState(true, email: email);

      // Log successful registration with UID
      debugPrint('User registered successfully. UID: ${credential.user?.uid}');
      debugPrint('User email: ${credential.user?.email}');

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('General Auth Error: $e');
      debugPrint('Error type: ${e.runtimeType}');

      // Check if user was actually created despite the error
      await Future.delayed(const Duration(milliseconds: 500));
      if (_auth.currentUser != null) {
        await _saveLoginState(true, email: _auth.currentUser!.email);
        debugPrint('User created despite error, proceeding...');
        return null; // Return null but user is created
      }

      throw 'Account creation error occurred. Please try again.';
    }
  }

  // Check if user is authenticated (works around the pigeon error)
  Future<bool> isUserAuthenticated() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser != null;
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      return _auth.currentUser != null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _saveLoginState(false);
      await clearStoredData();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw 'Failed to sign out. Please try again.';
    }
  }

  // Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('General password reset error: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Get user profile data with null safety
  Map<String, dynamic>? getUserData() {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return {
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'emailVerified': user.emailVerified,
          'creationTime': user.metadata.creationTime?.toIso8601String() ?? '',
          'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String() ?? '',
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Save user data to Realtime Database
  Future<void> saveUserDataToFirestore({
    required String name,
    required String city,
    required String email,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Check if Firebase Database is available
        try {
          DatabaseReference userRef = _database.ref().child('users').child(user.uid);

          Map<String, dynamic> userData = {
            'profile': {
              'name': name,
              'city': city,
              'email': email,
              'uid': user.uid,
              'level': 1, // Add level to profile
              'treesCompleted': 0, // Add trees completed to profile
              'createdAt': ServerValue.timestamp,
              'lastUpdated': ServerValue.timestamp,
            },
            'focusStats': {
              'totalSessions': 0,
              'totalFocusTime': 0,
              'treesPlanted': 0,
              'treesCompleted': 0, // Track completed trees
              'currentStreak': 0,
              'lastSessionDate': null,
              'lastUpdated': ServerValue.timestamp,
            },
            'preferences': {
              'focusTime': 25,
              'treeType': 'Oak',
              'notificationsEnabled': true,
            },
            'status': {
              'level': 1,
              'experience': 0,
              'rank': 'Seedling',
              'nextLevelExp': 100,
              'treesCompleted': 0, // Add trees completed to status as well
              'treesForNextLevel': 1, // Level 2 requires 1 tree
              'achievements': {},
              'isActive': true,
              'lastActiveDate': ServerValue.timestamp,
              'lastUpdated': ServerValue.timestamp,
            },
            'focusSessions': {},
          };

          await userRef.set(userData);

          // Update global user count
          await _updateGlobalUserCount();

          debugPrint('User data saved to Realtime Database successfully');
        } catch (dbError) {
          debugPrint('Database connection error: $dbError');
          throw 'Database temporarily unavailable. User data saved locally.';
        }
      }
    } catch (e) {
      debugPrint('Error saving user data to Realtime Database: $e');
      // Rethrow to let calling code handle it
      rethrow;
    }
  }

  // Update global user count
  Future<void> _updateGlobalUserCount() async {
    try {
      DatabaseReference globalStatsRef = _database.ref().child('globalStats');
      DatabaseReference userCountRef = globalStatsRef.child('totalUsers');

      // Use transaction to safely increment user count
      await userCountRef.runTransaction((Object? currentValue) {
        int currentCount = 0;
        if (currentValue != null) {
          currentCount = currentValue as int? ?? 0;
        }
        return Transaction.success(currentCount + 1);
      });

      await globalStatsRef.child('lastUpdated').set(ServerValue.timestamp);

      debugPrint('Global user count updated');
    } catch (e) {
      debugPrint('Error updating global user count: $e');
    }
  }

  // Get user data from Realtime Database with proper UID-based access
  Future<Map<String, dynamic>?> getUserDataFromFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      debugPrint('Getting user data from Firebase Realtime Database for user: ${user.uid}');
      
      // Get data from Firebase Realtime Database using correct path structure
      final DatabaseReference userRef = _database.ref('users/${user.uid}');
      final DataSnapshot snapshot = await userRef.get();
      
      if (snapshot.exists) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('Firebase Realtime Database user data: $userData');
        return userData;
      } else {
        debugPrint('No user data found in Firebase Realtime Database');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user data from Firebase Realtime Database: $e');
      return null;
    }
  }

  // Get user profile specifically
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      DatabaseReference profileRef = _database.ref().child('users').child(user.uid).child('profile');
      DataSnapshot snapshot = await profileRef.get();

      if (snapshot.exists && snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Get user focus stats specifically
  Future<Map<String, dynamic>?> getUserFocusStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      DatabaseReference focusStatsRef = _database.ref().child('users').child(user.uid).child('focusStats');
      DataSnapshot snapshot = await focusStatsRef.get();

      if (snapshot.exists && snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user focus stats: $e');
      return null;
    }
  }

  // Get user status specifically
  Future<Map<String, dynamic>?> getUserStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      DatabaseReference statusRef = _database.ref().child('users').child(user.uid).child('status');
      DataSnapshot snapshot = await statusRef.get();

      if (snapshot.exists && snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user status: $e');
      return null;
    }
  }

  // Get user's daily summary for a specific date
  Future<Map<String, dynamic>?> getUserDailySummaryForDate(String date) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      debugPrint('Getting daily summary for date: $date');
      
      final DatabaseReference summaryRef = _database.ref('users/${user.uid}/daily_summaries/$date');
      final DataSnapshot snapshot = await summaryRef.get();
      
      if (snapshot.exists) {
        final summaryData = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('Daily summary data for $date: $summaryData');
        return summaryData;
      } else {
        debugPrint('No daily summary found for date: $date');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting daily summary for $date: $e');
      return null;
    }
  }

  // Get user's daily sessions for a specific date
  Future<List<Map<String, dynamic>>> getUserDailySessionsForDate(String date) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      debugPrint('Getting daily sessions for date: $date');
      
      final DatabaseReference sessionsRef = _database.ref('users/${user.uid}/daily_sessions/$date');
      final DataSnapshot snapshot = await sessionsRef.get();
      
      if (snapshot.exists) {
        final sessionsData = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('Daily sessions data for $date: $sessionsData');
        
        // Convert to list format
        List<Map<String, dynamic>> sessions = [];
        sessionsData.forEach((key, value) {
          if (value is Map) {
            final sessionData = Map<String, dynamic>.from(value);
            sessionData['session_key'] = key;
            sessions.add(sessionData);
          }
        });
        
        // Sort by start_time (most recent first)
        sessions.sort((a, b) {
          final aTime = a['start_time'] ?? '';
          final bTime = b['start_time'] ?? '';
          return bTime.compareTo(aTime);
        });
        
        debugPrint('Processed ${sessions.length} sessions for $date');
        return sessions;
      } else {
        debugPrint('No daily sessions found for date: $date');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting daily sessions for $date: $e');
      return [];
    }
  }

  // Get user achievements
  Future<List<Map<String, dynamic>>> getUserAchievements() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      debugPrint('Getting achievements from Firebase Realtime Database');
      
      final DatabaseReference achievementsRef = _database.ref('users/${user.uid}/achievements');
      final DataSnapshot snapshot = await achievementsRef.get();
      
      if (snapshot.exists) {
        final achievementsData = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('Achievements data: $achievementsData');
        
        // Convert to list format
        List<Map<String, dynamic>> achievements = [];
        achievementsData.forEach((key, value) {
          if (value is Map) {
            final achievementData = Map<String, dynamic>.from(value);
            achievementData['achievement_key'] = key;
            achievements.add(achievementData);
          }
        });
        
        // Sort by timestamp (most recent first)
        achievements.sort((a, b) {
          final aTime = a['timestamp'] ?? '';
          final bTime = b['timestamp'] ?? '';
          return bTime.compareTo(aTime);
        });
        
        return achievements;
      } else {
        // Create achievements based on user stats if no achievements exist
        final userData = await getUserDataFromFirestore();
        if (userData == null) return [];

        final focusStats = userData['focusStats'] as Map<String, dynamic>?;
        final treesCompleted = focusStats?['treesCompleted'] ?? 0;
        final totalSessions = focusStats?['totalSessions'] ?? 0;
        final totalFocusTime = focusStats?['totalFocusTime'] ?? 0;

        List<Map<String, dynamic>> achievements = [];

        // Add achievements based on stats
        if (treesCompleted >= 1) {
          achievements.add({
            'title': 'First Tree Completed!',
            'description': 'You grew your first tree successfully',
            'icon': 'tree',
            'earned_at': focusStats?['lastTreeCompleted'] ?? DateTime.now().toIso8601String(),
          });
        }

        if (totalSessions >= 5) {
          achievements.add({
            'title': 'Consistent Focuser',
            'description': 'Completed 5 focus sessions',
            'icon': 'star',
            'earned_at': DateTime.now().toIso8601String(),
          });
        }

        if (totalFocusTime >= 60) {
          achievements.add({
            'title': 'Hour of Focus',
            'description': 'Accumulated 1 hour of focus time',
            'icon': 'timer',
            'earned_at': DateTime.now().toIso8601String(),
          });
        }

        return achievements;
      }
    } catch (e) {
      debugPrint('Error getting achievements: $e');
      return [];
    }
  }

  // Get user's current tree growth
  Future<Map<String, dynamic>?> getUserCurrentTreeGrowth() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      debugPrint('Getting current tree growth data');
      
      final DatabaseReference treeGrowthRef = _database.ref('users/${user.uid}/currentTreeGrowth');
      final DataSnapshot snapshot = await treeGrowthRef.get();
      
      if (snapshot.exists) {
        final treeGrowthData = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('Current tree growth data: $treeGrowthData');
        return treeGrowthData;
      } else {
        debugPrint('No current tree growth data found');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting current tree growth: $e');
      return null;
    }
  }

  // Update specific user data paths with proper UID access
  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DatabaseReference profileRef = _database.ref().child('users').child(user.uid).child('profile');
      await profileRef.update({
        ...profileData,
        'lastUpdated': ServerValue.timestamp,
      });
      
      debugPrint('User profile updated successfully');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
  }

  // Update user focus stats with proper UID access
  Future<void> updateUserFocusStats(Map<String, dynamic> focusStats) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DatabaseReference focusStatsRef = _database.ref().child('users').child(user.uid).child('focusStats');
      await focusStatsRef.update({
        ...focusStats,
        'lastUpdated': ServerValue.timestamp,
      });
      
      debugPrint('User focus stats updated successfully');
    } catch (e) {
      debugPrint('Error updating user focus stats: $e');
    }
  }

  // Update user status with proper UID access
  Future<void> updateUserStatus(Map<String, dynamic> statusData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DatabaseReference statusRef = _database.ref().child('users').child(user.uid).child('status');
      await statusRef.update({
        ...statusData,
        'lastUpdated': ServerValue.timestamp,
      });
      
      debugPrint('User status updated successfully');
    } catch (e) {
      debugPrint('Error updating user status: $e');
    }
  }

  // Save user's current tree growth
  Future<void> saveUserCurrentTreeGrowth(Map<String, dynamic> treeGrowthData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      debugPrint('Saving current tree growth data: $treeGrowthData');
      
      final DatabaseReference treeGrowthRef = _database.ref('users/${user.uid}/currentTreeGrowth');
      
      // Add lastUpdated timestamp
      treeGrowthData['lastUpdated'] = ServerValue.timestamp;
      
      await treeGrowthRef.set(treeGrowthData);
      debugPrint('Current tree growth data saved successfully');
    } catch (e) {
      debugPrint('Error saving current tree growth: $e');
    }
  }

  // Get all users for leaderboard (only public info)
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      DatabaseReference usersRef = _database.ref('users');
      DataSnapshot snapshot = await usersRef.get();

      if (snapshot.exists) {
        List<Map<String, dynamic>> leaderboard = [];
        Map<String, dynamic> allUsers = Map<String, dynamic>.from(snapshot.value as Map);

        allUsers.forEach((userId, userData) {
          Map<String, dynamic> user = Map<String, dynamic>.from(userData);
          Map<String, dynamic> profile = user['profile'] ?? {};
          Map<String, dynamic> status = user['status'] ?? {};
          Map<String, dynamic> focusStats = user['focusStats'] ?? {};

          leaderboard.add({
            'userId': userId,
            'name': profile['name'] ?? 'Anonymous',
            'city': profile['city'] ?? '',
            'level': status['level'] ?? 1,
            'rank': status['rank'] ?? 'Seedling',
            'experience': status['experience'] ?? 0,
            'treesPlanted': focusStats['treesPlanted'] ?? 0,
            'totalSessions': focusStats['totalSessions'] ?? 0,
          });
        });

        // Sort by level then by experience
        leaderboard.sort((a, b) {
          int levelComparison = (b['level'] ?? 0).compareTo(a['level'] ?? 0);
          if (levelComparison != 0) return levelComparison;
          return (b['experience'] ?? 0).compareTo(a['experience'] ?? 0);
        });

        return leaderboard;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }

  // Get trees data from Firebase Database
  Future<List<Map<String, dynamic>>> getTrees() async {
    try {
      DatabaseReference treesRef = _database.ref('trees');
      DataSnapshot snapshot = await treesRef.get();

      if (snapshot.exists && snapshot.value != null) {
        List<Map<String, dynamic>> trees = [];
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);

        data.forEach((key, value) {
          if (value != null) {
            Map<String, dynamic> tree = Map<String, dynamic>.from(value);
            trees.add(tree);
          }
        });

        // Sort by unlock level
        trees.sort((a, b) => (a['unlock_level'] ?? 0).compareTo(b['unlock_level'] ?? 0));

        return trees;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting trees data: $e');
      return [];
    }
  }

  // Get specific tree by ID
  Future<Map<String, dynamic>?> getTreeById(String treeId) async {
    try {
      DatabaseReference treeRef = _database.ref('trees').child(treeId);
      DataSnapshot snapshot = await treeRef.get();

      if (snapshot.exists && snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting tree by ID: $e');
      return null;
    }
  }

  // Get trees unlocked for user's current level
  Future<List<Map<String, dynamic>>> getUnlockedTrees() async {
    try {
      // Get user's current level
      final userStatus = await getUserStatus();
      int userLevel = userStatus?['level'] ?? 1;

      // Get all trees
      List<Map<String, dynamic>> allTrees = await getTrees();

      // Filter trees that are unlocked for user's level
      List<Map<String, dynamic>> unlockedTrees = allTrees
          .where((tree) => (tree['unlock_level'] ?? 1) <= userLevel)
          .toList();

      return unlockedTrees;
    } catch (e) {
      debugPrint('Error getting unlocked trees: $e');
      return [];
    }
  }

  // Get user's focus sessions
  Future<List<Map<String, dynamic>>> getUserFocusSessions({int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      DatabaseReference focusSessionsRef = _database.ref().child('users').child(user.uid).child('focusSessions');
      DataSnapshot snapshot = await focusSessionsRef.orderByChild('timestamp').limitToLast(limit).get();

      if (snapshot.exists && snapshot.value != null) {
        List<Map<String, dynamic>> sessions = [];
        final data = snapshot.value;
        
        if (data is Map) {
          Map<String, dynamic> sessionsMap = Map<String, dynamic>.from(data);
          
          sessionsMap.forEach((sessionId, sessionData) {
            if (sessionData != null && sessionData is Map) {
              Map<String, dynamic> session = Map<String, dynamic>.from(sessionData);
              session['id'] = sessionId; // Add the session ID
              sessions.add(session);
            }
          });
          
          // Sort by timestamp (newest first)
          sessions.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        }
        
        return sessions;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting user focus sessions: $e');
      return [];
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      case 'invalid-credential':
        return 'The provided credentials are invalid.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed: ${e.message ?? 'Unknown error'}';
    }
  }

  Future<dynamic> getTreeUnlocksForLevel(int level) async {
    try {
      print('Fetching tree unlocks for level $level from Firebase'); // Debug
      
      // Get tree unlocks from Firebase Realtime Database
      final DatabaseReference treeUnlocksRef = _database.ref().child('tree_unlocks').child('level_$level');
      final DataSnapshot snapshot = await treeUnlocksRef.get();
      
      if (snapshot.exists && snapshot.value != null) {
        print('Found tree unlocks for level $level: ${snapshot.value}'); // Debug
        return snapshot.value;
      }
      
      print('No tree unlocks found for level $level in Firebase'); // Debug
      return null;
    } catch (e) {
      print('Error fetching tree unlocks for level $level: $e');
      return null;
    }
  }
}
