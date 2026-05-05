import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class CloudinaryService {
  static const _defaultCloudName = 'dvnzloec6';
  static const _defaultUploadPreset = 'flutter_unsigned';

  static CloudinaryPublic build() {
    try {
      final rc = FirebaseRemoteConfig.instance;
      final cloudName = rc.getString('cloudinary_cloud_name').trim();
      final preset = rc.getString('cloudinary_upload_preset').trim();
      if (cloudName.isNotEmpty && preset.isNotEmpty) {
        return CloudinaryPublic(cloudName, preset, cache: false);
      }
    } catch (_) {}
    return CloudinaryPublic(_defaultCloudName, _defaultUploadPreset,
        cache: false);
  }
}
