// models/location.dart
class LocationModel {
  final String id;
  final String nome;
  final String indirizzo;
  final String cap;
  final String citta; // Rinominato da 'città' a 'citta'
  final String numero;
  final String orari;
  final String ivgFarm;
  final String ivgChirurgica;
  final String itg;
  final String annotazioni;

  LocationModel({
    required this.id,
    required this.nome,
    required this.indirizzo,
    required this.cap,
    required this.citta,
    required this.numero,
    required this.orari,
    required this.ivgFarm,
    required this.ivgChirurgica,
    required this.itg,
    required this.annotazioni,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'] ?? '',
      nome: map['Nome'] ?? '',
      indirizzo: map['Indirizzo'] ?? '',
      cap: map['CAP'] ?? '',
      citta: map['Città'] ?? '', // Mappatura del campo 'Città'
      numero: map['Numero'] ?? '',
      orari: map['Orari'] ?? '',
      ivgFarm: map['ivg_farm'] ?? '',
      ivgChirurgica: map['ivg_chirurgica'] ?? '',
      itg: map['itg'] ?? '',
      annotazioni: map['Annotazioni'] ?? '',
    );
  }
}
