class AgentDataOnConf {
  final int? agentId;
  final String? uuid;
  final int? sipSessionId;

  AgentDataOnConf({
    this.agentId,
    this.uuid,
    this.sipSessionId,
  });

  AgentDataOnConf copyWith({
    int? agentId,
    String? uuid,
    int? sipSessionId,
  }) =>
      AgentDataOnConf(
        agentId: agentId ?? this.agentId,
        uuid: uuid ?? this.uuid,
        sipSessionId: sipSessionId ?? this.sipSessionId,
      );

  factory AgentDataOnConf.fromJson(Map<String, dynamic> json) =>
      AgentDataOnConf(
        agentId: json["agentId"],
        uuid: json["uuid"],
        sipSessionId: json["sipSessionId"],
      );

  Map<String, dynamic> toJson() => {
        "agentId": agentId,
        "uuid": uuid,
        "sipSessionId": sipSessionId,
      };

  @override
  String toString() =>
      "AgentDataOnConf(agentId: $agentId, uuid: $uuid, sipSessionId: $sipSessionId)";
}
