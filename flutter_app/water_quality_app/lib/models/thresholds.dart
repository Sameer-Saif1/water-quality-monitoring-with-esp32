/// User-configurable alert thresholds, shared across all users of a device,
/// stored in Firebase Realtime Database alongside the sensor data.
class Thresholds {
  final double phMin;
  final double phMax;
  final double turbidityMax; // %
  final double tdsMax; // ppm
  final double tempMax; // °C

  const Thresholds({
    this.phMin = 6.5,
    this.phMax = 8.5,
    this.turbidityMax = 40,
    this.tdsMax = 500,
    this.tempMax = 35,
  });

  Thresholds copyWith({
    double? phMin,
    double? phMax,
    double? turbidityMax,
    double? tdsMax,
    double? tempMax,
  }) {
    return Thresholds(
      phMin: phMin ?? this.phMin,
      phMax: phMax ?? this.phMax,
      turbidityMax: turbidityMax ?? this.turbidityMax,
      tdsMax: tdsMax ?? this.tdsMax,
      tempMax: tempMax ?? this.tempMax,
    );
  }

  Map<String, dynamic> toMap() => {
        'phMin': phMin,
        'phMax': phMax,
        'turbidityMax': turbidityMax,
        'tdsMax': tdsMax,
        'tempMax': tempMax,
      };

  factory Thresholds.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const Thresholds();
    double toD(dynamic v, double fallback) =>
        v == null ? fallback : (v as num).toDouble();
    return Thresholds(
      phMin: toD(map['phMin'], 6.5),
      phMax: toD(map['phMax'], 8.5),
      turbidityMax: toD(map['turbidityMax'], 40),
      tdsMax: toD(map['tdsMax'], 500),
      tempMax: toD(map['tempMax'], 35),
    );
  }
}
