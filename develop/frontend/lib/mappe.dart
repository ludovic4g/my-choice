import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_state.dart';
import 'models/location.dart';
import 'models/farmacia_model.dart';

enum FilterOption { centri, farmacie, tutto }

class ReportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String message = "Le analisi dei paesi sono ora disponibili nei popup della pagina Spatial.";
    return Scaffold(
      appBar: AppBar(
        title: Text("Resoconto Dati"),
        backgroundColor: Color(0xFFFFF6F2),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
      ),
      backgroundColor: Color(0xFFFFF6F2),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(message, style: TextStyle(fontSize: 16)),
        ),
      ),
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
  BitmapDescriptor? farmaciaMarkerIcon;

  final String mapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final String directionsApiKey = dotenv.env['DIRECTIONS_API_KEY'] ?? '';

  LatLng? _center;
  LatLng? _userPosition;

  bool _isInfoWindowVisible = false;
  Offset _popupPosition = Offset(0, 0);
  dynamic _currentInfoWindowData;
  double? _currentMarkerDistance;

  final double _minZoom = 5.0;
  final double _maxZoom = 18.0;
  double _currentZoom = 6.0;

  List<LocationModel> _locations = [];
  List<FarmaciaModel> _farmacie = [];

  final Set<Marker> _localMarkers = {};
  final Set<Marker> _foreignMarkers = {};

  FilterOption _currentFilter = FilterOption.centri;
  String _searchQuery = "";
  bool _isLoading = false;

  final Map<String, LatLng> _geocodingCache = {};

  Set<Polyline> _polylines = {};
  String _routeDistance = "";
  String _routeDuration = "";

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final String _mapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#FFF6F2"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#DCB7B7"}]},
    {"featureType": "road", "stylers": [{"color": "#F3CCBB"}]},
    {"featureType": "water", "stylers": [{"color": "#FFF6F2"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _retrieveUserLocation();
    _loadCustomMarkerIcon();
    _fetchAllData();
  }

  Future<void> _retrieveUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return;
    setState(() {
      _userPosition = LatLng(position.latitude, position.longitude);
      _center = _userPosition;
    });
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
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    await _fetchLocationsFromSupabase();
    await _fetchFarmacieFromSupabase();
    await _fetchCountryCenters();
    await _updateMarkers();

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchLocationsFromSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('centri')
          .select()
          .execute();
      if (response.status == 200 && response.data != null) {
        final data = response.data as List<dynamic>;
        setState(() {
          _locations = data.map((item) => LocationModel.fromMap(item)).toList();
        });
      }
    } catch (error) {
      print("Errore nel recupero delle locazioni: $error");
    }
  }

  Future<void> _fetchFarmacieFromSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('farmacie')
          .select()
          .execute();
      if (response.status == 200 && response.data != null) {
        final data = response.data as List<dynamic>;
        setState(() {
          _farmacie = data.map((item) => FarmaciaModel.fromMap(item)).toList();
        });
      }
    } catch (error) {
      print("Errore nel recupero delle farmacie: $error");
    }
  }

  Future<void> _fetchCountryCenters() async {
    // Implementa se necessario per tabelle estere
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFFFFF6F2),
      elevation: 0,
      centerTitle: true,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cerca città o indirizzo...',
                border: InputBorder.none,
              ),
              onChanged: (value) async {
                setState(() => _searchQuery = value);
                await _applySearch();
              },
            )
          : Text("", style: TextStyle(color: Colors.black, fontSize: 20)),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.black),
          onPressed: () async {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchQuery = "";
                _searchController.clear();
              });
              await _updateMarkers();
            } else {
              setState(() => _isSearching = true);
            }
          },
        ),
        PopupMenuButton<FilterOption>(
          icon: Icon(
            _currentFilter == FilterOption.centri
                ? Icons.local_hospital
                : _currentFilter == FilterOption.farmacie
                    ? Icons.local_pharmacy
                    : Icons.layers,
            color: Colors.black,
          ),
          onSelected: _onFilterSelected,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<FilterOption>>[
            const PopupMenuItem<FilterOption>(
              value: FilterOption.centri,
              child: Text('Solo Centri'),
            ),
            const PopupMenuItem<FilterOption>(
              value: FilterOption.farmacie,
              child: Text('Solo Farmacie'),
            ),
            const PopupMenuItem<FilterOption>(
              value: FilterOption.tutto,
              child: Text('Tutto'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updateMarkers() async {
    _localMarkers.clear();
    List<Future<void>> geocodeFutures = [];

    if (_currentFilter == FilterOption.centri || _currentFilter == FilterOption.tutto) {
      geocodeFutures.add(_geocodeAllLocations());
    }
    if (_currentFilter == FilterOption.farmacie || _currentFilter == FilterOption.tutto) {
      geocodeFutures.add(_geocodeAllFarmacie());
    }

    if (geocodeFutures.isNotEmpty) await Future.wait(geocodeFutures);
    if (_searchQuery.isNotEmpty) await _applySearch();
    setState(() {});
  }

  Future<void> _geocodeAllLocations() async {
    await Future.wait(_locations.map((location) async {
      final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
      final coordinates = await _getCoordinatesFromAddress(fullAddress);
      if (coordinates != null) {
        setState(() {
          _localMarkers.add(Marker(
            markerId: MarkerId('centro_${location.id}'),
            position: coordinates,
            icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () => _showCustomInfoWindow(location, coordinates),
          ));
        });
      }
    }));
  }

  Future<void> _geocodeAllFarmacie() async {
    await Future.wait(_farmacie.map((farmacia) async {
      final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
      final coordinates = await _getCoordinatesFromAddress(fullAddress);
      if (coordinates != null) {
        setState(() {
          _localMarkers.add(Marker(
            markerId: MarkerId('farmacia_${farmacia.id}'),
            position: coordinates,
            icon: farmaciaMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () => _showCustomInfoWindow(farmacia, coordinates),
          ));
        });
      }
    }));
  }

  Future<void> _applySearch() async {
    _localMarkers.clear();
    List<LatLng> foundCoordinates = [];
    List<Future<void>> geocodeFutures = [];

    // Centri
    if (_currentFilter == FilterOption.centri || _currentFilter == FilterOption.tutto) {
      final filteredLocations = _locations.where((loc) =>
          loc.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loc.indirizzo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loc.citta.toLowerCase().contains(_searchQuery.toLowerCase()));
      geocodeFutures.add(Future.wait(filteredLocations.map((location) async {
        final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
        final coordinates = await _getCoordinatesFromAddress(fullAddress);
        if (coordinates != null) {
          foundCoordinates.add(coordinates);
          setState(() {
            _localMarkers.add(Marker(
              markerId: MarkerId('centro_${location.id}'),
              position: coordinates,
              icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
              onTap: () => _showCustomInfoWindow(location, coordinates),
            ));
          });
        }
      })));
    }

    // Farmacie
    if (_currentFilter == FilterOption.farmacie || _currentFilter == FilterOption.tutto) {
      final filteredFarmacie = _farmacie.where((farm) =>
          farm.descrizione.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          farm.indirizzo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          farm.comune.toLowerCase().contains(_searchQuery.toLowerCase()));
      geocodeFutures.add(Future.wait(filteredFarmacie.map((farmacia) async {
        final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
        final coordinates = await _getCoordinatesFromAddress(fullAddress);
        if (coordinates != null) {
          foundCoordinates.add(coordinates);
          setState(() {
            _localMarkers.add(Marker(
              markerId: MarkerId('farmacia_${farmacia.id}'),
              position: coordinates,
              icon: farmaciaMarkerIcon ?? BitmapDescriptor.defaultMarker,
              onTap: () => _showCustomInfoWindow(farmacia, coordinates),
            ));
          });
        }
      })));
    }

    if (geocodeFutures.isNotEmpty) await Future.wait(geocodeFutures);

    // Se abbiamo trovato coordinate, adattiamo la camera
    if (foundCoordinates.isNotEmpty && mapController != null) {
      if (foundCoordinates.length == 1) {
        await mapController.animateCamera(
          CameraUpdate.newLatLngZoom(foundCoordinates.first, 14),
        );
      } else {
        double minLat = foundCoordinates.map((p) => p.latitude).reduce(math.min);
        double maxLat = foundCoordinates.map((p) => p.latitude).reduce(math.max);
        double minLng = foundCoordinates.map((p) => p.longitude).reduce(math.min);
        double maxLng = foundCoordinates.map((p) => p.longitude).reduce(math.max);
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );
        await mapController.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60),
        );
      }
    }
  }

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    if (_geocodingCache.containsKey(address)) return _geocodingCache[address];
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$mapsApiKey";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);
          _geocodingCache[address] = latLng;
          return latLng;
        }
      }
    } catch (e) {
      print("Errore durante il geocoding di '$address': $e");
    }
    return null;
  }

  void _onFilterSelected(FilterOption option) async {
    setState(() {
      _currentFilter = option;
      _searchQuery = "";
      _searchController.clear();
    });
    await _updateMarkers();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController.setMapStyle(_mapStyle);
    if (_center != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_center!, _currentZoom));
    }
  }

  void _hideCustomInfoWindow() {
    setState(() {
      _isInfoWindowVisible = false;
      _currentInfoWindowData = null;
      _currentMarkerDistance = null;
    });
  }

  void _showCustomInfoWindow(dynamic locationData, LatLng position) async {
    final Size screenSize = MediaQuery.of(context).size;
    ScreenCoordinate screenCoordinate = await mapController.getScreenCoordinate(position);
    const double popupWidth = 200;
    const double popupHeight = 100;
    double left = screenCoordinate.x.toDouble() - (popupWidth / 2);
    double top = screenCoordinate.y.toDouble() - popupHeight - 10;
    if (left < 0) left = 10;
    else if (left + popupWidth > screenSize.width) left = screenSize.width - popupWidth - 10;
    if (top < 0) top = screenCoordinate.y.toDouble() + 10;
    double distanza = 0.0;
    if (_userPosition != null) {
      distanza = _calculateDistance(_userPosition!, position);
    }
    setState(() {
      _isInfoWindowVisible = true;
      _popupPosition = Offset(left, top);
      _currentInfoWindowData = locationData;
      _currentMarkerDistance = distanza;
    });
  }

  // Funzione corretta per salvare i preferiti
  Future<void> _addToFavourites(dynamic locationData) async {
    final userEmail = currentUserInfo?['email'];
    if (userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Devi essere loggato per aggiungere preferiti.")),
      );
      return;
    }

    // Determiniamo il testo da salvare in "fav"
    String favourite;
    if (locationData is LocationModel) {
      favourite = locationData.nome;
    } else if (locationData is FarmaciaModel) {
      favourite = locationData.descrizione;
    } else if (locationData is Map<String, dynamic>) {
      favourite = locationData['nome'] ?? locationData.toString();
    } else {
      favourite = locationData.toString();
    }

    final supabase = Supabase.instance.client;

    try {
      // Lettura diretta con .single()
      final data = await supabase
          .from('users')
          .select('fav')
          .eq('email', userEmail)
          .single() as Map<String, dynamic>?; 
          // Se non trova record, lancia eccezione

      String currentFavString = "";
      if (data != null && data['fav'] != null) {
        currentFavString = data['fav'] as String;
      }

      // Convertiamo la stringa in lista
      List<String> favList = currentFavString
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Evitiamo duplicati
      if (favList.contains(favourite)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Già presente nei preferiti")),
        );
        return;
      }

      // Aggiungiamo l'elemento
      favList.add(favourite);
      final newFavString = favList.join('\n');

      // Aggiorniamo sul DB
      await supabase
          .from('users')
          .update({'fav': newFavString})
          .eq('email', userEmail);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aggiunto ai preferiti")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore nel salvataggio preferiti: $e")),
      );
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const R = 6371000;
    double dLat = _degToRad(end.latitude - start.latitude);
    double dLon = _degToRad(end.longitude - start.longitude);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(start.latitude)) *
            math.cos(_degToRad(end.latitude)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180;

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&key=$directionsApiKey";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        final polylinePoints = route['overview_polyline']['points'];
        final distance = route['legs'][0]['distance']['text'];
        final duration = route['legs'][0]['duration']['text'];
        setState(() {
          _routeDistance = distance;
          _routeDuration = duration;
        });
        List<LatLng> decodedPath = _decodePolyline(polylinePoints);
        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: PolylineId("directions"),
            width: 5,
            color: Colors.blue,
            points: decodedPath,
          ));
        });
        _fitMapToPolyline(decodedPath);
      }
    }
  }

  void _fitMapToPolyline(List<LatLng> points) async {
    double minLat = points.map((p) => p.latitude).reduce(math.min);
    double maxLat = points.map((p) => p.latitude).reduce(math.max);
    double minLng = points.map((p) => p.longitude).reduce(math.min);
    double maxLng = points.map((p) => p.longitude).reduce(math.max);
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 50);
    await mapController.animateCamera(cameraUpdate);
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      final latD = lat / 1e5;
      final lngD = lng / 1e5;
      points.add(LatLng(latD, lngD));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          if (_userPosition != null)
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center ?? _userPosition!,
                zoom: _currentZoom,
              ),
              markers: _localMarkers.union(_foreignMarkers),
              polylines: _polylines,
              onTap: (LatLng position) => _hideCustomInfoWindow(),
              zoomControlsEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              minMaxZoomPreference: MinMaxZoomPreference(_minZoom, _maxZoom),
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
                onTap: () => setState(() => _isInfoWindowVisible = false),
                child: Container(
                  width: 200,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentInfoWindowData is LocationModel
                            ? _currentInfoWindowData.nome
                            : _currentInfoWindowData is FarmaciaModel
                                ? _currentInfoWindowData.descrizione
                                : "Info",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 5),
                      Text(
                        _currentInfoWindowData is LocationModel
                            ? "Indirizzo: ${_currentInfoWindowData.indirizzo}, ${_currentInfoWindowData.cap}, ${_currentInfoWindowData.citta}"
                            : _currentInfoWindowData is FarmaciaModel
                                ? "Indirizzo: ${_currentInfoWindowData.indirizzo}, ${_currentInfoWindowData.comune}"
                                : "N/D",
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      if (_currentMarkerDistance != null && _currentMarkerDistance! > 0)
                        Text(
                          "Distanza da te: ${(_currentMarkerDistance! / 1000).toStringAsFixed(2)} km",
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              // Implementa navigazione "Dettagli" se serve
                            },
                            child: Text('Dettagli', overflow: TextOverflow.ellipsis),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: Size(70, 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              if (_userPosition != null && _currentInfoWindowData != null) {
                                LatLng? markerPos;
                                if (_currentInfoWindowData is LocationModel) {
                                  markerPos = await _getCoordinatesFromAddress(
                                      "${_currentInfoWindowData.indirizzo}, ${_currentInfoWindowData.cap}, ${_currentInfoWindowData.citta}");
                                } else if (_currentInfoWindowData is FarmaciaModel) {
                                  markerPos = await _getCoordinatesFromAddress(
                                      "${_currentInfoWindowData.indirizzo}, ${_currentInfoWindowData.comune}");
                                }
                                if (markerPos != null) {
                                  await _getDirections(_userPosition!, markerPos);
                                }
                              }
                            },
                            child: Text('Avvia Nav', overflow: TextOverflow.ellipsis),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: Size(70, 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _addToFavourites(_currentInfoWindowData);
                            },
                            icon: Icon(Icons.star_border, size: 16, color: Colors.white),
                            label: Text('Preferiti', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFEB8686),
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoading) Center(child: CircularProgressIndicator()),
          if (_routeDistance.isNotEmpty && _routeDuration.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(15),
                color: Colors.white.withOpacity(0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Percorso trovato:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Distanza: $_routeDistance"),
                    Text("Durata: $_routeDuration"),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 50,
            left: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/spatial');
              },
              child: Icon(Icons.align_vertical_bottom_rounded, color: Colors.white),
              backgroundColor: Color(0xFFEB8686),
            ),
          ),
        ],
      ),
    );
  }

  String _getCountryNameFromTable(String tableName) {
    final Map<String, String> tableToCountry = {
      'centri_austria': 'Austria',
      'centri_belgio': 'Belgio',
      'centri_francia': 'Francia',
      'centri_germania': 'Germania',
      'centri_inghilterra': 'Inghilterra',
      'centri_irlanda': 'Irlanda',
      'centri_norvegia': 'Norvegia',
      'centri_olanda': 'Olanda',
      'centri_portogallo': 'Portogallo',
      'centri_spagna': 'Spagna',
      'centri_svizzera': 'Svizzera',
    };
    return tableToCountry[tableName] ?? 'Unknown';
  }
}
