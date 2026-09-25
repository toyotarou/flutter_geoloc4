import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/municipal_model.dart';

/// makeAreaPolygons の結果キャッシュ
/// （全区市町村のポリゴンを毎回 toString して重複排除していたため、地図のズーム/パンのたびに非常に重かった）
List<List<List<List<double>>>>? _areaPolygonsCacheSource;
int _areaPolygonsCacheLength = -1;
List<Color>? _areaPolygonsCacheColors;
List<Polygon<Object>> _areaPolygonsCacheResult = <Polygon<Object>>[];

///
// ignore: always_specify_types
List<Polygon> makeAreaPolygons({
  required List<List<List<List<double>>>> allPolygonsList,
  required List<Color> fortyEightColor,
}) {
  // 入力が前回と同じ（同じリスト・同じ件数・同じ色）なら前回の結果を返す
  if (_areaPolygonsCacheSource == allPolygonsList &&
      _areaPolygonsCacheLength == allPolygonsList.length &&
      _areaPolygonsCacheColors == fortyEightColor) {
    return _areaPolygonsCacheResult;
  }

  // ignore: always_specify_types
  final List<Polygon<Object>> polygonList = <Polygon<Object>>[];

  _areaPolygonsCacheSource = allPolygonsList;
  _areaPolygonsCacheLength = allPolygonsList.length;
  _areaPolygonsCacheColors = fortyEightColor;
  _areaPolygonsCacheResult = polygonList;

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

///
/// parseMunicipalGeoJson を別 isolate で実行する（起動直後の UI カクつき防止）
Future<List<MunicipalModel>> parseMunicipalGeoJsonInBackground(String text) =>
    compute<String, List<MunicipalModel>>(parseMunicipalGeoJson, text);

///
/// 区市町村 GeoJSON（FeatureCollection / Feature）を MunicipalModel のリストに変換する
/// （tokyo_municipal.dart にあった処理を、compute() から呼べるようトップレベル関数にしたもの。処理内容は同じ）
List<MunicipalModel> parseMunicipalGeoJson(String text) {
  final List<MunicipalModel> list = <MunicipalModel>[];

  // ignore: always_specify_types
  final data = jsonDecode(text);

  // ignore: always_specify_types, strict_raw_type
  final List features;
  // ignore: avoid_dynamic_calls
  if (data['type'] == 'FeatureCollection') {
    // ignore: avoid_dynamic_calls, always_specify_types
    features = data['features'] as List;

    // ignore: avoid_dynamic_calls
  } else if (data['type'] == 'Feature') {
    features = <dynamic>[data];
  } else {
    // ignore: avoid_dynamic_calls
    throw Exception('Unsupported root type: ${data['type']}');
  }

  // ignore: always_specify_types
  for (final f in features) {
    // ignore: avoid_dynamic_calls
    final Map<String, dynamic> props = Map<String, dynamic>.from(f['properties'] as Map<String, dynamic>);

    // ignore: avoid_dynamic_calls
    final Map<String, dynamic> geom = Map<String, dynamic>.from(f['geometry'] as Map<String, dynamic>);

    if (geom.isEmpty) {
      continue;
    }

    final String name = (props['N03_004'] ?? props['name'] ?? '') as String;
    if (name.isEmpty) {
      continue;
    }

    final String? type = geom['type'] as String?;

    // ignore: always_specify_types
    final coords = geom['coordinates'];

    int count = 0;

    double? minLat, minLng, maxLat, maxLng;

    final List<List<List<List<double>>>> polygons = <List<List<List<double>>>>[];

    double sumLat = 0, sumLng = 0;

    int ptCnt = 0;

    void addPoint(double lng, double lat) {
      count++;

      minLat = (minLat == null) ? lat : (lat < minLat! ? lat : minLat);

      maxLat = (maxLat == null) ? lat : (lat > maxLat! ? lat : maxLat);

      minLng = (minLng == null) ? lng : (lng < minLng! ? lng : minLng);

      maxLng = (maxLng == null) ? lng : (lng > maxLng! ? lng : maxLng);

      sumLat += lat;

      sumLng += lng;

      ptCnt++;
    }

    // ignore: always_specify_types, strict_raw_type
    List<List<List<double>>> parseRings(List rawRings) {
      final List<List<List<double>>> rings = <List<List<double>>>[];

      // ignore: always_specify_types
      for (final ring in rawRings) {
        final List<List<double>> rr = <List<double>>[];

        // ignore: always_specify_types
        for (final pt in (ring as List)) {
          // ignore: avoid_dynamic_calls
          final double lng = (pt[0] as num).toDouble();

          // ignore: avoid_dynamic_calls
          final double lat = (pt[1] as num).toDouble();

          addPoint(lng, lat);

          rr.add(<double>[lng, lat]);
        }

        rings.add(rr);
      }

      return rings;
    }

    if (type == 'Polygon') {
      // ignore: always_specify_types
      polygons.add(parseRings(coords as List));
    } else if (type == 'MultiPolygon') {
      // ignore: always_specify_types
      for (final poly in (coords as List)) {
        // ignore: always_specify_types
        polygons.add(parseRings(poly as List));
      }
    } else {
      continue;
    }

    final double centroidLat = ptCnt == 0 ? 0.0 : (sumLat / ptCnt);

    final double centroidLng = ptCnt == 0 ? 0.0 : (sumLng / ptCnt);

    list.add(
      MunicipalModel(
        name,
        count,
        minLat: minLat ?? 0,
        minLng: minLng ?? 0,
        maxLat: maxLat ?? 0,
        maxLng: maxLng ?? 0,
        polygons: polygons,
        centroidLat: centroidLat,
        centroidLng: centroidLng,
      ),
    );
  }

  return list;
}
