import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

// -------------------
// MODELLO/REPORT
// -------------------
class CountryAnalysis {
  final String country;
  final int markerCount;
  final double area; // in km²
  final double areaPerMarker;
  final double meanNearestDistance; // in km
  final double moranI;
  
  CountryAnalysis({
    required this.country,
    required this.markerCount,
    required this.area,
    required this.areaPerMarker,
    required this.meanNearestDistance,
    required this.moranI,
  });
}

class ReportPage extends StatelessWidget {
  final List<CountryAnalysis> countryAnalyses;

  ReportPage({required this.countryAnalyses});

  @override
  Widget build(BuildContext context) {
    // Ordina i dati in ordine decrescente per numero di marker
    List<CountryAnalysis> sortedAnalyses = List.from(countryAnalyses)
      ..sort((a, b) => b.markerCount.compareTo(a.markerCount));

    // Testo di spiegazione (adattabile secondo necessità)
    String explanation =
        "Spiegazione dei Dati:\n\n"
        "1. Bounding Box: Rettangolo che racchiude tutti i punti di un Paese (latitudine/longitudine minime e massime). "
        "L'area si calcola approssimando le distanze tra le coordinate.\n\n"
        "2. Area per Marker: Rapporto tra l'area del Bounding Box e il numero di punti. "
        "Valore basso = distribuzione densa, alto = più sparsa.\n\n"
        "3. Distanza Media dal Nearest Neighbor: Media delle distanze tra ogni punto e il punto più vicino. "
        "Più è bassa, più i punti sono concentrati.\n\n"
        "4. Moran's I: Indice di autocorrelazione spaziale. "
        "Valori positivi > 0 indicano aggregazione, vicino allo 0 indica distribuzione casuale, valori negativi indicano dispersione.\n\n"
        "Valutazione della Copertura Territoriale:\n"
        "  • Migliore copertura: calcolo basato sull'Area/Marker più bassa.\n"
        "  • Peggiore copertura: Area/Marker più alta.\n\n"
        "Identificazione delle Aree di Concentrazione/Dispersione:\n"
        "  • Migliore concentrazione: Nearest Neighbor più basso.\n"
        "  • Maggiore dispersione: Nearest Neighbor più alto.";

    return Scaffold(
      appBar: AppBar(
        title: Text("Resoconto Dati"),
        backgroundColor: Color(0xFFFFF6F2),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
      ),
      backgroundColor: Color(0xFFFFF6F2),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  explanation,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text("Country", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Marker", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Area (km²)", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Area/Marker (km²)", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Nearest (km)", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Moran's I", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: sortedAnalyses.map((ca) {
                  return DataRow(
                    cells: [
                      DataCell(Text(ca.country)),
                      DataCell(Text(ca.markerCount.toString())),
                      DataCell(Text(ca.area.toStringAsFixed(2))),
                      DataCell(Text(ca.areaPerMarker.toStringAsFixed(2))),
                      DataCell(Text(ca.meanNearestDistance.toStringAsFixed(2))),
                      DataCell(Text(ca.moranI.toStringAsFixed(4))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------
// PAGINA PRINCIPALE
// -------------------
class SpatialPage extends StatefulWidget {
  @override
  _SpatialPageState createState() => _SpatialPageState();
}

class _SpatialPageState extends State<SpatialPage> {
  final Map<String, List<LatLng>> countryCoordinates = {
    "Austria": [LatLng(47.5, 9.5), LatLng(48.5, 14.5)],
    "Belgio": [LatLng(50.75, 3.25), LatLng(51.25, 5.25)],
    "Inghilterra": [LatLng(50.5, -5.5), LatLng(55.5, 0.5)],
    "Francia": [LatLng(41.5, -5.5), LatLng(51.5, 9.5)],
    "Germania": [LatLng(47.5, 5.5), LatLng(55.0, 15.5)],
    "Irlanda": [LatLng(51.5, -10.5), LatLng(55.5, -5.5)],
    "Olanda": [LatLng(50.5, 3.25), LatLng(53.5, 7.5)],
    "Norvegia": [LatLng(58.5, 4.5), LatLng(71.5, 31.5)],
    "Italia": [LatLng(36.5, 6.5), LatLng(47.5, 18.5)],
    "Portogallo": [LatLng(36.5, -10.5), LatLng(42.0, -6.5)],
    "Spagna": [LatLng(36.0, -9.5), LatLng(43.5, 3.5)],
    "Svizzera": [LatLng(45.5, 5.5), LatLng(47.8, 10.5)],
  };

  String _currentCountry = "Austria";
  late GoogleMapController _mapController;
  bool _showPopup = false;
  String _analysisInfo = "";

  final String _mapStyle = '''
  [
    {
      "featureType": "all",
      "elementType": "geometry",
      "stylers": [
        { "color": "#FCECEC" }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#EB8686" }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [
        { "color": "#FFD2D2" }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#FFF5F5" }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#B3A3A3" }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#FADCDC" }
      ]
    }
  ]
  ''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "",
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/map');
          },
        ),
        actions: [
          // Icona per mostrare i dati di analisi del Paese corrente
          IconButton(
            icon: Icon(Icons.article_rounded, color: Color(0xFFEB8686)),
            onPressed: () {
              setState(() {
                _analysisInfo = _computeCountryAnalysis(_currentCountry);
                _showPopup = !_showPopup;
              });
            },
          ),
          // Icona per ranking densità
          IconButton(
            icon: Icon(Icons.format_list_numbered_rtl, color: Color(0xFFEB8686)),
            onPressed: _showDensityRanking,
          ),
          // Icona per navigare alla pagina di Report globale
          IconButton(
            icon: Icon(Icons.pie_chart, color: Color(0xFFEB8686)),
            onPressed: () {
              // Calcoliamo le analisi per TUTTI i Paesi e navighiamo a ReportPage
              List<CountryAnalysis> allAnalyses = _computeAllCountriesAnalysis();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportPage(countryAnalyses: allAnalyses),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Container che contiene la mappa
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              // ClipRRect per arrotondare la mappa
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: countryCoordinates[_currentCountry]![0],
                    zoom: 6,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    _mapController.setMapStyle(_mapStyle);
                  },
                  markers: {
                    Marker(
                      markerId: MarkerId(_currentCountry),
                      position: countryCoordinates[_currentCountry]![0],
                    ),
                  },
                ),
              ),
            ),
          ),
          // Popup info sul paese corrente
          if (_showPopup)
            Positioned(
              left: 50,
              top: 100,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showPopup = false;
                  });
                },
                child: Container(
                  width: 250,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Info su $_currentCountry",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 5),
                      Text(
                        _analysisInfo,
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showPopup = false;
                          });
                        },
                        child: Text('Chiudi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFEB8686),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: Color(0xFFFFF6F2), // Sfondo rosato
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              color: Color(0xFFEB8686),
              onPressed: () {
                setState(() {
                  _currentCountry = _getPreviousCountry(_currentCountry);
                  _mapController.animateCamera(
                    CameraUpdate.newLatLng(countryCoordinates[_currentCountry]![0]),
                  );
                });
              },
            ),
            Text(
              _currentCountry,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFEB8686),
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward),
              color: Color(0xFFEB8686),
              onPressed: () {
                setState(() {
                  _currentCountry = _getNextCountry(_currentCountry);
                  _mapController.animateCamera(
                    CameraUpdate.newLatLng(countryCoordinates[_currentCountry]![0]),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // Restituisce la lista di analisi complete su TUTTI i Paesi
  List<CountryAnalysis> _computeAllCountriesAnalysis() {
    List<CountryAnalysis> analyses = [];
    countryCoordinates.forEach((country, points) {
      if (points.isEmpty) {
        analyses.add(CountryAnalysis(
          country: country,
          markerCount: 0,
          area: 0,
          areaPerMarker: 0,
          meanNearestDistance: 0,
          moranI: 0,
        ));
      } else {
        double minLat = points.map((p) => p.latitude).reduce(math.min);
        double maxLat = points.map((p) => p.latitude).reduce(math.max);
        double minLng = points.map((p) => p.longitude).reduce(math.min);
        double maxLng = points.map((p) => p.longitude).reduce(math.max);

        double latDist = _calculateDistance(LatLng(minLat, minLng), LatLng(maxLat, minLng));
        double lngDist = _calculateDistance(LatLng(minLat, minLng), LatLng(minLat, maxLng));
        double area = latDist * lngDist; // in km²
        int markerCount = points.length;
        double areaPerMarker = (markerCount > 0) ? (area / markerCount) : 0;

        // Distanza media nearest neighbor
        double totalNearestDistance = 0;
        for (int i = 0; i < points.length; i++) {
          double nearest = double.infinity;
          for (int j = 0; j < points.length; j++) {
            if (i == j) continue;
            double d = _calculateDistance(points[i], points[j]);
            if (d < nearest) nearest = d;
          }
          if (nearest == double.infinity) nearest = 0;
          totalNearestDistance += nearest;
        }
        double meanNearestDistance = (points.isNotEmpty) ? totalNearestDistance / points.length : 0;
        // Moran's I
        double moranI = _computeCountryGridMoranI(points);

        analyses.add(CountryAnalysis(
          country: country,
          markerCount: markerCount,
          area: area,
          areaPerMarker: areaPerMarker,
          meanNearestDistance: meanNearestDistance,
          moranI: moranI,
        ));
      }
    });
    return analyses;
  }

  // Restituisce la descrizione testuale per il Paese corrente
  String _computeCountryAnalysis(String country) {
    List<LatLng> points = countryCoordinates[country]!;
    if (points.isEmpty) return "Nessun dato disponibile.";

    double minLat = points.map((p) => p.latitude).reduce(math.min);
    double maxLat = points.map((p) => p.latitude).reduce(math.max);
    double minLng = points.map((p) => p.longitude).reduce(math.min);
    double maxLng = points.map((p) => p.longitude).reduce(math.max);

    double latDist = _calculateDistance(LatLng(minLat, minLng), LatLng(maxLat, minLng));
    double lngDist = _calculateDistance(LatLng(minLat, minLng), LatLng(minLat, maxLng));
    double area = latDist * lngDist; // in km²
    int markerCount = points.length;
    double density = (area > 0) ? markerCount / area : 0;

    // Distanza media nearest neighbor
    double totalNearestDistance = 0;
    for (int i = 0; i < points.length; i++) {
      double nearest = double.infinity;
      for (int j = 0; j < points.length; j++) {
        if (i == j) continue;
        double d = _calculateDistance(points[i], points[j]);
        if (d < nearest) nearest = d;
      }
      if (nearest == double.infinity) nearest = 0;
      totalNearestDistance += nearest;
    }
    double meanNearestDistance = (points.isNotEmpty) ? totalNearestDistance / points.length : 0;
    // Moran's I
    double moranI = _computeCountryGridMoranI(points);

    return "Punti: $markerCount\n"
           "Area: ${area.toStringAsFixed(6)} km²\n"
           "Densità: ${density.toStringAsExponential(6)} punti/km²\n"
           "Nearest Neighbor: ${meanNearestDistance.toStringAsFixed(6)} km\n"
           "Moran's I: ${moranI.toStringAsFixed(6)}";
  }

  // Classifica di densità (già presente)
  void _showDensityRanking() {
    List<_CountryDensity> densities = countryCoordinates.entries.map((entry) {
      double minLat = entry.value.map((p) => p.latitude).reduce(math.min);
      double maxLat = entry.value.map((p) => p.latitude).reduce(math.max);
      double minLng = entry.value.map((p) => p.longitude).reduce(math.min);
      double maxLng = entry.value.map((p) => p.longitude).reduce(math.max);

      double latDist = _calculateDistance(LatLng(minLat, minLng), LatLng(maxLat, minLng));
      double lngDist = _calculateDistance(LatLng(minLat, minLng), LatLng(minLat, maxLng));
      double area = latDist * lngDist;
      double density = (area > 0) ? entry.value.length / area : 0;

      return _CountryDensity(entry.key, density);
    }).toList();

    densities.sort((a, b) => b.density.compareTo(a.density));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFFFFF6F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Color(0xFFF3CCBB), width: 1),
          ),
          title: Text(
            '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEB8686),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: densities.map((cd) {
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListTile(
                    title: Text(
                      cd.country,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEB8686),
                      ),
                    ),
                    trailing: Text(
                      "Densità: ${cd.density.toStringAsExponential(6)} punti/km²",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFFEB8686),
                foregroundColor: Colors.white,
                textStyle: TextStyle(fontSize: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  // Calcoli di supporto
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371; // in km
    double dLat = _toRadians(p2.latitude - p1.latitude);
    double dLng = _toRadians(p2.longitude - p1.longitude);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(p1.latitude)) *
            math.cos(_toRadians(p2.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180.0;

  double _computeCountryGridMoranI(List<LatLng> points) {
    if (points.isEmpty) return 0.0;
    double minLat = points.map((p) => p.latitude).reduce(math.min);
    double maxLat = points.map((p) => p.latitude).reduce(math.max);
    double minLng = points.map((p) => p.longitude).reduce(math.min);
    double maxLng = points.map((p) => p.longitude).reduce(math.max);

    double cellSizeLat = 0.5;
    double cellSizeLng = 0.5;
    List<double> gridValues = [];
    List<LatLng> gridCentroids = [];

    for (double lat = minLat; lat <= maxLat; lat += cellSizeLat) {
      for (double lng = minLng; lng <= maxLng; lng += cellSizeLng) {
        double cellMinLat = lat;
        double cellMaxLat = lat + cellSizeLat;
        double cellMinLng = lng;
        double cellMaxLng = lng + cellSizeLng;
        int count = points.where((p) =>
            p.latitude >= cellMinLat &&
            p.latitude < cellMaxLat &&
            p.longitude >= cellMinLng &&
            p.longitude < cellMaxLng).length;

        gridValues.add(count.toDouble());
        double centroidLat = (cellMinLat + cellMaxLat) / 2;
        double centroidLng = (cellMinLng + cellMaxLng) / 2;
        gridCentroids.add(LatLng(centroidLat, centroidLng));
      }
    }
    return _computeMoranI(gridValues, gridCentroids);
  }

  double _computeMoranI(List<double> values, List<LatLng> centroids) {
    int n = values.length;
    double mean = values.reduce((a, b) => a + b) / n;
    List<List<double>> weights = List.generate(n, (_) => List.filled(n, 0.0));
    double S0 = 0.0;

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i != j) {
          double d = _calculateDistance(centroids[i], centroids[j]);
          double w = d > 0 ? 1 / d : 0.0;
          weights[i][j] = w;
          S0 += w;
        }
      }
    }

    double numerator = 0.0;
    double denominator = 0.0;
    for (int i = 0; i < n; i++) {
      denominator += (values[i] - mean) * (values[i] - mean);
      for (int j = 0; j < n; j++) {
        if (i != j) {
          numerator += weights[i][j] * (values[i] - mean) * (values[j] - mean);
        }
      }
    }
    return (n / S0) * (numerator / denominator);
  }

  String _getPreviousCountry(String country) {
    List<String> countries = countryCoordinates.keys.toList();
    int currentIndex = countries.indexOf(country);
    int previousIndex = (currentIndex - 1 + countries.length) % countries.length;
    return countries[previousIndex];
  }

  String _getNextCountry(String country) {
    List<String> countries = countryCoordinates.keys.toList();
    int currentIndex = countries.indexOf(country);
    int nextIndex = (currentIndex + 1) % countries.length;
    return countries[nextIndex];
  }
}

class _CountryDensity {
  final String country;
  final double density;
  _CountryDensity(this.country, this.density);
}
