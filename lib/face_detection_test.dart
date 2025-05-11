// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'dart:io';
// import 'dart:ui' as ui;

// class FaceDetectionStaticTest extends StatefulWidget {
//   const FaceDetectionStaticTest({super.key});

//   @override
//   State<FaceDetectionStaticTest> createState() =>
//       _FaceDetectionStaticTestState();
// }

// class _FaceDetectionStaticTestState extends State<FaceDetectionStaticTest> {
//   late FaceDetector _faceDetector;
//   List<Face> _faces = [];
//   bool _isProcessing = false;
//   ui.Image? _image;
//   String _statusText = "Initializing...";
//   String _lastError = "";

//   @override
//   void initState() {
//     super.initState();
//     _initializeFaceDetector();
//     _loadTestImage();
//   }

//   void _initializeFaceDetector() {
//     final options = FaceDetectorOptions(
//       enableContours: true,
//       enableClassification: true,
//       enableTracking: true,
//       performanceMode: FaceDetectorMode.fast,
//       minFaceSize: 0.1,
//     );
//     _faceDetector = FaceDetector(options: options);
//     _statusText = "Face detector initialized";
//     setState(() {});
//   }

//   Future<void> _loadTestImage() async {
//     try {
//       // Load a test image from assets
//       // You'll need to add this image to your assets folder and pubspec.yaml
//       final ByteData data = await rootBundle.load('assets/test_face.jpg');
//       final Uint8List bytes = data.buffer.asUint8List();

//       // Decode the image
//       final codec = await ui.instantiateImageCodec(bytes);
//       final frameInfo = await codec.getNextFrame();

//       setState(() {
//         _image = frameInfo.image;
//         _statusText = "Test image loaded";
//       });

//       // Process the image for face detection
//       await _detectFacesInImage(bytes);
//     } catch (e) {
//       setState(() {
//         _statusText = "Error loading test image: $e";
//         _lastError = e.toString();
//       });
//       print("Error loading test image: $e");
//     }
//   }

//   Future<void> _detectFacesInImage(Uint8List imageBytes) async {
//     if (_isProcessing) return;
//     _isProcessing = true;

//     try {
//       // Create a temporary file to use with ML Kit
//       final tempDir = Directory.systemTemp;
//       final tempFile = File('${tempDir.path}/temp_test_face.jpg');
//       await tempFile.writeAsBytes(imageBytes);

//       // Create InputImage from file path
//       final inputImage = InputImage.fromFilePath(tempFile.path);

//       // Process the image
//       final faces = await _faceDetector.processImage(inputImage);

//       setState(() {
//         _faces = faces;
//         _statusText = "Faces detected: ${faces.length}";

//         if (faces.isNotEmpty) {
//           Face face = faces.first;
//           _statusText +=
//               "\nLeft eye: ${face.leftEyeOpenProbability?.toStringAsFixed(2) ?? 'unknown'}";
//           _statusText +=
//               "\nRight eye: ${face.rightEyeOpenProbability?.toStringAsFixed(2) ?? 'unknown'}";
//           _statusText +=
//               "\nHead X: ${face.headEulerAngleX?.toStringAsFixed(2) ?? 'unknown'}";
//         }
//       });

//       // Clean up
//       await tempFile.delete();
//     } catch (e) {
//       setState(() {
//         _statusText = "Face detection error: $e";
//         _lastError = e.toString();
//       });
//       print("Face detection error: $e");
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   @override
//   void dispose() {
//     _faceDetector.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Static Face Detection Test'),
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             flex: 3,
//             child: Stack(
//               fit: StackFit.expand,
//               children: [
//                 // Display the test image
//                 if (_image != null)
//                   Center(
//                     child: CustomPaint(
//                       painter: TestImagePainter(
//                         image: _image!,
//                         faces: _faces,
//                       ),
//                       size: Size(
//                         MediaQuery.of(context).size.width,
//                         MediaQuery.of(context).size.width *
//                             _image!.height /
//                             _image!.width,
//                       ),
//                     ),
//                   ),

