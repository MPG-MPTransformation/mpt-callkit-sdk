class SpeedTestResult {
  final double? speed;
  final int? bytes;
  final double? duration;
  final bool? success;
  final String? error;

  SpeedTestResult({
    this.speed,
    this.bytes,
    this.duration,
    this.success,
    this.error,
  });

  SpeedTestResult copyWith({
    double? speed,
    int? bytes,
    double? duration,
    bool? success,
    String? error,
  }) =>
      SpeedTestResult(
        speed: speed ?? this.speed,
        bytes: bytes ?? this.bytes,
        duration: duration ?? this.duration,
        success: success ?? this.success,
        error: error ?? this.error,
      );

  factory SpeedTestResult.fromJson(Map<String, dynamic> json) =>
      SpeedTestResult(
        speed: json['speed'],
        bytes: json['bytes'],
        duration: json['duration'],
        success: json['success'],
        error: json['error'],
      );

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'bytes': bytes,
        'duration': duration,
        'success': success,
        'error': error,
      };

  @override
  String toString() =>
      'SpeedTestResult(speed: $speed, bytes: $bytes, duration: $duration, success: $success, error: $error)';
}
