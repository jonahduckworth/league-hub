import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/weather_snapshot.dart';
import '../services/weather_service.dart';

final weatherDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );
});

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService(ref.watch(weatherDioProvider));
});

final currentWeatherProvider = FutureProvider.autoDispose<WeatherSnapshot>(
  (ref) => ref.watch(weatherServiceProvider).getCurrentWeather(),
);
