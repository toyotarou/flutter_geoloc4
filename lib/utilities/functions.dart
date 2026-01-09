import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

///
// ignore: always_specify_types
List<Polygon> makeAreaPolygons({
  required List<List<List<List<double>>>> allPolygonsList,
  required List<Color> fortyEightColor,
}) {
  // ignore: always_specify_types
  final List<Polygon<Object>> polygonList = <Polygon<Object>>[];

  if (allPolygonsList.isEmpty) {
    return polygonList;
  }

  final Map<String, List<List<List<double>>>> uniquePolygons = <String, List<List<List<double>>>>{};

  for (final List<List<List<double>>> poly in allPolygonsList) {
    final String key = poly.toString();
    uniquePolygons[key] = poly;
  }

  int idx = 0;
  for (final List<List<List<double>>> poly in uniquePolygons.values) {
    final Polygon<Object>? polygon = getColorPaintPolygon(
      polygon: poly,
      color: fortyEightColor[idx % 48].withValues(alpha: 0.3),
    );

    if (polygon != null) {
      polygonList.add(polygon);
      idx++;
    }
  }

  return polygonList;
}

///
// ignore: always_specify_types
Polygon? getColorPaintPolygon({required List<List<List<double>>> polygon, required Color color}) {
  if (polygon.isEmpty) {
    return null;
  }

  final List<LatLng> outer = polygon.first.map((List<double> element) => LatLng(element[1], element[0])).toList();

  final List<List<LatLng>> holes = <List<LatLng>>[];

  for (int i = 1; i < polygon.length; i++) {
    holes.add(polygon[i].map((List<double> element4) => LatLng(element4[1], element4[0])).toList());
  }

  // ignore: always_specify_types
  return Polygon(
    points: outer,
    holePointsList: holes.isEmpty ? null : holes,
    isFilled: true,
    color: color.withValues(alpha: 0.3),
    borderColor: color.withValues(alpha: 0.8),
    borderStrokeWidth: 1.5,
  );
}
