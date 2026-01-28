import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/controllers_mixin.dart';
import '../../extensions/extensions.dart';
import '../../models/geoloc_model.dart';
import '../../models/temple_latlng_model.dart';
import '../../models/walk_record_model.dart';
import '../../utilities/tile_provider.dart';

class MonthlyMapAlert extends ConsumerStatefulWidget {
  const MonthlyMapAlert({
    super.key,
    required this.geolocStateList,
    this.displayTempMap,
    required this.displayMonthMap,
    required this.walkRecord,
    this.templeInfoList,
    required this.date,
    this.polylineModeAsTempleVisitedDate,
    this.monthDaysFirstDateTempleExists,
    this.templeGeolocNearlyDateList,
  });

  final DateTime date;
  final List<GeolocModel> geolocStateList;
  final bool? displayTempMap;
  final bool displayMonthMap;
  final WalkRecordModel walkRecord;
  final List<TempleInfoModel>? templeInfoList;
  final bool? polylineModeAsTempleVisitedDate;
  final bool? monthDaysFirstDateTempleExists;
  final List<String>? templeGeolocNearlyDateList;

  @override
  ConsumerState<MonthlyMapAlert> createState() => _MonthlyMapAlertState();
}

class _MonthlyMapAlertState extends ConsumerState<MonthlyMapAlert> with ControllersMixin<MonthlyMapAlert> {
  List<double> latList = <double>[];
  List<double> lngList = <double>[];

  double minLat = 0.0;
  double maxLat = 0.0;
  double minLng = 0.0;
  double maxLng = 0.0;

  final MapController mapController = MapController();

  double currentZoomEightTeen = 18;

  List<GeolocModel> sortedWidgetGeolocStateList = <GeolocModel>[];

  bool isLoading = false;

  double? currentZoom;

  List<Marker> markerList = <Marker>[];

  ///
  @override
  void initState() {
    super.initState();

    sortedWidgetGeolocStateList = widget.geolocStateList
      ..sort(
          (GeolocModel a, GeolocModel b) => '${a.year}-${a.month}-${a.day}'.compareTo('${b.year}-${b.month}-${b.day}'))
      ..sort((GeolocModel a, GeolocModel b) => a.time.compareTo(b.time));

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        setState(() => isLoading = true);

        // ignore: always_specify_types
        Future.delayed(
          const Duration(seconds: 2),
          () {
            setDefaultBoundsMap();

            setState(() => isLoading = false);
          },
        );
      },
    );
  }

  ///
  @override
  Widget build(BuildContext context) {
    makeMinMaxLatLng();

    makeMarker();

    return Scaffold(
        body: Stack(
      children: <Widget>[
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: (sortedWidgetGeolocStateList.isNotEmpty)
                ? LatLng(sortedWidgetGeolocStateList[0].latitude.toDouble(),
                    sortedWidgetGeolocStateList[0].longitude.toDouble())
                : const LatLng(35.718532, 139.586639),
            initialZoom: currentZoomEightTeen,
            onPositionChanged: (MapCamera position, bool isMoving) {
              if (isMoving) {
                appParamNotifier.setCurrentZoom(zoom: position.zoom);
              }
            },
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              tileProvider: CachedTileProvider(),
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(markers: markerList)
          ],
        ),
        if (isLoading) ...<Widget>[const Center(child: CircularProgressIndicator())],
      ],
    ));
  }

  ///
  void makeMinMaxLatLng() {
    latList = <double>[];

    lngList = <double>[];

    for (final GeolocModel element in sortedWidgetGeolocStateList) {
      latList.add(element.latitude.toDouble());
      lngList.add(element.longitude.toDouble());
    }

    if (latList.isNotEmpty && lngList.isNotEmpty) {
      minLat = latList.reduce(min);
      maxLat = latList.reduce(max);
      minLng = lngList.reduce(min);
      maxLng = lngList.reduce(max);
    }
  }

  ///
  void setDefaultBoundsMap() {
    if (sortedWidgetGeolocStateList.length > 1) {
      final LatLngBounds bounds = LatLngBounds.fromPoints(<LatLng>[LatLng(minLat, maxLng), LatLng(maxLat, minLng)]);

      final CameraFit cameraFit =
          CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(appParamState.currentPaddingIndex * 10));

      mapController.fitCamera(cameraFit);

      /// これは残しておく
      // final LatLng newCenter = mapController.camera.center;

      final double newZoom = mapController.camera.zoom;

      setState(() => currentZoom = newZoom);

      appParamNotifier.setCurrentZoom(zoom: newZoom);
    }
  }

  ///
  void makeMarker() {
    markerList = <Marker>[];

    for (final GeolocModel element in sortedWidgetGeolocStateList) {
      markerList.add(Marker(
          point: LatLng(element.latitude.toDouble(), element.longitude.toDouble()),
          child: Icon(
            Icons.ac_unit,
            color: Colors.redAccent.withValues(alpha: 0.3),
          )));
    }
  }
}
