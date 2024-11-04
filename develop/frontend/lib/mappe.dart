// mappa.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  BitmapDescriptor? customMarkerIcon;
  final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final String address = "Piazza del Colosseo, 00184 Roma, Italia"; 
  LatLng? _center;
  Marker? _selectedMarker;
  bool _isInfoWindowVisible = false;
  Offset _popupPosition = Offset(0, 0);

  final double _minZoom = 5.0;
  final double _maxZoom = 18.0;
  double _currentZoom = 6.0;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
  }

  Future<void> _loadCustomMarkerIcon() async {
    customMarkerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/marker.png',
    );
    setState(() {});
  }

  Future<void> _getCoordinatesFromAddress(String address) async {
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        setState(() {
          _center = LatLng(location['lat'], location['lng']);
        });
        mapController.animateCamera(CameraUpdate.newLatLng(_center!));
      } else {
        print("Errore nel Geocoding: ${data['status']}");
      }
    } else {
      print("Errore nella richiesta HTTP: ${response.statusCode}");
    }
  }

  // Stile personalizzato della mappa
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
    _getCoordinatesFromAddress(address);
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
              target: _center ?? LatLng(41.9028, 12.4964),
              zoom: _currentZoom,
            ),
            markers: {
              if (_center != null && customMarkerIcon != null)
                Marker(
                  markerId: MarkerId("Marker"),
                  position: _center!,
                  icon: customMarkerIcon!,
                ),
            },
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            minMaxZoomPreference: MinMaxZoomPreference(_minZoom, _maxZoom),
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
