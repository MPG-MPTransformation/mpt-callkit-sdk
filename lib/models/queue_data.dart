class QueueData {
  final String? id;
  final String? queueName;
  final int? tenantId;
  final String? queueExtension;
  final bool? enabled;

  QueueData({
    this.id,
    this.queueName,
    this.tenantId,
    this.queueExtension,
    this.enabled,
  });

  QueueData copyWith({
    String? id,
    String? queueName,
    int? tenantId,
    String? queueExtension,
    bool? enabled,
  }) =>
      QueueData(
        id: id ?? this.id,
        queueName: queueName ?? this.queueName,
        tenantId: tenantId ?? this.tenantId,
        queueExtension: queueExtension ?? this.queueExtension,
        enabled: enabled ?? this.enabled,
      );

  factory QueueData.fromJson(Map<String, dynamic> json) => QueueData(
        id: json["id"],
        queueName: json["queue_name"],
        tenantId: json["tenant_id"],
        queueExtension: json["queue_extension"],
        enabled: json["enabled"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "queue_name": queueName,
        "tenant_id": tenantId,
        "queue_extension": queueExtension,
        "enabled": enabled,
      };

  @override
  String toString() =>
      "QueueData(id: $id, queueName: $queueName, tenantId: $tenantId, queueExtension: $queueExtension, enabled: $enabled)";
}
