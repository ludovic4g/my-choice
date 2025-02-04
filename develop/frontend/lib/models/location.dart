class LocationModel {
  final int id;
  final String nome;
  final String indirizzo;
  final dynamic cap; // Può essere String o int
  final String citta;
  final dynamic numero; // Può essere String o int
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
      id: map['id'],
      nome: map['Nome'] ?? '',
      indirizzo: map['Indirizzo'] ?? '',
      cap: map['CAP'],
      citta: map['Citta'] ?? '',
      numero: map['Numero'],
      orari: map['Orari'] ?? '',
      ivgFarm: map['ivg_farm'] ?? '',
      ivgChirurgica: map['ivg_chirurgica'] ?? '',
      itg: map['itg'] ?? '',
      annotazioni: map['Annotazioni'] ?? '',
    );
  }
}