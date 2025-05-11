import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'face_detection_test.dart';
import 'main_complete.dart' as main_app;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  final cameras = await availableCameras();
  final firstCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  runApp(TestLauncherApp(camera: firstCamera));
}

class TestLauncherApp extends StatelessWidget {
  final CameraDescription camera;

  const TestLauncherApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eye Detection Test Launcher',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TestLauncherScreen(camera: camera),
    );
  }
}

class TestLauncherScreen extends StatelessWidget {
  final CameraDescription camera;

  const TestLauncherScreen({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eye Detection App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select which app to launch:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => main_app.MyApp(camera: camera),
                  ),
                );
              },
              icon: const Icon(Icons.remove_red_eye),
              label: const Text('Main Eye Detection App'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FaceDetectionTempFileTest(),
                  ),
                );
              },
              icon: const Icon(Icons.face),
              label: const Text('Face Detection Test'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Use the Face Detection Test if you want to verify\n'
              'that ML Kit face detection is working properly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
