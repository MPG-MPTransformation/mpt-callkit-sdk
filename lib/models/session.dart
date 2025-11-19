class Session {
  int? sessionId;
  String? uuid;
  bool? hasVideo;
  bool? hasAudio;
  String? callState;
  String? callType;

  Session({
    this.sessionId,
    this.uuid,
    this.hasVideo,
    this.hasAudio,
    this.callState,
    this.callType,
  });

  Session copyWith({
    int? sessionId,
    String? uuid,
    bool? hasVideo,
    bool? hasAudio,
    String? callState,
    String? callType,
  }) =>
      Session(
        sessionId: sessionId ?? this.sessionId,
        uuid: uuid ?? this.uuid,
        hasVideo: hasVideo ?? this.hasVideo,
        hasAudio: hasAudio ?? this.hasAudio,
        callState: callState ?? this.callState,
        callType: callType ?? this.callType,
      );

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        sessionId: json['sessionId'],
        uuid: json['uuid'],
        hasVideo: json['hasVideo'],
        hasAudio: json['hasAudio'],
        callState: json['callState'],
        callType: json['callType'],
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'uuid': uuid,
        'hasVideo': hasVideo,
        'hasAudio': hasAudio,
        'callState': callState,
        'callType': callType,
      };

  void reset() {
    sessionId = null;
    uuid = null;
    hasVideo = null;
    hasAudio = null;
    callState = null;
    callType = null;
  }

  @override
  String toString() =>
      'Session(sessionId: $sessionId, uuid: $uuid, hasVideo: $hasVideo, hasAudio: $hasAudio, callState: $callState, callType: $callType)';
}
