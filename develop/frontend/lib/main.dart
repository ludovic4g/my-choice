// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'mappe.dart';

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

// SplashScreen per l'avvio dell'app con logo animato e pulsante Entra
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _buttonController;
  late Animation<Offset> _logoAnimation; // Animazione di ascesa per il logo
  late Animation<double> _buttonAnimation; // Animazione di opacità per il pulsante

  @override
  void initState() {
    super.initState();

    // Configura il controller per l'animazione di ascesa del logo
    _logoController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _logoAnimation = Tween<Offset>(
      begin: Offset(0, 1), // Parte da sotto lo schermo
      end: Offset(0, 0), // Arriva alla posizione originale
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    ));

    // Configura il controller per l'animazione del pulsante
    _buttonController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _buttonAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    );

    // Avvia l'animazione di ascesa del logo e, al termine, mostra il pulsante "Entra"
    _logoController.forward().whenComplete(() {
      _buttonController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF6F2), // Colore di sfondo
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo con effetto di ascesa
            SlideTransition(
              position: _logoAnimation,
              child: Container(
                padding: EdgeInsets.all(40),
                child: Image.asset(
                  'assets/logo_grande.png', // Assicurati di avere un file logo_grande.png in assets
                  width: 300,
                  height: 300,
                ),
              ),
            ),
            SizedBox(height: 5),
            FadeTransition(
              opacity: _buttonAnimation,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomePage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEB8686),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                ),
                child: Text(
                  "Entra",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
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
          ],
        ),
      ),
    );
  }
}
