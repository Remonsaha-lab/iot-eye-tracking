import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'bluetooth_service.dart';

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  final cameras = await availableCameras();
  final firstCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  runApp(MyApp(camera: firstCamera));
}

enum EyeMovement {
  neutral,
  up,
  down,
  blinking,
  doubleBlinking,
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eye Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: EyeDetectionScreen(camera: camera),
    );
  }
}

class EyeDetectionScreen extends StatefulWidget {
  final CameraDescription camera;

  const EyeDetectionScreen({super.key, required this.camera});

  @override
  State<EyeDetectionScreen> createState() => _EyeDetectionScreenState();
}

class _EyeDetectionScreenState extends State<EyeDetectionScreen> {
  late CameraController _cameraController;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  EyeMovement _currentEyeMovement = EyeMovement.neutral;
  int _currentAngle = 0;

  // For debug information
  bool _showDebugInfo = true;
  List<Face> _detectedFaces = [];
  String _debugText = "Initializing...";

  // For blink detection
  bool _wasBlinking = false;
  int _blinkCount = 0;
  DateTime? _lastBlinkTime;

  // Bluetooth
  final ESP32BluetoothService _bluetoothService = ESP32BluetoothService();
  String _bluetoothStatus = "Not Connected";
  List<fbp.BluetoothDevice> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeFaceDetector();
    _initializeCamera();

