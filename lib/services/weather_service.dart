import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String apiKey = '0e425a94523e6d3334fa6fb15215480a';
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<Map<String, dynamic>> getWeather(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/weather?q=$city&appid=$apiKey&units=metric')
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw 'Failed to load weather data';
    } catch (e) {
      throw 'Error getting weather: $e';
    }
  }
}

enum WeatherCondition {
  clear,
  cloudy,
  rain,
  thunderstorm,
  snow,
  fog,
  unknown
}

WeatherCondition getWeatherCondition(String? weatherCode) {
  if (weatherCode == null) return WeatherCondition.unknown;
  
  switch (weatherCode) {
    case '01d':
    case '01n':
      return WeatherCondition.clear;
    case '02d':
    case '02n':
    case '03d':
    case '03n':
    case '04d':
    case '04n':
      return WeatherCondition.cloudy;
    case '09d':
    case '09n':
    case '10d':
    case '10n':
      return WeatherCondition.rain;
    case '11d':
    case '11n':
      return WeatherCondition.thunderstorm;
    case '13d':
    case '13n':
      return WeatherCondition.snow;
    case '50d':
    case '50n':
      return WeatherCondition.fog;
    default:
      return WeatherCondition.unknown;
  }
}
