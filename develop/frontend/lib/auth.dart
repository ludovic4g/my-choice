// auth.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_state.dart'; // Importa lo stato di autenticazione
import 'main.dart';

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
          .select('id, username, email, password')
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
        print('=== DEBUG LOGIN: Dati Utente ===');
        print('ID Utente: ${userResponse['id']}');
        print('Username: $username');
        print('Email: $userEmail');
        print('=== DEBUG LOGIN: Fine Dati Utente ===');

        // Aggiorna lo stato di autenticazione
        isLoggedIn = true;
        currentUserInfo = {
          'id': userResponse['id'],
          'username': username,
          'email': userEmail,
        };

        // Naviga alla HomePage passando l'username e email
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(username: username, email: userEmail),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Accesso'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Torna alla pagina precedente
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
             TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
             SizedBox(height: 20),
             ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
             SizedBox(height: 20),
             ElevatedButton(
              onPressed: () {
                // Logica per la registrazione
              },
              child: Text('Registrazione'),
            ),
          ],
        ),
      ),
    );
  }
}
