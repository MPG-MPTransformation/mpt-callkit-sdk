class QueueDataByAgent {
  final String? id;
  final String? queueName;
  final int? tenantId;
  final String? queueExtension;
  final bool? agentActive;

  QueueDataByAgent({
    this.id,
    this.queueName,
    this.tenantId,
    this.queueExtension,
    this.agentActive,
  });

  QueueDataByAgent copyWith({
    String? id,
    String? queueName,
    int? tenantId,
    String? queueExtension,
    bool? agentActive,
  }) =>
      QueueDataByAgent(
        id: id ?? this.id,
        queueName: queueName ?? this.queueName,
        tenantId: tenantId ?? this.tenantId,
        queueExtension: queueExtension ?? this.queueExtension,
        agentActive: agentActive ?? this.agentActive,
      );

  factory QueueDataByAgent.fromJson(Map<String, dynamic> json) =>
      QueueDataByAgent(
        id: json["id"],
        queueName: json["queue_name"],
        tenantId: json["tenant_id"],
        queueExtension: json["queue_extension"],
        agentActive: json["agent_active"] is bool
            ? json["agent_active"] as bool
            : (json["agent_active"]?.toString().toLowerCase() == "true"),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "queue_name": queueName,
        "tenant_id": tenantId,
        "queue_extension": queueExtension,
        "agent_active": agentActive,
      };

  @override
  String toString() =>
      "QueueDataByAgent(id: $id, queueName: $queueName, tenantId: $tenantId, queueExtension: $queueExtension, agentActive: $agentActive)";
}
