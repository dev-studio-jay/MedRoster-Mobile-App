import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

Future<void> _exportPng(String outputPath, int size) async {
  final svgString = await rootBundle.loadString('assets/icon/app_icon.svg');
  final pictureInfo = await vg.loadPicture(SvgStringLoader(svgString), null);
  final image = await pictureInfo.picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(outputPath).writeAsBytes(byteData!.buffer.asUint8List());
  pictureInfo.picture.dispose();
  image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export launcher icon PNGs from SVG', () async {
    await _exportPng('assets/icon/app_icon.png', 1024);
    await _exportPng('assets/icon/app_icon_512.png', 512);
    expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
    expect(File('assets/icon/app_icon_512.png').existsSync(), isTrue);
  });
}
