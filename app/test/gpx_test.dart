import 'package:flutter_test/flutter_test.dart';
import 'package:oratge/data/activities.dart';

void main() {
  test('reads tracks with elevation, falls back to routes', () {
    const trk = '<gpx><trk><name>Collserola</name><trkseg>'
        '<trkpt lat="41.418" lon="2.118"><ele>200</ele></trkpt><trkpt lat="41.43" lon="2.09"><ele>420.5</ele></trkpt>'
        '</trkseg></trk></gpx>';
    final g = parseGpx(trk);
    expect(g.name, 'Collserola');
    expect(g.points, [[41.418, 2.118, 200.0], [41.43, 2.09, 420.5]]);
    const rte = '<gpx><rte><rtept lat="41.1" lon="2.1"/><rtept lat="41.2" lon="2.2"/></rte></gpx>';
    expect(parseGpx(rte).points.length, 2);
  });

  test('simplify keeps the shape under the limit', () {
    // A 2000-point zig-zag along 0.2° of longitude.
    final pts = [for (var i = 0; i < 2000; i++) <double?>[41.3 + (i % 50 < 25 ? i % 25 : 25 - i % 25) * 0.0004, 2.0 + i * 0.0001, null]];
    final s = simplify(pts, max: 300);
    expect(s.length, lessThanOrEqualTo(300));
    expect(s.first, pts.first);
    expect(s.last, pts.last);
    final a = Activity(id: 'x', sport: 'bike', kind: 'route', name: 'x', track: s);
    final full = Activity(id: 'y', sport: 'bike', kind: 'route', name: 'y', track: pts);
    expect(a.distanceKm, closeTo(full.distanceKm, full.distanceKm * 0.1)); // distance survives simplification
  });
}
