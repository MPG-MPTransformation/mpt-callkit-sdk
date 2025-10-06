class AudioRawData {
  final int? audioCallbackMode;
  final int? samplingFreqHz;
  final int? dataLength;

  AudioRawData({
    this.audioCallbackMode,
    this.samplingFreqHz,
    this.dataLength,
  });

  AudioRawData copyWith({
    int? audioCallbackMode,
    int? samplingFreqHz,
    int? dataLength,
  }) =>
      AudioRawData(
        audioCallbackMode: audioCallbackMode ?? this.audioCallbackMode,
        samplingFreqHz: samplingFreqHz ?? this.samplingFreqHz,
        dataLength: dataLength ?? this.dataLength,
      );

  factory AudioRawData.fromJson(Map<String, dynamic> json) => AudioRawData(
        audioCallbackMode: json['audioCallbackMode'],
        samplingFreqHz: json['samplingFreqHz'],
        dataLength: json['dataLength'],
      );

  Map<String, dynamic> toJson() => {
        'audioCallbackMode': audioCallbackMode,
        'samplingFreqHz': samplingFreqHz,
        'dataLength': dataLength,
      };
}

class VideoRawData {
  final int? videoCallbackMode;
  final int? width;
  final int? height;
  final int? dataLength;

  VideoRawData({
    this.videoCallbackMode,
    this.width,
    this.height,
    this.dataLength,
  });

  VideoRawData copyWith({
    int? videoCallbackMode,
    int? width,
    int? height,
    int? dataLength,
  }) =>
      VideoRawData(
        videoCallbackMode: videoCallbackMode ?? this.videoCallbackMode,
        width: width ?? this.width,
        height: height ?? this.height,
        dataLength: dataLength ?? this.dataLength,
      );

  factory VideoRawData.fromJson(Map<String, dynamic> json) => VideoRawData(
        videoCallbackMode: json['videoCallbackMode'],
        width: json['width'],
        height: json['height'],
        dataLength: json['dataLength'],
      );

  Map<String, dynamic> toJson() => {
        'videoCallbackMode': videoCallbackMode,
        'width': width,
        'height': height,
        'dataLength': dataLength,
      };
}
