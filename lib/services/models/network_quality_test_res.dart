class NetworkQualityTestResult {
  final double? downloadSpeed;
  final double? uploadSpeed;
  final double? latency;
  final bool? success;
  final String? error;
  final DateTime? timestamp;

  NetworkQualityTestResult({
    this.downloadSpeed,
    this.uploadSpeed,
    this.latency,
    this.success,
    this.error,
    this.timestamp,
  });

  NetworkQualityTestResult copyWith({
    double? downloadSpeed,
    double? uploadSpeed,
    double? latency,
    bool? success,
    String? error,
    DateTime? timestamp,
  }) =>
      NetworkQualityTestResult(
        downloadSpeed: downloadSpeed ?? this.downloadSpeed,
        uploadSpeed: uploadSpeed ?? this.uploadSpeed,
        latency: latency ?? this.latency,
        success: success ?? this.success,
        error: error ?? this.error,
        timestamp: timestamp ?? this.timestamp,
      );

  factory NetworkQualityTestResult.fromJson(Map<String, dynamic> json) =>
      NetworkQualityTestResult(
        downloadSpeed: json['downloadSpeed'],
        uploadSpeed: json['uploadSpeed'],
        latency: json['latency'],
        success: json['success'],
        error: json['error'],
        timestamp: json['timestamp'],
      );

  Map<String, dynamic> toJson() => {
        'downloadSpeed': downloadSpeed,
        'uploadSpeed': uploadSpeed,
        'latency': latency,
        'success': success,
        'error': error,
        'timestamp': timestamp,
      };

  @override
  String toString() =>
      'NetworkQualityTestResult(downloadSpeed: $downloadSpeed, uploadSpeed: $uploadSpeed, latency: $latency, success: $success, error: $error, timestamp: $timestamp)';
}
