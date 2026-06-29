class WeatherSnapshot {
  final double temperatureC;
  final double apparentTemperatureC;
  final double windSpeedKph;
  final int weatherCode;
  final DateTime observedAt;

  const WeatherSnapshot({
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.windSpeedKph,
    required this.weatherCode,
    required this.observedAt,
  });

  String get temperatureLabel => '${temperatureC.round()}°';
  String get apparentTemperatureLabel => '${apparentTemperatureC.round()}°';
  String get windLabel => '${windSpeedKph.round()} km/h';

  String get description => weatherDescriptionForCode(weatherCode);
}

String weatherDescriptionForCode(int code) {
  if (code == 0) return 'Clear';
  if (code >= 1 && code <= 3) return 'Partly cloudy';
  if (code == 45 || code == 48) return 'Fog';
  if ((code >= 51 && code <= 57) || (code >= 61 && code <= 67)) {
    return 'Rain';
  }
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Showers';
  if (code >= 95) return 'Storms';
  return 'Weather';
}
