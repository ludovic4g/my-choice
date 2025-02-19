import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_state.dart';

class FavouritePage extends StatefulWidget {
  @override
  _FavouritePageState createState() => _FavouritePageState();
}

class _FavouritePageState extends State<FavouritePage> {
  List<String> favourites = [];

  @override
  void initState() {
    super.initState();
    loadFavourites();
  }

  Future<void> loadFavourites() async {
    final userEmail = currentUserInfo?['email'];
    if (userEmail == null) return;

    final supabase = Supabase.instance.client;

    try {
      // Lettura diretta con .single() (senza .execute())
      final data = await supabase
          .from('users')
          .select('fav')
          .eq('email', userEmail)
          .single() as Map<String, dynamic>?;

      if (data == null) {
        setState(() {
          favourites = [];
        });
        return;
      }

      String favString = data['fav'] ?? "";
      List<String> favList = favString
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      setState(() {
        favourites = favList;
      });
    } catch (e) {
      // Se fallisce la query o non esiste l'utente
      setState(() {
        favourites = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/homepage');
          },
        ),
        title: Text(
          "Preferiti",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD46A6A)),
        ),
        centerTitle: true,
      ),
      body: favourites.isEmpty
          ? Center(
              child: Text(
                "Nessun preferito disponibile",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(10.0),
              child: ListView.builder(
                itemCount: favourites.length,
                itemBuilder: (context, index) {
                  final fav = favourites[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFFF2CFCF), width: 2),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 1)],
                      ),
                      padding: EdgeInsets.all(16),
                      child: Text(
                        fav,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
