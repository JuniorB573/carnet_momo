/// Une opération de dépôt ou retrait enregistrée par l'agent.
class MomoTransaction {
  final String id;
  final String network; // 'mtn' | 'moov' | 'celtiis'
  final String type; // 'depot' | 'retrait'
  final String operationNumber;
  final int montant;
  final int commission;
  final DateTime date;

  MomoTransaction({
    required this.id,
    required this.network,
    required this.type,
    required this.operationNumber,
    required this.montant,
    required this.commission,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'network': network,
      'type': type,
      'operation_number': operationNumber,
      'montant': montant,
      'commission': commission,
      'date': date.toIso8601String(),
    };
  }

  factory MomoTransaction.fromMap(Map<String, dynamic> map) {
    return MomoTransaction(
      id: map['id'] as String,
      network: map['network'] as String,
      type: map['type'] as String,
      operationNumber: map['operation_number'] as String,
      montant: map['montant'] as int,
      commission: map['commission'] as int,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
