import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/weather.dart';
import '../models/weather_info.dart';

class WeatherService {
  static String get _apiKey {
    // Web版ではAPIキーを使用しない（Edge Function経由でアクセス）
    if (kIsWeb) {
      return '';
    }
    
    if (kDebugMode) {
      return dotenv.env['OPENWEATHERMAP_API_KEY'] ?? '';
    } else {
      return const String.fromEnvironment('OPENWEATHERMAP_API_KEY');
    }
  }

  Future<WeatherInfo> getWeather(String cityName) async {
    if (!kIsWeb && _apiKey.isEmpty) {
      throw Exception('OpenWeatherMap APIキーが設定されていません。');
    }

    if (kIsWeb) {
      // Web版: Supabase Edge Function経由で呼び出し
      return _getWeatherViaEdgeFunction(cityName);
    } else {
      // モバイル版: 直接OpenWeatherMap APIを呼び出し
      return _getWeatherDirect(cityName);
    }
  }

  Future<WeatherInfo> _getWeatherViaEdgeFunction(String cityName) async {
    // Supabase Edge FunctionのURLを構築
    final supabaseClient = Supabase.instance.client;
    final edgeFunctionUrl = '${supabaseClient.restUrl.replaceAll('/rest/v1', '')}/functions/v1/weather-proxy';

    final uri = Uri.parse(edgeFunctionUrl).replace(
      queryParameters: {'city': cityName},
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('天気予報の取得に失敗しました: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    
    // Edge Functionから返されたデータを解析
    final cityNameResolved = data['cityName'] as String? ?? cityName;
    final prefectureName = data['prefectureName'] as String? ?? '';
    final forecastList = data['list'] as List;

    if (forecastList.isEmpty) {
      throw Exception('天気予報データがありません。');
    }

    // 最初の予報を現在の天気として使用
    final currentWeatherJson = forecastList[0];
    final currentWeather = Weather.fromJson(currentWeatherJson);

    // 今後の雨をチェック
    String forecastDescription = currentWeather.description;
    bool willRain = false;
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

    final finalWeather = Weather(
      description: forecastDescription,
      iconCode: currentWeather.iconCode,
      temperature: currentWeather.temperature,
    );

    return WeatherInfo(
      weather: finalWeather,
      cityName: cityNameResolved,
      prefectureName: prefectureName,
    );
  }

  Future<WeatherInfo> _getWeatherDirect(String cityName) async {
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
