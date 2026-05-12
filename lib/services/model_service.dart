import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

class ModelService {
  late Interpreter _interpreter;
  List<String> _labels = [];

  // Load model + labels
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/model.tflite');

    // Load labels
    final labelData = await rootBundle.loadString('assets/labels.txt');
    _labels = labelData.split('\n');

    print("Model & Labels Loaded");
  }

  // Predict function
  Future<Map<String, dynamic>> predict(String imagePath) async {
    // Load image
    File imageFile = File(imagePath);
    img.Image? image = img.decodeImage(imageFile.readAsBytesSync());

    if (image == null) {
      throw Exception("Image decoding failed");
    }

    // Preprocess
    img.Image resized = img.copyResize(image, width: 224, height: 224);

    var input = Float32List(1 * 224 * 224 * 3);
    int index = 0;

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        var pixel = resized.getPixel(x, y);

        input[index++] = pixel.r / 255.0;
        input[index++] = pixel.g / 255.0;
        input[index++] = pixel.b / 255.0;
      }
    }

    // Output buffer
    var output = List.generate(1, (_) => List.filled(_labels.length, 0.0));

    // Run model
    _interpreter.run(input.reshape([1, 224, 224, 3]), output);

    // Find best prediction
    int maxIndex = 0;
    double maxValue = output[0][0];

    for (int i = 1; i < output[0].length; i++) {
      if (output[0][i] > maxValue) {
        maxValue = output[0][i];
        maxIndex = i;
      }
    }

    return {
      "label": _labels[maxIndex],
      "confidence": maxValue,
    };
  }
}