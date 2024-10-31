import 'dart:async';
import 'dart:convert'; // Per JSON
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config.env');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Italia',
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
  final String address = "Piazza del Colosseo, Roma, Italia";
  LatLng _center = LatLng(41.9028, 12.4964); // Posizione predefinita a Roma

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
    _getCoordinatesFromAddress(address);
  }

  Future<void> _loadCustomMarkerIcon() async {
    customMarkerIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(48, 48)),
      'assets/marker.png', 
    );
    setState(() {});
  }

  Future<void> _getCoordinatesFromAddress(String address) async {
    final String url = "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        setState(() {
          _center = LatLng(lat, lng);
          mapController.animateCamera(CameraUpdate.newLatLng(_center));
        });
      } else {
        print("Errore nel Geocoding: ${data['status']}");
      }
    } else {
      print("Errore nella richiesta HTTP: ${response.statusCode}");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController.setMapStyle(mapStyle);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Google Maps Italia"),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 6.0,
              ),
              markers: {
                if (customMarkerIcon != null)
                  Marker(
                    markerId: MarkerId("Marker"),
                    position: _center,
                    icon: customMarkerIcon!,
                    infoWindow: InfoWindow(title: address),
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
