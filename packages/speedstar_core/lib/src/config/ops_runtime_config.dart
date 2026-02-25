import 'package:firebase_remote_config/firebase_remote_config.dart';

class OpsRuntimeValues {
  const OpsRuntimeValues({
    required this.chatEnabled,
    required this.notificationsEnabled,
    required this.ringtoneEnabled,
    required this.ringtoneVolume,
    required this.chatDisabledMessage,
  });

  final bool chatEnabled;
  final bool notificationsEnabled;
  final bool ringtoneEnabled;
  final double ringtoneVolume;
  final String chatDisabledMessage;
}

class OpsRuntimeConfig {
  const OpsRuntimeConfig._();

  static Map<String, Object> defaultFlagsFor(
    String appKey, {
    String chatDisabledMessage = 'الدردشة متوقفة مؤقتًا.',
  }) {
    return {
      'ops_chat_enabled': true,
      'ops_chat_disabled_message': 'الدردشة متوقفة مؤقتًا.',
      'ops_notifications_enabled': true,
      'ops_ringtone_enabled': true,
      'ops_ringtone_volume': 1.0,
      '${appKey}_chat_enabled': true,
      '${appKey}_chat_disabled_message': chatDisabledMessage,
      '${appKey}_notifications_enabled': true,
      '${appKey}_ringtone_enabled': true,
      '${appKey}_ringtone_volume': 1.0,
    };
  }

  static OpsRuntimeValues fromRemoteConfig(
    FirebaseRemoteConfig rc, {
    required String appKey,
    String fallbackChatMessage = 'الدردشة متوقفة مؤقتًا.',
  }) {
    final globalChatEnabled = rc.getBool('ops_chat_enabled');
    final appChatEnabled = rc.getBool('${appKey}_chat_enabled');

    final globalNotificationsEnabled = rc.getBool('ops_notifications_enabled');
    final appNotificationsEnabled = rc.getBool('${appKey}_notifications_enabled');

    final globalRingtoneEnabled = rc.getBool('ops_ringtone_enabled');
    final appRingtoneEnabled = rc.getBool('${appKey}_ringtone_enabled');

    final globalMessage = rc.getString('ops_chat_disabled_message').trim();
    final appMessage = rc.getString('${appKey}_chat_disabled_message').trim();
    final message = appMessage.isNotEmpty
        ? appMessage
        : (globalMessage.isNotEmpty ? globalMessage : fallbackChatMessage);

    final appVolume = rc.getDouble('${appKey}_ringtone_volume');
    final globalVolume = rc.getDouble('ops_ringtone_volume');
    final rawVolume = appVolume > 0 ? appVolume : globalVolume;

    return OpsRuntimeValues(
      chatEnabled: globalChatEnabled && appChatEnabled,
      notificationsEnabled: globalNotificationsEnabled && appNotificationsEnabled,
      ringtoneEnabled:
          globalNotificationsEnabled &&
          appNotificationsEnabled &&
          globalRingtoneEnabled &&
          appRingtoneEnabled,
      ringtoneVolume: rawVolume.clamp(0.0, 1.0),
      chatDisabledMessage: message,
    );
  }
}