class Weather {
  final String description;
  final String iconCode;
  final double temperature;

  Weather({
    required this.description,
    required this.iconCode,
    required this.temperature,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      description: json['weather'][0]['description'] ?? '',
      iconCode: json['weather'][0]['icon'] ?? '',
      temperature: (json['main']['temp'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
