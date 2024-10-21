class ReleaseExtensionModel {
  final bool? success;
  final String? message;
  final String? data;

  ReleaseExtensionModel({
    this.success,
    this.message,
    this.data,
  });

  ReleaseExtensionModel copyWith({
    bool? success,
    String? message,
    String? data,
  }) =>
      ReleaseExtensionModel(
        success: success ?? this.success,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  factory ReleaseExtensionModel.fromJson(Map<String, dynamic> json) =>
      ReleaseExtensionModel(
        success: json["success"],
        message: json["message"],
        data: json["data"],
      );

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "data": data,
      };
}
