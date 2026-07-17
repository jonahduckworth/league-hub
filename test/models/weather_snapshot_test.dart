import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/weather_snapshot.dart';

void main() {
  test('maps every supported WMO weather family', () {
    expect(weatherDescriptionForCode(0), 'Clear');
    expect(weatherDescriptionForCode(1), 'Mainly clear');
    expect(weatherDescriptionForCode(2), 'Partly cloudy');
    expect(weatherDescriptionForCode(3), 'Overcast');
    expect(weatherDescriptionForCode(45), 'Fog');
    expect(weatherDescriptionForCode(51), 'Drizzle');
    expect(weatherDescriptionForCode(56), 'Freezing drizzle');
    expect(weatherDescriptionForCode(61), 'Rain');
    expect(weatherDescriptionForCode(66), 'Freezing rain');
    expect(weatherDescriptionForCode(71), 'Snow');
    expect(weatherDescriptionForCode(77), 'Snow grains');
    expect(weatherDescriptionForCode(80), 'Rain showers');
    expect(weatherDescriptionForCode(85), 'Snow showers');
    expect(weatherDescriptionForCode(95), 'Thunderstorm');
    expect(weatherDescriptionForCode(96), 'Storm with hail');
    expect(weatherDescriptionForCode(-1), 'Weather');
  });

  test('formats the values shown on the Home weather tile', () {
    final snapshot = WeatherSnapshot(
      temperatureC: 27.1,
      apparentTemperatureC: 27.9,
      windSpeedKph: 9.2,
      weatherCode: 2,
      isDay: true,
      observedAt: DateTime(2026, 7, 17, 17, 45),
    );

    expect(snapshot.temperatureLabel, '27°');
    expect(snapshot.apparentTemperatureLabel, '28°');
    expect(snapshot.windLabel, '9 km/h');
    expect(snapshot.description, 'Partly cloudy');
  });
}
