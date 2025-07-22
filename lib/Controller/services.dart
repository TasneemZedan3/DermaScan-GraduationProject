import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class LocationService {
  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("❌ Location services are disabled.");
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("❌ Location permission denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("❌ Location permissions permanently denied.");
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<List<Map<String, dynamic>>> fetchNearbyHospitals(double userLat, double userLng) async {
    const String apiKey = 'ADD UR API';
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$userLat,$userLng&rankby=distance&keyword=dermatologist&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['status'] == 'OK') {
        List hospitals = data['results'];
        List<Map<String, dynamic>> hospitalList = [];

        for (var hospital in hospitals) {
          String name = hospital['name'];
          double lat = hospital['geometry']['location']['lat'];
          double lng = hospital['geometry']['location']['lng'];
          double distance = calculateDistance(userLat, userLng, lat, lng);

          hospitalList.add({
            'name': name,
            'distance': distance.toStringAsFixed(2),
            'lat': lat,  // Add this line
            'lng': lng,  // Add this line
          });

        }

        return hospitalList;
      } else {
        throw Exception("❌ API Error: ${data['status']}");
      }
    } else {
      throw Exception("❌ HTTP Error: ${response.statusCode}");
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth radius in km
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * pi / 180) *
                cos(lat2 * pi / 180) *
                sin(dLon / 2) *
                sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in km
  }
}
