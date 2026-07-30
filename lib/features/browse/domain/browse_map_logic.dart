import 'dart:math' as math;

import '../../../data/models/building.dart';

class BrowseMapBounds {
  const BrowseMapBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  bool contains({required double latitude, required double longitude}) {
    return latitude <= north &&
        latitude >= south &&
        longitude <= east &&
        longitude >= west;
  }
}

bool buildingHasCoordinates(Building building) {
  return !building.isDeleted &&
      building.latitude != null &&
      building.longitude != null;
}

List<Building> coordinateBuildings(Iterable<Building> buildings) {
  return sortBuildingsNorthToSouth(buildings.where(buildingHasCoordinates));
}

BrowseMapBounds? boundsForBuildings(Iterable<Building> buildings) {
  final List<Building> positioned = coordinateBuildings(buildings);
  if (positioned.isEmpty) {
    return null;
  }

  double north = positioned.first.latitude!;
  double south = positioned.first.latitude!;
  double east = positioned.first.longitude!;
  double west = positioned.first.longitude!;

  for (final Building building in positioned.skip(1)) {
    final double latitude = building.latitude!;
    final double longitude = building.longitude!;
    north = math.max(north, latitude);
    south = math.min(south, latitude);
    east = math.max(east, longitude);
    west = math.min(west, longitude);
  }

  return BrowseMapBounds(north: north, south: south, east: east, west: west);
}

List<Building> visibleBuildings(
  Iterable<Building> buildings,
  BrowseMapBounds bounds,
) {
  return sortBuildingsNorthToSouth(
    buildings.where((Building building) {
      final double? latitude = building.latitude;
      final double? longitude = building.longitude;
      return !building.isDeleted &&
          latitude != null &&
          longitude != null &&
          bounds.contains(latitude: latitude, longitude: longitude);
    }),
  );
}

List<Building> sortBuildingsNorthToSouth(Iterable<Building> buildings) {
  final List<Building> sorted = List<Building>.of(buildings);
  sorted.sort((Building left, Building right) {
    final double leftLatitude = left.latitude ?? -90;
    final double rightLatitude = right.latitude ?? -90;
    final int latitudeComparison = rightLatitude.compareTo(leftLatitude);
    if (latitudeComparison != 0) {
      return latitudeComparison;
    }

    final int nameComparison = left.buildingName.compareTo(right.buildingName);
    if (nameComparison != 0) {
      return nameComparison;
    }
    return left.buildingId.compareTo(right.buildingId);
  });
  return List<Building>.unmodifiable(sorted);
}

List<Building> filterBuildingsByQuery(
  Iterable<Building> buildings,
  String query,
) {
  final String normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return List<Building>.unmodifiable(buildings);
  }

  return List<Building>.unmodifiable(
    buildings.where((Building building) {
      final String haystack = <String>[
        building.buildingName,
        building.searchName,
        building.address ?? '',
      ].join('\n').toLowerCase();
      return haystack.contains(normalizedQuery);
    }),
  );
}

double browseMapWidthMeters(BrowseMapBounds bounds) {
  final double centerLatitude = (bounds.north + bounds.south) / 2;
  return _haversineMeters(
    centerLatitude,
    bounds.west,
    centerLatitude,
    bounds.east,
  );
}

double browseMapHeightMeters(BrowseMapBounds bounds) {
  final double centerLongitude = (bounds.east + bounds.west) / 2;
  return _haversineMeters(
    bounds.south,
    centerLongitude,
    bounds.north,
    centerLongitude,
  );
}

bool shouldShowBuildingLabels(
  BrowseMapBounds bounds, {
  double thresholdMeters = 4000,
}) {
  return browseMapWidthMeters(bounds) < thresholdMeters &&
      browseMapHeightMeters(bounds) < thresholdMeters;
}

double _haversineMeters(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const double earthRadiusMeters = 6371000;
  final double latitudeDelta = _degreesToRadians(latitude2 - latitude1);
  final double longitudeDelta = _degreesToRadians(longitude2 - longitude1);
  final double firstLatitude = _degreesToRadians(latitude1);
  final double secondLatitude = _degreesToRadians(latitude2);

  final double a =
      math.pow(math.sin(latitudeDelta / 2), 2).toDouble() +
      math.cos(firstLatitude) *
          math.cos(secondLatitude) *
          math.pow(math.sin(longitudeDelta / 2), 2).toDouble();
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;
