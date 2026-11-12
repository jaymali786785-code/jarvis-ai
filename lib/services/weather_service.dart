// weather_service.dart
// Real weather: geolocator for position, Open-Meteo (free, no key) for data,
// OpenStreetMap Nominatim for the city name.

import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temp, feels, high, low;
  final int humidity, code;
  final String city;
  WeatherData(this.temp, this.feels, this.high, this.low, this.humidity, this.code, this.city);

  String get description {
    if (code == 0) return 'Clear Sky';
    if (code <= 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain Showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Cloudy';
  }

  bool get isClear => code <= 2;
}

class WeatherService {
  static Future<WeatherData> fetch() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location (GPS) off hai');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw Exception('Location permission nahi mili');
    }
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 20));

    final url = Uri.parse('https://api.open-meteo.com/v1/forecast'
        '?latitude=${pos.latitude}&longitude=${pos.longitude}'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code'
        '&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1');
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Weather API error ${res.statusCode}');
    final j = jsonDecode(res.body);
    final cur = j['current'];

    String city = 'Your location';
    try {
      final g = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&zoom=10'
            '&lat=${pos.latitude}&lon=${pos.longitude}'),
        headers: {'User-Agent': 'jarvis_ai/1.0'},
      ).timeout(const Duration(seconds: 15));
      if (g.statusCode == 200) {
        final a = jsonDecode(g.body)['address'] ?? {};
        city = a['city'] ?? a['town'] ?? a['village'] ?? a['suburb'] ?? a['county'] ?? city;
      }
    } catch (_) {}

    return WeatherData(
      (cur['temperature_2m'] as num).toDouble(),
      (cur['apparent_temperature'] as num).toDouble(),
      (j['daily']['temperature_2m_max'][0] as num).toDouble(),
      (j['daily']['temperature_2m_min'][0] as num).toDouble(),
      (cur['relative_humidity_2m'] as num).round(),
      (cur['weather_code'] as num).toInt(),
      city,
    );
  }
}
