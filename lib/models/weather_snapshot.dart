class WeatherSnapshot {
  final double temperatureC;
  final double apparentTemperatureC;
  final double windSpeedKph;
  final int weatherCode;
  final bool isDay;
  final DateTime observedAt;

  const WeatherSnapshot({
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.windSpeedKph,
    required this.weatherCode,
    required this.isDay,
    required this.observedAt,
  });

  String get temperatureLabel => '${temperatureC.round()}°';
  String get apparentTemperatureLabel => '${apparentTemperatureC.round()}°';
  String get windLabel => '${windSpeedKph.round()} km/h';

  String get description => weatherDescriptionForCode(weatherCode);
}

String weatherDescriptionForCode(int code) {
  if (code == 0) return 'Clear';
  if (code == 1) return 'Mainly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 55) return 'Drizzle';
  if (code == 56 || code == 57) return 'Freezing drizzle';
  if (code >= 61 && code <= 65) return 'Rain';
  if (code == 66 || code == 67) return 'Freezing rain';
  if (code >= 71 && code <= 75) return 'Snow';
  if (code == 77) return 'Snow grains';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code == 85 || code == 86) return 'Snow showers';
  if (code == 95) return 'Thunderstorm';
  if (code == 96 || code == 99) return 'Storm with hail';
  return 'Weather';
}
