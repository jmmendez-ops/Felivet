import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CatGatekeeper {
  static const String _assetPath = 'assets/mobilenet_gatekeeper.tflite';
  static const int _size = 224;

  // ImageNet cat classes: tabby, tiger cat, Persian, Siamese, Egyptian cat.
  static const List<int> _catClassIds = [281, 282, 283, 284, 285];

  // Lower to 0.10-0.15 if real cats / fur close-ups get rejected.
  // Raise to 0.40 if random objects get through.
  static const double catThreshold = 0.25;

  Interpreter? _interpreter;

  Future<void> load() async {
    _interpreter ??= await Interpreter.fromAsset(_assetPath);
  }

  Future<double> catScore(Uint8List imageBytes) async {
    await load();

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Could not decode image');
    }

    final oriented = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      oriented,
      width: _size,
      height: _size,
      interpolation: img.Interpolation.linear,
    );

    final buffer = Float32List(_size * _size * 3);
    var i = 0;
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        final p = resized.getPixel(x, y);
        buffer[i++] = p.r / 127.5 - 1.0;
        buffer[i++] = p.g / 127.5 - 1.0;
        buffer[i++] = p.b / 127.5 - 1.0;
      }
    }

    final input = buffer.reshape([1, _size, _size, 3]);
    final output = List.filled(1 * 1000, 0.0).reshape([1, 1000]);
    _interpreter!.run(input, output);

    final row = output[0] as List;
    var score = 0.0;
    for (final id in _catClassIds) {
      score += (row[id] as num).toDouble();
    }
    return score;
  }

  Future<bool> isCat(
    Uint8List imageBytes, {
    double threshold = catThreshold,
  }) async {
    return (await catScore(imageBytes)) >= threshold;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
