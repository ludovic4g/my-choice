// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'mappe.dart'; // Importa la pagina della mappa

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Carica le variabili d'ambiente
  await dotenv.load(fileName: 'assets/config.env');

  // Imposta la modalità a schermo intero
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
      home: SplashScreen(), // Imposta SplashScreen come pagina iniziale
      debugShowCheckedModeBanner: false,
    );
  }
}

// SplashScreen per l'avvio dell'app
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome(); // Naviga alla HomePage dopo lo splash screen
  }

  void _navigateToHome() async {
    await Future.delayed(Duration(seconds: 3)); // Tempo di visualizzazione dello splash screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Benvenuti in Mappa Italia",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// HomePage con pulsanti di navigazione
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Homepage"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MapScreen()),
                );
              },
              child: Text("Mappa Interattiva"),
            ),
            ElevatedButton(
              onPressed: () {
                // Navigazione alla pagina del profilo (da implementare)
              },
              child: Text("Profilo"),
            ),
            // Aggiungi altri pulsanti per altre sezioni
          ],
        ),
      ),
    );
  }
}
