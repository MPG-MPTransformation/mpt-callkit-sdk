class AddAgentToConfReq {
  final int? agentId;
  final String? destExt;
  final String? uuid;
  final int? sipSessionId;

  AddAgentToConfReq({
    this.agentId,
    this.destExt,
    this.uuid,
    this.sipSessionId,
  });

  AddAgentToConfReq copyWith({
    int? agentId,
    String? destExt,
    String? uuid,
    int? sipSessionId,
  }) =>
      AddAgentToConfReq(
        agentId: agentId ?? this.agentId,
        destExt: destExt ?? this.destExt,
        uuid: uuid ?? this.uuid,
        sipSessionId: sipSessionId ?? this.sipSessionId,
      );

  factory AddAgentToConfReq.fromJson(Map<String, dynamic> json) =>
      AddAgentToConfReq(
        agentId: json["agentId"],
        destExt: json["destExt"] as String?,
        uuid: json["uuid"],
        sipSessionId: json["sipSessionId"],
      );

  Map<String, dynamic> toJson() => {
        "agentId": agentId,
        "destExt": destExt,
        "uuid": uuid,
        "sipSessionId": sipSessionId,
      };

  @override
  String toString() =>
      "AddAgentToConfReq(agentId: $agentId, destExt: $destExt, uuid: $uuid, sipSessionId: $sipSessionId)";
}
