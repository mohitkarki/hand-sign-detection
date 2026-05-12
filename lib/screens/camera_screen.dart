import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/model_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {

  // Camera controller
  CameraController? _controller;

  // Camera list (front/back)
  List<CameraDescription> cameras = [];
  int cameraIndex = 0;

  // Model
  late ModelService modelService;

  // UI data
  String result = "Waiting...";
  double confidence = 0.0;

  // Control flags
  bool isDetecting = false;
  bool isRunning = true;

  // Voice
  final FlutterTts flutterTts = FlutterTts();
  String lastSpoken = "";

  // Stability
  List<String> predictionHistory = [];

  @override
  void initState() {
    super.initState();
    initEverything();
  }

  // INIT (MODEL + CAMERA)
  Future<void> initEverything() async {
    await loadModel();
    await initCamera();
  }

  Future<void> loadModel() async {
    modelService = ModelService();
    await modelService.loadModel();
  }

  // CAMERA INIT
  Future<void> initCamera() async {

    cameras = await availableCameras();

    // Use FRONT camera by default
    cameraIndex = cameras.indexWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
    );

    if (cameraIndex == -1) cameraIndex = 0;

    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();

    startDetection();

    setState(() {});
  }

  // SWITCH CAMERA
  Future<void> switchCamera() async {
    if (cameras.isEmpty) return;

    isRunning = false; // stop old loop
    await Future.delayed(const Duration(milliseconds: 300));

    cameraIndex = (cameraIndex + 1) % cameras.length;

    await _controller?.dispose();

    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();

    isRunning = true; // restart loop
    startDetection();

    setState(() {});
  }

  // DETECTION LOOP (FAST + STABLE)
  void startDetection() async {
    while (isRunning) {

      if (!isDetecting &&
          _controller != null &&
          _controller!.value.isInitialized) {

        isDetecting = true;

        try {
          // Capture frame
          XFile file = await _controller!.takePicture();

          // Run model
          var output = await modelService.predict(file.path);

          String newPrediction = output['label'];
          double conf = output['confidence'];

          // Confidence filter
          if (conf > 0.7) {

            // Reset history if new label appears
            if (predictionHistory.isNotEmpty &&
                predictionHistory.last != newPrediction) {
              predictionHistory.clear();
            }

            predictionHistory.add(newPrediction);

            // Keep small history (FAST + STABLE)
            if (predictionHistory.length > 3) {
              predictionHistory.removeAt(0);
            }
          }

          // Get stable result
          String stableResult = getStablePrediction();

          if (!mounted) return;

          setState(() {
            result = stableResult;
            confidence = conf * 100;
          });

          // 🔊 Speak only when changed
          if (stableResult != lastSpoken) {
            await speak(stableResult);
            lastSpoken = stableResult;
          }

        } catch (e) {
          debugPrint(e.toString());
        }

        isDetecting = false;
      }

      // Balanced delay (speed vs stability)
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // STABLE PREDICTION
  String getStablePrediction() {
    if (predictionHistory.isEmpty) return result;

    Map<String, int> countMap = {};

    for (var label in predictionHistory) {
      countMap[label] = (countMap[label] ?? 0) + 1;
    }

    String stable = predictionHistory.last;
    int maxCount = 0;

    countMap.forEach((key, value) {
      if (value > maxCount) {
        maxCount = value;
        stable = key;
      }
    });

    return stable;
  }

  // =========================
  // TEXT TO SPEECH
  // =========================
  Future<void> speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  // =========================
  // CLEANUP
  // =========================
  @override
  void dispose() {
    isRunning = false;
    _controller?.dispose();
    super.dispose();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Real-Time Detection")),

      body: Stack(
        children: [

          // Camera Preview
          CameraPreview(_controller!),

          // Prediction Box
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                children: [
                  Text(
                    "Prediction: $result",
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                  ),
                  Text(
                    "Confidence: ${confidence.toStringAsFixed(2)}%",
                    style: const TextStyle(color: Colors.green, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

          // Switch Camera Button
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton(
              onPressed: switchCamera,
              child: const Icon(Icons.cameraswitch),
            ),
          ),
        ],
      ),
    );
  }
}