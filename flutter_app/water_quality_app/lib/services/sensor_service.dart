import 'package:firebase_database/firebase_database.dart';
import '../models/water_reading.dart';
import '../models/thresholds.dart';

/// Wraps all Firebase Realtime Database access for sensor data on a
/// single device.
///
/// Expected RTDB structure (written by the ESP32 firmware):
///   /devices/<deviceId>/latest             -> single map, overwritten each send
///   /devices/<deviceId>/history/<pushId>   -> one entry per send, auto-ordered
///   /devices/<deviceId>/thresholds         -> optional, shared alert limits
class SensorService {
  SensorService({this.deviceId = 'device1'});

  final String deviceId;

  DatabaseReference get _deviceRef =>
      FirebaseDatabase.instance.ref('devices/$deviceId');

  DatabaseReference get _latestRef => _deviceRef.child('latest');
  DatabaseReference get _historyRef => _deviceRef.child('history');
  DatabaseReference get _thresholdsRef => _deviceRef.child('thresholds');

  /// Live stream of the most recent reading.
  Stream<WaterReading?> latestReadingStream() {
    return _latestRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return null;
      return WaterReading.fromMap(data, fallbackTime: DateTime.now());
    });
  }

  /// Live stream of history (auto-updates as new entries arrive).
  Stream<List<WaterReading>> historyStream({int limit = 100}) {
    final query = _historyRef.orderByKey().limitToLast(limit);
    return query.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <WaterReading>[];

      final raw = Map<dynamic, dynamic>.from(data);
      final entries = raw.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

      return entries.map((e) {
        final map = Map<dynamic, dynamic>.from(e.value as Map);
        return WaterReading.fromMap(map, fallbackTime: DateTime.now());
      }).toList();
    });
  }

  Stream<Thresholds> thresholdsStream() {
    return _thresholdsRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return const Thresholds();
      return Thresholds.fromMap(data);
    });
  }

  Future<void> saveThresholds(Thresholds t) {
    return _thresholdsRef.set(t.toMap());
  }

  /// Whether the device has sent any data within the last [staleAfter].
  bool isStale(DateTime? lastUpdate, {Duration staleAfter = const Duration(seconds: 30)}) {
    if (lastUpdate == null) return true;
    return DateTime.now().difference(lastUpdate) > staleAfter;
  }
}
