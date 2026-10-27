import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../data/receipt_repository.dart';

/// Asks camera vs. gallery, then returns the resized photo (or null if cancelled).
Future<PickedReceipt?> pickReceiptImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text('Quét hóa đơn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.photo_camera, color: AppColors.primary),
            title: const Text('Chụp ảnh hóa đơn'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.secondary),
            title: const Text('Chọn từ thư viện ảnh'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;

  // Resize on device (≤1920px, ~85% quality) so uploads stay small on 4G.
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );
  if (file == null) return null;
  return PickedReceipt.fromFile(await file.readAsBytes(), name: file.name, mimeType: file.mimeType);
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
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Không mở được ảnh hóa đơn', textAlign: TextAlign.center),
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          }
          final url = snapshot.data!;
          return InteractiveViewer(child: url.startsWith('data:') ? Image.memory(base64Decode(url.split(',').last), fit: BoxFit.contain) : Image.network(url, fit: BoxFit.contain));
        },
      ),
    ),
  );
}
