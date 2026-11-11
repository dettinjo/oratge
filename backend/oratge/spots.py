"""Spot registry. comarques: Meteocat comarca codes (warnings are issued per comarca). Station codes checked against XEMA metadata (2026-11-11).

shore_facing: direction the beach faces towards the sea (degrees). exposure: directions open to the sea.
"""

SPOTS = {
    'castelldefels': {
        'name': 'Castelldefels', 'sport': 'wing', 'kind': 'Wing · flatwater', 'lat': 41.265, 'lon': 1.975,
        'comarques': [11], 'municipi': '080557', 'beach': 'castelldefels', 'station': 'YY', 'station_name': 'Viladecans',
        # Viladecans has no anemometer: wind comes from the nearest coastal station.
        'wind_station': 'XL', 'wind_station_name': 'el Prat de Llobregat',
        'shore_facing': 170, 'exposure': [90, 250],
    },
    'ocata': {
        'name': 'Ocata', 'sport': 'surf', 'kind': 'Surf · beach', 'lat': 41.477, 'lon': 2.338,
        'comarques': [21], 'municipi': '081181', 'beach': 'ocata', 'station': 'YV', 'station_name': 'Mataró',
        'shore_facing': 120, 'exposure': [40, 180],
    },
    'collserola': {
        'name': 'Collserola loop', 'sport': 'bike', 'kind': 'Bike · 42 km', 'lat': 41.418, 'lon': 2.118,
        'comarques': [13, 40], 'municipi': '080193', 'station': 'XV', 'station_name': 'Sant Cugat del Vallès – CAR',
        'route': [[40, 120], [70, 95], [95, 70], [130, 45], [175, 30], [220, 28], [262, 42], [285, 70], [280, 102],
                  [250, 122], [205, 132], [150, 135], [100, 132], [60, 128], [40, 120]],
        'route_labels': [[50, 142, 'start · Sarrià'], [175, 20, 'Tibidabo 512 m']],
    },
    'barcelona-run': {
        'name': 'Passeig Marítim', 'sport': 'run', 'kind': 'Run · 10 km', 'lat': 41.381, 'lon': 2.194,
        'comarques': [13], 'municipi': '080193', 'station': 'X4', 'station_name': 'Barcelona – el Raval',
    },
    'pedraforca': {
        'name': 'Pedraforca', 'sport': 'hike', 'kind': 'Hike · 2506 m', 'lat': 42.239, 'lon': 1.703,
        'summit_alt': 2506, 'base_alt': 1215, 'hut_alt': 1640, 'peak_slug': 'el-pedraforca',
        'comarques': [14], 'municipi': '251943', 'station': 'UI', 'station_name': 'Gisclareny',
        # Gisclareny has no anemometer; Cadí Nord (2145 m, 6 km) is close to summit height.
        'wind_station': 'Z9', 'wind_station_name': 'Cadí Nord (2145 m)',
    },
}

HOME = {'name': 'Barcelona', 'lat': 41.389, 'lon': 2.159, 'comarques': [13], 'municipi': '080193', 'station': 'X4',
        'station_name': 'el Raval'}

SPORT_SPOT = {'wing': 'castelldefels', 'surf': 'ocata', 'bike': 'collserola', 'run': 'barcelona-run', 'hike': 'pedraforca'}


COMARCA_NAMES = {11: 'Baix Llobregat', 13: 'Barcelonès', 14: 'Berguedà', 21: 'Maresme', 40: 'Vallès Occidental'}

WIND_VARS = (30, 31, 50)  # XEMA: wind speed 10 m (m/s), direction (°), max gust (m/s)


def merge_wind(own: dict, wind: dict) -> dict:
    """Readings per XEMA variable code, with wind taken from the wind station when the spot's own has none."""
    if 30 in own or not wind:
        return own
    return {**own, **{c: v for c, v in wind.items() if c in WIND_VARS}}
