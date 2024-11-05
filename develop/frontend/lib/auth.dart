// auth.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class Profile extends StatefulWidget {
  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context); // Torna indietro alla pagina precedente
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Logica per il primo bottone
              },
              child: Text('Login'),
            ),
            SizedBox(height: 20), // Spazio tra i bottoni
            ElevatedButton(
              onPressed: () {
                // Logica per il secondo bottone
              },
              child: Text('Registrazione'),
            ),
            SizedBox(height: 40), // Spazio tra i bottoni e il pulsante "Torna alla Home"
          ],
        ),
      ),
    );
  }
}
