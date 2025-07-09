import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  PageController pageController = PageController();
  int currentIndex = 0;
  bool _locationPermissionGranted = false;
  bool _notificationPermissionGranted = false;

  final List<OnboardingContent> contents = [
    OnboardingContent(
      title: "Turn your focus into growth.",
      description: "Each time you concentrate using our Pomodoro timer, a virtual tree begins to grow. Stay focused, and see it thrive.",
      image: Icons.spa,
    ),
    OnboardingContent(
      title: "Every session counts.",
      description: "With every completed Pomodoro session, your tree grows a little more. Distractions pause growth—consistency is key.",
      image: Icons.forest,
    ),
    OnboardingContent(
      title: "When it's fully grown, we plant it.",
      description: "Once your virtual tree is complete, we'll plant a real one for you. You focus—we take care of nature.",
      image: Icons.park,
    ),
    OnboardingContent(
      title: "Build forests with your focus.",
      description: "Join a growing community turning screen time into green time. The more you focus, the more trees we plant—together.",
      image: Icons.groups,
    ),
    OnboardingContent(
      title: "Enable Permissions",
      description: "Allow location and notifications for the best experience",
      image: Icons.security,
    ),
  ];

  Future<void> _requestLocationPermission() async {
    try {
      // Request using permission_handler instead of Geolocator
      final status = await Permission.location.request();
      if (status.isGranted) {
        setState(() {
          _locationPermissionGranted = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission granted!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting location permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      PermissionStatus status = await Permission.notification.request();
      
      if (status.isGranted) {
        setState(() {
          _notificationPermissionGranted = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission granted!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission denied'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting notification permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPermissionPage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 150,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 40),
          const Text(
            "Enable Permissions",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Allow location and notifications for the best focus experience",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 40),
          
          // Location Permission Card
          Card(
            elevation: 3,
            child: ListTile(
              leading: Icon(
                Icons.location_on,
                color: _locationPermissionGranted ? Colors.green : Colors.orange,
                size: 30,
              ),
              title: const Text('Location Access'),
              subtitle: Text(
                _locationPermissionGranted 
                    ? 'Permission granted' 
                    : 'Tap to enable location access'
              ),
              trailing: _locationPermissionGranted 
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.arrow_forward_ios),
              onTap: _locationPermissionGranted ? null : _requestLocationPermission,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Notification Permission Card
          Card(
            elevation: 3,
            child: ListTile(
              leading: Icon(
                Icons.notifications,
                color: _notificationPermissionGranted ? Colors.green : Colors.orange,
                size: 30,
              ),
              title: const Text('Focus Notifications'),
              subtitle: Text(
                _notificationPermissionGranted 
                    ? 'Permission granted' 
                    : 'Tap to enable focus reminders'
              ),
              trailing: _notificationPermissionGranted 
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.arrow_forward_ios),
              onTap: _notificationPermissionGranted ? null : _requestNotificationPermission,
            ),
          ),
          
          const SizedBox(height: 30),
          
          if (_locationPermissionGranted && _notificationPermissionGranted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All permissions granted! Ready to start growing trees.',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: contents.length,
              onPageChanged: (int index) {
                setState(() {
                  currentIndex = index;
                });
              },
              itemBuilder: (_, i) {
                // Show permission page for the last index
                if (i == contents.length - 1) {
                  return _buildPermissionPage();
                }
                
                // Show regular onboarding pages
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        contents[i].image,
                        size: 150,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 40),
                      Text(
                        contents[i].title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        contents[i].description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              contents.length,
              (index) => buildDot(index),
            ),
          ),
          Container(
            height: 60,
            margin: const EdgeInsets.all(40),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (currentIndex == contents.length - 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                } else {
                  pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                currentIndex == contents.length - 1 
                    ? "Start Growing Trees" 
                    : currentIndex == contents.length - 2 
                        ? "Setup Permissions" 
                        : "Next",
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Container buildDot(int index) {
    return Container(
      height: 10,
      width: currentIndex == index ? 25 : 10,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: currentIndex == index ? Colors.green.shade600 : Colors.grey,
      ),
    );
  }
}

class OnboardingContent {
  String title;
  String description;
  IconData image;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.image,
  });
}
