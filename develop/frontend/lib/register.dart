import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _email2Controller = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _password2Controller = TextEditingController();
  final supabase = Supabase.instance.client;

  Future<void> _register() async {
    final nome = _nameController.text;
    final cognome = _surnameController.text;
    final username = _usernameController.text;
    final email = _emailController.text;
    final emailConfirm = _email2Controller.text;
    final password = _passwordController.text;
    final passwordConfirm = _password2Controller.text;

    if (email != emailConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Le email non coincidono!')),
      );
      return;
    }

    if (password != passwordConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Le password non coincidono!')),
      );
      return;
    }

    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'nome': nome,
          'cognome': cognome,
          'username': username,
        },
      );

      if (response.user != null) {
        await supabase.from('users').insert({
          'nome': nome,
          'cognome': cognome,
          'username': username,
          'email': email,
        });
      }
      
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la registrazione')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Background impostato su white
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              Image.asset(
                'assets/logo_piccolo.png', 
                height: 100,
              ),
              SizedBox(height: 20),
              Text(
                'Registrati',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD46A6A),
                ),
              ),
              SizedBox(height: 10),
              _buildTextField(_nameController, 'Nome'),
              _buildTextField(_surnameController, 'Cognome'),
              _buildTextField(_usernameController, 'Username'),
              _buildTextField(_emailController, 'Email'),
              _buildTextField(_email2Controller, 'Conferma Email'),
              _buildTextField(_passwordController, 'Password', isPassword: true),
              _buildTextField(_password2Controller, 'Conferma Password', isPassword: true),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEB8686),
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Conferma',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Container(
        child: TextField(
          controller: controller,
          obscureText: isPassword,
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
