import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/location.dart';
import 'models/farmacia_model.dart';

class SearchSuggestion {
  final String display;
  final String type;
  final dynamic data;

  SearchSuggestion({
    required this.display,
    required this.type,
    this.data,
  });
}

enum FilterOption { centri, farmacie, tutto }

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  BitmapDescriptor? customMarkerIcon;
  BitmapDescriptor? farmaciaMarkerIcon;

  // Chiavi API
  final String mapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final String directionsApiKey = dotenv.env['DIRECTIONS_API_KEY'] ?? '';

  LatLng? _center;
  LatLng? _userPosition;
  bool _isInfoWindowVisible = false;
  Offset _popupPosition = Offset(0, 0);

  final double _minZoom = 5.0;
  final double _maxZoom = 18.0;
  double _currentZoom = 6.0;

  List<LocationModel> _locations = [];
  List<FarmaciaModel> _farmacie = [];

  // Marker separati:
  // _localMarkers per i marker relativi a "centri" e "farmacie" (Italia)
  // _foreignMarkers per i marker relativi alle table estere (es. centri_austria, centri_belgio, ecc.)
  final Set<Marker> _localMarkers = {};
  final Set<Marker> _foreignMarkers = {};

  dynamic _currentInfoWindowData;
  FilterOption _currentFilter = FilterOption.centri;
  String _searchQuery = "";
  bool _isLoading = false;

  final Map<String, LatLng> _geocodingCache = {};
  double? _currentMarkerDistance; // Distanza dal marker corrente

  // Variabili per la navigazione interna
  Set<Polyline> _polylines = {};
  String _routeDistance = "";
  String _routeDuration = "";

  // Resoconto finale per passarlo alla ReportPage
  List<CountryAnalysis> _countryAnalyses = [];

  // Mappa dei tassi di aborti (tabella tasso_aborti: Paese, Tasso_Aborti)
  Map<String, double> _tassoAborti = {};

  @override
  void initState() {
    super.initState();
    _retrieveUserLocation();
    _loadCustomMarkerIcon();
    _fetchAllData();
  }

  Future<void> _retrieveUserLocation() async {
    print("[DEBUG] Recupero posizione utente...");
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      print("[DEBUG] Permessi negati, li richiedo...");
      permission = await Geolocator.requestPermission();
    }
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    print("[DEBUG] Posizione utente: ${position.latitude}, ${position.longitude}");
    if (!mounted) return;
    setState(() {
      _userPosition = LatLng(position.latitude, position.longitude);
      _center = _userPosition;
    });
  }

  Future<void> _loadCustomMarkerIcon() async {
    print("[DEBUG] Caricamento icone dei marker personalizzati...");
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
    print("[DEBUG] Recupero dati da Supabase...");
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    await _fetchLocationsFromSupabase();
    await _fetchFarmacieFromSupabase();
    await _fetchCountryCenters(); // Recupero centri esteri
    await _fetchTassoAborti();     // Recupero tassi di aborti
    await _updateMarkers();
    await _performCountrySpatialAnalysis(); // Analisi spaziale per ogni country

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchTassoAborti() async {
    try {
      final response = await Supabase.instance.client.from('tasso_aborti').select().execute();
      if (response.data != null && response.status == 200) {
        final data = response.data as List<dynamic>;
        Map<String, double> tmp = {};
        for (var item in data) {
          tmp[item['Paese']] = double.tryParse(item['Tasso_Aborti'].toString()) ?? 0.0;
        }
        setState(() {
          _tassoAborti = tmp;
        });
        print("[DEBUG] Tassi aborti: $_tassoAborti");
      }
    } catch (error) {
      print("Errore nel recupero dei tassi di aborti: $error");
    }
  }

  Future<void> _fetchCountryCenters() async {
    print("[DEBUG] Recupero dati dei centri da altri paesi...");
    List<String> tables = [
      'centri_austria',
      'centri_belgio',
      'centri_francia',
      'centri_germania',
      'centri_inghilterra',
      'centri_irlanda',
      'centri_norvegia',
      'centri_olanda',
      'centri_portogallo',
      'centri_spagna',
      'centri_svizzera',
    ];
    List<Future<void>> fetchFutures = tables.map((table) => _fetchLocationsFromCountry(table)).toList();
    await Future.wait(fetchFutures);
    print("[DEBUG] Recupero completato.");
  }

  Future<void> _fetchLocationsFromCountry(String tableName) async {
    try {
      final response = await Supabase.instance.client.from(tableName).select().execute();
      if (response.data != null && response.status == 200) {
        final data = response.data as List<dynamic>;
        List<LocationModel> locations = data.map((item) => LocationModel.fromMap(item)).toList();
        print("[DEBUG] Recuperati ${locations.length} centri da $tableName.");
        await Future.wait(locations.map((location) async {
          final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}, ${_getCountryNameFromTable(tableName)}";
          final coordinates = await _getCoordinatesFromAddress(fullAddress);
          if (coordinates != null) {
            if (!mounted) return;
            setState(() {
              _foreignMarkers.add(Marker(
                markerId: MarkerId('centro_${tableName}_${location.id}'),
                position: coordinates,
                icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
                onTap: () {
                  _showCustomInfoWindow(location, coordinates);
                },
              ));
            });
          }
        }));
      }
    } catch (error) {
      print("Errore nel recupero delle locazioni per $tableName: $error");
    }
  }

  Future<void> _fetchLocationsFromSupabase() async {
    try {
      final response = await Supabase.instance.client.from('centri').select().execute();
      if (response.data != null && response.status == 200) {
        final data = response.data as List<dynamic>;
        if (!mounted) return;
        setState(() {
          _locations = data.map((item) => LocationModel.fromMap(item)).toList();
        });
        print("[DEBUG] Recuperati ${_locations.length} centri.");
      }
    } catch (error) {
      print("Errore nel recupero delle locazioni: $error");
    }
  }

  Future<void> _fetchFarmacieFromSupabase() async {
    try {
      final response = await Supabase.instance.client.from('farmacie').select().execute();
      if (response.data != null && response.status == 200) {
        final data = response.data as List<dynamic>;
        if (!mounted) return;
        setState(() {
          _farmacie = data.map((item) => FarmaciaModel.fromMap(item)).toList();
        });
        print("[DEBUG] Recuperate ${_farmacie.length} farmacie.");
      }
    } catch (error) {
      print("Errore nel recupero delle farmacie: $error");
    }
  }

  Future<void> _updateMarkers() async {
    print("[DEBUG] Aggiornamento marker sulla mappa...");
    _localMarkers.clear();
    List<Future<void>> geocodeFutures = [];
    if (_currentFilter == FilterOption.centri || _currentFilter == FilterOption.tutto) {
      geocodeFutures.add(_geocodeAllLocations());
    }
    if (_currentFilter == FilterOption.farmacie || _currentFilter == FilterOption.tutto) {
      geocodeFutures.add(_geocodeAllFarmacie());
    }
    if (geocodeFutures.isNotEmpty) {
      await Future.wait(geocodeFutures);
    }
    if (_searchQuery.isNotEmpty) {
      await _applySearch();
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _geocodeAllLocations() async {
    print("[DEBUG] Geocoding centri...");
    await Future.wait(_locations.map((location) async {
      final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
      final coordinates = await _getCoordinatesFromAddress(fullAddress);
      if (coordinates != null) {
        if (!mounted) return;
        setState(() {
          _localMarkers.add(Marker(
            markerId: MarkerId('centro_${location.id}'),
            position: coordinates,
            icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () {
              _showCustomInfoWindow(location, coordinates);
            },
          ));
        });
      }
    }));
  }

  Future<void> _geocodeAllFarmacie() async {
    print("[DEBUG] Geocoding farmacie...");
    await Future.wait(_farmacie.map((farmacia) async {
      final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
      final coordinates = await _getCoordinatesFromAddress(fullAddress);
      if (coordinates != null) {
        if (!mounted) return;
        setState(() {
          _localMarkers.add(Marker(
            markerId: MarkerId('farmacia_${farmacia.id}'),
            position: coordinates,
            icon: farmaciaMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () {
              _showCustomInfoWindow(farmacia, coordinates);
            },
          ));
        });
      }
    }));
  }

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    if (_geocodingCache.containsKey(address)) {
      return _geocodingCache[address];
    }
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$mapsApiKey";
    print("[DEBUG] Richiesta geocoding per: $address");
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);
          _geocodingCache[address] = latLng;
          return latLng;
        } else {
          print("[DEBUG] Geocoding status: ${data['status']}. Nessuna posizione per $address");
        }
      } else {
        print("[DEBUG] Errore geocoding http: ${response.statusCode}");
      }
    } catch (e) {
      print("Errore durante il geocoding di '$address': $e");
    }
    return null;
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    print("[DEBUG] Richiesta direzioni da $origin a $destination");
    String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&key=$directionsApiKey";
    final response = await http.get(Uri.parse(url));
    print("[DEBUG] Risposta API Directions: ${response.statusCode}");
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print("[DEBUG] Data Directions: $data");
      if (data['status'] == 'OK') {
        print("[DEBUG] Direzioni trovate.");
        final route = data['routes'][0];
        final polylinePoints = route['overview_polyline']['points'];
        final distance = route['legs'][0]['distance']['text'];
        final duration = route['legs'][0]['duration']['text'];
        if (!mounted) return;
        setState(() {
          _routeDistance = distance;
          _routeDuration = duration;
        });
        print("[DEBUG] Distanza: $distance, Durata: $duration");
        print("[DEBUG] Decodifica polyline...");
        List<LatLng> decodedPath = _decodePolyline(polylinePoints);
        print("[DEBUG] Punti nel percorso: ${decodedPath.length}");
        if (!mounted) return;
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
      } else {
        print("[DEBUG] Nessun percorso trovato. Status: ${data['status']}");
      }
    } else {
      print("[DEBUG] Errore nel recupero delle direzioni: ${response.statusCode}");
    }
  }

  void _fitMapToPolyline(List<LatLng> points) async {
    print("[DEBUG] Adattamento mappa al percorso...");
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
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      double latD = lat / 1e5;
      double lngD = lng / 1e5;
      points.add(LatLng(latD, lngD));
    }
    return points;
  }

  // Definizione del metodo _hideCustomInfoWindow
  void _hideCustomInfoWindow() {
    print("[DEBUG] Nascondo popup...");
    if (!mounted) return;
    setState(() {
      _isInfoWindowVisible = false;
      _currentInfoWindowData = null;
      _currentMarkerDistance = null;
    });
  }

  // Definizione del metodo _showCustomInfoWindow
  void _showCustomInfoWindow(dynamic locationData, LatLng position) async {
    print("[DEBUG] Mostro popup per marker...");
    final Size screenSize = MediaQuery.of(context).size;
    ScreenCoordinate screenCoordinate = await mapController.getScreenCoordinate(position);
    const double popupWidth = 200;
    const double popupHeight = 100;
    double left = screenCoordinate.x.toDouble() - (popupWidth / 2);
    double top = screenCoordinate.y.toDouble() - popupHeight - 10;
    if (left < 0) {
      left = 10;
    } else if (left + popupWidth > screenSize.width) {
      left = screenSize.width - popupWidth - 10;
    }
    if (top < 0) {
      top = screenCoordinate.y.toDouble() + 10;
    }
    double distanza = 0.0;
    if (_userPosition != null) {
      distanza = _calculateDistance(_userPosition!, position);
    }
    if (!mounted) return;
    setState(() {
      _isInfoWindowVisible = true;
      _popupPosition = Offset(left, top);
      _currentInfoWindowData = locationData;
      _currentMarkerDistance = distanza;
    });
  }

  // Definizione del metodo _applySearch
  Future<void> _applySearch() async {
    print("[DEBUG] Applico ricerca: $_searchQuery");
    _localMarkers.clear();
    List<Future<void>> geocodeFutures = [];
    if (_currentFilter == FilterOption.centri || _currentFilter == FilterOption.tutto) {
      final filteredLocations = _locations.where((loc) =>
          loc.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loc.indirizzo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loc.citta.toLowerCase().contains(_searchQuery.toLowerCase()));
      geocodeFutures.add(Future.wait(filteredLocations.map((location) async {
        final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
        final coordinates = await _getCoordinatesFromAddress(fullAddress);
        if (coordinates != null) {
          if (!mounted) return;
          setState(() {
            _localMarkers.add(Marker(
              markerId: MarkerId('centro_${location.id}'),
              position: coordinates,
              icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
              onTap: () {
                _showCustomInfoWindow(location, coordinates);
              },
            ));
          });
        }
      })));
    }
    if (_currentFilter == FilterOption.farmacie || _currentFilter == FilterOption.tutto) {
      final filteredFarmacie = _farmacie.where((farm) =>
          farm.descrizione.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          farm.indirizzo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          farm.comune.toLowerCase().contains(_searchQuery.toLowerCase()));
      geocodeFutures.add(Future.wait(filteredFarmacie.map((farmacia) async {
        final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
        final coordinates = await _getCoordinatesFromAddress(fullAddress);
        if (coordinates != null) {
          if (!mounted) return;
          setState(() {
            _localMarkers.add(Marker(
              markerId: MarkerId('farmacia_${farmacia.id}'),
              position: coordinates,
              icon: farmaciaMarkerIcon ?? BitmapDescriptor.defaultMarker,
              onTap: () {
                _showCustomInfoWindow(farmacia, coordinates);
              },
            ));
          });
        }
      })));
    }
    if (geocodeFutures.isNotEmpty) {
      await Future.wait(geocodeFutures);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    print("[DEBUG] Mappa creata");
    mapController = controller;
    mapController.setMapStyle(mapStyle);
    if (_center != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_center!, _currentZoom));
    }
  }

  void _onFilterSelected(FilterOption option) async {
    print("[DEBUG] Filtro selezionato: $option");
    if (!mounted) return;
    setState(() {
      _currentFilter = option;
      _searchQuery = "";
    });
    await _updateMarkers();
    await _performCountrySpatialAnalysis();
  }

  // Metodo per calcolare la distanza tra due coordinate (in metri)
  double _calculateDistance(LatLng start, LatLng end) {
    const R = 6371000; // raggio della Terra in metri
    double dLat = _degToRad(end.latitude - start.latitude);
    double dLon = _degToRad(end.longitude - start.longitude);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(start.latitude)) *
            math.cos(_degToRad(end.latitude)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) {
    return deg * math.pi / 180;
  }
  // Metodo per eseguire l'analisi spaziale per ogni country e stampare i risultati in console.
  // Le metriche calcolate sono:
  // - Numero di marker
  // - Bounding Box (MinLat, MaxLat, MinLng, MaxLng)
  // - Centroide
  // - Distanza media tra i marker
  // - Standard Distance
  // - Distanza media dal nearest neighbor
  // - Area del Bounding Box
  // - Area per marker
  // - Moran's I
  Future<void> _performCountrySpatialAnalysis() async {
    Set<Marker> allMarkers = _localMarkers.union(_foreignMarkers);
    Map<String, List<LatLng>> countryPoints = {};
    for (Marker marker in allMarkers) {
      String markerId = marker.markerId.value;
      String country = "Italia"; // default per centri e farmacie italiani
      if (markerId.startsWith("centro_")) {
        List<String> parts = markerId.split('_');
        if (parts.length >= 4) {
          String tableName = "${parts[1]}_${parts[2]}";
          country = _getCountryNameFromTable(tableName);
        }
      } else if (markerId.startsWith("farmacia_")) {
        country = "Italia";
      }
      countryPoints.putIfAbsent(country, () => []).add(marker.position);
    }

    List<CountryAnalysis> analyses = [];
    countryPoints.forEach((country, points) {
      // Calcolo del bounding box
      double minLat = points.map((p) => p.latitude).reduce(math.min);
      double maxLat = points.map((p) => p.latitude).reduce(math.max);
      double minLng = points.map((p) => p.longitude).reduce(math.min);
      double maxLng = points.map((p) => p.longitude).reduce(math.max);
      double centerLat = (minLat + maxLat) / 2;
      double centerLng = (minLng + maxLng) / 2;

      // Calcolo delle metriche
      int count = 0;
      double totalDistance = 0;
      for (int i = 0; i < points.length; i++) {
        for (int j = i + 1; j < points.length; j++) {
          totalDistance += _calculateDistance(points[i], points[j]);
          count++;
        }
      }
      double avgDistance = count > 0 ? totalDistance / count : 0;

      double sumSq = 0;
      for (var p in points) {
        double d = _calculateDistance(p, LatLng(centerLat, centerLng));
        sumSq += d * d;
      }
      double standardDistance = points.isNotEmpty ? math.sqrt(sumSq / points.length) : 0;

      double totalNearestDistance = 0;
      for (int i = 0; i < points.length; i++) {
        double nearest = double.infinity;
        for (int j = 0; j < points.length; j++) {
          if (i == j) continue;
          double d = _calculateDistance(points[i], points[j]);
          if (d < nearest) nearest = d;
        }
        totalNearestDistance += nearest;
      }
      double meanNearestDistance = points.isNotEmpty ? totalNearestDistance / points.length : 0;

      double latDistance = _calculateDistance(LatLng(minLat, minLng), LatLng(maxLat, minLng));
      double lngDistance = _calculateDistance(LatLng(minLat, minLng), LatLng(minLat, maxLng));
      double area = latDistance * lngDistance;
      double areaPerMarker = points.isNotEmpty ? area / points.length : 0;

      double moranI = computeCountryGridMoranI(points);

      // Stampa in console nel formato richiesto
      print("--------------------------------------------------");
      print("Analisi spaziale per $country:");
      print("Numero di marker: ${points.length}");
      print("Bounding Box: MinLat: $minLat, MaxLat: $maxLat, MinLng: $minLng, MaxLng: $maxLng");
      print("Centroide: ($centerLat, $centerLng)");
      print("Distanza media tra i marker: ${avgDistance.toStringAsFixed(2)} metri");
      print("Standard Distance: ${standardDistance.toStringAsFixed(2)} metri");
      print("Distanza media dal nearest neighbor: ${meanNearestDistance.toStringAsFixed(2)} metri");
      print("Area del Bounding Box: ${area.toStringAsFixed(2)} m²");
      print("Area per marker: ${areaPerMarker.toStringAsFixed(2)} m²");
      print("Moran's I per $country: ${moranI.toStringAsFixed(4)}");
      print("--------------------------------------------------");

      analyses.add(CountryAnalysis(
        country: country,
        markerCount: points.length,
        area: area,
        areaPerMarker: areaPerMarker,
        meanNearestDistance: meanNearestDistance,
        moranI: moranI,
        minLat: minLat,
        minLng: minLng,
        maxLat: maxLat,
        maxLng: maxLng,
        minLocation: "",
        maxLocation: "",
      ));
    });

    setState(() {
      _countryAnalyses = analyses;
    });
  }

  double computeCountryGridMoranI(List<LatLng> points) {
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
    return computeMoranI(gridValues, gridCentroids);
  }

  double computeMoranI(List<double> values, List<LatLng> centroids) {
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

  final String mapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#FFF6F2"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#DCB7B7"}]},
    {"featureType": "road", "stylers": [{"color": "#F3CCBB"}]},
    {"featureType": "water", "stylers": [{"color": "#FFF6F2"}]}
  ]
  ''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MyChoice"),
        actions: [
          PopupMenuButton<FilterOption>(
            icon: Icon(
              _currentFilter == FilterOption.centri
                  ? Icons.local_hospital
                  : _currentFilter == FilterOption.farmacie
                      ? Icons.local_pharmacy
                      : Icons.layers,
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
          // Icona per aprire il report dei dati in una tabella
          IconButton(
            icon: Icon(Icons.pie_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportPage(countryAnalyses: _countryAnalyses),
                ),
              );
            },
          ),
        ],
        centerTitle: true,
        backgroundColor: Color(0xFFFFF6F2),
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
      ),
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
                if (!mounted) return;
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentInfoWindowData is LocationModel
                            ? _currentInfoWindowData.nome
                            : _currentInfoWindowData.descrizione,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                              print("Dettagli per ${_currentInfoWindowData is LocationModel ? _currentInfoWindowData.nome : _currentInfoWindowData.descrizione}");
                            },
                            child: Text('Dettagli', overflow: TextOverflow.ellipsis),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: Size(70, 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              if (_userPosition != null && _currentInfoWindowData != null) {
                                LatLng? markerPos;
                                if (_currentInfoWindowData is LocationModel) {
                                  markerPos = await _getCoordinatesFromAddress(
                                      "${_currentInfoWindowData.indirizzo}, ${_currentInfoWindowData.cap}, ${_currentInfoWindowData.citta}");
                                } else {
                                  markerPos = await _getCoordinatesFromAddress(
                                      "${_currentInfoWindowData.indirizzo}, ${_currentInfoWindowData.comune}");
                                }
                                if (markerPos != null) {
                                  print("[DEBUG] Posizione destinazione: $markerPos");
                                  await _getDirections(_userPosition!, markerPos);
                                } else {
                                  print("[DEBUG] Impossibile ottenere posizione destinazione");
                                }
                              }
                            },
                            child: Text('Avvia Nav', overflow: TextOverflow.ellipsis),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: Size(70, 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoading)
            Center(child: CircularProgressIndicator()),
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
        ],
      ),
    );
  }
}

