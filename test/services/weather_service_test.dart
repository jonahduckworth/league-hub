import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:league_hub/services/weather_service.dart';

void main() {
  group('WeatherService', () {
    test('requests and parses current metric weather', () async {
      late RequestOptions request;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'current': {
                      'temperature_2m': 27.1,
                      'apparent_temperature': 27.9,
                      'weather_code': 2,
                      'wind_speed_10m': 9.2,
                      'is_day': 1,
                      'time': '2026-07-17T17:45',
                    },
                  },
                ),
              );
            },
          ),
        );
      final service = WeatherService(
        dio,
        positionLoader: () async => _position(),
      );

      final weather = await service.getCurrentWeather();

      expect(request.queryParameters['latitude'], 53.5461);
      expect(request.queryParameters['longitude'], -113.4938);
      expect(request.queryParameters['temperature_unit'], 'celsius');
      expect(request.queryParameters['wind_speed_unit'], 'kmh');
      expect(request.queryParameters['current'], contains('is_day'));
      expect(weather.temperatureC, 27.1);
      expect(weather.apparentTemperatureC, 27.9);
      expect(weather.windSpeedKph, 9.2);
      expect(weather.weatherCode, 2);
      expect(weather.isDay, isTrue);
      expect(weather.description, 'Partly cloudy');
    });

    test('rejects incomplete current weather responses', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'current': {
                      'temperature_2m': 10,
                    },
                  },
                ),
              );
            },
          ),
        );
      final service = WeatherService(
        dio,
        positionLoader: () async => _position(),
      );

      await expectLater(
        service.getCurrentWeather(),
        throwsA(
          isA<WeatherLocationException>().having(
            (error) => error.message,
            'message',
            'Weather is unavailable right now.',
          ),
        ),
      );
    });
  });
}

Position _position() {
  return Position(
    longitude: -113.4938,
    latitude: 53.5461,
    timestamp: DateTime(2026, 7, 17),
    accuracy: 10,
    altitude: 645,
    altitudeAccuracy: 10,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
