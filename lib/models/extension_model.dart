class ExtensionModel {
  final bool? success;
  final String? message;
  final ExtensionData? data;

  ExtensionModel({
    this.success,
    this.message,
    this.data,
  });

  ExtensionModel copyWith({
    bool? success,
    String? message,
    ExtensionData? data,
  }) =>
      ExtensionModel(
        success: success ?? this.success,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  factory ExtensionModel.fromJson(Map<String, dynamic> json) => ExtensionModel(
        success: json["success"],
        message: json["message"],
        data: json["data"] == null
            ? null
            : json["data"].runtimeType is String
                ? null
                : ExtensionData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "data": data?.toJson(),
      };
}

class ExtensionData {
  final String? username;
  final String? password;
  final String? domain;
  final String? sipServer;
  final int? port;
  final int? expiresAt;

  ExtensionData({
    this.username,
    this.password,
    this.domain,
    this.sipServer,
    this.port,
    this.expiresAt,
  });

  ExtensionData copyWith({
    String? username,
    String? password,
    String? domain,
    String? sipServer,
    int? port,
    int? expiresAt,
  }) =>
      ExtensionData(
        username: username ?? this.username,
        password: password ?? this.password,
        domain: domain ?? this.domain,
        sipServer: sipServer ?? this.sipServer,
        port: port ?? this.port,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  factory ExtensionData.fromJson(Map<String, dynamic> json) => ExtensionData(
        username: json["username"],
        password: json["password"],
        domain: json["domain"],
        sipServer: json["sipServer"],
        port: json["port"],
        expiresAt: json["expiresAt"],
      );

  Map<String, dynamic> toJson() => {
        "username": username,
        "password": password,
        "domain": domain,
        "sipServer": sipServer,
        "port": port,
        "expiresAt": expiresAt,
      };
}
