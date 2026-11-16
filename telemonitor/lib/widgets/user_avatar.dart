import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_photo_service.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// Initials of a name: first letters of the first and last words, '?' if empty.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// A person's photo when they have set one and the viewer may see it;
/// otherwise their initials, or [fallbackIcon] when given.
class UserAvatar extends StatefulWidget {
  final String? uid;
  final String name;
  final double size;
  final Color background;
  final Color foreground;

  /// Corner radius; null for a circle.
  final double? radius;
  final BoxBorder? border;
  final IconData? fallbackIcon;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.uid,
    required this.name,
    required this.size,
    this.background = AppColors.primary,
    this.foreground = Colors.white,
    this.radius,
    this.border,
    this.fallbackIcon,
    this.fontSize,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Stream<Uint8List?>? _photo;

  void _subscribe() {
    final uid = widget.uid;
    _photo = (uid == null || uid.isEmpty) ? null : ProfilePhotoService.instance.watch(uid);
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(UserAvatar old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: widget.fallbackIcon != null
          ? Icon(widget.fallbackIcon, color: widget.foreground, size: widget.size * 0.5)
          : Text(
              initialsOf(widget.name),
              style: TextStyle(
                color: widget.foreground,
                fontWeight: FontWeight.bold,
                fontSize: widget.fontSize ?? widget.size * 0.34,
              ),
            ),
    );
    final content = _photo == null
        ? fallback
        : StreamBuilder<Uint8List?>(
            stream: _photo,
            builder: (_, snap) => snap.data == null
                ? fallback
                : Image.memory(
                    snap.data!,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    semanticLabel: context.l10n.photoOf(widget.name),
                  ),
          );
    final circle = widget.radius == null;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.background,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(widget.radius!),
        border: widget.border,
      ),
      child: circle
          ? ClipOval(child: content)
          : ClipRRect(borderRadius: BorderRadius.circular(widget.radius!), child: content),
    );
  }
}

/// Bottom sheet to take, choose or remove the signed-in person's photo.
/// [uid] is theirs; [forClinician] sets who is told they will see it.
Future<void> showProfilePhotoSheet(BuildContext context,
    {required String uid, required bool forClinician}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: StreamBuilder<Uint8List?>(
        stream: ProfilePhotoService.instance.watch(uid),
        builder: (_, snap) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(sheet.l10n.profilePhoto,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText(sheet))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                forClinician ? sheet.l10n.photoNoteClinician : sheet.l10n.photoNotePatient,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary(sheet), height: 1.4),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(sheet.l10n.takePhoto),
              onTap: () => _act(sheet, context, () => ProfilePhotoService.instance.pickAndSave(ImageSource.camera)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(sheet.l10n.chooseFromGallery),
              onTap: () => _act(sheet, context, () => ProfilePhotoService.instance.pickAndSave(ImageSource.gallery)),
            ),
            if (snap.data != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.dangerText(sheet)),
                title: Text(sheet.l10n.removePhoto, style: TextStyle(color: AppColors.dangerText(sheet))),
                onTap: () => _act(sheet, context, () async {
                  await ProfilePhotoService.instance.remove();
                  return true;
                }, done: sheet.l10n.photoRemoved),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Future<void> _act(BuildContext sheet, BuildContext page, Future<bool> Function() action,
    {String? done}) async {
  final l10n = sheet.l10n;
  done ??= l10n.photoSaved;
  Navigator.pop(sheet);
  final messenger = ScaffoldMessenger.of(page);
  try {
    if (await action()) messenger.showSnackBar(SnackBar(content: Text(done)));
  } on TimeoutException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.savedOffline)));
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.photoNotUpdated('$e'))));
  }
}
