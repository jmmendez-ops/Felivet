import 'dart:io';

import 'package:image/image.dart';

const iconSizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
  'app_icon_16': 16,
  'app_icon_32': 32,
  'app_icon_64': 64,
  'app_icon_128': 128,
  'app_icon_256': 256,
  'app_icon_512': 512,
  'Icon-App-20x20@1x': 20,
  'Icon-App-20x20@2x': 40,
  'Icon-App-20x20@3x': 60,
  'Icon-App-29x29@1x': 29,
  'Icon-App-29x29@2x': 58,
  'Icon-App-29x29@3x': 87,
  'Icon-App-40x40@1x': 40,
  'Icon-App-40x40@2x': 80,
  'Icon-App-40x40@3x': 120,
  'Icon-App-60x60@2x': 120,
  'Icon-App-60x60@3x': 180,
  'Icon-App-76x76@1x': 76,
  'Icon-App-76x76@2x': 152,
  'Icon-App-83.5x83.5@2x': 167,
  'Icon-App-1024x1024@1x': 1024,
};

ColorUint8 color(int r, int g, int b) => ColorUint8.rgb(r, g, b);

Image buildPawIcon(int size) {
  final purple = color(124, 77, 255);
  final white = color(255, 255, 255);
  final image = Image(width: size, height: size);
  fill(image, color: purple);

  final centerX = size ~/ 2;
  final centerY = size ~/ 2;
  final padRadius = (size * 0.24).toInt();
  final toeRadius = (size * 0.1).toInt();
  final toeOffset = (size * 0.16).toInt();

  fillCircle(
    image,
    x: centerX,
    y: centerY + (size * 0.08).toInt(),
    radius: padRadius,
    color: white,
  );

  fillCircle(
    image,
    x: centerX - toeOffset,
    y: centerY - toeOffset,
    radius: toeRadius,
    color: white,
  );
  fillCircle(
    image,
    x: centerX + toeOffset,
    y: centerY - toeOffset,
    radius: toeRadius,
    color: white,
  );
  fillCircle(
    image,
    x: centerX - toeOffset ~/ 2,
    y: centerY - toeOffset * 2,
    radius: toeRadius,
    color: white,
  );
  fillCircle(
    image,
    x: centerX + toeOffset ~/ 2,
    y: centerY - toeOffset * 2,
    radius: toeRadius,
    color: white,
  );

  return image;
}

void main() {
  final outputDir = Directory('tool_icons');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  for (final entry in iconSizes.entries) {
    final image = buildPawIcon(entry.value);
    final file = File('${outputDir.path}/${entry.key}.png');
    file.writeAsBytesSync(encodePng(image));
  }

  print('Generated ${iconSizes.length} paw icon files in ${outputDir.path}');
}
