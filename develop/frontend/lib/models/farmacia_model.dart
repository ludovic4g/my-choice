class FarmaciaModel {
  final int id;
  final String indirizzo;
  final String descrizione;
  final String comune;

  FarmaciaModel({
    required this.id,
    required this.indirizzo,
    required this.descrizione,
    required this.comune,
  });

  factory FarmaciaModel.fromMap(Map<String, dynamic> map) {
    return FarmaciaModel(
      id: map['id'],
      indirizzo: map['indirizzo'] ?? '',
      descrizione: map['descrizione'] ?? '',
      comune: map['comune'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'indirizzo': indirizzo,
      'descrizione': descrizione,
      'comune': comune,
    };
  }
}
