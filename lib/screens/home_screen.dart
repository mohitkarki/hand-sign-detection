import 'package:flutter/material.dart';
import 'dart:io';
import '../services/model_service.dart';
import '../services/image_service.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  File? _image;

  String result = "No prediction yet";
  double confidence = 0.0;
  bool isLoading = false;
  bool isModelLoaded = false;

  final ModelService modelService = ModelService();

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  // Load TFLite model
  Future<void> loadModel() async {
    try {
      print("Loading model...");

      await modelService.loadModel();

      print("Model loaded successfully");

      setState(() {
        isModelLoaded = true;
      });

    } catch (e) {
      print("Model load error: $e");

      setState(() {
        result = "Model load failed";
      });
    }
  }

  // Pick image
  Future<void> pickImage() async {
    if (!isModelLoaded) {
      setState(() {
        result = "Model is still loading...";
      });
      return;
    }

    final pickedFile = await ImageService.pickImage();

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        isLoading = true;
      });

      runModel(pickedFile.path);
    }
  }

  // Run model locally (NO API)
  Future<void> runModel(String path) async {
    try {
      var output = await modelService.predict(path);

      setState(() {
        result = output['label'];
        confidence = output['confidence'] * 100;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        result = "Error: $e";
        isLoading = false;
      });
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hand Sign Detector")),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            _image != null
                ? Image.file(_image!, height: 200)
                : const Text("No Image Selected"),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isModelLoaded ? pickImage : null,
              child: Text(isModelLoaded ? "Capture Image" : "Loading Model..."),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isModelLoaded
                  ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CameraScreen(),
                  ),
                );
              }
                  : null,
              child: const Text("Real-Time Detection"),
            ),

            const SizedBox(height: 20),

            if (isLoading)
              const CircularProgressIndicator(),

            const SizedBox(height: 20),

            if (!isLoading) ...[
              Text(
                "Prediction: $result",
                style: const TextStyle(fontSize: 24),
              ),

              const SizedBox(height: 10),

              Text(
                "Confidence: ${confidence.toStringAsFixed(2)}%",
                style: const TextStyle(fontSize: 20, color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}