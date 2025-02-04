import 'package:supabase_flutter/supabase_flutter.dart';
import 'location.dart';

class LocationCountryService {
  static Future<List<LocationModel>> fetchLocations(String tableName) async {
    try {
      final response = await Supabase.instance.client.from(tableName).select().execute();
      if (response.data != null && response.status == 200) {
        final data = response.data as List<dynamic>;
        return data.map((item) => LocationModel.fromMap(item)).toList();
      }
    } catch (error) {
      print("Errore nel recupero di $tableName: $error");
    }
    return [];
  }
}
