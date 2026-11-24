import 'package:flutter_test/flutter_test.dart';
import 'package:oratge/data/radar.dart';
import 'package:oratge/theme/oratge_tokens.dart';
import 'package:oratge/ui/map/field.dart';

void main() {
  test('radar index: frames sorted oldest first, tile URL with scheme 2 and zoom placeholders', () {
    final frames = RainRadar.parse({
      'host': 'https://tilecache.rainviewer.com',
      'radar': {
        'past': [
          {'time': 1795545000, 'path': '/v2/radar/bbb'},
          {'time': 1795544400, 'path': '/v2/radar/aaa'},
        ],
      },
    });
    expect(frames.length, 2);
    expect(frames.first.time.isBefore(frames.last.time), isTrue);
    expect(frames.first.url, 'https://tilecache.rainviewer.com/v2/radar/aaa/512/{z}/{x}/{y}/2/1_0.png');
  });

  test('radar index without frames parses to an empty list', () {
    expect(RainRadar.parse({'host': 'h'}), isEmpty);
  });

  test('radar layer has a legend and no forecast colours', () {
    final colors = FieldColors(OratgeColors.light);
    expect(colors.legend(FieldLayer.radar).length, 5);
    expect(FieldLayer.radar.label, 'Radar');
  });
}