//                 // Status display
//                 Positioned(
//                   top: 10,
//                   left: 10,
//                   child: Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.5),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       _statusText,
//                       style: const TextStyle(color: Colors.white, fontSize: 14),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.all(16.0),
//             color: _faces.isEmpty
//                 ? Colors.red.withOpacity(0.2)
//                 : Colors.green.withOpacity(0.2),
//             child: Column(
//               children: [
//                 Text(
//                   'Face Detection Status: ${_faces.isEmpty ? "No face detected" : "${_faces.length} face(s) detected"}',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: _faces.isEmpty
//                         ? Colors.red.shade800
//                         : Colors.green.shade800,
//                   ),
//                 ),
//                 if (_lastError.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 8.0),
//                     child: Text(
//                       "Error: $_lastError",
//                       style: const TextStyle(color: Colors.red, fontSize: 12),
//                     ),
//                   ),

//                 // Add a button to reload the image and test again
//                 Padding(
//                   padding: const EdgeInsets.only(top: 16.0),
//                   child: ElevatedButton(
//                     onPressed: () {
//                       _loadTestImage();
//                     },
//                     child: const Text("Retest with Static Image"),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class TestImagePainter extends CustomPainter {
//   final ui.Image image;
//   final List<Face> faces;

//   TestImagePainter({
//     required this.image,
//     required this.faces,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     // Draw the image
//     final paint = Paint();
//     canvas.drawImageRect(
//       image,
//       Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
//       Rect.fromLTWH(0, 0, size.width, size.height),
//       paint,
//     );

//     // Draw face rectangles
//     final facePaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3.0
//       ..color = Colors.green;

//     for (final face in faces) {
//       // Scale the face rectangle to match the displayed image size
//       final scaleX = size.width / image.width;
//       final scaleY = size.height / image.height;

//       final scaledRect = Rect.fromLTWH(
//         face.boundingBox.left * scaleX,
//         face.boundingBox.top * scaleY,
//         face.boundingBox.width * scaleX,
//         face.boundingBox.height * scaleY,
//       );

//       canvas.drawRect(scaledRect, facePaint);
//     }
//   }

//   @override
//   bool shouldRepaint(TestImagePainter oldDelegate) {
//     return oldDelegate.image != image || oldDelegate.faces != faces;
//   }
// }

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

/// This approach uses a different method to get face detection working
/// by temporarily saving camera frames to files
class FaceDetectionTempFileTest extends StatefulWidget {
  const FaceDetectionTempFileTest({super.key});

  @override
  State<FaceDetectionTempFileTest> createState() =>
      _FaceDetectionTempFileTestState();
}

