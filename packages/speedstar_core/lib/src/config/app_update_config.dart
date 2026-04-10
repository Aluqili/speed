import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateRuntimeValues {
  const AppUpdateRuntimeValues({
    required this.forceUpdateRequired,
    required this.isOutdated,
    required this.currentBuildNumber,
    required this.minBuildNumber,
    required this.message,
    required this.updateUrl,
  });

  final bool forceUpdateRequired;
  final bool isOutdated;
  final int currentBuildNumber;
  final int minBuildNumber;
  final String message;
  final String updateUrl;
}

class AppUpdateConfig {
  const AppUpdateConfig._();

  static Map<String, Object> defaultFlagsFor(
    String appKey, {
    String updateMessage =
        'يتوفر إصدار أحدث من التطبيق لتحسين الأداء والاستقرار. الرجاء التحديث للمتابعة.',
  }) {
    return {
      'ops_force_update_enabled': false,
      'ops_min_build_android': 0,
      'ops_update_message': updateMessage,
      'ops_update_url_android': '',
      '${appKey}_force_update_enabled': false,
      '${appKey}_min_build_android': 0,
      '${appKey}_update_message': updateMessage,
      '${appKey}_update_url_android': '',
    };
  }

  static Future<AppUpdateRuntimeValues> fromRemoteConfig(
    FirebaseRemoteConfig rc, {
    required String appKey,
    String fallbackMessage =
        'يتوفر إصدار أحدث من التطبيق لتحسين الأداء والاستقرار. الرجاء التحديث للمتابعة.',
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    final globalMinBuild = rc.getInt('ops_min_build_android');
    final appMinBuild = rc.getInt('${appKey}_min_build_android');
    final minBuild = appMinBuild > 0 ? appMinBuild : globalMinBuild;

    final globalForceEnabled = rc.getBool('ops_force_update_enabled');
    final appForceEnabled = rc.getBool('${appKey}_force_update_enabled');

    final globalMessage = rc.getString('ops_update_message').trim();
    final appMessage = rc.getString('${appKey}_update_message').trim();
    final message = appMessage.isNotEmpty
        ? appMessage
        : (globalMessage.isNotEmpty ? globalMessage : fallbackMessage);

    final appUrl = rc.getString('${appKey}_update_url_android').trim();
    final globalUrl = rc.getString('ops_update_url_android').trim();
    final updateUrl = appUrl.isNotEmpty ? appUrl : globalUrl;

    final isOutdated = minBuild > 0 && currentBuild < minBuild;
    final forceUpdateRequired =
        globalForceEnabled && appForceEnabled && isOutdated;

    return AppUpdateRuntimeValues(
      forceUpdateRequired: forceUpdateRequired,
      isOutdated: isOutdated,
      currentBuildNumber: currentBuild,
      minBuildNumber: minBuild,
      message: message,
      updateUrl: updateUrl,
    );
  }
}