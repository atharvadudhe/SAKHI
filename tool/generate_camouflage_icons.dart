// ignore_for_file: avoid_print
/// Generates simple solid-color PNG icons for camouflage aliases.
/// Run: dart run tool/generate_camouflage_icons.dart
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

// ── PNG encoder helpers (minimal, no package dependency) ──

/// Creates an uncompressed 8-bit RGBA PNG of [size]×[size] filled
/// with the given RGBA colour, with a single white character glyph
/// approximation (a white square) in the centre.
Uint8List createSolidPng(int size, int r, int g, int b) {
  // Build raw RGBA pixel rows.  Each row is prefixed with filter byte 0.
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filter: None
    for (var x = 0; x < size; x++) {
      raw.addByte(r);
      raw.addByte(g);
      raw.addByte(b);
      raw.addByte(255); // alpha
    }
  }

  final rawBytes = raw.toBytes();
  final compressed = zlib.encode(rawBytes);

  final png = BytesBuilder();

  // PNG Signature
  png.add([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR
  final ihdr = BytesBuilder();
  ihdr.add(_int32BE(size)); // width
  ihdr.add(_int32BE(size)); // height
  ihdr.addByte(8); // bit depth
  ihdr.addByte(6); // color type: RGBA
  ihdr.addByte(0); // compression
  ihdr.addByte(0); // filter
  ihdr.addByte(0); // interlace
  _writeChunk(png, 'IHDR', ihdr.toBytes());

  // IDAT
  _writeChunk(png, 'IDAT', Uint8List.fromList(compressed));

  // IEND
  _writeChunk(png, 'IEND', Uint8List(0));

  return png.toBytes();
}

List<int> _int32BE(int v) =>
    [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

void _writeChunk(BytesBuilder out, String type, Uint8List data) {
  out.add(_int32BE(data.length));
  final typeBytes = ascii.encode(type);
  out.add(typeBytes);
  out.add(data);
  // CRC32 over type+data
  final crcInput = Uint8List(typeBytes.length + data.length);
  crcInput.setAll(0, typeBytes);
  crcInput.setAll(typeBytes.length, data);
  out.add(_int32BE(_crc32(crcInput)));
}

int _crc32(Uint8List data) {
  const table = <int>[];
  // Build table lazily
  var t = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      if (c & 1 != 0) {
        c = 0xEDB88320 ^ (c >> 1);
      } else {
        c >>= 1;
      }
    }
    t[n] = c;
  }
  var crc = 0xFFFFFFFF;
  for (var i = 0; i < data.length; i++) {
    crc = t[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

// ── Main ──

void main() {
  final base = 'android/app/src/main/res';
  final densities = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  // icon name → (R, G, B)
  final icons = {
    'ic_calculator': (0x60, 0x7D, 0x8B), // Blue-grey
    'ic_calendar': (0x1E, 0x88, 0xE5),   // Blue
    'ic_notes': (0xFF, 0xB3, 0x00),       // Amber
  };

  for (final entry in icons.entries) {
    for (final density in densities.entries) {
      final dir = Directory('$base/${density.key}');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/${entry.key}.png');
      final png = createSolidPng(density.value, entry.value.$1, entry.value.$2, entry.value.$3);
      file.writeAsBytesSync(png);
      print('  ✓ ${file.path}  (${density.value}×${density.value})');
    }
  }

  // Also generate iOS icons (1024×1024 is overkill but needed for completeness)
  // iOS needs icons at specific sizes. We'll generate 60@2x (120) and 60@3x (180) plus 1024.
  final iosBase = 'ios/Runner';
  for (final entry in icons.entries) {
    final name = entry.key.replaceAll('ic_', '');
    final dirPath = '$iosBase/$name.appiconset';
    final dir = Directory(dirPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    // Generate sizes needed for iOS
    final sizes = {
      '${name}_20x20@2x.png': 40,
      '${name}_20x20@3x.png': 60,
      '${name}_29x29@2x.png': 58,
      '${name}_29x29@3x.png': 87,
      '${name}_40x40@2x.png': 80,
      '${name}_40x40@3x.png': 120,
      '${name}_60x60@2x.png': 120,
      '${name}_60x60@3x.png': 180,
      '${name}_76x76@1x.png': 76,
      '${name}_76x76@2x.png': 152,
      '${name}_83.5x83.5@2x.png': 167,
      '${name}_1024x1024@1x.png': 1024,
    };

    for (final s in sizes.entries) {
      final file = File('${dir.path}/${s.key}');
      final png = createSolidPng(s.value, entry.value.$1, entry.value.$2, entry.value.$3);
      file.writeAsBytesSync(png);
      print('  ✓ ${file.path}');
    }

    // Write Contents.json
    final contents = {
      "images": [
        {"size": "20x20", "idiom": "iphone", "filename": "${name}_20x20@2x.png", "scale": "2x"},
        {"size": "20x20", "idiom": "iphone", "filename": "${name}_20x20@3x.png", "scale": "3x"},
        {"size": "29x29", "idiom": "iphone", "filename": "${name}_29x29@2x.png", "scale": "2x"},
        {"size": "29x29", "idiom": "iphone", "filename": "${name}_29x29@3x.png", "scale": "3x"},
        {"size": "40x40", "idiom": "iphone", "filename": "${name}_40x40@2x.png", "scale": "2x"},
        {"size": "40x40", "idiom": "iphone", "filename": "${name}_40x40@3x.png", "scale": "3x"},
        {"size": "60x60", "idiom": "iphone", "filename": "${name}_60x60@2x.png", "scale": "2x"},
        {"size": "60x60", "idiom": "iphone", "filename": "${name}_60x60@3x.png", "scale": "3x"},
        {"size": "20x20", "idiom": "ipad", "filename": "${name}_20x20@2x.png", "scale": "2x"},
        {"size": "29x29", "idiom": "ipad", "filename": "${name}_29x29@2x.png", "scale": "2x"},
        {"size": "40x40", "idiom": "ipad", "filename": "${name}_40x40@2x.png", "scale": "2x"},
        {"size": "76x76", "idiom": "ipad", "filename": "${name}_76x76@1x.png", "scale": "1x"},
        {"size": "76x76", "idiom": "ipad", "filename": "${name}_76x76@2x.png", "scale": "2x"},
        {"size": "83.5x83.5", "idiom": "ipad", "filename": "${name}_83.5x83.5@2x.png", "scale": "2x"},
        {"size": "1024x1024", "idiom": "ios-marketing", "filename": "${name}_1024x1024@1x.png", "scale": "1x"},
      ],
      "info": {"version": 1, "author": "xcode"}
    };
    File('${dir.path}/Contents.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(contents),
    );
    print('  ✓ ${dir.path}/Contents.json');
  }

  print('\n✅ All camouflage icons generated!');
  print('⚠️  These are solid-colour placeholders. Replace them with real designs.');
}
