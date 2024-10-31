// main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carica le variabili d'ambiente dal file .env
  await dotenv.load(fileName: 'assets/config.env');

  // Imposta la modalità a schermo intero per rimuovere le barre di sistema
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mappa Italia',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  BitmapDescriptor? customMarkerIcon;
  final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final String address = "Piazza del Colosseo, 00184 Roma, Italia"; // Indirizzo da geocodificare
  LatLng? _center; // Posizione centrale basata sull'indirizzo
  Marker? _selectedMarker; // Marker selezionato
  bool _isInfoWindowVisible = false; // Visibilità della finestra informativa
  Offset _popupPosition = Offset(0, 0); // Posizione del popup personalizzato

  // Limiti di zoom
  final double _minZoom = 5.0;
  final double _maxZoom = 18.0;
  double _currentZoom = 6.0; // Zoom iniziale

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
    // La chiamata a _getCoordinatesFromAddress verrà effettuata dopo la creazione della mappa
  }

  // Carica l'icona personalizzata per il marker
  Future<void> _loadCustomMarkerIcon() async {
    customMarkerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/marker.png', // Assicurati che il file marker.png sia presente in assets
    );
    setState(() {});
  }

  // Ottiene le coordinate dall'indirizzo usando l'API di Geocoding di Google
  Future<void> _getCoordinatesFromAddress(String address) async {
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        setState(() {
          _center = LatLng(lat, lng);
        });
        // Animare la camera dopo aver impostato la posizione centrale
        mapController.animateCamera(CameraUpdate.newLatLng(_center!));
      } else {
        print("Errore nel Geocoding: ${data['status']}");
      }
    } else {
      print("Errore nella richiesta HTTP: ${response.statusCode}");
    }
  }

  // Imposta lo stile della mappa
  final String mapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        { "color": "#FFF6F2" }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#DCB7B7" }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        { "color": "#FFFFFF" }
      ]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [
        { "color": "#F3CCBB" }
      ]
    },
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [
        { "color": "#FFF0F0" }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [
        { "color": "#FFEAFA" }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        { "color": "#FFF6F2" }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        { "color": "#F3CCBB" }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [
        { "color": "#EB8686" }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        { "color": "#EB8686" }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        { "color": "#DCB7B7" }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        { "color": "#FFF6F2" }
      ]
    }
  ]
  ''';

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController.setMapStyle(mapStyle);
    // Dopo la creazione della mappa, ottenere le coordinate dall'indirizzo
    _getCoordinatesFromAddress(address);
  }

  // Funzione per zoom in
  void _zoomIn() {
    if (_currentZoom < _maxZoom) {
      mapController.animateCamera(CameraUpdate.zoomIn());
    }
  }

  // Funzione per zoom out
  void _zoomOut() {
    if (_currentZoom > _minZoom) {
      mapController.animateCamera(CameraUpdate.zoomOut());
    }
  }

  // Funzione per centrare la mappa sull'indirizzo
  void _centerMap() {
    if (_center != null) {
      mapController.animateCamera(CameraUpdate.newLatLng(_center!));
    }
  }

  // Funzione per mostrare il custom info window
  Future<void> _showCustomInfoWindow(Marker marker) async {
    // Ottieni le coordinate dello schermo del marker
    ScreenCoordinate screenCoordinate = await mapController.getScreenCoordinate(marker.position);

    // Converti ScreenCoordinate in posizioni relative allo schermo
    double left = screenCoordinate.x.toDouble();
    double top = screenCoordinate.y.toDouble();

    // Ottieni le dimensioni dello schermo
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Calcola la posizione del popup (ad esempio sopra il marker)
    double popupLeft = left - 75; // metà della larghezza del popup (150 / 2)
    double popupTop = top - 120; // altezza del popup + offset

    // Assicurati che il popup non esca dallo schermo
    if (popupLeft < 10) popupLeft = 10;
    if (popupTop < 10) popupTop = 10;
    if (popupLeft + 150 > screenWidth) popupLeft = screenWidth - 160;
    if (popupTop + 100 > screenHeight) popupTop = screenHeight - 110;

    setState(() {
      _selectedMarker = marker;
      _isInfoWindowVisible = true;
      // Usa variabili per la posizione del popup
      _popupPosition = Offset(popupLeft, popupTop);
    });
  }

  // Funzione per nascondere il custom info window
  void _hideCustomInfoWindow() {
    setState(() {
      _selectedMarker = null;
      _isInfoWindowVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mappa Italia"),
        centerTitle: true,
        backgroundColor: Color(0xFFFFF6F2),
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.transparent, // Evita la comparsa di barre bianche
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center ?? LatLng(41.9028, 12.4964), // Posizione di default a Roma
              zoom: _currentZoom,
            ),
            markers: {
              if (_center != null && customMarkerIcon != null)
                Marker(
                  markerId: MarkerId("Marker"),
                  position: _center!,
                  icon: customMarkerIcon!,
                  onTap: () {
                    _showCustomInfoWindow(Marker(
                      markerId: MarkerId("Marker"),
                      position: _center!,
                      icon: customMarkerIcon!,
                    ));
                  },
                ),
            },
            mapToolbarEnabled: false, // Disabilita la toolbar di Google Maps
            zoomControlsEnabled: false, // Disabilita i controlli di zoom di default
            myLocationButtonEnabled: false, // Disabilita il pulsante di localizzazione di default
            minMaxZoomPreference: MinMaxZoomPreference(_minZoom, _maxZoom), // Limiti di zoom
            onTap: (LatLng position) {
              _hideCustomInfoWindow();
            },
            onCameraMove: (CameraPosition position) {
              setState(() {
                _currentZoom = position.zoom;
                // Aggiorna lo stato dei pulsanti di zoom, se necessario
              });
            },
          ),
          // Popup personalizzato
          if (_isInfoWindowVisible && _selectedMarker != null)
            Positioned(
              left: _popupPosition.dx,
              top: _popupPosition.dy,
              child: GestureDetector(
                onTap: () {
                  // Gestisci il tap sul popup, se necessario
                },
                child: Container(
                  width: 150,
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
                        address,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Il Colosseo è un'icona di Roma.",
                        style: TextStyle(
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 5),
                      ElevatedButton(
                        onPressed: () {
                          // Azione da eseguire quando si preme il pulsante
                          print("Pulsante Info Window premuto");
                        },
                        child: Text('Dettagli'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Colore del pulsante
                          foregroundColor: Colors.white, // Colore del testo
                          minimumSize: Size(80, 30), // Dimensioni minime
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Controlli della mappa (Zoom e Centra)
          Positioned(
            bottom: 20, // Margine regolato dal basso
            right: 10,  // Margine regolato dal lato destro
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsante per centrare la mappa sull'indirizzo
                FloatingActionButton(
                  mini: true,
                  onPressed: _centerMap,
                  child: Icon(Icons.my_location, size: 18),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 2,
                ),
                SizedBox(height: 8),
                // Pulsante per zoom in
                FloatingActionButton(
                  mini: true,
                  onPressed: _currentZoom < _maxZoom ? _zoomIn : null,
                  child: Icon(Icons.add, size: 18),
                  backgroundColor: _currentZoom < _maxZoom ? Colors.white : Colors.grey,
                  foregroundColor: _currentZoom < _maxZoom ? Colors.black : Colors.white,
                  elevation: 2,
                ),
                SizedBox(height: 8),
                // Pulsante per zoom out
                FloatingActionButton(
                  mini: true,
                  onPressed: _currentZoom > _minZoom ? _zoomOut : null,
                  child: Icon(Icons.remove, size: 18),
                  backgroundColor: _currentZoom > _minZoom ? Colors.white : Colors.grey,
                  foregroundColor: _currentZoom > _minZoom ? Colors.black : Colors.white,
                  elevation: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
