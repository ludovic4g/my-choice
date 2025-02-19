// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mappe.dart';
import 'auth.dart';
import 'spatial.dart';
import 'register.dart';
import 'favourites.dart';
import 'auth_state.dart'; // Importa lo stato di autenticazione
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  
  // Carica le variabili d’ambiente
  await dotenv.load(fileName: 'assets/config.env');

  // Inizializza Supabase con sessione persistente
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    authCallbackUrlHostname: 'login-callback',
    localStorage: HiveLocalStorage(), // Assicura la persistenza della sessione
  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

// Chiave globale per accedere al contesto
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession(); // Controlla se esiste una sessione valida
  }

  Future<void> _checkSession() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session != null) {
      // L'utente è loggato, recupera le informazioni dell'utente
      final userId = session.user!.id;
      final userResponse = await supabase
          .from('users')
          .select('id, username, email')
          .eq('id', userId)
          .maybeSingle();

      if (userResponse != null) {
        isLoggedIn = true;
        currentUserInfo = {
          'id': userResponse['id'],
          'nome': userResponse['nome'],
          'cognome': userResponse['cognome'],
          'username': userResponse['username'],
          'email': userResponse['email'],
        };
      } else {
        isLoggedIn = false;
        currentUserInfo = null;
      }
    } else {
      isLoggedIn = false;
      currentUserInfo = null;
    }
    setState(() {
      _isLoading = false;
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Mappa Italia',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _isLoggedIn && currentUserInfo != null
          ? HomePage(
              username: currentUserInfo!['username'],
              email: currentUserInfo!['email'],
              nome: currentUserInfo!['nome'],
              cognome: currentUserInfo!['cognome'],
            )
          : SplashScreen(), // Mostra la SplashScreen se non loggato
      routes: {
        '/homepage': (context) => HomePage(
              username: currentUserInfo?['username'] ?? 'Utente',
              email: currentUserInfo?['email'] ?? '',
              nome: currentUserInfo?['nome'] ?? '',
              cognome: currentUserInfo?['cognome'] ?? '',
            ),
        '/map': (context) => MapScreen(),
        '/profile': (context) => ProfilePage(
              username: currentUserInfo?['username'] ?? 'Utente',
              email: currentUserInfo?['email'] ?? '',
              nome: currentUserInfo?['nome'] ?? '',
              cognome: currentUserInfo?['cognome'] ?? '',
            ),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/favourites': (context) => FavouritePage(),
        '/spatial': (context) => SpatialPage(),
        
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// SplashScreen con animazioni delle bolle migliorate
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late List<Bubble> bubbles = [];

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _logoController.forward();

    // Naviga automaticamente dopo l'animazione
    Future.delayed(Duration(seconds: 4), () {
      if (isLoggedIn && currentUserInfo != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              username: currentUserInfo!['username'],
              email: currentUserInfo!['email'],
              nome: currentUserInfo!['nome'],
              cognome: currentUserInfo!['cognome'],
            ),
          ),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Inizializza le bolle animate qui, poiché abbiamo accesso al contesto completo
    for (int i = 0; i < 15; i++) {
      bubbles.add(Bubble(
        size: Random().nextDouble() * 60 + 20, // Dimensioni casuali
        x: Random().nextDouble() * MediaQuery.of(context).size.width,
        y: Random().nextDouble() * MediaQuery.of(context).size.height,
        xDirection: Random().nextBool() ? 1 : -1,
        yDirection: Random().nextBool() ? 1 : -1,
        speed: Random().nextDouble() * 0.5 + 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    for (var bubble in bubbles) {
      bubble.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Aggiorna le bolle
    for (var bubble in bubbles) {
      bubble.update(size: MediaQuery.of(context).size);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animazione delle bolle
          CustomPaint(
            painter: BubblePainter(bubbles: bubbles),
            child: Container(),
          ),
          // Logo centrale
          Center(
            child: FadeTransition(
              opacity: _logoController,
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
        ],
      ),
    );
  }
}

class Bubble {
  double x;
  double y;
  double size;
  double speed;
  int xDirection;
  int yDirection;
  late AnimationController controller;

  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.xDirection,
    required this.yDirection,
  }) {
    controller = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: navigatorKey.currentState!.overlay!,
    )..repeat();
  }

  void update({required Size size}) {
    x += speed * xDirection;
    y += speed * yDirection;

    // Inverti la direzione se tocca i bordi
    if (x <= 0 || x >= size.width) {
      xDirection *= -1;
    }
    if (y <= 0 || y >= size.height) {
      yDirection *= -1;
    }
  }
}

class BubblePainter extends CustomPainter {
  List<Bubble> bubbles;
  BubblePainter({required this.bubbles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(0xFFFFEAEA).withOpacity(0.5);

    for (var bubble in bubbles) {
      canvas.drawCircle(Offset(bubble.x, bubble.y), bubble.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// HomePage
class HomePage extends StatelessWidget {
  final String username;
  final String email;
  final String nome;
  final String cognome;

  HomePage({required this.username, required this.email, required this.nome, required this.cognome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Rimuove il pulsante "back"
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Contenuto della HomePage
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                SizedBox(height: 20),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Color(0xFFF2CFCF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Container(
                        width: 300,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Color(0xFFEB8686),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Ciao $username!",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEB8686),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -90,
                      left: 190,
                      child: Image.asset(
                        'assets/logo_piccolo.png',
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InkWell(
                    child: Container(
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
                      child: Center(
                          child: Text(
                            "Preferiti",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEB8686),
                            ),
                          ),
                        ),
                    ),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/favourites');
                      // print("Favourites cliccato!");
                    }
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
              ],
            ),
          ),
          // Barra di navigazione inferiore
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
                        // Siamo già in HomePage
                      },
                      icon: Image.asset(
                        'assets/home.png',
                        width: 25,
                        height: 25,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (ModalRoute.of(context)?.settings.name != '/map') {
                          Navigator.pushNamed(context, '/map');
                        }
                      },
                      icon: Image.asset(
                        'assets/mappe.png',
                        width: 30,
                        height: 30,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (isLoggedIn) {
                          // Naviga alla pagina del profilo se loggato
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilePage(
                                  username: username, email: email, nome: nome, cognome: cognome),
                            ),
                          );
                        } else {
                          // Naviga alla pagina di login se non loggato
                          Navigator.pushReplacementNamed(context, '/login');
                        }
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

// ProfilePage
class ProfilePage extends StatelessWidget {
  final String username;
  final String email;
  final String cognome;
  final String nome;

  ProfilePage({required this.username, required this.email, required this.nome, required this.cognome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Sfondo rosa chiaro
      appBar: AppBar(
        title: Text(
          'Profilo',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFFCEDED), // Colore sfondo AppBar
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icona del profilo circolare
          CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFFE5A9A9), // Colore rosa più scuro
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          SizedBox(height: 20),

          // Contenitore delle informazioni
          Container(
            margin: EdgeInsets.symmetric(horizontal: 30),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFF2CFCF), // Rosa più scuro per il box
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                InfoField(label: "Username", value: username),
                InfoField(label: "Email", value: email),
                InfoField(label: "Nome", value: nome),
                InfoField(label: "Cognome", value: cognome),
              ],
            ),
          ),

          SizedBox(height: 30),

          // Pulsante di logout
          ElevatedButton(
            onPressed: () async {
              final supabase = Supabase.instance.client;
              await supabase.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE5A9A9), // Rosa scuro per il bottone
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Logout',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget per i campi delle informazioni utente
class InfoField extends StatelessWidget {
  final String label;
  final String value;

  InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
