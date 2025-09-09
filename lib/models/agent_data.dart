class AgentData {
  final int? tenantId;
  final int? userId;
  final String? userName;
  final String? fullName;
  final String? extension;

  AgentData({
    this.tenantId,
    this.userId,
    this.userName,
    this.fullName,
    this.extension,
  });

  AgentData copyWith({
    int? tenantId,
    int? userId,
    String? userName,
    String? fullName,
    String? extension,
  }) =>
      AgentData(
        tenantId: tenantId ?? this.tenantId,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        fullName: fullName ?? this.fullName,
        extension: extension ?? this.extension,
      );

  factory AgentData.fromJson(Map<String, dynamic> json) => AgentData(
        tenantId: json["tenantId"],
        userId: json["userId"],
        userName: json["userName"],
        fullName: json["fullName"],
        extension: json["extension"],
      );

  Map<String, dynamic> toJson() => {
        "tenantId": tenantId,
        "userId": userId,
        "userName": userName,
        "fullName": fullName,
        "extension": extension,
      };

  @override
  String toString() =>
      "AgentData(tenantId: $tenantId, userId: $userId, userName: $userName, fullName: $fullName, extension: $extension)";
}
