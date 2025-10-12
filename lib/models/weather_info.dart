import './weather.dart';

class WeatherInfo {
  final Weather weather;
  final String cityName;
  final String prefectureName;

  WeatherInfo({
    required this.weather,
    required this.cityName,
    required this.prefectureName,
  });
}
