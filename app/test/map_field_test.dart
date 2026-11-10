import 'package:flutter_test/flutter_test.dart';
import 'package:oratge/data/models.dart';
import 'package:oratge/theme/oratge_tokens.dart';
import 'package:oratge/ui/map/field.dart';

MapForecast _fc() {
  // 2x2 grid, 2 hours. Wind from N (0°) at 10 kn everywhere; temp 10..20 west→east.
  List<List<double>> f(List<double> a, List<double> b) => [a, b];
  return MapForecast.fromJson({
    'lats': [41.0, 42.0],
    'lons': [1.0, 2.0],
    'times': ['2026-11-10T00:00', '2026-11-10T01:00'],
    'source': 'test',
    'fields': {
      'wind': f([10, 10, 10, 10], [20, 20, 20, 20]),
      'wdir': f([0, 0, 0, 0], [90, 90, 90, 90]),
      'gust': f([15, 15, 15, 15], [25, 25, 25, 25]),
      'temp': f([10, 20, 10, 20], [12, 22, 12, 22]),
      'precip': f([0, 0, 2, 0], [0, 0, 0, 0]),
      'pprob': f([0, 0, 80, 0], [0, 0, 0, 0]),
      'code': f([0, 0, 61, 0], [0, 0, 0, 0]),
    },
  });
}

void main() {
  test('bilinear sampling interpolates between nodes and clamps outside', () {
    final s = FieldSampler(_fc(), 0);
    expect(s.sample('temp', 41.5, 1.5), closeTo(15, 1e-9));
    expect(s.sample('temp', 41.0, 1.0), 10);
    expect(s.sample('temp', 50.0, 9.0), 20); // clamped to the NE node
    expect(s.sample('precip', 42.0, 1.0), 2);
  });

  test('wind from north blows south; from east blows west', () {
    final (u0, v0) = FieldSampler(_fc(), 0).wind(41.5, 1.5);
    expect(u0, closeTo(0, 1e-9));
    expect(v0, closeTo(-10, 1e-9));
    final (u1, v1) = FieldSampler(_fc(), 1).wind(41.5, 1.5);
    expect(u1, closeTo(-20, 1e-9));
    expect(v1, closeTo(0, 1e-9));
  });

  test('extent includes half a cell', () {
    final s = FieldSampler(_fc(), 0);
    expect(s.nw.latitude, 42.5);
    expect(s.se.longitude, 2.5);
  });

  test('dry cells are transparent, rain is visible', () {
    final colors = FieldColors(OratgeColors.light);
    expect(colors.rain(0).a, 0);
    expect(colors.rain(2).a, greaterThan(0.4));
    expect(colors.legend(FieldLayer.wind).length, 6);
  });

  testWidgets('renders an image of the requested size', (tester) async {
    final img = await tester.runAsync(
        () => renderField(FieldSampler(_fc(), 0), FieldLayer.temp, FieldColors(OratgeColors.light), width: 20, height: 16));
    expect(img!.width, 20);
    expect(img.height, 16);
  });
}
