// mappe.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/location.dart';
import 'models/farmacia_model.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  BitmapDescriptor? customMarkerIcon;
  BitmapDescriptor? farmaciaMarkerIcon;
  final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  LatLng? _center;
  bool _isInfoWindowVisible = false;
  Offset _popupPosition = Offset(0, 0);

  final double _minZoom = 5.0;
  final double _maxZoom = 18.0;
  double _currentZoom = 6.0;

  List<LocationModel> _locations = [];
  List<FarmaciaModel> _farmacie = [];
  final Set<Marker> _markers = {};
  dynamic _currentInfoWindowData;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
    _fetchLocationsFromSupabase();
    _fetchFarmacieFromSupabase();
  }

  Future<void> _loadCustomMarkerIcon() async {
    customMarkerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/marker.png',
    );
    farmaciaMarkerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/farmacie.png',
    );
    setState(() {});
  }

  Future<void> _fetchLocationsFromSupabase() async {
    try {
      print("Tentativo di accesso a Supabase per i centri...");

      final response =
          await Supabase.instance.client.from('centri').select().execute();

      if (response.data == null || response.status != 200) {
        print("Errore nella connessione a Supabase o tabella 'centri' non trovata.");
        print("Stato della risposta: ${response.status}");
        return;
      }

      print("Accesso effettuato a Supabase per i centri");
      print("Dati recuperati dal database: ${response.data}");

      final data = response.data as List<dynamic>;
      setState(() {
        _locations = data.map((item) => LocationModel.fromMap(item)).toList();
      });

      if (_locations.isEmpty) {
        print("Nessun dato trovato nella tabella 'centri'");
      } else {
        print("Modello _locations: $_locations");
      }

      await _geocodeAllLocations();
    } catch (error) {
      print("Errore nel recupero delle locazioni: $error");
    }
  }

  Future<void> _fetchFarmacieFromSupabase() async {
    try {
      print("Tentativo di accesso a Supabase per le farmacie...");

      final response =
          await Supabase.instance.client.from('farmacie').select().execute();

      if (response.data == null || response.status != 200) {
        print("Errore nella connessione a Supabase o tabella 'farmacie' non trovata.");
        print("Stato della risposta: ${response.status}");
        return;
      }

      print("Accesso effettuato a Supabase per le farmacie");
      print("Dati recuperati dal database: ${response.data}");

      final data = response.data as List<dynamic>;
      setState(() {
        _farmacie = data.map((item) => FarmaciaModel.fromMap(item)).toList();
      });

      if (_farmacie.isEmpty) {
        print("Nessun dato trovato nella tabella 'farmacie'");
      } else {
        print("Modello _farmacie: $_farmacie");
      }

      await _geocodeAllFarmacie();
    } catch (error) {
      print("Errore nel recupero delle farmacie: $error");
    }
  }

  Future<void> _geocodeAllLocations() async {
    for (var location in _locations) {
      final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
      print("Geocodifica per l'indirizzo: $fullAddress");

      final coordinates = await _getCoordinatesFromAddress(fullAddress);
      if (coordinates != null) {
        print("Coordinate trovate per $fullAddress: ${coordinates.latitude}, ${coordinates.longitude}");
        setState(() {
          _markers.add(Marker(
            markerId: MarkerId('centro_${location.id}'),
            position: coordinates,
            icon: customMarkerIcon!,
            onTap: () {
              _showCustomInfoWindow(location, coordinates);
            },
          ));
        });
      } else {
        print("Impossibile ottenere le coordinate per: $fullAddress");
      }
    }
  }

  Future<void> _geocodeAllFarmacie() async {
    for (var farmacia in _farmacie) {
      final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
      print("Geocodifica per l'indirizzo: $fullAddress");

      final coordinates = await _getCoordinatesFromAddress(fullAddress);
      if (coordinates != null) {
        print("Coordinate trovate per $fullAddress: ${coordinates.latitude}, ${coordinates.longitude}");
        setState(() {
          _markers.add(Marker(
            markerId: MarkerId('farmacia_${farmacia.id}'),
            position: coordinates,
            icon: farmaciaMarkerIcon!,
            onTap: () {
              _showCustomInfoWindow(farmacia, coordinates);
            },
          ));
        });
      } else {
        print("Impossibile ottenere le coordinate per: $fullAddress");
      }
    }
  }

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      } else {
        print("Errore nel Geocoding: ${data['status']} per l'indirizzo: $address");
        return null;
      }
    } else {
      print("Errore nella richiesta HTTP: ${response.statusCode} per l'indirizzo: $address");
      return null;
    }
  }

  void _showCustomInfoWindow(dynamic locationData, LatLng position) async {
        ScreenCoordinate screenCoordinate = await mapController.getScreenCoordinate(position);

    double left = screenCoordinate.x.toDouble();
    double top = screenCoordinate.y.toDouble();
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double popupLeft = left - 75;
    double popupTop = top - 120;
    if (popupLeft < 10) popupLeft = 10;
    if (popupTop < 10) popupTop = 10;
    if (popupLeft + 150 > screenWidth) popupLeft = screenWidth - 160;
    if (popupTop + 100 > screenHeight) popupTop = screenHeight - 110;

    setState(() {
      _isInfoWindowVisible = true;
      _popupPosition = Offset(popupLeft, popupTop);
      _currentInfoWindowData = locationData;
    });
  }

  void _hideCustomInfoWindow() {
    setState(() {
      _isInfoWindowVisible = false;
      _currentInfoWindowData = null;
    });
  }

  // Stile della mappa
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
    if (_center != null) {
      mapController
          .animateCamera(CameraUpdate.newLatLngZoom(_center!, _currentZoom));
    }
  }

  void _zoomIn() {
    if (_currentZoom < _maxZoom) {
      mapController.animateCamera(CameraUpdate.zoomIn());
    }
  }

  void _zoomOut() {
    if (_currentZoom > _minZoom) {
      mapController.animateCamera(CameraUpdate.zoomOut());
    }
  }

  void _centerMap() {
    if (_center != null) {
      mapController.animateCamera(CameraUpdate.newLatLng(_center!));
    }
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
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center ??
                  LatLng(41.9028, 12.4964), // Posizione di default a Roma
              zoom: _currentZoom,
            ),
            markers: _markers,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            minMaxZoomPreference: MinMaxZoomPreference(_minZoom, _maxZoom),
            onTap: (LatLng position) {
              _hideCustomInfoWindow();
            },
            onCameraMove: (CameraPosition position) {
              setState(() {
                _currentZoom = position.zoom;
              });
            },
          ),
          if (_isInfoWindowVisible && _currentInfoWindowData != null)
            Positioned(
              left: _popupPosition.dx,
              top: _popupPosition.dy,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: 200,
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
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentInfoWindowData is LocationModel
                              ? _currentInfoWindowData.nome
                              : _currentInfoWindowData.descrizione,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 5),
                        Text(
                          _currentInfoWindowData is LocationModel
                              ? "Indirizzo: ${_currentInfoWindowData.indirizzo}, ${_currentInfoWindowData.cap}, ${_currentInfoWindowData.citta}"
                              : "Indirizzo: ${_currentInfoWindowData.indirizzo}, ${_currentInfoWindowData.comune}",
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        if (_currentInfoWindowData is LocationModel) ...[
                          SizedBox(height: 5),
                          Text(
                            "Numero: ${_currentInfoWindowData.numero}",
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 5),
                          Text(
                            "Orari: ${_currentInfoWindowData.orari}",
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 5),
                          Text(
                            "IVG Farmacologica: ${_currentInfoWindowData.ivgFarm}",
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 5),
                          Text(
                            "IVG Chirurgica: ${_currentInfoWindowData.ivgChirurgica}",
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 5),
                          Text(
                            "ITG: ${_currentInfoWindowData.itg}",
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 5),
                          Text(
                            "Annotazioni: ${_currentInfoWindowData.annotazioni}",
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        SizedBox(height: 5),
                        ElevatedButton(
                          onPressed: () {
                            print(
                                "Dettagli per ${_currentInfoWindowData is LocationModel ? _currentInfoWindowData.nome : _currentInfoWindowData.descrizione}");
                          },
                          child: Text('Dettagli'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: Size(80, 30),
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
            ),
          Positioned(
            bottom: 20,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: _centerMap,
                  child: Icon(Icons.my_location, size: 18),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _zoomIn,
                  child: Icon(Icons.add, size: 18),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _zoomOut,
                  child: Icon(Icons.remove, size: 18),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


