class AgentDataOnConf {
  final int? agentId;
  final String? uuid;
  final int? sipSessionId;
  final String? extension;

  AgentDataOnConf({
    this.agentId,
    this.uuid,
    this.sipSessionId,
    this.extension,
  });

  AgentDataOnConf copyWith({
    int? agentId,
    String? uuid,
    int? sipSessionId,
    String? extension,
  }) =>
      AgentDataOnConf(
        agentId: agentId ?? this.agentId,
        uuid: uuid ?? this.uuid,
        sipSessionId: sipSessionId ?? this.sipSessionId,
        extension: extension ?? this.extension,
      );

  factory AgentDataOnConf.fromJson(Map<String, dynamic> json) =>
      AgentDataOnConf(
        agentId: json["agentId"],
        uuid: json["uuid"],
        sipSessionId: json["sipSessionId"],
        extension: json["extension"],
      );

  Map<String, dynamic> toJson() => {
        "agentId": agentId,
        "uuid": uuid,
        "sipSessionId": sipSessionId,
        "extension": extension,
      };

  @override
  String toString() =>
      "AgentDataOnConf(agentId: $agentId, uuid: $uuid, sipSessionId: $sipSessionId, extension: $extension)";
}
