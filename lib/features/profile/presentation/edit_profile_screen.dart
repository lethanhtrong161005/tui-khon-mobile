import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';

/// Edits the profile: avatar, display name and phone. The email is the login
/// identity and is shown read-only.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen(
      {super.key,
      this.initialName = '',
      this.initialPhone = '',
      this.initialEmail = ''});

  factory EditProfileScreen.fromProfile(UserProfile? profile, {Key? key}) =>
      EditProfileScreen(
        key: key,
        initialName: profile?.name ?? '',
        initialPhone: profile?.phone ?? '',
        initialEmail: profile?.email ?? '',
      );

  final String initialName;
  final String initialPhone;
  final String initialEmail;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _phone = TextEditingController(text: widget.initialPhone);
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _saving = false;
  bool _uploading = false;

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text(appL10n(context).msgTakePhoto335),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(appL10n(context).msgChooseFromLibrary336),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final isPng = file.name.toLowerCase().endsWith('.png');
      await ref.read(authRepositoryProvider).uploadAvatar(
            await file.readAsBytes(),
            extension: isPng ? 'png' : 'jpg',
            mimeType: isPng ? 'image/png' : 'image/jpeg',
          );
      ref.invalidate(profileProvider);
      if (mounted)
        showToast(context, appL10n(context).msgProfilePhotoUpdated337);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty)
      return showToast(context, appL10n(context).msgEnterADisplayName122);
    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateProfile(displayName: _name.text, phone: _phone.text);
      ref.invalidate(profileProvider);
      if (!mounted) return;
      showToast(context, appL10n(context).msgProfileUpdated338);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e, context: context));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    return Scaffold(
      backgroundColor: appPalette(context).surface,
      appBar: AppBar(
        backgroundColor: appPalette(context).surface,
        elevation: 0,
        title: Text(appL10n(context).msgUpdateProfile339,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _uploading ? null : _changeAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primaryFixed,
                    backgroundImage: profile?.avatarUrl == null
                        ? null
                        : NetworkImage(profile!.avatarUrl!),
                    child: _uploading
                        ? CircularProgressIndicator(
                            color: appPalette(context).primary)
                        : profile?.avatarUrl == null
                            ? Text(profile?.initials ?? '',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: appPalette(context).primary))
                            : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: appPalette(context).primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(appL10n(context).msgTapToChangeProfilePhoto340,
                style: TextStyle(
                    fontSize: 11, color: appPalette(context).onSurfaceVariant)),
          ),
          const SizedBox(height: 24),
          TextField(
              controller: _name,
              maxLength: 100,
              decoration:
                  sheetInputDecoration(appL10n(context).msgDisplayName341)),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            decoration: sheetInputDecoration(
                appL10n(context).msgPhoneNumberOptional254),
          ),
          const SizedBox(height: 8),
          TextField(
              controller: _email,
              enabled: false,
              decoration:
                  sheetInputDecoration(appL10n(context).msgSignInEmail342)),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: appPalette(context).primary,
                foregroundColor: appPalette(context).onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(appL10n(context).msgSaveChanges343,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
