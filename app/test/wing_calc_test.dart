import 'package:flutter_test/flutter_test.dart';
import 'package:oratge/data/wing_calc.dart';

// Same reference cases as backend/tests/test_wingcalc.py.
const me = {'weight': '78', 'boardVolume': '95', 'frontWing': '1100', 'wings': ['4 m', '5 m'], 'wingLevel': 'Riding upwind'};

void main() {
  test('reference rider', () {
    final g = WingGear.of(me);
    final four = g.wings.firstWhere((w) => w.size == 4), five = g.wings.firstWhere((w) => w.size == 5);
    expect(five.low, 12.8);
    expect(four.low, 14.3);
    expect(four.high, 31.4);
    expect(five.high, 28.0);
  });

  test('gear moves the minimum', () {
    final base = WingGear.of(me).minWind;
    expect(WingGear.of({...me, 'boardVolume': '60'}).minWind, greaterThan(base + 4));
    expect(WingGear.of({...me, 'frontWing': '1900'}).minWind, lessThan(base - 2));
    final learner = WingGear.of({...me, 'wingLevel': 'Learning'});
    expect(learner.minWind, greaterThan(base));
    expect(learner.maxGust, lessThan(WingGear.of(me).maxGust));
  });

  test('pick a wing', () {
    final g = WingGear.of(me);
    expect(g.pick(16, 20).size, 5);
    expect(g.pick(18, 30).size, 4);
    expect(g.pick(10, 13).state, 'under');
    expect(g.pick(28, 36).state, 'over');
    expect(WingGear.quiver('3 m, 4.5 m'), [3.0, 4.5]);
  });
}
