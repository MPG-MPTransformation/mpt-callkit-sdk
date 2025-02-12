class MsgData {
  String? creationTime;
  List<Attachment>? attachments;
  MessageResponse? messageResponse;

  MsgData({
    required this.attachments,
    required this.messageResponse,
    required this.creationTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'creationTime': creationTime,
      'attachments': attachments!.map((e) => e.toJson()).toList(),
      'message': messageResponse!.toJson(),
    };
  }

  factory MsgData.fromJson(Map<String, dynamic> json) {
    return MsgData(
      creationTime: json['creationTime'],
      attachments: List<Attachment>.from(
          json['attachments'].map((x) => Attachment.fromJson(x))),
      messageResponse: MessageResponse.fromJson(json['message']),
    );
  }
}

class Attachment {
  String? fileName;
  String? media;
  String? mediaType;

  Attachment(
      {required this.fileName, required this.media, required this.mediaType});

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'media': media,
      'mediaType': mediaType,
    };
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      fileName: json['fileName'],
      media: json['media'],
      mediaType: json['mediaType'],
    );
  }

  @override
  String toString() {
    return 'Attachment{fileName: $fileName, media: $media, mediaType: $mediaType}';
  }
}

class MessageResponse {
  String? applicationId;
  int? cloudAgentId;
  int? cloudTenantId;
  String? conversationId;
  String? messageType;
  String? sendFrom;
  String? senderId;
  String? text;

  MessageResponse(
      {required this.applicationId,
      required this.cloudAgentId,
      required this.cloudTenantId,
      required this.conversationId,
      required this.messageType,
      required this.sendFrom,
      required this.senderId,
      required this.text});

  Map<String, dynamic> toJson() {
    return {
      'applicationId': applicationId,
      'cloudAgentId': cloudAgentId,
      'cloudTenantId': cloudTenantId,
      'conversationId': conversationId,
      'messageType': messageType,
      'sendFrom': sendFrom,
      'senderId': senderId,
      'text': text,
    };
  }

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      applicationId: json['applicationId'],
      cloudAgentId: json['cloudAgentId'],
      cloudTenantId: json['cloudTenantId'],
      conversationId: json['conversationId'],
      messageType: json['messageType'],
      sendFrom: json['sendFrom'],
      senderId: json['senderId'],
      text: json['text'],
    );
  }

  @override
  String toString() {
    return 'MessageResponse{applicationId: $applicationId, cloudAgentId: $cloudAgentId, cloudTenantId: $cloudTenantId, conversationId: $conversationId, messageType: $messageType, sendFrom: $sendFrom, senderId: $senderId, text: $text}';
  }
}
