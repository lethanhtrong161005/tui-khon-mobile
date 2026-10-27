import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/offline/local_store.dart';

/// A receipt photo picked from the camera or gallery (already resized ≤1920px).
class PickedReceipt {
  final Uint8List bytes;
  final String mimeType;
  final String extension;

  const PickedReceipt({required this.bytes, required this.mimeType, required this.extension});

  /// Derives the MIME type from the file name; image_picker often leaves it null.
  factory PickedReceipt.fromFile(Uint8List bytes, {String? name, String? mimeType}) {
    final ext = (name != null && name.contains('.')) ? name.split('.').last.toLowerCase() : 'jpg';
    final mime = mimeType ??
        switch (ext) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'heic' || 'heif' => 'image/heic',
          _ => 'image/jpeg',
        };
    return PickedReceipt(bytes: bytes, mimeType: mime, extension: ext == 'jpeg' ? 'jpg' : ext);
  }
}

/// Stores receipt images in the private `receipts` bucket under `{user_id}/`.
/// Storage policies only let users touch their own folder; images are shown
/// through signed URLs that expire after 15 minutes.
class ReceiptRepository {
  ReceiptRepository(this._client, [this.local]);

  final SupabaseClient _client;
  final LocalStore? local;

  static const _bucket = 'receipts';
  static const signedUrlTtlSeconds = 900;

  /// Uploads [receipt] and returns its storage path (saved in `receipt_path`).
  Future<String> upload(PickedReceipt receipt) async {
    final userId = _client.auth.currentUser?.id ?? local?.userId;
    if (userId == null) throw StateError('Bạn cần đăng nhập để lưu hóa đơn');
    final path = '$userId/${sha256.convert(receipt.bytes)}.${receipt.extension}';
    if (local != null) {
      await local!.attach(path, receipt.bytes, receipt.mimeType);
      return path;
    }
    await _client.storage.from(_bucket).uploadBinary(
          path,
          receipt.bytes,
          fileOptions: FileOptions(contentType: receipt.mimeType, upsert: true),
        );
    return path;
  }

  Future<String> signedUrl(String path) async {
    final bytes = await local?.attachment(path);
    if (bytes != null) return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    return _client.storage.from(_bucket).createSignedUrl(path, signedUrlTtlSeconds);
  }
}

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepository(ref.watch(supabaseClientProvider), ref.watch(localStoreProvider)),
);
