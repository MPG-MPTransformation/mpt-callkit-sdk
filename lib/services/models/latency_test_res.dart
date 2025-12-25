class LatencyTestResult {
  final double? latency;
  final double? min;
  final double? max;
  final int? attempts;
  final bool? success;
  final String? error;

  LatencyTestResult({
    this.latency,
    this.min,
    this.max,
    this.attempts,
    this.success,
    this.error,
  });

  LatencyTestResult copyWith({
    double? latency,
    double? min,
    double? max,
    int? attempts,
    bool? success,
    String? error,
  }) =>
      LatencyTestResult(
        latency: latency ?? this.latency,
        min: min ?? this.min,
        max: max ?? this.max,
        attempts: attempts ?? this.attempts,
        success: success ?? this.success,
        error: error ?? this.error,
      );

  factory LatencyTestResult.fromJson(Map<String, dynamic> json) =>
      LatencyTestResult(
        latency: json['latency'],
        min: json['min'],
        max: json['max'],
        attempts: json['attempts'],
        success: json['success'],
        error: json['error'],
      );

  Map<String, dynamic> toJson() => {
        'latency': latency,
        'min': min,
        'max': max,
        'attempts': attempts,
        'success': success,
        'error': error,
      };

  @override
  String toString() =>
      'LatencyTestResult(latency: $latency, min: $min, max: $max, attempts: $attempts, success: $success, error: $error)';
}
