/// A single set of sensor readings from the ESP32 water quality station.
class WaterReading {
  final double pH;
  final double tds; // ppm
  final double ec; // mS/cm
  final double waterTemp; // °C
  final double turbidity; // %
  final int? deviceMillis;
  final int? rssi;
  final DateTime timestamp;

  const WaterReading({
    required this.pH,
    required this.tds,
    required this.ec,
    required this.waterTemp,
    required this.turbidity,
    required this.timestamp,
    this.deviceMillis,
    this.rssi,
  });

  factory WaterReading.fromMap(Map<dynamic, dynamic> map, {DateTime? fallbackTime}) {
    double toD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int? toI(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return WaterReading(
      pH: toD(map['pH']),
      tds: toD(map['tds']),
      ec: toD(map['ec']),
      waterTemp: toD(map['waterTemp']),
      turbidity: toD(map['turbidity']),
      deviceMillis: toI(map['deviceMillis']),
      rssi: toI(map['rssi']),
      timestamp: fallbackTime ?? DateTime.now(),
    );
  }

  /// Simple status classification used for the alert banner / coloring.
  WaterStatus get status {
    if (pH < 6.0 || pH > 9.0 || turbidity > 70) return WaterStatus.alert;
    if (pH < 6.5 || pH > 8.5 || turbidity > 40 || tds > 500) {
      return WaterStatus.warning;
    }
    return WaterStatus.good;
  }
}

enum WaterStatus { good, warning, alert }
