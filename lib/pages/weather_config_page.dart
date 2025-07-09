import 'package:flutter/material.dart';
import 'home_page.dart';

class WeatherConfigPage extends StatefulWidget {
  const WeatherConfigPage({super.key});

  @override
  State<WeatherConfigPage> createState() => _WeatherConfigPageState();
}

class _WeatherConfigPageState extends State<WeatherConfigPage> {
  final _nameController = TextEditingController();
  int selectedFocusTime = 25;
  String selectedTreeType = 'Oak';

  final List<int> focusTimes = [15, 25, 30, 45, 60];
  final List<String> treeTypes = ['Oak', 'Pine', 'Maple', 'Birch', 'Cherry'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Setup'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Configure Your Focus Preferences',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'What should we call you?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, color: Colors.green),
                hintText: 'e.g. Alex, Sarah, Michael',
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Focus Session Duration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: focusTimes
                    .map(
                      (time) => RadioListTile<int>(
                        title: Text('$time minutes'),
                        subtitle: Text(time == 25
                            ? 'Classic Pomodoro'
                            : '$time min focus'),
                        value: time,
                        groupValue: selectedFocusTime,
                        onChanged: (value) {
                          setState(() {
                            selectedFocusTime = value!;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Virtual Tree Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedTreeType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.park, color: Colors.green),
                      ),
                      items: treeTypes
                          .map(
                            (tree) => DropdownMenuItem(
                              value: tree,
                              child: Text(tree),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTreeType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your virtual $selectedTreeType tree will grow with each focus session!',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.isNotEmpty) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomePage(
                          userName: _nameController.text.trim(),
                          focusTime: selectedFocusTime,
                          treeType: selectedTreeType,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your name'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Start Growing Trees',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
