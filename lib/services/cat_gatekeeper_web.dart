import 'dart:typed_data';

class CatGatekeeper {
  static const double catThreshold = 0.25;

  Future<void> load() async {}

  Future<double> catScore(Uint8List imageBytes) async {
    throw UnsupportedError(
      'Cat detection is not available on web. Please use the mobile app.',
    );
  }

  Future<bool> isCat(
    Uint8List imageBytes, {
    double threshold = catThreshold,
  }) async {
    return false;
  }

  void close() {}
}
