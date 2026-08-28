import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateRuntimeValues {
  const AppUpdateRuntimeValues({
    required this.forceUpdateRequired,
    required this.optionalUpdateAvailable,
    required this.isOutdated,
    required this.currentBuildNumber,
    required this.minBuildNumber,
    required this.recommendedBuildNumber,
    required this.message,
    required this.optionalMessage,
    required this.updateUrl,
  });

  final bool forceUpdateRequired;
  final bool optionalUpdateAvailable;
  final bool isOutdated;
  final int currentBuildNumber;
  final int minBuildNumber;
  final int recommendedBuildNumber;
  final String message;
  final String optionalMessage;
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
      'ops_min_build_ios': 0,
      'ops_update_message': updateMessage,
      'ops_update_url_android': '',
      'ops_update_url_ios': '',
      '${appKey}_force_update_enabled': false,
      '${appKey}_min_build_android': 0,
      '${appKey}_min_build_ios': 0,
      '${appKey}_update_message': updateMessage,
      '${appKey}_update_url_android': '',
      '${appKey}_update_url_ios': '',
      '${appKey}_optional_update_enabled': false,
      '${appKey}_recommended_build_android': 0,
      '${appKey}_recommended_build_ios': 0,
      '${appKey}_optional_update_message':
          'يتوفر إصدار جديد من التطبيق. ننصحك بالتحديث للحصول على أفضل تجربة.',
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
    final platformSuffix =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android';

    final globalMinBuild = rc.getInt('ops_min_build_$platformSuffix');
    final appMinBuild = rc.getInt('${appKey}_min_build_$platformSuffix');
    final minBuild = appMinBuild > 0 ? appMinBuild : globalMinBuild;

    final globalForceEnabled = rc.getBool('ops_force_update_enabled');
    final appForceEnabled = rc.getBool('${appKey}_force_update_enabled');
    final optionalEnabled = rc.getBool('${appKey}_optional_update_enabled');
    final recommendedBuild =
        rc.getInt('${appKey}_recommended_build_$platformSuffix');

    final globalMessage = rc.getString('ops_update_message').trim();
    final appMessage = rc.getString('${appKey}_update_message').trim();
    final message = appMessage.isNotEmpty
        ? appMessage
        : (globalMessage.isNotEmpty ? globalMessage : fallbackMessage);

    final appUrl = rc.getString('${appKey}_update_url_$platformSuffix').trim();
    final globalUrl = rc.getString('ops_update_url_$platformSuffix').trim();
    final updateUrl = appUrl.isNotEmpty ? appUrl : globalUrl;

    final isOutdated = minBuild > 0 && currentBuild < minBuild;
    final forceUpdateRequired =
        isOutdated && (appForceEnabled || (globalForceEnabled && appMinBuild <= 0));
    final optionalUpdateAvailable = !forceUpdateRequired &&
        optionalEnabled &&
        recommendedBuild > 0 &&
        currentBuild < recommendedBuild;
    final optionalMessage =
        rc.getString('${appKey}_optional_update_message').trim();

    return AppUpdateRuntimeValues(
      forceUpdateRequired: forceUpdateRequired,
      optionalUpdateAvailable: optionalUpdateAvailable,
      isOutdated: isOutdated,
      currentBuildNumber: currentBuild,
      minBuildNumber: minBuild,
      recommendedBuildNumber: recommendedBuild,
      message: message,
      optionalMessage:
          optionalMessage.isNotEmpty ? optionalMessage : fallbackMessage,
      updateUrl: updateUrl,
    );
  }
}