    // Listen to Bluetooth messages
    _bluetoothService.messages.listen((message) {
      debugPrint("Bluetooth: $message");
      if (message.contains("Connected")) {
        setState(() {
          _bluetoothStatus = "Connected";
        });
      } else if (message.contains("Disconnected")) {
        setState(() {
          _bluetoothStatus = "Not Connected";
        });
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();

      setState(() {
        _isCameraInitialized = true;
      });

      _cameraController.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;

    _isDetecting = true;

    try {
      // Convert CameraImage to InputImage
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage != null) {
        final faces = await _faceDetector.processImage(inputImage);
        _detectEyeMovements(faces);

        // Update detected faces for visualization
        setState(() {
          _detectedFaces = faces;
          _debugText = "Faces detected: ${faces.length}";
          if (faces.isNotEmpty) {
            Face face = faces.first;
            _debugText +=
                "\nLeft eye open: ${face.leftEyeOpenProbability?.toStringAsFixed(2) ?? 'unknown'}";
            _debugText +=
                "\nRight eye open: ${face.rightEyeOpenProbability?.toStringAsFixed(2) ?? 'unknown'}";
            _debugText +=
                "\nHead angle X: ${face.headEulerAngleX?.toStringAsFixed(2) ?? 'unknown'}";
          }
        });
      }
    } catch (e) {
      setState(() {
        _debugText = "Error: $e";
      });
      debugPrint('Error processing camera image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    // For Android, we can use InputImage.fromMediaImage
    if (Platform.isAndroid) {
      final rotation = InputImageRotationValue.fromRawValue(
              widget.camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      return InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
    // For iOS, a different approach is needed, but we'll just use a simpler method
    else {
      return InputImage.fromFilePath(
        widget.camera.name, // Just a placeholder, won't actually work
      );
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  void _detectEyeMovements(List<Face> faces) {
    if (faces.isEmpty) {
      setState(() {
        _currentEyeMovement = EyeMovement.neutral;
      });
      return;
    }

    final face = faces.first;

    // Check for eye landmarks if available
    final leftEye = face.leftEyeOpenProbability ?? 0;
    final rightEye = face.rightEyeOpenProbability ?? 0;

    // Detect if eyes are closed (blinking)
    final isBlinking = leftEye < 0.3 && rightEye < 0.3;

    // Handle blink detection
    if (isBlinking && !_wasBlinking) {
      // Start of a blink
      final now = DateTime.now();
      if (_lastBlinkTime != null &&
          now.difference(_lastBlinkTime!).inMilliseconds < 500) {
        // Less than 500ms between blinks, counting as double blink
        _blinkCount++;
        if (_blinkCount >= 2) {
          setState(() {
            _currentEyeMovement = EyeMovement.doubleBlinking;
          });
          // When double blink is detected, send the select command to ESP32
          if (_bluetoothService.isConnected) {
            _bluetoothService.sendSelectCommand();
          }
          _blinkCount = 0;
        }
      } else {
        _blinkCount = 1;
      }
      _lastBlinkTime = now;
    }

    // Check eye movement based on head position
    // More sensitive thresholds for head movement detection
    final headEulerAngleX = face.headEulerAngleX ?? 0; // X-axis is up/down

    // Define thresholds for different head positions
    const double upThreshold = -5.0; // More sensitive (was -10.0)
    const double downThreshold = 5.0; // More sensitive (was 10.0)
    const double angleChangeRate = 5.0; // Smaller changes for smoother movement

    // Update eye movement state
    EyeMovement newEyeMovement;
    if (isBlinking) {
      newEyeMovement = EyeMovement.blinking;
    } else if (headEulerAngleX < upThreshold) {
      // Looking up
      newEyeMovement = EyeMovement.up;
      // Calculate angle change based on how far up the head is tilted
      // The further the tilt, the faster the angle changes
      double tiltFactor = math.min(1.0, (headEulerAngleX).abs() / 30.0);
      double angleChange = angleChangeRate + (angleChangeRate * tiltFactor);
      _updateAngle(angleChange.round());
    } else if (headEulerAngleX > downThreshold) {
      // Looking down
      newEyeMovement = EyeMovement.down;
      // Calculate angle change based on how far down the head is tilted
      double tiltFactor = math.min(1.0, (headEulerAngleX).abs() / 30.0);
      double angleChange = angleChangeRate + (angleChangeRate * tiltFactor);
      _updateAngle(-angleChange.round());
    } else {
      newEyeMovement = EyeMovement.neutral;
    }

    setState(() {
      _currentEyeMovement = newEyeMovement;
    });

    _wasBlinking = isBlinking;
  }

  void _updateAngle(int change) {
    setState(() {
      _currentAngle += change;
      // Ensure angle stays within reasonable limits (e.g., -180 to 180 degrees)
      _currentAngle = math.max(-180, math.min(180, _currentAngle));
    });

    // Send the angle to the ESP32 via Bluetooth
    if (_bluetoothService.isConnected) {
      _bluetoothService.sendMotorAngle(_currentAngle);
    }
  }

  // Start scanning for ESP32 devices
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _bluetoothStatus = "Scanning...";
    });

    try {
      final devices = await _bluetoothService.startScan();
      setState(() {
        _devices = devices;
        _isScanning = false;
        _bluetoothStatus = devices.isEmpty
            ? "No devices found"
            : "Found ${devices.length} device(s)";
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _bluetoothStatus = "Scan error: $e";
      });
      debugPrint("Bluetooth scan error: $e");
    }
  }

  // Connect to an ESP32 device
  Future<void> _connectToDevice(fbp.BluetoothDevice device) async {
    setState(() {
      _bluetoothStatus = "Connecting...";
    });

    try {
      final connected = await _bluetoothService.connectToDevice(device);
      setState(() {
        _bluetoothStatus = connected ? "Connected" : "Failed to connect";
      });
    } catch (e) {
      setState(() {
        _bluetoothStatus = "Connection error";
      });
      debugPrint("Bluetooth connection error: $e");
    }
  }

  @override
  void dispose() {
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _faceDetector.close();
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing camera...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Eye Movement Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          // Add a debug toggle button
          IconButton(
            icon:
                Icon(_showDebugInfo ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
            },
            tooltip: 'Toggle debug info',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceVariant,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera preview
                    CameraPreview(_cameraController),

                    // Face overlay
                    CustomPaint(
                      painter: FaceOverlayPainter(
                        faces: _detectedFaces,
                        imageSize: Size(
                          _cameraController.value.previewSize?.height ?? 0,
                          _cameraController.value.previewSize?.width ?? 0,
                        ),
                        rotation: InputImageRotation.rotation90deg,
                        cameraLensDirection: widget.camera.lensDirection,
                      ),
                    ),

                    // Debug info
                    if (_showDebugInfo)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _debugText,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),

                    // Camera guide overlay
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Look at the camera and tilt your head slightly',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Eye movement info with icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getEyeMovementIcon(),
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Movement: ${_currentEyeMovement.name}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),

                      // Current angle with circular indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              value: (_currentAngle + 180) /
                                  360, // Normalize from -180:180 to 0:1
                              backgroundColor:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              color: Theme.of(context).colorScheme.secondary,
                              strokeWidth: 6,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Text(
                            'Angle: $_currentAngle°',
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),

                      // Bluetooth status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _bluetoothStatus == "Connected"
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _bluetoothStatus == "Connected"
                                ? Colors.green
                                : Colors.red,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bluetooth,
                              color: _bluetoothStatus == "Connected"
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _bluetoothStatus,
                              style: TextStyle(
                                color: _bluetoothStatus == "Connected"
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isScanning ? null : _startScan,
                            icon: const Icon(Icons.search),
                            label: const Text('Scan for ESP32'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _devices.isEmpty
                                ? null
                                : () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Select Device'),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _devices.length,
                                            itemBuilder: (context, index) {
                                              final device = _devices[index];
                                              return ListTile(
                                                leading:
                                                    const Icon(Icons.bluetooth),
                                                title: Text(
                                                    device.platformName.isEmpty
                                                        ? '(Unknown device)'
                                                        : device.platformName),
                                                subtitle: Text(
                                                    device.remoteId.toString()),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _connectToDevice(device);
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.link),
                            label: const Text('Connect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get icon based on eye movement
  IconData _getEyeMovementIcon() {
    switch (_currentEyeMovement) {
      case EyeMovement.up:
        return Icons.arrow_upward;
      case EyeMovement.down:
        return Icons.arrow_downward;
      case EyeMovement.blinking:
        return Icons.remove_red_eye;
      case EyeMovement.doubleBlinking:
        return Icons.visibility_off;
      case EyeMovement.neutral:
      default:
        return Icons.face;
    }
  }
}

// Add a custom painter to draw face overlays
class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    final Paint eyePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.yellow;

    for (final Face face in faces) {
      // Convert coordinates based on screen size
      final faceRect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
        rotation: rotation,
        cameraLensDirection: cameraLensDirection,
      );

      // Draw face rectangle
      canvas.drawRect(faceRect, paint);

      // Draw eyes
      if (face.leftEyeOpenProbability != null) {
        final leftEyeOpen = face.leftEyeOpenProbability! > 0.5;
        final leftEyeColor = leftEyeOpen ? Colors.green : Colors.red;

        // Approximate left eye position (since we don't have exact coordinates)
        final leftEyeRect = Rect.fromLTWH(
          faceRect.left + faceRect.width * 0.3,
          faceRect.top + faceRect.height * 0.33,
          faceRect.width * 0.15,
          faceRect.height * 0.10,
        );

        canvas.drawOval(leftEyeRect, eyePaint..color = leftEyeColor);
      }

      if (face.rightEyeOpenProbability != null) {
        final rightEyeOpen = face.rightEyeOpenProbability! > 0.5;
        final rightEyeColor = rightEyeOpen ? Colors.green : Colors.red;

        // Approximate right eye position
        final rightEyeRect = Rect.fromLTWH(
          faceRect.left + faceRect.width * 0.55,
          faceRect.top + faceRect.height * 0.33,
          faceRect.width * 0.15,
          faceRect.height * 0.10,
        );

        canvas.drawOval(rightEyeRect, eyePaint..color = rightEyeColor);
      }

      // Draw head angle indicator
      if (face.headEulerAngleX != null) {
        final arrowStart =
            Offset(faceRect.left + faceRect.width / 2, faceRect.top - 10);
        final arrowEnd = Offset(
          arrowStart.dx,
          arrowStart.dy -
              (face.headEulerAngleX! /
                  45 *
                  30), // Scale the angle for visualization
        );

        final arrowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.blue;

        canvas.drawLine(arrowStart, arrowEnd, arrowPaint);

        // Draw arrowhead
        final arrowheadSize = 5.0;
        final arrowVector = arrowEnd - arrowStart;
        final arrowDirection = arrowVector.direction;

        final leftArrowhead = Offset(
          arrowEnd.dx +
              arrowheadSize * math.cos(arrowDirection + math.pi * 3 / 4),
          arrowEnd.dy +
              arrowheadSize * math.sin(arrowDirection + math.pi * 3 / 4),
        );

        final rightArrowhead = Offset(
          arrowEnd.dx +
              arrowheadSize * math.cos(arrowDirection - math.pi * 3 / 4),
          arrowEnd.dy +
              arrowheadSize * math.sin(arrowDirection - math.pi * 3 / 4),
        );

        canvas.drawLine(arrowEnd, leftArrowhead, arrowPaint);
        canvas.drawLine(arrowEnd, rightArrowhead, arrowPaint);
      }
    }
  }

  // Helper method to scale the face rectangle to the widget size
  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    required InputImageRotation rotation,
    required CameraLensDirection cameraLensDirection,
  }) {
    // Handle different rotations
    final bool isScreenPortrait = widgetSize.height > widgetSize.width;
    final bool isCameraRotated = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;

    // Adjust for front camera mirroring
    final bool flipX = cameraLensDirection == CameraLensDirection.front;

    // Scale factors
    double scaleX = 1.0, scaleY = 1.0;
    double offsetX = 0.0, offsetY = 0.0;

    if (!isCameraRotated) {
      scaleX = widgetSize.width / imageSize.width;
      scaleY = widgetSize.height / imageSize.height;
    } else {
      scaleX = widgetSize.width / imageSize.height;
      scaleY = widgetSize.height / imageSize.width;
    }

    // Create scaled rectangle
    double scaledLeft, scaledTop, scaledWidth, scaledHeight;

    if (flipX) {
      scaledLeft = imageSize.width - rect.right;
    } else {
      scaledLeft = rect.left;
    }

    scaledLeft = scaledLeft * scaleX + offsetX;
    scaledTop = rect.top * scaleY + offsetY;
    scaledWidth = rect.width * scaleX;
    scaledHeight = rect.height * scaleY;

    return Rect.fromLTWH(scaledLeft, scaledTop, scaledWidth, scaledHeight);
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
