class AgentDataByQueue {
  final String? id;
  final int? tenantId;
  final int? agentId;
  final int? reasonCodeId;
  final int? reasonId;
  final String? reasonCode;
  final String? reasonName;
  final String? extension;
  final String? username;
  final String? agentName;
  final bool? enabled;

  AgentDataByQueue({
    this.id,
    this.tenantId,
    this.agentId,
    this.reasonCodeId,
    this.reasonId,
    this.reasonCode,
    this.reasonName,
    this.extension,
    this.username,
    this.agentName,
    this.enabled,
  });

  AgentDataByQueue copyWith({
    String? id,
    int? tenantId,
    int? agentId,
    int? reasonCodeId,
    int? reasonId,
    String? reasonCode,
    String? reasonName,
    String? extension,
    String? username,
    String? agentName,
    bool? enabled,
  }) =>
      AgentDataByQueue(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        agentId: agentId ?? this.agentId,
        reasonCodeId: reasonCodeId ?? this.reasonCodeId,
        reasonId: reasonId ?? this.reasonId,
        reasonCode: reasonCode ?? this.reasonCode,
        reasonName: reasonName ?? this.reasonName,
        extension: extension ?? this.extension,
        username: username ?? this.username,
        agentName: agentName ?? this.agentName,
        enabled: enabled ?? this.enabled,
      );

  factory AgentDataByQueue.fromJson(Map<String, dynamic> json) =>
      AgentDataByQueue(
        id: json["id"],
        tenantId: json["tenant_id"],
        agentId: json["agent_id"],
        reasonCodeId: json["reason_code_id"],
        reasonId: json["reason_id"],
        reasonCode: json["reason_code"],
        reasonName: json["reason_name"],
        extension: json["extension"],
        username: json["user_name"],
        agentName: json["agent_name"],
        enabled: json["enabled"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "tenant_id": tenantId,
        "agent_id": agentId,
        "reason_code_id": reasonCodeId,
        "reason_id": reasonId,
        "reason_code": reasonCode,
        "reason_name": reasonName,
        "extension": extension,
        "user_name": username,
        "agent_name": agentName,
        "enabled": enabled,
      };
}
