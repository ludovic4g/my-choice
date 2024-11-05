import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'models/location.dart';
import 'models/farmacia_model.dart';

// Classe per rappresentare le suggestion nella ricerca
class SearchSuggestion {
  final String display;
  final String type; // 'city', 'centro', 'farmacia'
  final dynamic data; // Può essere una stringa per la città, LocationModel per i centri o FarmaciaModel per le farmacie

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
  final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  LatLng? _center;
  bool _isInfoWindowVisible = false;
  Offset _popupPosition = Offset(0, 0);

  final double _minZoom = 5.0;
  final double _maxZoom = 18.0;
  double _currentZoom = 6.0; // Inizializzato a 6.0

  List<LocationModel> _locations = [];
  List<FarmaciaModel> _farmacie = [];
  final Set<Marker> _markers = {};
  dynamic _currentInfoWindowData;
  FilterOption _currentFilter = FilterOption.centri;
  String _searchQuery = "";

  // Cache per i risultati del geocoding
  final Map<String, LatLng> _geocodingCache = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
    _fetchAllData();
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

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchLocationsFromSupabase();
    await _fetchFarmacieFromSupabase();
    await _updateMarkers();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchLocationsFromSupabase() async {
    try {
      final response = await Supabase.instance.client.from('centri').select().execute();
      if (response.data != null && response.status == 200) {
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
      final response = await Supabase.instance.client.from('farmacie').select().execute();
      if (response.data != null && response.status == 200) {
        final data = response.data as List<dynamic>;
        setState(() {
          _farmacie = data.map((item) => FarmaciaModel.fromMap(item)).toList();
        });
      }
    } catch (error) {
      print("Errore nel recupero delle farmacie: $error");
    }
  }

  Future<void> _updateMarkers() async {
    _markers.clear();
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

    setState(() {});
  }

  Future<void> _geocodeAllLocations() async {
    // Esegui il geocoding in parallelo
    await Future.wait(_locations.map((location) async {
      final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
      final coordinates = await _getCoordinatesFromAddress(fullAddress);
      if (coordinates != null) {
        setState(() {
          _markers.add(Marker(
            markerId: MarkerId('centro_${location.id}'),
            position: coordinates,
            icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () {
              _showCustomInfoWindow(location, coordinates!); // Utilizzo di '!'
            },
          ));
        });
      }
    }));
  }

  Future<void> _geocodeAllFarmacie() async {
    // Esegui il geocoding in parallelo
    await Future.wait(_farmacie.map((farmacia) async {
      final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
      final coordinates = await _getCoordinatesFromAddress(fullAddress);
      if (coordinates != null) {
        setState(() {
          _markers.add(Marker(
            markerId: MarkerId('farmacia_${farmacia.id}'),
            position: coordinates,
            icon: farmaciaMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () {
              _showCustomInfoWindow(farmacia, coordinates!); // Utilizzo di '!'
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
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey";
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

  void _showCustomInfoWindow(dynamic locationData, LatLng position) async {
    // Ottieni le dimensioni dello schermo
    final Size screenSize = MediaQuery.of(context).size;

    // Ottieni le coordinate dello schermo del marker
    ScreenCoordinate screenCoordinate = await mapController.getScreenCoordinate(position);

    // Definisci la dimensione del popup
    const double popupWidth = 200;
    const double popupHeight = 100;

    // Calcola la posizione del popup
    double left = screenCoordinate.x.toDouble() - (popupWidth / 2);
    double top = screenCoordinate.y.toDouble() - popupHeight - 10; // 10 per uno spazio di margine

    // Assicurati che il popup non esca dal lato sinistro o destro
    if (left < 0) {
      left = 10;
    } else if (left + popupWidth > screenSize.width) {
      left = screenSize.width - popupWidth - 10;
    }

    // Assicurati che il popup non esca dalla parte superiore
    if (top < 0) {
      top = screenCoordinate.y.toDouble() + 10; // Posiziona sotto il marker se fuori dalla parte superiore
    }

    setState(() {
      _isInfoWindowVisible = true;
      _popupPosition = Offset(left, top);
      _currentInfoWindowData = locationData;
    });
  }

  void _hideCustomInfoWindow() {
    setState(() {
      _isInfoWindowVisible = false;
      _currentInfoWindowData = null;
    });
  }

  Future<void> _applySearch() async {
    _markers.clear();
    List<Future<void>> geocodeFutures = [];

    if (_currentFilter == FilterOption.centri || _currentFilter == FilterOption.tutto) {
      final filteredLocations = _locations.where((loc) =>
          loc.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loc.indirizzo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loc.citta.toLowerCase().contains(_searchQuery.toLowerCase()));
      print("Centri trovati: ${filteredLocations.length}");
      geocodeFutures.add(Future.wait(filteredLocations.map((location) async {
        final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
        final coordinates = await _getCoordinatesFromAddress(fullAddress);
        if (coordinates != null) {
          setState(() {
            _markers.add(Marker(
              markerId: MarkerId('centro_${location.id}'),
              position: coordinates,
              icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
              onTap: () {
                _showCustomInfoWindow(location, coordinates!); // Utilizzo di '!'
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
      print("Farmacie trovate: ${filteredFarmacie.length}");
      geocodeFutures.add(Future.wait(filteredFarmacie.map((farmacia) async {
        final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
        final coordinates = await _getCoordinatesFromAddress(fullAddress);
        if (coordinates != null) {
          setState(() {
            _markers.add(Marker(
              markerId: MarkerId('farmacia_${farmacia.id}'),
              position: coordinates,
              icon: farmaciaMarkerIcon ?? BitmapDescriptor.defaultMarker,
              onTap: () {
                _showCustomInfoWindow(farmacia, coordinates!); // Utilizzo di '!'
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
    mapController = controller;
    mapController.setMapStyle(mapStyle);
    if (_center != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_center!, _currentZoom));
    }
  }

  void _zoomIn() {
    if (_currentZoom < _maxZoom) {
      mapController.animateCamera(CameraUpdate.zoomIn());
      // Non aggiorniamo _currentZoom manualmente; sarà gestito da onCameraMove
    }
  }

  void _zoomOut() {
    if (_currentZoom > _minZoom) {
      mapController.animateCamera(CameraUpdate.zoomOut());
      // Non aggiorniamo _currentZoom manualmente; sarà gestito da onCameraMove
    }
  }

  void _onFilterSelected(FilterOption option) async {
    setState(() {
      _currentFilter = option;
      _searchQuery = ""; // Resetta la query di ricerca quando cambia il filtro
    });
    await _updateMarkers();
  }

  void _searchMarkers(SearchSuggestion suggestion) async {
    setState(() {
      _isLoading = true;
      _searchQuery = suggestion.display; // Imposta la query di ricerca
    });

    if (suggestion.type == 'city') {
      // Geocode la città per ottenere le coordinate
      LatLng? cityCoordinates = await _getCoordinatesFromAddress(suggestion.display);
      if (cityCoordinates != null) {
        print("Centro sulla città: ${suggestion.display}");
        // Centra la mappa sulla città
        mapController.animateCamera(CameraUpdate.newLatLngZoom(cityCoordinates, 12));

        // Filtra i marker per mostrare solo quelli nella città
        _markers.clear();
        List<Future<void>> geocodeFutures = [];

        // Centri
        final filteredLocations = _locations.where((loc) =>
            loc.citta.trim().toLowerCase().contains(suggestion.display.trim().toLowerCase()));
        print("Centri trovati: ${filteredLocations.length}");
        geocodeFutures.add(Future.wait(filteredLocations.map((location) async {
          final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
          final coordinates = await _getCoordinatesFromAddress(fullAddress);
          if (coordinates != null) {
            setState(() {
              _markers.add(Marker(
                markerId: MarkerId('centro_${location.id}'),
                position: coordinates,
                icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
                onTap: () {
                  _showCustomInfoWindow(location, coordinates!);
                },
              ));
              print("Marker aggiunto per centro: ${location.nome}");
            });
          }
        })));

        // Farmacie
        final filteredFarmacie = _farmacie.where((farm) =>
            farm.comune.trim().toLowerCase().contains(suggestion.display.trim().toLowerCase()));
        print("Farmacie trovate: ${filteredFarmacie.length}");
        geocodeFutures.add(Future.wait(filteredFarmacie.map((farmacia) async {
          final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
          final coordinates = await _getCoordinatesFromAddress(fullAddress);
          if (coordinates != null) {
            setState(() {
              _markers.add(Marker(
                markerId: MarkerId('farmacia_${farmacia.id}'),
                position: coordinates,
                icon: farmaciaMarkerIcon ?? BitmapDescriptor.defaultMarker,
                onTap: () {
                  _showCustomInfoWindow(farmacia, coordinates!);
                },
              ));
              print("Marker aggiunto per farmacia: ${farmacia.descrizione}");
            });
          }
        })));

        if (geocodeFutures.isNotEmpty) {
          await Future.wait(geocodeFutures);
        }
      }
    } else if (suggestion.type == 'centro' || suggestion.type == 'farmacia') {
      // Mostra solo il marker selezionato
      _markers.clear();
      dynamic selectedData = suggestion.data;
      LatLng? coordinates;

      if (suggestion.type == 'centro') {
        final location = selectedData as LocationModel;
        final fullAddress = "${location.indirizzo}, ${location.cap}, ${location.citta}";
        coordinates = await _getCoordinatesFromAddress(fullAddress);
        if (coordinates != null) {
          _markers.add(Marker(
            markerId: MarkerId('centro_${location.id}'),
            position: coordinates,
            icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () {
              _showCustomInfoWindow(location, coordinates!); // Utilizzo di '!'
            },
          ));
          print("Marker aggiunto per centro: ${location.nome}");
          // Centra la mappa sul marker
          mapController.animateCamera(CameraUpdate.newLatLngZoom(coordinates, 14));
        }
      } else if (suggestion.type == 'farmacia') {
        final farmacia = selectedData as FarmaciaModel;
        final fullAddress = "${farmacia.indirizzo}, ${farmacia.comune}";
        coordinates = await _getCoordinatesFromAddress(fullAddress);
        if (coordinates != null) {
          _markers.add(Marker(
            markerId: MarkerId('farmacia_${farmacia.id}'),
            position: coordinates,
            icon: farmaciaMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () {
              _showCustomInfoWindow(farmacia, coordinates!); // Utilizzo di '!'
            },
          ));
          print("Marker aggiunto per farmacia: ${farmacia.descrizione}");
          // Centra la mappa sul marker
          mapController.animateCamera(CameraUpdate.newLatLngZoom(coordinates, 14));
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Ottieni tutte le città uniche dai centri e farmacie
  List<String> get _uniqueCities {
    final citiesFromCentri = _locations.map((loc) => loc.citta).toSet();
    final citiesFromFarmacie = _farmacie.map((farm) => farm.comune).toSet();
    final allCities = citiesFromCentri.union(citiesFromFarmacie).toList();
    allCities.sort();
    return allCities;
  }

  // Ottieni tutti i nomi dei centri
  List<String> get _centroNames {
    return _locations.map((loc) => loc.nome).toList();
  }

  // Ottieni tutti i nomi delle farmacie
  List<String> get _farmaciaNames {
    return _farmacie.map((farm) => farm.descrizione).toList();
  }

  // Funzione per ottenere le suggestion basate sulla query
  List<SearchSuggestion> _getSuggestions(String query) {
    final lowerQuery = query.toLowerCase();
    List<SearchSuggestion> suggestions = [];

    // Suggerimenti per le città
    for (var city in _uniqueCities) {
      if (city.toLowerCase().contains(lowerQuery)) {
        suggestions.add(SearchSuggestion(
          display: city,
          type: 'city',
        ));
      }
    }

    // Suggerimenti per i centri
    for (var centro in _locations) {
      if (centro.nome.toLowerCase().contains(lowerQuery)) {
        suggestions.add(SearchSuggestion(
          display: centro.nome,
          type: 'centro',
          data: centro,
        ));
      }
    }

    // Suggerimenti per le farmacie
    for (var farmacia in _farmacie) {
      if (farmacia.descrizione.toLowerCase().contains(lowerQuery)) {
        suggestions.add(SearchSuggestion(
          display: farmacia.descrizione,
          type: 'farmacia',
          data: farmacia,
        ));
      }
    }

    return suggestions;
  }

  // Funzione per ottenere l'icona corretta in base al tipo di suggestion
  IconData _getIconForSuggestion(String type) {
    switch (type) {
      case 'city':
        return Icons.location_city;
      case 'centro':
        return Icons.local_hospital;
      case 'farmacia':
        return Icons.local_pharmacy;
      default:
        return Icons.location_on;
    }
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
        title: Text("Mappa Italia"),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Cerca'),
                    content: TypeAheadField<SearchSuggestion>(
                      textFieldConfiguration: TextFieldConfiguration(
                        decoration: InputDecoration(
                          hintText: "Inserisci il nome o l'indirizzo",
                        ),
                      ),
                      suggestionsCallback: (pattern) {
                        return _getSuggestions(pattern);
                      },
                      itemBuilder: (context, SearchSuggestion suggestion) {
                        return ListTile(
                          leading: Icon(_getIconForSuggestion(suggestion.type)),
                          title: Text(suggestion.display),
                        );
                      },
                      onSuggestionSelected: (SearchSuggestion suggestion) {
                        Navigator.of(context).pop(); // Chiudi il dialogo
                        _searchMarkers(suggestion); // Esegui la ricerca
                      },
                      noItemsFoundBuilder: (context) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Nessun risultato trovato'),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          // Ripristina la mappa senza alcuna ricerca
                          setState(() {
                            _searchQuery = ""; // Elimina la query di ricerca
                          });
                          await _updateMarkers(); // Ripristina i marker in base al filtro attuale
                          Navigator.of(context).pop(); // Chiudi il dialogo
                        },
                        child: Text('Elimina Ricerca'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Chiudi il dialogo senza modifiche
                        },
                        child: Text('Chiudi'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
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
        ],
        centerTitle: true,
        backgroundColor: Color(0xFFFFF6F2),
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: Column(
        children: [
          // Barra di Stato della Ricerca
          if (_searchQuery.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Cosa si è cercato: $_searchQuery',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () async {
                      setState(() {
                        _searchQuery = ""; // Elimina la query di ricerca
                      });
                      await _updateMarkers(); // Ripristina i marker in base al filtro attuale
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _center ?? LatLng(41.9028, 12.4964), // Posizione di default a Roma
                    zoom: _currentZoom,
                  ),
                  markers: _markers,
                  onTap: (LatLng position) => _hideCustomInfoWindow(),
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
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
                            ElevatedButton(
                              onPressed: () {
                                print("Dettagli per ${_currentInfoWindowData is LocationModel ? _currentInfoWindowData.nome : _currentInfoWindowData.descrizione}");
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
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(),
                  ),
                Positioned(
                  bottom: 20,
                  right: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoomIn', // Tag Unico per il FAB di Zoom In
                        mini: true,
                        onPressed: _zoomIn,
                        child: Icon(Icons.add, size: 18),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'zoomOut', // Tag Unico per il FAB di Zoom Out
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
          ),
        ],
      ),
    );
  }
}
