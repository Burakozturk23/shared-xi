/// Durable admission for one repeatable game, never for an individual round.
class EnergySession {
  const EnergySession({required this.id, required this.status, this.expiresAt});
  final String id, status;
  final int? expiresAt;
  bool get free => status == 'free';
  bool get confirmed => status == 'confirmed';
  Map<String, dynamic> toJson() => {
    'id': id, 'status': status, if (expiresAt != null) 'expiresAt': expiresAt,
  };
  factory EnergySession.fromJson(Map<String, dynamic> json) {
    final id = json['id'], status = json['status'], expiry = json['expiresAt'];
    if (id is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
        !['pending', 'reserved', 'confirmed', 'free'].contains(status) ||
        (expiry != null && expiry is! int) ||
        (['reserved', 'confirmed'].contains(status) && expiry == null)) {
      throw const FormatException('Invalid energy admission');
    }
    return EnergySession(id: id, status: status as String, expiresAt: expiry as int?);
  }
}
