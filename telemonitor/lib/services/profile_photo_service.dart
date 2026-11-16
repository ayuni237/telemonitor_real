import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import '../l10n/l10n.dart';

/// Optional profile photo of a patient or a clinician.
///
/// Stored as a small square JPEG (at most [side] pixels a side, about 20 KB)
/// in `users/{uid}/photo/current`, a document of its own so that reading a
/// profile or the roster never downloads photos. Firestore rather than Cloud
/// Storage: since February 2026 Cloud Storage needs the Blaze plan, and the
/// project runs on the free Spark plan.
///
/// Who sees it (firestore.rules): the person; for a patient, their assigned
/// clinician; for a clinician, their patients. Nobody else.
class ProfilePhotoService {
  ProfilePhotoService._();
  static final ProfilePhotoService instance = ProfilePhotoService._();

  static const int side = 256;
  static const int quality = 75;

  /// Upper bound on the stored photo, also enforced by the security rules.
  static const int maxBytes = 150 * 1024;

  /// False where Firebase is not initialised (screen tests): avatars then
  /// show initials.
  bool get available => Firebase.apps.isNotEmpty;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('photo').doc('current');

  /// The photo of [uid]; null when there is none or it may not be read.
  Stream<Uint8List?> watch(String uid) {
    if (!available) return Stream.value(null);
    return _doc(uid)
        .snapshots()
        .map<Uint8List?>((d) {
          final b = d.data()?['image'];
          return b is Blob ? b.bytes : null;
        })
        .transform(StreamTransformer<Uint8List?, Uint8List?>.fromHandlers(
          handleError: (_, _, sink) => sink.add(null),
        ));
  }

  /// The stored form of a photo: centre square, at most [side] pixels a side,
  /// orientation applied, transparency on white, JPEG.
  static Uint8List encode(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) {
      throw FormatException(l10nNow.notAnImage);
    }
    var im = img.bakeOrientation(decoded);
    final s = math.min(im.width, im.height);
    im = img.copyCrop(im, x: (im.width - s) ~/ 2, y: (im.height - s) ~/ 2, width: s, height: s);
    if (s > side) {
      im = img.copyResize(im, width: side, height: side, interpolation: img.Interpolation.average);
    }
    if (im.numChannels == 4) {
      final white = img.Image(width: im.width, height: im.height);
      img.fill(white, color: img.ColorRgb8(255, 255, 255));
      im = img.compositeImage(white, im);
    }
    final out = Uint8List.fromList(img.encodeJpg(im, quality: quality));
    if (out.length > maxBytes) {
      throw FormatException(l10nNow.photoTooLarge);
    }
    return out;
  }

  /// Takes or chooses a photo and saves it. False when the person cancels.
  /// Offline, the photo is kept on the phone and sent when the connection
  /// returns; [TimeoutException] tells the caller so.
  Future<bool> pickAndSave(ImageSource source) async {
    final uid = AuthService.instance.currentFirebaseUser?.uid;
    if (uid == null) throw StateError('Not signed in.');
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return false;
    final bytes = encode(await file.readAsBytes());
    await _doc(uid)
        .set({'image': Blob(bytes), 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(const Duration(seconds: 15));
    return true;
  }

  /// Removes the signed-in person's photo.
  Future<void> remove() async {
    final uid = AuthService.instance.currentFirebaseUser?.uid;
    if (uid == null) throw StateError('Not signed in.');
    await _doc(uid).delete().timeout(const Duration(seconds: 15));
  }
}
