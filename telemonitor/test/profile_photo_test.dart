import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:telemonitor/services/profile_photo_service.dart';
import 'package:telemonitor/widgets/user_avatar.dart';

/// A gradient PNG of the given size, opaque or fully transparent.
Uint8List _png(int w, int h, {bool transparent = false}) {
  final im = img.Image(width: w, height: h, numChannels: transparent ? 4 : 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgba(x, y, (x * 255) ~/ w, (y * 255) ~/ h, 128, transparent ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  group('stored photo', () {
    test('a large landscape photo becomes a 256 px square JPEG under the size limit', () {
      final out = ProfilePhotoService.encode(_png(1200, 800));
      final back = img.decodeJpg(out)!;
      expect([back.width, back.height], [256, 256]);
      expect(out.sublist(0, 2), [0xFF, 0xD8]); // JPEG signature
      expect(out.length, lessThan(ProfilePhotoService.maxBytes));
    });

    test('a small photo is cropped to a square but not enlarged', () {
      final back = img.decodeJpg(ProfilePhotoService.encode(_png(120, 90)))!;
      expect([back.width, back.height], [90, 90]);
    });

    test('transparent areas become white', () {
      final back = img.decodeJpg(ProfilePhotoService.encode(_png(64, 64, transparent: true)))!;
      final p = back.getPixel(32, 32);
      expect([p.r, p.g, p.b].every((c) => c > 240), isTrue);
    });

    test('a file that is not an image is refused', () {
      expect(() => ProfilePhotoService.encode(Uint8List.fromList([1, 2, 3, 4])), throwsFormatException);
    });
  });

  group('initials', () {
    test('first and last words of the name', () {
      expect(initialsOf('Nsame Ayuni Rodrick'), 'NR');
      expect(initialsOf('  alice  '), 'A');
      expect(initialsOf(''), '?');
    });

    testWidgets('without Firebase (screen tests) the avatar shows the initials', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: UserAvatar(uid: 'u1', name: 'Malong Yannick', size: 40)),
      ));
      await tester.pump();
      expect(find.text('MY'), findsOneWidget);
    });

    testWidgets('with no uid, the fallback icon is used when given', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: UserAvatar(uid: null, name: 'Clinician', size: 36, fallbackIcon: Icons.medical_services_outlined),
        ),
      ));
      expect(find.byIcon(Icons.medical_services_outlined), findsOneWidget);
    });
  });
}
