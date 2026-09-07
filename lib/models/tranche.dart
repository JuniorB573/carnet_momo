/// Une tranche de commission : si le montant de l'opération tombe entre
/// [min] et [max], l'agent touche [commission] francs CFA.
class Tranche {
  final String id;
  final String network; // 'mtn' | 'moov' | 'celtiis'
  final String type; // 'depot' | 'retrait'
  final int min;
  final int max;
  final int commission;

  Tranche({
    required this.id,
    required this.network,
    required this.type,
    required this.min,
    required this.max,
    required this.commission,
  });

  Tranche copyWith({int? min, int? max, int? commission}) {
    return Tranche(
      id: id,
      network: network,
      type: type,
      min: min ?? this.min,
      max: max ?? this.max,
      commission: commission ?? this.commission,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'network': network,
      'type': type,
      'min_amount': min,
      'max_amount': max,
      'commission': commission,
    };
  }

  factory Tranche.fromMap(Map<String, dynamic> map) {
    return Tranche(
      id: map['id'] as String,
      network: map['network'] as String,
      type: map['type'] as String,
      min: map['min_amount'] as int,
      max: map['max_amount'] as int,
      commission: map['commission'] as int,
    );
  }
}
