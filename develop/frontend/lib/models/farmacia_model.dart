// models/farmacia.dart
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

  // Costruttore per creare un `FarmaciaModel` da una mappa
  factory FarmaciaModel.fromMap(Map<String, dynamic> map) {
    return FarmaciaModel(
      id: map['id'],
      indirizzo: map['indirizzo'] ?? '',
      descrizione: map['descrizione'] ?? '',
      comune: map['comune'] ?? '',
    );
  }
}
