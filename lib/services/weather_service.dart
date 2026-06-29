import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../models/weather_snapshot.dart';

class WeatherLocationException implements Exception {
  final String message;

  const WeatherLocationException(this.message);

  @override
  String toString() => message;
}

class WeatherService {
  static const _forecastEndpoint = 'https://api.open-meteo.com/v1/forecast';

  final Dio _dio;

  const WeatherService(this._dio);

  Future<WeatherSnapshot> getCurrentWeather() async {
    final position = await _currentPosition();
    final response = await _dio.get<Map<String, dynamic>>(
      _forecastEndpoint,
      queryParameters: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'current':
            'temperature_2m,apparent_temperature,weather_code,wind_speed_10m',
        'timezone': 'auto',
      },
    );

    final data = response.data;
    final current = data?['current'];
    if (current is! Map<String, dynamic>) {
      throw const WeatherLocationException('Weather is unavailable right now.');
    }

    return WeatherSnapshot(
      temperatureC: _number(current['temperature_2m']),
      apparentTemperatureC: _number(current['apparent_temperature']),
      windSpeedKph: _number(current['wind_speed_10m']),
      weatherCode: _number(current['weather_code']).round(),
      observedAt:
          DateTime.tryParse(current['time'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  Future<Position> _currentPosition() async {
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      throw const WeatherLocationException('Turn on location for weather.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const WeatherLocationException('Allow location for weather.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const WeatherLocationException('Location is blocked.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
      ),
    );
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    throw const WeatherLocationException('Weather is unavailable right now.');
  }
}
