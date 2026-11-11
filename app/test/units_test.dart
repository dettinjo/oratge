import 'package:flutter_test/flutter_test.dart';
import 'package:oratge/data/units.dart';

void main() {
  test('wind texts convert, including ranges and bare gust numbers', () {
    const u = Units(wind: 'km/h');
    expect(u.convert('SW 12 kn · gusts 18'), 'SW 22 km/h · gusts 33');
    expect(u.convert('side-on 14–24 kn'), 'side-on 26–44 km/h');
    expect(u.convert('gusts up to 13 kn'), 'gusts up to 24 km/h');
    expect(u.convert('peak 13 kn stays inside'), 'peak 24 km/h stays inside');
    expect(const Units(wind: 'Bft').convert('W 12 kn'), 'W 4 Bft');
    expect(const Units(wind: 'm/s').windText(10), '5.1 m/s');
  });

  test('temperatures convert to °F, other numbers stay', () {
    const u = Units(temp: '°F');
    expect(u.convert('17° · feels 15°'), '63° · feels 59°');
    expect(u.convert('max 3 at 13 h'), 'max 3 at 13 h');
    expect(u.convertJson({'a': ['20°', 5]}), {'a': ['68°', 5]});
  });

  test('default units leave everything untouched', () {
    const u = Units();
    final j = {'x': '12 kn', 'y': '17°'};
    expect(identical(u.convertJson(j), j), isTrue);
  });
}
