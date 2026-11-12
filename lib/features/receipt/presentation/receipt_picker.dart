import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/receipt_repository.dart';
import '../data/receipt_image.dart';

/// Asks camera vs. gallery, then returns the resized photo (or null if cancelled).
Future<PickedReceipt?> pickReceiptImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: appPalette(context).surfaceContainerLowest,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: const Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              appL10n(context).msgScanReceipt192,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: appPalette(context).primary,
              ),
              title: Text(appL10n(context).msgTakeReceiptPhoto392),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: appPalette(context).secondary,
              ),
              title: Text(appL10n(context).msgChoosePhotoFromLibrary393),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  FocusManager.instance.primaryFocus?.unfocus();

  // Preserve details for local OCR. A smaller cloud derivative is made only
  // when the user explicitly asks AI to read more.
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 3200,
    maxHeight: 3200,
    imageQuality: 95,
  );
  if (file == null) return null;
  return normalizeReceiptImage(await file.readAsBytes());
}

/// Shows a stored receipt through a short-lived signed URL.
Future<void> showReceiptImage(BuildContext context, Future<String> signedUrl) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: FutureBuilder<String>(
        future: signedUrl,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                appL10n(context).msgCouldNotOpenReceiptImage394,
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 200,
              child: const Center(child: const CircularProgressIndicator()),
            );
          }
          final url = snapshot.data!;
          return InteractiveViewer(
            child: url.startsWith('data:')
                ? Image.memory(
                    base64Decode(url.split(',').last),
                    fit: BoxFit.contain,
                  )
                : Image.network(url, fit: BoxFit.contain),
          );
        },
      ),
    ),
  );
}
