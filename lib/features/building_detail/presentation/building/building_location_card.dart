part of '../building_detail_page.dart';

class _BuildingLocationCard extends StatelessWidget {
  const _BuildingLocationCard({
    required this.building,
    required this.enableNetworkTiles,
  });

  final Building building;
  final bool enableNetworkTiles;

  @override
  Widget build(BuildContext context) {
    final double? latitude = building.latitude;
    final double? longitude = building.longitude;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.map_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '代表位置',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: latitude == null || longitude == null
                ? const Center(child: Text('代表位置は登録されていません。'))
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(latitude, longitude),
                      initialZoom: 17,
                      minZoom: 5,
                      maxZoom: 19,
                    ),
                    children: <Widget>[
                      if (enableNetworkTiles)
                        TileLayer(
                          urlTemplate:
                              'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
                          maxNativeZoom: 18,
                          userAgentPackageName: 'building_record_app',
                        ),
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: LatLng(latitude, longitude),
                            width: 46,
                            height: 46,
                            alignment: Alignment.bottomCenter,
                            child: Icon(
                              Icons.location_on,
                              size: 42,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SimpleAttributionWidget(source: Text('国土地理院')),
                    ],
                  ),
          ),
          if (latitude != null && longitude != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Text(
                '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
