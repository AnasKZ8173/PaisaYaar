import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class ProofUploadService {
  ProofUploadService(this._client);

  final SupabaseClient? _client;

  Future<String?> pickAndUploadProof() async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return null;

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last;
    final path = '$uid/proof_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await client.storage.from('proofs').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return client.storage.from('proofs').getPublicUrl(path);
  }
}

final proofUploadServiceProvider = Provider<ProofUploadService>((ref) {
  return ProofUploadService(ref.watch(supabaseClientProvider));
});
