"""Spot registry. Station codes are from the public XEMA list; verify with a Meteocat key.

shore_facing: direction the beach faces towards the sea (degrees). exposure: directions open to the sea.
"""

SPOTS = {
    'castelldefels': {
        'name': 'Castelldefels', 'sport': 'wing', 'kind': 'Wing · flatwater', 'lat': 41.265, 'lon': 1.975,
        'municipi': '080557', 'beach': 'castelldefels', 'station': 'YY', 'station_name': 'Viladecans',
        'shore_facing': 170, 'exposure': [90, 250],
    },
    'ocata': {
        'name': 'Ocata', 'sport': 'surf', 'kind': 'Surf · beach', 'lat': 41.477, 'lon': 2.338,
        'municipi': '081181', 'beach': 'ocata', 'station': 'YV', 'station_name': 'Mataró',
        'shore_facing': 120, 'exposure': [40, 180],
    },
    'collserola': {
        'name': 'Collserola loop', 'sport': 'bike', 'kind': 'Bike · 42 km', 'lat': 41.418, 'lon': 2.118,
        'municipi': '080193', 'station': 'XV', 'station_name': 'Sant Cugat del Vallès – CAR',
        'route': [[40, 120], [70, 95], [95, 70], [130, 45], [175, 30], [220, 28], [262, 42], [285, 70], [280, 102],
                  [250, 122], [205, 132], [150, 135], [100, 132], [60, 128], [40, 120]],
        'route_labels': [[50, 142, 'start · Sarrià'], [175, 20, 'Tibidabo 512 m']],
    },
    'barcelona-run': {
        'name': 'Passeig Marítim', 'sport': 'run', 'kind': 'Run · 10 km', 'lat': 41.381, 'lon': 2.194,
        'municipi': '080193', 'station': 'X4', 'station_name': 'Barcelona – el Raval',
    },
    'pedraforca': {
        'name': 'Pedraforca', 'sport': 'hike', 'kind': 'Hike · 2506 m', 'lat': 42.239, 'lon': 1.703,
        'summit_alt': 2506, 'base_alt': 1215, 'hut_alt': 1640, 'peak_slug': 'el-pedraforca',
        'municipi': '251943', 'station': 'UI', 'station_name': 'Gisclareny',
    },
}

HOME = {'name': 'Barcelona', 'lat': 41.389, 'lon': 2.159, 'municipi': '080193', 'station': 'X4',
        'station_name': 'el Raval'}

SPORT_SPOT = {'wing': 'castelldefels', 'surf': 'ocata', 'bike': 'collserola', 'run': 'barcelona-run', 'hike': 'pedraforca'}
