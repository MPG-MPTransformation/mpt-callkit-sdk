class Message {
  String? id;
  String? message;
  DateTime? createdAt;
  bool? isMine;

  int? get createdAtInTimeStamp => createdAt?.millisecondsSinceEpoch;

  Message({
    this.id,
    this.message,
    this.createdAt,
    this.isMine,
  });
}