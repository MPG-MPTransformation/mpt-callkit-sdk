import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mpt_callkit/services/models/models.dart';

/// Network Speed Test Service
/// Provides functionality to test download/upload speeds and network latency
class MptNetworkSpeedTest {
  static final MptNetworkSpeedTest _instance = MptNetworkSpeedTest._internal();
  factory MptNetworkSpeedTest() => _instance;
  MptNetworkSpeedTest._internal();

  static MptNetworkSpeedTest get instance => _instance;

  /// Speed test result model
  Map<String, dynamic> _createSpeedTestResult({
    required double downloadSpeed,
    required double uploadSpeed,
    required double latency,
    required bool success,
    String? error,
  }) {
    return {
      'downloadSpeed': downloadSpeed, // Mbps
      'uploadSpeed': uploadSpeed, // Mbps
      'latency': latency, // ms
      'success': success,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Test download speed
  /// Returns speed in Mbps
  Future<SpeedTestResult> testDownloadSpeed({
    String? testUrl,
    int chunkTimeoutSeconds = 5,
    int dataSizeKB = 5 * 1024,
  }) async {
    final fileSizeBytes = dataSizeKB * 1024;
    try {
      // Use a test file URL (you can replace with your own server)
      final url =
          testUrl ?? 'https://speed.cloudflare.com/__down?bytes=$fileSizeBytes';

      final stopwatch = Stopwatch()..start();
      int totalBytes = 0;

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        client.close();
        return SpeedTestResult(
          speed: 0.0,
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }

      await for (var chunk in response.stream.timeout(
        Duration(seconds: chunkTimeoutSeconds),
        onTimeout: (sink) {
          sink.close();
        },
      )) {
        totalBytes += chunk.length;
      }

      stopwatch.stop();
      client.close();

      // Calculate speed in Mbps
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      final megabits = (totalBytes * 8) / 1000000.0;
      final speedMbps = seconds > 0 ? megabits / seconds : 0.0;

      debugPrint(
          'Download test: $totalBytes bytes in ${seconds}s = ${speedMbps.toStringAsFixed(2)} Mbps');

      return SpeedTestResult(
        speed: double.parse(speedMbps.toStringAsFixed(2)),
        bytes: totalBytes,
        duration: seconds,
        success: true,
      );
    } catch (e) {
      debugPrint('Download speed test error: $e');
      return SpeedTestResult(
        speed: 0.0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Test upload speed
  /// Returns speed in Mbps
  Future<SpeedTestResult> testUploadSpeed({
    String? testUrl,
    int dataSizeKB = 1024, // 1MB default
  }) async {
    try {
      // Use a test upload URL (you can replace with your own server)
      final url = testUrl ?? 'https://speed.cloudflare.com/__up';

      // Generate random data to upload
      final data = List<int>.generate(dataSizeKB * 1024, (i) => i % 256);

      final stopwatch = Stopwatch()..start();

      final response = await http.post(
        Uri.parse(url),
        body: data,
        headers: {'Content-Type': 'application/octet-stream'},
      ).timeout(const Duration(seconds: 30));

      stopwatch.stop();

      if (response.statusCode != 200 && response.statusCode != 201) {
        return SpeedTestResult(
          speed: 0.0,
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }

      // Calculate speed in Mbps
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      final megabits = (data.length * 8) / 1000000.0;
      final speedMbps = seconds > 0 ? megabits / seconds : 0.0;

      debugPrint(
          'Upload test: ${data.length} bytes in ${seconds}s = ${speedMbps.toStringAsFixed(2)} Mbps');

      return SpeedTestResult(
        speed: double.parse(speedMbps.toStringAsFixed(2)),
        bytes: data.length,
        duration: seconds,
        success: true,
      );
    } catch (e) {
      debugPrint('Upload speed test error: $e');
      return SpeedTestResult(
        speed: 0.0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Test network latency (ping)
  /// Returns latency in milliseconds
  Future<LatencyTestResult> testLatency({
    String? testUrl,
    int attempts = 3,
  }) async {
    try {
      final url = testUrl ?? 'https://cloudflare.com/cdn-cgi/trace';

      final latencies = <double>[];

      for (int i = 0; i < attempts; i++) {
        final stopwatch = Stopwatch()..start();

        final response = await http
            .get(
              Uri.parse(url),
            )
            .timeout(const Duration(seconds: 5));

        stopwatch.stop();

        if (response.statusCode == 200) {
          latencies.add(stopwatch.elapsedMilliseconds.toDouble());
        }

        // Small delay between attempts
        if (i < attempts - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (latencies.isEmpty) {
        return LatencyTestResult(
          latency: 0.0,
          success: false,
          error: 'No successful ping',
        );
      }

      // Calculate average latency
      final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;

      debugPrint(
          'Latency test: ${avgLatency.toStringAsFixed(2)} ms (${latencies.length} attempts)');

      return LatencyTestResult(
        latency: double.parse(avgLatency.toStringAsFixed(2)),
        min: latencies.reduce((a, b) => a < b ? a : b),
        max: latencies.reduce((a, b) => a > b ? a : b),
        attempts: latencies.length,
        success: true,
      );
    } catch (e) {
      debugPrint('Latency test error: $e');
      return LatencyTestResult(
        latency: 0.0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Run complete speed test
  /// Returns a map with download speed (Mbps), upload speed (Mbps), and latency (ms)
  ///
  /// Usage:
  /// ```dart
  /// final result = await NetworkSpeedTest.instance.runSpeedTest();
  /// print('Download: ${result['downloadSpeed']} Mbps');
  /// print('Upload: ${result['uploadSpeed']} Mbps');
  /// print('Latency: ${result['latency']} ms');
  /// ```
  Future<NetworkQualityTestResult> runSpeedTest({
    String? downloadTestUrl,
    String? uploadTestUrl,
    String? latencyTestUrl,
    int downloadChunkTimeoutSeconds = 5,
    int downloadDataSizeKB = 5 * 1024,
    int uploadDataSizeKB = 1024,
    int latencyAttempts = 3,
  }) async {
    debugPrint('Starting speed test...');

    try {
      // Test latency first (quick test)
      final latencyResult = await testLatency(
        testUrl: latencyTestUrl,
        attempts: latencyAttempts,
      );

      // Test download speed
      final downloadResult = await testDownloadSpeed(
        testUrl: downloadTestUrl,
        chunkTimeoutSeconds: downloadChunkTimeoutSeconds,
        dataSizeKB: downloadDataSizeKB,
      );

      // Test upload speed
      final uploadResult = await testUploadSpeed(
        testUrl: uploadTestUrl,
        dataSizeKB: uploadDataSizeKB,
      );

      final result = NetworkQualityTestResult(
        downloadSpeed: downloadResult.speed,
        uploadSpeed: uploadResult.speed,
        latency: latencyResult.latency,
        success: (downloadResult.success ?? false) &&
            (uploadResult.success ?? false) &&
            (latencyResult.success ?? false),
      );

      debugPrint('Speed test completed: $result');

      return result;
    } catch (e) {
      debugPrint('Speed test error: $e');
      return NetworkQualityTestResult(
        downloadSpeed: 0.0,
        uploadSpeed: 0.0,
        latency: 0.0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Quick speed test (faster but less accurate)
  /// Uses smaller data sizes and fewer attempts
  Future<NetworkQualityTestResult> runQuickSpeedTest() async {
    return await runSpeedTest(
      downloadChunkTimeoutSeconds: 3,
      uploadDataSizeKB: 500,
      latencyAttempts: 1,
    );
  }

  /// Run selective speed test (skip tests you don't need)
  /// Set parameters to false to skip that test
  /// This allows you to only test what you need, saving time
  Future<NetworkQualityTestResult> runSelectiveSpeedTest({
    bool includeLatency = false,
    bool includeDownload = true,
    bool includeUpload = true,
    String? downloadTestUrl,
    String? uploadTestUrl,
    String? latencyTestUrl,
    int downloadChunkTimeoutSeconds = 5,
    int downloadDataSizeKB = 5 * 1024,
    int uploadDataSizeKB = 1 * 1024,
    int latencyAttempts = 3,
  }) async {
    debugPrint('Starting selective speed test...');

    try {
      double latency = 0.0;
      double downloadSpeed = 0.0;
      double uploadSpeed = 0.0;
      bool success = true;
      String? error;

      // Test latency (if enabled)
      if (includeLatency) {
        final latencyResult = await testLatency(
          testUrl: latencyTestUrl,
          attempts: latencyAttempts,
        );
        latency = latencyResult.latency ?? 0.0;
        if (!(latencyResult.success ?? false)) {
          success = false;
          error = latencyResult.error;
        }
      }

      // Test download speed (if enabled)
      if (includeDownload) {
        final downloadResult = await testDownloadSpeed(
          testUrl: downloadTestUrl,
          chunkTimeoutSeconds: downloadChunkTimeoutSeconds,
          dataSizeKB: downloadDataSizeKB,
        );
        downloadSpeed = downloadResult.speed ?? 0.0;
        if (!(downloadResult.success ?? false)) {
          success = false;
          error ??= downloadResult.error;
        }
      }

      // Test upload speed (if enabled)
      if (includeUpload) {
        final uploadResult = await testUploadSpeed(
          testUrl: uploadTestUrl,
          dataSizeKB: uploadDataSizeKB,
        );
        uploadSpeed = uploadResult.speed ?? 0.0;
        if (!(uploadResult.success ?? false)) {
          success = false;
          error ??= uploadResult.error;
        }
      }

      final result = NetworkQualityTestResult(
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        latency: latency,
        success: success,
        error: error,
      );

      debugPrint('Selective speed test completed: $result');
      return result;
    } catch (e) {
      debugPrint('Selective speed test error: $e');
      return NetworkQualityTestResult(
        downloadSpeed: 0.0,
        uploadSpeed: 0.0,
        latency: 0.0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Run speed test with progress callback
  /// The callback will be called after each test completes
  Future<Map<String, dynamic>> runSpeedTestWithProgress({
    required Function(String stage, Map<String, dynamic> result) onProgress,
    String? downloadTestUrl,
    String? uploadTestUrl,
    String? latencyTestUrl,
    int downloadChunkTimeoutSeconds = 5,
    int downloadDataSizeKB = 5,
    int uploadDataSizeKB = 1000,
    int latencyAttempts = 3,
  }) async {
    debugPrint('Starting speed test with progress...');

    try {
      // Test latency first (quick test)
      final latencyResult = await testLatency(
        testUrl: latencyTestUrl,
        attempts: latencyAttempts,
      );
      onProgress('latency', latencyResult.toJson());

      // Test download speed
      final downloadResult = await testDownloadSpeed(
        testUrl: downloadTestUrl,
        chunkTimeoutSeconds: downloadChunkTimeoutSeconds,
        dataSizeKB: downloadDataSizeKB,
      );
      onProgress('download', downloadResult.toJson());

      // Test upload speed
      final uploadResult = await testUploadSpeed(
        testUrl: uploadTestUrl,
        dataSizeKB: uploadDataSizeKB,
      );
      onProgress('upload', uploadResult.toJson());

      final result = _createSpeedTestResult(
        downloadSpeed: downloadResult.speed ?? 0.0,
        uploadSpeed: uploadResult.speed ?? 0.0,
        latency: latencyResult.latency ?? 0.0,
        success: (downloadResult.success ?? false) &&
            (uploadResult.success ?? false) &&
            (latencyResult.success ?? false),
        error: !(downloadResult.success ?? false)
            ? downloadResult.error
            : !(uploadResult.success ?? false)
                ? uploadResult.error
                : !(latencyResult.success ?? false)
                    ? latencyResult.error
                    : null,
      );

      onProgress('complete', result);
      debugPrint('Speed test completed: $result');

      return result;
    } catch (e) {
      debugPrint('Speed test error: $e');
      final errorResult = _createSpeedTestResult(
        downloadSpeed: 0.0,
        uploadSpeed: 0.0,
        latency: 0.0,
        success: false,
        error: e.toString(),
      );
      onProgress('error', errorResult);
      return errorResult;
    }
  }
}
