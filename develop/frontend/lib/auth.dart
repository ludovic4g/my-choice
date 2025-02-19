import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_state.dart'; // Importa lo stato di autenticazione
import 'main.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final supabase = Supabase.instance.client;

  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      print('=== DEBUG LOGIN: Inizio ===');
      print('Email inserita: $email');

      final userResponse = await supabase
          .from('users')
          .select('id, username, email, password, nome, cognome')
          .eq('email', email)
          .maybeSingle();

      if (userResponse == null) {
        print('Email "$email" non trovata nella tabella "users".');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email non trovata')),
        );
        print('=== DEBUG LOGIN: Email non trovata ===');
        return;
      }

      final storedPassword = userResponse['password'];
      if (password == storedPassword) {
        print('Password corretta per l\'utente con email "$email".');
        final username = userResponse['username'];
        final userEmail = userResponse['email'];
        final nome = userResponse['nome'];
        final cognome = userResponse['cognome'];
        print('=== DEBUG LOGIN: Dati Utente ===');
        print('ID Utente: ${userResponse['id']}');
        print('Username: $username');
        print('Email: $userEmail');
        print('=== DEBUG LOGIN: Fine Dati Utente ===');

        // Aggiorna lo stato di autenticazione
        isLoggedIn = true;
        currentUserInfo = {
          'id': userResponse['id'],
          'nome': userResponse['nome'],
          'cognome': userResponse['cognome'],
          'username': username,
          'email': userEmail,
        };

        // Naviga alla HomePage passando l'username e email
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HomePage(username: username, email: userEmail, nome: nome, cognome: cognome),
          ),
        );
      } else {
        print('Password errata per l\'email "$email".');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Credenziali non valide')),
        );
      }
    } catch (e) {
      print('Errore durante il login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore di connessione')),
      );
    } finally {
      print('=== DEBUG LOGIN: Fine del processo di login ===');
    }
  }

  Future<void> _register() async {
    Navigator.pushReplacementNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Background impostato su white
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Image.asset(
              'assets/logo_piccolo.png', 
              height: 150,
            ),
            SizedBox(height: 20),
            Text(
              'Login',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD46A6A),
              ),
            ),
            SizedBox(height: 10),
            _buildTextField(_emailController, 'Email'),
            _buildTextField(_passwordController, 'Password', isPassword: true),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text(
                  'Conferma',
                  style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEB8686),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _register,
              child: Text(
                  'Registrati',
                  style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEB8686),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Container(
        width: 400,
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.pink.shade400),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