class CountryAnalysis {
  final String country;
  final int markerCount;
  final double area; // in m²
  final double areaPerMarker;
  final double meanNearestDistance;
  final double moranI;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;
  final String minLocation;
  final String maxLocation;

  CountryAnalysis({
    required this.country,
    required this.markerCount,
    required this.area,
    required this.areaPerMarker,
    required this.meanNearestDistance,
    required this.moranI,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    required this.minLocation,
    required this.maxLocation,
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

    String explanation = 
      "Spiegazione dei Dati:\n\n"
      "1. Bounding Box: È il rettangolo che racchiude tutti i centri di un country, calcolato a partire dalla latitudine e longitudine minima e massima. "
      "L'area del Bounding Box si ottiene moltiplicando la distanza (in metri) tra la latitudine minima e quella massima per quella tra la longitudine minima e massima.\n\n"
      "2. Area per Marker: Si calcola dividendo l'area del Bounding Box per il numero di centri. Un valore basso indica una distribuzione densa, mentre un valore elevato indica centri più sparsi.\n\n"
      "3. Distanza Media dal Nearest Neighbor: Indica la distanza media dal centro più vicino per ogni centro. Valori bassi indicano una forte concentrazione, mentre valori elevati indicano dispersione.\n\n"
      "4. Moran's I: È un indice di autocorrelazione spaziale che misura se le aree con un alto numero di centri tendono ad aggregarsi (valore positivo), se la distribuzione è casuale (valore vicino a 0) o se è dispersa (valore negativo).\n\n"
      "Valutazione della Copertura Territoriale:\n"
      "  Migliore copertura: ${sortedAnalyses.where((ca) => ca.country == sortedAnalyses.reduce((a, b) => a.areaPerMarker < b.areaPerMarker ? a : b).country).first.country} con Area/Marker di ${sortedAnalyses.reduce((a, b) => a.areaPerMarker < b.areaPerMarker ? a : b).areaPerMarker.toStringAsFixed(2)} m²\n"
      "  Peggiore copertura: ${sortedAnalyses.where((ca) => ca.country == sortedAnalyses.reduce((a, b) => a.areaPerMarker > b.areaPerMarker ? a : b).country).first.country} con Area/Marker di ${sortedAnalyses.reduce((a, b) => a.areaPerMarker > b.areaPerMarker ? a : b).areaPerMarker.toStringAsFixed(2)} m²\n\n"
      "Identificazione delle Aree di Concentrazione/Dispersione:\n"
      "  Migliore concentrazione: ${sortedAnalyses.where((ca) => ca.country == sortedAnalyses.reduce((a, b) => a.meanNearestDistance < b.meanNearestDistance ? a : b).country).first.country} con Nearest Neighbor di ${sortedAnalyses.reduce((a, b) => a.meanNearestDistance < b.meanNearestDistance ? a : b).meanNearestDistance.toStringAsFixed(2)} m\n"
      "  Maggiore dispersione: ${sortedAnalyses.where((ca) => ca.country == sortedAnalyses.reduce((a, b) => a.meanNearestDistance > b.meanNearestDistance ? a : b).country).first.country} con Nearest Neighbor di ${sortedAnalyses.reduce((a, b) => a.meanNearestDistance > b.meanNearestDistance ? a : b).meanNearestDistance.toStringAsFixed(2)} m";

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
                  DataColumn(label: Text("Area (m²)", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Area/Marker (m²)", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Nearest (m)", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Moran's I", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: sortedAnalyses.map((ca) {
                  return DataRow(cells: [
                    DataCell(Text(ca.country)),
                    DataCell(Text(ca.markerCount.toString())),
                    DataCell(Text(ca.area.toStringAsFixed(2))),
                    DataCell(Text(ca.areaPerMarker.toStringAsFixed(2))),
                    DataCell(Text(ca.meanNearestDistance.toStringAsFixed(2))),
                    DataCell(Text(ca.moranI.toStringAsFixed(4))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}