// ignore_for_file: avoid_print
/// Resizes the real camouflage icon PNGs into all required
/// Android mipmap and iOS icon sizes.
///
/// Run:  dart run tool/resize_camouflage_icons.dart
library;

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final icons = {
    'calculator': 'assets/images/calculator.png',
    'calendar':   'assets/images/calendar.png',
    'notes':      'assets/images/notes.png',
    'lotus':      'assets/images/Lotus.png',
    'sakhi':      'assets/images/Sakhi.png',
    'sakhi_hindi': 'assets/images/सखी.png',
  };

  // ── Android densities ──
  final androidDensities = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
  };

  // ── iOS sizes ──
  final iosSizes = <String, int>{
    '20x20@2x':      40,
    '20x20@3x':      60,
    '29x29@2x':      58,
    '29x29@3x':      87,
    '40x40@2x':      80,
    '40x40@3x':      120,
    '60x60@2x':      120,
    '60x60@3x':      180,
    '76x76@1x':      76,
    '76x76@2x':      152,
    '83.5x83.5@2x':  167,
    '1024x1024@1x':  1024,
  };

  for (final entry in icons.entries) {
    final name = entry.key;
    final srcPath = entry.value;
    final srcFile = File(srcPath);

    if (!srcFile.existsSync()) {
      print('  ✗ Source not found: $srcPath');
      continue;
    }

    final srcBytes = srcFile.readAsBytesSync();
    final srcImage = img.decodePng(srcBytes);
    if (srcImage == null) {
      print('  ✗ Failed to decode: $srcPath');
      continue;
    }

    print('Processing $name (${srcImage.width}×${srcImage.height})...');

    // ── Android ──
    for (final d in androidDensities.entries) {
      final dir = Directory('android/app/src/main/res/${d.key}');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final resized = img.copyResize(srcImage, width: d.value, height: d.value,
          interpolation: img.Interpolation.average);
      final outPath = '${dir.path}/ic_$name.png';
      File(outPath).writeAsBytesSync(img.encodePng(resized));
      print('  ✓ $outPath  (${d.value}×${d.value})');
    }

    // ── iOS ──
    final iosDir = Directory('ios/Runner/$name.appiconset');
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    for (final s in iosSizes.entries) {
      final size = s.value;
      final resized = img.copyResize(srcImage, width: size, height: size,
          interpolation: img.Interpolation.average);
      final filename = '${name}_${s.key}.png';
      final outPath = '${iosDir.path}/$filename';
      File(outPath).writeAsBytesSync(img.encodePng(resized));
      print('  ✓ $outPath');
    }

    print('  ✓ $name done\n');
  }

  print('✅ All camouflage icons resized from real source images!');
}
