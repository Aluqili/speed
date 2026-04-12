import 'package:shared_preferences/shared_preferences.dart';

class GuestLocationData {
  const GuestLocationData({
    required this.addressName,
    required this.latitude,
    required this.longitude,
    required this.stateId,
  });

  final String addressName;
  final double latitude;
  final double longitude;
  final String stateId;
}

class GuestLocationService {
  const GuestLocationService._();

  static const String _nameKey = 'guest_location_name';
  static const String _latKey = 'guest_location_lat';
  static const String _lngKey = 'guest_location_lng';
  static const String _stateIdKey = 'guest_location_state_id';

  static Future<GuestLocationData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = (prefs.getString(_nameKey) ?? '').trim();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    final stateId = (prefs.getString(_stateIdKey) ?? '').trim();

    if (name.isEmpty || lat == null || lng == null) {
      return null;
    }

    return GuestLocationData(
      addressName: name,
      latitude: lat,
      longitude: lng,
      stateId: stateId,
    );
  }

  static Future<void> save(GuestLocationData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, data.addressName);
    await prefs.setDouble(_latKey, data.latitude);
    await prefs.setDouble(_lngKey, data.longitude);
    await prefs.setString(_stateIdKey, data.stateId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
    await prefs.remove(_stateIdKey);
  }
}
