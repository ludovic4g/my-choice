// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mappe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carica le variabili d’ambiente dal file .env
  await dotenv.load(fileName: 'assets/config.env');

  // Imposta la modalità a schermo intero e il colore della status bar a bianco
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.white, // Colore bianco per la status bar
    statusBarBrightness: Brightness.light, // Imposta il contenuto della status bar chiaro
    statusBarIconBrightness: Brightness.dark, // Imposta le icone della status bar in colore scuro
  ));

  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  Future<void> _initializeSupabase() async {
    // Inizializza Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeSupabase(),
      builder: (context, snapshot) {
        // Mostra uno splash temporaneo finché Supabase non è inizializzato
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Dopo l'inizializzazione di Supabase, mostra la SplashScreen
        return MaterialApp(
          title: 'Mappa Italia',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: SplashScreen(),
          routes: {
            '/homepage': (context) => HomePage(),
            '/map': (context) => MapScreen(),
            '/profile': (context) => MapScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// SplashScreen per l'avvio dell'app con logo animato, cerchi galleggianti e pulsante Entra
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _buttonController;
  late AnimationController _floatingCircleController;
  late Animation<Offset> _logoAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _logoAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    ));

    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    ));

    _buttonController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _buttonAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    );

    _floatingCircleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _logoController.forward().whenComplete(() {
      _buttonController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonController.dispose();
    _floatingCircleController.dispose();
    super.dispose();
  }

  Widget _buildFloatingCircle(double size, Offset offset) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: AnimatedBuilder(
        animation: _floatingCircleController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 10 * (_floatingCircleController.value - 0.5)),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFEAEA).withOpacity(0.5),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Impostato lo sfondo bianco
      body: Stack(
        children: [
          _buildFloatingCircle(100, Offset(50, 150)),
          _buildFloatingCircle(70, Offset(250, 250)),
          _buildFloatingCircle(50, Offset(300, 650)),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoOpacityAnimation,
                  child: SlideTransition(
                    position: _logoAnimation,
                    child: Container(
                      padding: EdgeInsets.all(40),
                      child: Image.asset(
                        'assets/logo_grande.png',
                        width: 300,
                        height: 300,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 5),
                FadeTransition(
                  opacity: _buttonAnimation,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/homepage');
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
        ],
      ),
    );
  }
}

// HomePage con barra di navigazione arrotondata

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Sfondo chiaro simile all'immagine
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                SizedBox(height: 20), // Spazio per abbassare il rettangolo
                Stack(
                  clipBehavior: Clip.none, // Permette agli elementi di uscire dai limiti
                  children: [
                    Container(
                      padding: EdgeInsets.all(3), // Padding per creare lo spazio del bordo esterno
                      decoration: BoxDecoration(
                        color: Color(0xFFF2CFCF), // Colore del bordo esterno
                        borderRadius: BorderRadius.circular(22), // Arrotondamento esterno
                      ),
                      child: Container(
                        width: 300,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFF0F0), // Colore del rettangolo interno
                          borderRadius: BorderRadius.circular(20), // Arrotondamento interno
                          border: Border.all(
                            color: Color(0xFFEB8686), // Colore del bordo interno
                            width: 2, // Spessore del bordo interno
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Ciao User!",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEB8686),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Icona di cuore posizionata sopra il rettangolo
                    Positioned(
                      top: -90,
                      left: 190,
                      child: Image.asset(
                        'assets/logo_piccolo.png', // Assicurati che il file sia corretto
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30), // Spazio tra i rettangoli

                // Secondo rettangolo con icona stella
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 300,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Color(0xFFF2CFCF),
                          width: 2,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 20,
                      child: Icon(
                        Icons.star,
                        color: Color(0xFFE19C9C),
                        size: 30,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20), // Spazio tra i rettangoli

                // Terzo rettangolo senza icona
                Container(
                  width: 300,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(0xFFF2CFCF),
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Barra inferiore con icone
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Container(
                width: 300,
                height: 70,
                decoration: BoxDecoration(
                  color: Color(0xFFF2CFCF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (ModalRoute.of(context)?.settings.name != '/homepage') {
                          Navigator.pushReplacementNamed(context, '/homepage');
                        }
                      },
                      icon: Image.asset(
                        'assets/home.png',
                        width: 25,
                        height: 25,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/map');
                      },
                      icon: Image.asset(
                        'assets/mappe.png',
                        width: 30,
                        height: 30,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                         Navigator.pushReplacementNamed(context, '/profile');
                      },
                      icon: Image.asset(
                        'assets/profile.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
