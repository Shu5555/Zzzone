import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/weather.dart';
import '../models/weather_info.dart';

class WeatherService {
  static final String _apiKey = kDebugMode
      ? dotenv.env['OPENWEATHERMAP_API_KEY']!
      : const String.fromEnvironment('OPENWEATHERMAP_API_KEY');

  Future<WeatherInfo> getWeather(String cityName) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenWeatherMap APIキーが設定されていません。');
    }

    // Step 1: Geocoding - Convert city name to coordinates and get location details
    final geoUri = Uri.https(
      'api.openweathermap.org',
      '/geo/1.0/direct',
      {
        'q': '$cityName,JP',
        'limit': '1',
        'appid': _apiKey,
      },
    );
    final geoResponse = await http.get(geoUri);
    if (geoResponse.statusCode != 200) {
      throw Exception('地点の座標取得に失敗しました。');
    }
    final geoData = json.decode(geoResponse.body) as List;
    if (geoData.isEmpty) {
      throw Exception('地点が見つかりません。都市名を確認してください。');
    }

    final locationData = geoData[0];
    final lat = locationData['lat'];
    final lon = locationData['lon'];
    final String prefectureName = locationData['state'] ?? '';
    final String resolvedCityName = locationData['local_names']?['ja'] ?? locationData['name'] ?? cityName;

    // Step 2: Get Weather - Use coordinates to get weather data
    final weatherUri = Uri.https(
      'api.openweathermap.org',
      '/data/2.5/forecast',
      {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'appid': _apiKey,
        'units': 'metric',
        'lang': 'ja',
      },
    );

    final forecastResponse = await http.get(weatherUri);
    if (forecastResponse.statusCode == 200) {
      final forecastData = json.decode(forecastResponse.body);
      final forecastList = forecastData['list'] as List;
      if (forecastList.isEmpty) {
        throw Exception('天気予報データがありません。');
      }

      // Use the first forecast as the current weather
      final currentWeatherJson = forecastList[0];
      final currentWeather = Weather.fromJson(currentWeatherJson);

      // Check for upcoming rain
      String forecastDescription = currentWeather.description;
      bool willRain = false;
      // Check the next 8 forecasts (24 hours)
      for (int i = 1; i < forecastList.length && i <= 8; i++) {
        final hourlyForecast = forecastList[i];
        final weatherDescription = hourlyForecast['weather'][0]['description'] as String? ?? '';
        if (weatherDescription.contains('雨')) {
          willRain = true;
          break;
        }
      }

      if (willRain && !forecastDescription.contains('雨')) {
        forecastDescription += '、のち雨';
      }

      // Create a new Weather object with the potentially updated description
      final finalWeather = Weather(
        description: forecastDescription,
        iconCode: currentWeather.iconCode,
        temperature: currentWeather.temperature,
      );

      return WeatherInfo(
        weather: finalWeather,
        cityName: resolvedCityName,
        prefectureName: prefectureName,
      );
    } else {
      throw Exception('天気予報の取得に失敗しました。');
    }
  }
}