class _FaceDetectionTempFileTestState extends State<FaceDetectionTempFileTest> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  List<Face> _faces = [];
  bool _isProcessing = false;
  String _statusText = "Initializing...";
  String _lastError = "";
  bool _mounted = true;

  // For frame capturing via XFile
  int _frameSkip = 0;
  int _frameSkipCount = 8; // Process fewer frames for better performance

  @override
  void initState() {
    super.initState();
    _initializeFaceDetector();
    _initializeCamera();
  }

  @override
  void dispose() {
    _mounted = false;
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.1,
    );
    _faceDetector = FaceDetector(options: options);
    _statusText = "Face detector initialized";
    setState(() {});
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _statusText = "No cameras available";
      setState(() {});
      return;
    }

    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low, // Lower resolution for faster processing
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();

      if (!_mounted) return;

      setState(() {
        _statusText = "Camera initialized";
      });

      // Start a timer to regularly take pictures
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!_mounted) {
          timer.cancel();
          return;
        }

        // Skip frames to reduce CPU load
        if (_frameSkip < _frameSkipCount) {
          _frameSkip++;
          return;
        }
        _frameSkip = 0;

        if (!_isProcessing &&
            _cameraController != null &&
            _cameraController!.value.isInitialized) {
          _captureAndDetectFaces();
        }
      });
    } catch (e) {
      _statusText = "Camera error: $e";
      _lastError = e.toString();
      print("Camera initialization error: $e");
      if (_mounted) setState(() {});
    }
  }

  Future<void> _captureAndDetectFaces() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Take a picture
      final XFile file = await _cameraController!.takePicture();

      if (!_mounted) return;

      // Process the image
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (!_mounted) return;

      print("Faces detected: ${faces.length}");

      setState(() {
        _faces = faces;
        _statusText = "Faces: ${faces.length}";

        if (faces.isNotEmpty) {
          Face face = faces.first;
          _statusText +=
              "\nLeft eye: ${face.leftEyeOpenProbability?.toStringAsFixed(2) ?? 'unknown'}";
          _statusText +=
              "\nRight eye: ${face.rightEyeOpenProbability?.toStringAsFixed(2) ?? 'unknown'}";
          _statusText +=
              "\nHead X: ${face.headEulerAngleX?.toStringAsFixed(2) ?? 'unknown'}";
        }
      });

      // Clean up the temporary file
      try {
        File(file.path).deleteSync();
      } catch (e) {
        print("Error deleting temporary file: $e");
      }
    } catch (e) {
      if (!_mounted) return;

      setState(() {
        _statusText = "Processing error: $e";
        _lastError = e.toString();
      });
      print("Face detection error: $e");
    } finally {
      if (_mounted) _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Face Detection Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_statusText),
              if (_lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Error: $_lastError",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Face Detection Test')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                CameraPreview(_cameraController!),

                // Face overlay painter
                CustomPaint(
                  painter: FaceOverlayPainter(
                    faces: _faces,
                    previewSize: _cameraController!.value.previewSize!,
                    screenSize: MediaQuery.of(context).size,
                    cameraLensDirection:
                        _cameraController!.description.lensDirection,
                  ),
                ),

                // Face outline guide
                if (_faces.isEmpty)
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.blue.withOpacity(0.5), width: 2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Center(
                        child: Text(
                          "Position your face here",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Status display
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
                      _statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: _faces.isEmpty
                ? Colors.red.withOpacity(0.2)
                : Colors.green.withOpacity(0.2),
            child: Column(
              children: [
                Text(
                  'Face Detection Status: ${_faces.isEmpty ? "No face detected" : "${_faces.length} face(s) detected"}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _faces.isEmpty
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                if (_faces.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        Text(
                          'Troubleshooting tips:',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Make sure your face is clearly visible\n'
                          '• Avoid extreme angles\n'
                          '• Check for good lighting\n'
                          '• Move closer to the camera',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Add a button to force a capture
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton(
                    onPressed: _captureAndDetectFaces,
                    child: const Text("Force Detect Face"),
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

class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size previewSize;
  final Size screenSize;
  final CameraLensDirection cameraLensDirection;

  FaceOverlayPainter({
    required this.faces,
    required this.previewSize,
    required this.screenSize,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    for (final Face face in faces) {
      // Calculate scaling factors
      final double scaleX = size.width / previewSize.width;
      final double scaleY = size.height / previewSize.height;

      // Adjust for front camera mirroring
      double left = face.boundingBox.left;
      if (cameraLensDirection == CameraLensDirection.front) {
        left = previewSize.width - face.boundingBox.right;
      }

      // Scale face rectangle to preview size
      final scaledRect = Rect.fromLTWH(
        left * scaleX,
        face.boundingBox.top * scaleY,
        face.boundingBox.width * scaleX,
        face.boundingBox.height * scaleY,
      );

      // Draw face rectangle
      canvas.drawRect(scaledRect, paint);

      // Draw face ID if available
      if (face.trackingId != null) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: "ID: ${face.trackingId}",
            style: const TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(scaledRect.left, scaledRect.top - 20),
        );
      }

      // Draw eyes if probability values are available
      if (face.leftEyeOpenProbability != null ||
          face.rightEyeOpenProbability != null) {
        final eyePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        if (face.leftEyeOpenProbability != null) {
          final bool isOpen = face.leftEyeOpenProbability! > 0.5;
          eyePaint.color = isOpen ? Colors.green : Colors.red;

          final leftEyeRect = Rect.fromLTWH(
            scaledRect.left + scaledRect.width * 0.3,
            scaledRect.top + scaledRect.height * 0.33,
            scaledRect.width * 0.15,
            scaledRect.height * 0.1,
          );

          canvas.drawOval(leftEyeRect, eyePaint);
        }

        if (face.rightEyeOpenProbability != null) {
          final bool isOpen = face.rightEyeOpenProbability! > 0.5;
          eyePaint.color = isOpen ? Colors.green : Colors.red;

          final rightEyeRect = Rect.fromLTWH(
            scaledRect.left + scaledRect.width * 0.55,
            scaledRect.top + scaledRect.height * 0.33,
            scaledRect.width * 0.15,
            scaledRect.height * 0.1,
          );

          canvas.drawOval(rightEyeRect, eyePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
