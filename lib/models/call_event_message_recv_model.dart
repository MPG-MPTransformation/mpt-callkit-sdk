import 'dart:convert';

class Recording {
  final String? id;
  final String? sessionId;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final int? duration;
  final int? startedStamp;
  final int? endedStamp;

  Recording({
    this.id,
    this.sessionId,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.startedStamp,
    this.endedStamp,
  });

  Recording copyWith({
    String? id,
    String? sessionId,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    int? startedStamp,
    int? endedStamp,
  }) =>
      Recording(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        fileUrl: fileUrl ?? this.fileUrl,
        fileName: fileName ?? this.fileName,
        fileSize: fileSize ?? this.fileSize,
        duration: duration ?? this.duration,
        startedStamp: startedStamp ?? this.startedStamp,
        endedStamp: endedStamp ?? this.endedStamp,
      );

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json["id"],
        sessionId: json["session_id"],
        fileUrl: json["file_url"],
        fileName: json["file_name"],
        fileSize: json["file_size"],
        duration: json["duration"],
        startedStamp: json["started_stamp"],
        endedStamp: json["ended_stamp"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "session_id": sessionId,
        "file_url": fileUrl,
        "file_name": fileName,
        "file_size": fileSize,
        "duration": duration,
        "started_stamp": startedStamp,
        "ended_stamp": endedStamp,
      };
}

class CallEventSocketRecv {
  final String? messageId;
  final String? sessionId;
  final int? eventEpoch;
  final int? tenantId;
  final String? direction;
  final String? ani;
  final String? text;
  final String? dnis;
  final String? state;
  final String? channel;
  final int? agentId;
  final String? hangupSide;
  final List<Recording>? recordings;
  final ExtraInfo? extraInfo;
  final String? statusCode;

  CallEventSocketRecv({
    this.messageId,
    this.sessionId,
    this.eventEpoch,
    this.tenantId,
    this.direction,
    this.ani,
    this.text,
    this.dnis,
    this.state,
    this.channel,
    this.agentId,
    this.hangupSide,
    this.recordings,
    this.extraInfo,
    this.statusCode,
  });

  CallEventSocketRecv copyWith({
    String? messageId,
    String? sessionId,
    int? eventEpoch,
    int? tenantId,
    String? direction,
    String? ani,
    String? text,
    String? dnis,
    String? state,
    String? channel,
    int? agentId,
    String? hangupSide,
    List<Recording>? recordings,
    ExtraInfo? extraInfo,
    String? statusCode,
  }) =>
      CallEventSocketRecv(
        messageId: messageId ?? this.messageId,
        sessionId: sessionId ?? this.sessionId,
        eventEpoch: eventEpoch ?? this.eventEpoch,
        tenantId: tenantId ?? this.tenantId,
        direction: direction ?? this.direction,
        ani: ani ?? this.ani,
        text: text ?? this.text,
        dnis: dnis ?? this.dnis,
        state: state ?? this.state,
        channel: channel ?? this.channel,
        agentId: agentId ?? this.agentId,
        hangupSide: hangupSide ?? this.hangupSide,
        recordings: recordings ?? this.recordings,
        extraInfo: extraInfo ?? this.extraInfo,
        statusCode: statusCode ?? this.statusCode,
      );

  factory CallEventSocketRecv.fromJson(Map<String, dynamic> json) =>
      CallEventSocketRecv(
        messageId: json["messageId"],
        sessionId: json["sessionId"],
        eventEpoch: json["event_epoch"],
        tenantId: json["tenantId"],
        direction: json["direction"],
        ani: json["ani"],
        text: json["text"],
        dnis: json["dnis"],
        state: json["state"],
        channel: json["channel"],
        agentId: json["agentId"],
        hangupSide: json["hangup_side"],
        recordings: json["recordings"] == null
            ? null
            : List<Recording>.from(
                json["recordings"].map((x) => Recording.fromJson(x))),
        extraInfo: json["extraInfo"] == null || json["extraInfo"] == ""
            ? null
            : json["extraInfo"] is String
                ? ExtraInfo.fromJsonString(json["extraInfo"])
                : ExtraInfo.fromJson(json["extraInfo"]),
        statusCode: json["statusCode"],
      );

  Map<String, dynamic> toJson() => {
        "messageId": messageId,
        "sessionId": sessionId,
        "event_epoch": eventEpoch,
        "tenantId": tenantId,
        "direction": direction,
        "ani": ani,
        "text": text,
        "dnis": dnis,
        "state": state,
        "channel": channel,
        "agentId": agentId,
        "hangup_side": hangupSide,
        "recordings": recordings?.map((x) => x.toJson()).toList(),
        "extraInfo": extraInfo?.toJsonString(),
        "statusCode": statusCode,
      };
}

class ExtraInfo {
  final String? type;
  final String? extraInfo;

  ExtraInfo({
    this.type,
    this.extraInfo,
  });

  ExtraInfo copyWith({
    String? type,
    String? extraInfo,
  }) =>
      ExtraInfo(
        type: type ?? this.type,
        extraInfo: extraInfo ?? this.extraInfo,
      );

  factory ExtraInfo.fromJson(Map<String, dynamic> json) => ExtraInfo(
        type: json["type"],
        extraInfo: json["extraInfo"],
      );

  factory ExtraInfo.fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return ExtraInfo.fromJson(json);
    } catch (e) {
      // If parsing fails, return null object
      return ExtraInfo();
    }
  }

  Map<String, dynamic> toJson() => {
        "type": type,
        "extraInfo": extraInfo,
      };

  String toJsonString() => jsonEncode(toJson());
}
