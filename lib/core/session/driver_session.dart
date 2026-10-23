import 'package:get_storage/get_storage.dart';

class DriverSession {
  static final _box = GetStorage();

  static const _driverIdKey = 'driver_id';
  static const _driverNameKey = 'driver_name';
  static const _driverPhoneKey = 'driver_phone';

  static String? get driverId => _box.read(_driverIdKey);
  static String? get driverName => _box.read(_driverNameKey);
  static String? get driverPhone => _box.read(_driverPhoneKey);

  static bool get isLoggedIn => driverId != null && driverId!.isNotEmpty;

  static Future<void> saveDriver({
    required String driverId,
    required String name,
    required String phone,
  }) async {
    await _box.write(_driverIdKey, driverId);
    await _box.write(_driverNameKey, name);
    await _box.write(_driverPhoneKey, phone);
  }

  static Future<void> logout() async {
    await _box.remove(_driverIdKey);
    await _box.remove(_driverNameKey);
    await _box.remove(_driverPhoneKey);
  }
}
