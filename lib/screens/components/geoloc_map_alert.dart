import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/controllers_mixin.dart';
import '../../controllers/lat_lng_address/lat_lng_address.dart';
import '../../enums/map_type.dart';
import '../../extensions/extensions.dart';
import '../../mixin/geoloc_map_control_panel/geoloc_map_control_panel_widget.dart';
import '../../models/geoloc_model.dart';
import '../../models/lat_lng_address.dart';
import '../../models/temple_latlng_model.dart';
import '../../models/temple_photo_model.dart';
import '../../models/walk_record_model.dart';
import '../../utilities/functions.dart';
import '../../utilities/tile_provider.dart';
import '../../utilities/utilities.dart';
import '../parts/button_error_overlay.dart';
import '../parts/error_dialog.dart';
import '../parts/geoloc_overlay.dart';
import '../parts/icon_fadeout_overlay.dart';

class GeolocMapAlert extends ConsumerStatefulWidget {
  const GeolocMapAlert({
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
  ConsumerState<GeolocMapAlert> createState() => _GeolocMapAlertState();
}

class _GeolocMapAlertState extends ConsumerState<GeolocMapAlert> with ControllersMixin<GeolocMapAlert> {
  List<double> latList = <double>[];
  List<double> lngList = <double>[];

  double minLat = 0.0;
  double maxLat = 0.0;
  double minLng = 0.0;
  double maxLng = 0.0;

  final MapController mapController = MapController();

  List<Marker> markerList = <Marker>[];

  late ScrollController scrollController;

  List<GeolocModel> polylineGeolocList = <GeolocModel>[];

  Map<String, List<String>> selectedHourMap = <String, List<String>>{};

  double? currentZoom;

  double currentZoomEightTeen = 18;

  final double circleRadiusMeters = 100.0;

  bool isLoading = false;

  List<LatLng> latLngList = <LatLng>[];

  final List<LatLng> tappedPoints = <LatLng>[];

  List<LatLng> enclosedMarkers = <LatLng>[];

  Map<String, GeolocModel> latLngGeolocModelMap = <String, GeolocModel>{};

  Map<String, List<TemplePhotoModel>> templePhotoDateMap = <String, List<TemplePhotoModel>>{};

  List<GeolocModel> gStateList = <GeolocModel>[];

  Set<LatLng> emphasisMarkers = <LatLng>{};

  Map<LatLng, int> emphasisMarkersIndices = <LatLng, int>{};

  List<GeolocModel> emphasisMarkersPositions = <GeolocModel>[];

  List<GlobalKey> globalKeyList = <GlobalKey>[];

  final List<OverlayEntry> _secondEntries = <OverlayEntry>[];

  List<GeolocModel> sortedWidgetGeolocStateList = <GeolocModel>[];

  DateTime recordStartDate = DateTime(2023, 4);

  List<TempleInfoModel>? monthDaysTempleInfoList = <TempleInfoModel>[];

  List<TemplePhotoModel>? monthDaysTemplePhotoDateList = <TemplePhotoModel>[];

  String? monthDaysDateStr;

  final GlobalKey monthDaysPageViewKey = GlobalKey();

  Utility utility = Utility();

  List<Color> fortyEightColor = <Color>[];

  List<Marker> displayGhostGeolocDateList = <Marker>[];

  bool firstDisplayFinished = false;

  GeolocModel? geolocStateListFirstRecord;

  LatLng? _fixedCenter;

  int _markerCacheKey = 0;
  int _ghostCacheKey = 0;

  ///
  @override
  void initState() {
    super.initState();

    /// ここは widget.displayMonthMap を使う
    if (widget.displayMonthMap) {
      geolocNotifier.getAllGeoloc();
    }

    scrollController = ScrollController();

    // ignore: always_specify_types
    globalKeyList = List.generate(1000, (int index) => GlobalKey());

    sortedWidgetGeolocStateList = <GeolocModel>[...widget.geolocStateList]..sort((GeolocModel a, GeolocModel b) {
        final int d = '${a.year}-${a.month}-${a.day}'.compareTo('${b.year}-${b.month}-${b.day}');
        if (d != 0) {
          return d;
        }
        return a.time.compareTo(b.time);
      });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        setState(() => isLoading = true);

        // ignore: use_if_null_to_convert_nulls_to_bools
        if (widget.monthDaysFirstDateTempleExists == true) {
          iconFadeoutOverlay(
            context: context,
            targetKey: monthDaysPageViewKey,
            icon: const Icon(FontAwesomeIcons.toriiGate),
            overlayWidth: 40,
          );
        }

        // ignore: always_specify_types
        Future.delayed(
          const Duration(seconds: 2),
          () {
            if (!mounted) {
              return;
            }

            _rebuildDerivedState();

            setState(() => isLoading = false);
          },
        );
      },
    );
  }

  ///
  @override
  void didUpdateWidget(covariant GeolocMapAlert oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.geolocStateList, widget.geolocStateList) ||
        oldWidget.date != widget.date ||
        oldWidget.displayMonthMap != widget.displayMonthMap ||
        oldWidget.templeGeolocNearlyDateList != widget.templeGeolocNearlyDateList) {
      firstDisplayFinished = false;
      _rebuildDerivedState();
    }
  }

  ///
  @override
  void dispose() {
    scrollController.dispose();

    super.dispose();
  }

  ///
  @override
  Widget build(BuildContext context) {
    polylineGeolocList = (!appParamState.isMarkerShow) ? gStateList : <GeolocModel>[];
    polylineGeolocList.sort((GeolocModel a, GeolocModel b) => a.time.compareTo(b.time));

    if (appParamState.polylineGeolocModel != null) {
      makePolylineGeolocList(geoloc: appParamState.polylineGeolocModel!);
    }

    if (templePhotoState.templePhotoDateMap.value != null) {
      templePhotoDateMap = templePhotoState.templePhotoDateMap.value!;
    }

    if (fortyEightColor.isEmpty) {
      fortyEightColor = utility.getFortyEightColor();
    }

    final LatLng centerForCircle = _fixedCenter ?? _calcDefaultCenter();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        final Size mapSize = Size(constraints.maxWidth, constraints.maxHeight);

        final List<LatLng> circlePoints = (appParamState.selectedRadiusKm == 0)
            ? <LatLng>[]
            : buildCirclePolygonPoints(
                center: centerForCircle,
                radiusMeters: appParamState.selectedRadiusKm * 1000,
                sides: 90,
              );

        return Stack(
          children: <Widget>[
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: (gStateList.isNotEmpty)
                    ? LatLng(gStateList[0].latitude.toDouble(), gStateList[0].longitude.toDouble())
                    : const LatLng(35.718532, 139.586639),
                initialZoom: currentZoomEightTeen,
                onPositionChanged: (MapCamera position, bool isMoving) {
                  if (isMoving) {
                    appParamNotifier.setCurrentZoom(zoom: position.zoom);
                  }
                },
                onTap: (TapPosition tapPosition, LatLng latlng) => setState(() => tappedPoints.add(latlng)),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: CachedTileProvider(),
                  userAgentPackageName: 'com.example.app',
                ),

                if (appParamState.selectedRadiusKm != 0) ...<Widget>[
                  // ignore: always_specify_types
                  PolygonLayer(
                    polygons: <Polygon<Object>>[
                      // ignore: always_specify_types
                      Polygon(
                        points: circlePoints,
                        color: Colors.blue.withOpacity(0.12),
                        borderColor: Colors.blue.withOpacity(0.6),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ],

                if (appParamState.keepAllPolygonsList.isNotEmpty) ...<Widget>[
                  // ignore: always_specify_types
                  PolygonLayer(
                    polygons: makeAreaPolygons(
                      allPolygonsList: appParamState.keepAllPolygonsList,
                      fortyEightColor: fortyEightColor,
                    ),
                  ),
                ],

                if (appParamState.isMarkerShow) ...<Widget>[MarkerLayer(markers: markerList)],

                if (!appParamState.isMarkerShow) ...<Widget>[
                  if ((appParamState.mapType == MapType.daily || appParamState.mapType == MapType.monthly) &&
                      widget.polylineModeAsTempleVisitedDate == false) ...<Widget>[
                    // ignore: always_specify_types
                    PolylineLayer(
                      polylines: <Polyline<Object>>[
                        // ignore: always_specify_types
                        Polyline(
                          points: sortedWidgetGeolocStateList
                              .map((GeolocModel e) => LatLng(e.latitude.toDouble(), e.longitude.toDouble()))
                              .toList(),
                          color: Colors.redAccent,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  ],
                ],

                // ignore: always_specify_types
                PolylineLayer(
                  polylines: <Polyline<Object>>[
                    // ignore: always_specify_types
                    Polyline(
                      points: polylineGeolocList
                          .map((GeolocModel e) => LatLng(e.latitude.toDouble(), e.longitude.toDouble()))
                          .toList(),
                      color: Colors.orangeAccent,
                      strokeWidth: 5,
                    ),
                  ],
                ),

                if (appParamState.isTempleCircleShow && appParamState.currentCenter != null) ...<Widget>[
                  // ignore: always_specify_types
                  PolygonLayer(
                    polygons: <Polygon<Object>>[
                      // ignore: always_specify_types
                      Polygon(
                        points: calculateCirclePoints(appParamState.currentCenter!, circleRadiusMeters),
                        color: Colors.redAccent.withOpacity(0.1),
                        borderStrokeWidth: 2.0,
                        borderColor: Colors.redAccent.withOpacity(0.5),
                      ),
                    ],
                  ),
                ],

                if (tappedPoints.isNotEmpty) ...<Widget>[
                  MarkerLayer(
                    markers: tappedPoints
                        .map(
                          (LatLng point) => Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.circle, size: 20, color: Colors.purple),
                          ),
                        )
                        .toList(),
                  ),
                ],

                if (tappedPoints.isNotEmpty) ...<Widget>[
                  // ignore: always_specify_types
                  PolygonLayer(
                    polygons: <Polygon<Object>>[
                      // ignore: always_specify_types
                      Polygon(
                        points: tappedPoints,
                        color: Colors.purple.withOpacity(0.1),
                        borderColor: Colors.purple,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ],

                if (widget.templeGeolocNearlyDateList != null &&
                    widget.templeGeolocNearlyDateList!.isNotEmpty &&
                    appParamState.isDisplayGhostGeolocPolyline) ...<Widget>[
                  // ignore: always_specify_types
                  PolylineLayer(polylines: makeGhostGeolocPolyline()),
                  MarkerLayer(markers: displayGhostGeolocDateList),
                ],
              ],
            ),

            ////////------------------------

            displayMapStackPartsUpper(mapSize: mapSize),

            ///////

            if (enclosedMarkers.isNotEmpty) ...<Widget>[displayMapStackPartsEnclosedMarkersInfo()],

            //////

            if (appParamState.mapType == MapType.monthly) ...<Widget>[displayMapStackPartsMonthBottom()],

            /////

            if (appParamState.mapType == MapType.daily) ...<Widget>[
              if (appParamState.selectedTimeGeoloc != null) ...<Widget>[
                Positioned(top: 150, child: displayMapStackPartsLatLngAddress())
              ],
            ],

            /////

            if (gStateList.isEmpty) ...<Widget>[
              Center(child: Icon(Icons.do_not_disturb_alt, color: Colors.redAccent.withOpacity(0.3), size: 200))
            ],

            /////

            if (isLoading) ...<Widget>[const Center(child: CircularProgressIndicator())],
          ],
        );
      }),
    );
  }

  int recordAdjustDayNum = 0;

  ///
  Widget displayMapStackPartsUpper({required Size mapSize}) {
    int monthEnd = 0;
    if (appParamState.mapType == MapType.monthDays) {
      monthEnd = DateTime(widget.date.year, widget.date.month + 1, 0).day;
    }

    if (geolocStateListFirstRecord != null) {
      if (widget.date.yyyymm == '${geolocStateListFirstRecord!.year}-${geolocStateListFirstRecord!.month}') {
        recordAdjustDayNum = geolocStateListFirstRecord!.day.toInt() - 1;
      }
    }

    if (widget.date.yyyymm == DateTime.now().yyyymm) {
      recordAdjustDayNum = 0;
    }

    return Positioned(
      top: 5,
      right: 5,
      left: 5,
      child: Column(
        children: <Widget>[
          Container(
            width: context.screenSize.width,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text((appParamState.mapType == MapType.daily) ? widget.date.yyyymmdd : widget.date.yyyymm,
                        style: const TextStyle(fontSize: 20)),
                    if (appParamState.selectedTimeGeoloc != null) ...<Widget>[
                      Text(appParamState.selectedTimeGeoloc!.time, style: const TextStyle(fontSize: 20)),
                    ],
                    if (appParamState.selectedTimeGeoloc == null) ...<Widget>[
                      const SizedBox.shrink(),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const SizedBox.shrink(),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.3))),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      const SizedBox(width: 70, child: Text('size: ')),
                                      Expanded(
                                        child: Container(
                                          alignment: Alignment.topRight,
                                          child: Text(appParamState.currentZoom.toStringAsFixed(2),
                                              style: const TextStyle(fontSize: 20)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.3)))),
                                  child: Row(
                                    children: <Widget>[
                                      const SizedBox(width: 70, child: Text('padding: ')),
                                      Expanded(
                                        child: Container(
                                          alignment: Alignment.topRight,
                                          child: Text(
                                            '${appParamState.currentPaddingIndex * 10} px',
                                            style: const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.templeGeolocNearlyDateList != null &&
                              widget.templeGeolocNearlyDateList!.isNotEmpty) ...<Widget>[
                            const SizedBox(width: 20),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (appParamState.isDisplayGhostGeolocPolyline)
                                    ? Colors.yellowAccent.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  appParamNotifier.setIsDisplayGhostGeolocPolyline(
                                    flag: !appParamState.isDisplayGhostGeolocPolyline,
                                  );

                                  _rebuildGhostMarkersIfNeeded();
                                },
                                child: const Stack(
                                  children: <Widget>[
                                    Positioned(
                                      bottom: 0,
                                      child: Text('ghost', style: TextStyle(color: Colors.yellowAccent, fontSize: 8)),
                                    ),
                                    Icon(Icons.stacked_line_chart),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (appParamState.mapType == MapType.daily ||
                              appParamState.mapType == MapType.monthDays) ...<Widget>[
                            const SizedBox(width: 20),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                              child: IconButton(
                                onPressed: () {
                                  appParamNotifier.setTimeGeolocDisplay(start: -1, end: 23);

                                  appParamNotifier.setSecondOverlayParams(secondEntries: _secondEntries);

                                  List<TempleInfoModel>? templeInfoList = widget.templeInfoList;
                                  if (appParamState.mapType == MapType.monthDays) {
                                    /// MapType.monthDaysで開いた直後はnull（X月1日）
                                    templeInfoList =
                                        (monthDaysDateStr == null) ? widget.templeInfoList : monthDaysTempleInfoList;
                                  }

                                  List<TemplePhotoModel> templePhotoDateList =
                                      templePhotoDateMap[widget.date.yyyymmdd] ?? <TemplePhotoModel>[];
                                  if (appParamState.mapType == MapType.monthDays) {
                                    /// MapType.monthDaysで開いた直後はnull（X月1日）
                                    if (monthDaysDateStr == null) {
                                      templePhotoDateList =
                                          templePhotoDateMap['${widget.date.year}-${widget.date.month}-01'] ??
                                              <TemplePhotoModel>[];
                                    } else {
                                      templePhotoDateList = monthDaysTemplePhotoDateList ?? <TemplePhotoModel>[];
                                    }
                                  }

                                  if (appParamState.mapType == MapType.daily) {
                                    appParamNotifier.setMapControlDisplayDate(date: widget.date.yyyymmdd);
                                  } else if (appParamState.mapType == MapType.monthDays) {
                                    if (monthDaysDateStr == null) {
                                      appParamNotifier.setMapControlDisplayDate(
                                          date:
                                              '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-01');
                                    } else {
                                      appParamNotifier.setMapControlDisplayDate(date: monthDaysDateStr!);
                                    }
                                  }

                                  addSecondOverlay(
                                    context: context,
                                    secondEntries: _secondEntries,
                                    setStateCallback: setState,
                                    width: context.screenSize.width,
                                    height: context.screenSize.height * 0.4,
                                    color: Colors.blueGrey.withOpacity(0.3),
                                    initialPosition: Offset(0, context.screenSize.height * 0.6),
                                    widget: GeolocMapControlPanelWidget(
                                      date: widget.date,
                                      geolocStateList: gStateList,
                                      templeInfoList: templeInfoList,
                                      mapController: mapController,
                                      currentZoomEightTeen: currentZoomEightTeen,
                                      selectedHourMap: selectedHourMap,
                                      minMaxLatLngMap: <String, double>{
                                        'minLat': minLat,
                                        'maxLng': maxLng,
                                        'maxLat': maxLat,
                                        'minLng': minLng,
                                      },
                                      displayTempMap: widget.displayTempMap,
                                      templePhotoDateList: templePhotoDateList,
                                    ),
                                    onPositionChanged: (Offset newPos) =>
                                        appParamNotifier.updateOverlayPosition(newPos),
                                    fixedFlag: true,
                                  );
                                },
                                icon: const Icon(Icons.info),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              //:::::::::::::::::::::::::::::::::::::::::::::::::://

              if (appParamState.mapType == MapType.daily) ...<Widget>[
                if (widget.walkRecord.step != 0 && widget.walkRecord.distance != 0) ...<Widget>[
                  Text(
                    'step: ${widget.walkRecord.step} / distance: ${widget.walkRecord.distance}',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ],
                if (widget.walkRecord.step == 0 || widget.walkRecord.distance == 0) ...<Widget>[
                  const SizedBox.shrink()
                ],
              ],
              if (appParamState.mapType == MapType.monthly || appParamState.mapType == MapType.monthDays) ...<Widget>[
                const SizedBox.shrink()
              ],

              //:::::::::::::::::::::::::::::::::::::::::::::::::://

              Text(
                gStateList.length.toString(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),

              //:::::::::::::::::::::::::::::::::::::::::::::::::://
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              //:::::::::::::::::::::::::::::::::::::::::::::::::://

              Container(
                decoration:
                    BoxDecoration(color: Colors.purpleAccent.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: <Widget>[
                    IconButton(
                        onPressed: () => _findEnclosedMarkers(), icon: const Icon(Icons.list, color: Colors.purple)),
                    IconButton(onPressed: () => _clearPolygon(), icon: const Icon(Icons.clear, color: Colors.purple)),
                  ],
                ),
              ),

              //:::::::::::::::::::::::::::::::::::::::::::::::::://

              if (appParamState.mapType == MapType.daily) ...<Widget>[
                Container(
                  decoration:
                      BoxDecoration(color: Colors.redAccent.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                          onPressed: () => restrictionAreaMarkerEmphasis(),
                          icon: const Icon(Icons.check_box, color: Colors.red)),
                      IconButton(
                          onPressed: () => displayEmphasisMarkersList(),
                          icon: const Icon(Icons.list, color: Colors.red)),
                      IconButton(
                        onPressed: () => setState(
                          () {
                            emphasisMarkers.clear();
                            emphasisMarkersIndices.clear();
                            _rebuildMarkersIfNeeded();
                          },
                        ),
                        icon: const Icon(Icons.clear, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],

              if (appParamState.mapType == MapType.monthly) ...<Widget>[const SizedBox.shrink()],

              if (appParamState.mapType == MapType.monthDays) ...<Widget>[
                SizedBox(
                  key: monthDaysPageViewKey,
                  width: 60,
                  height: 60,
                  child: PageView.builder(
                    itemCount: (widget.date.yyyymm == DateTime.now().yyyymm)
                        ? DateTime.now().day
                        : monthEnd - recordAdjustDayNum,
                    scrollDirection: Axis.vertical,
                    onPageChanged: (int index) => updateGStateListWhenMonthDays(day: index + 1 + recordAdjustDayNum),
                    itemBuilder: (BuildContext context, int index) {
                      final String youbi =
                          DateTime(widget.date.year, widget.date.month, index + 1 + recordAdjustDayNum).youbiStr;

                      return CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.3),
                        child: Text(
                          '${index + 1 + recordAdjustDayNum} ${youbi.substring(0, 3)}',
                          style: const TextStyle(fontSize: 12, color: Colors.black),
                        ),
                      );
                    },
                  ),
                ),
              ],

              //:::::::::::::::::::::::::::::::::::::::::::::::::://
            ],
          ),
          if (widget.displayTempMap ?? false) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const SizedBox.shrink(),
                Row(
                    children: <int>[1, 2, 3, 4, 5]
                        .map((int e) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: GestureDetector(
                                onTap: () {
                                  _fixedCenter = _calcDefaultCenter();

                                  appParamNotifier.setSelectedRadiusKm(radius: e);

                                  setRadiusZoom(mapSize, e);
                                },
                                child: CircleAvatar(
                                  backgroundColor: (appParamState.selectedRadiusKm == e)
                                      ? Colors.yellowAccent.withOpacity(0.2)
                                      : Colors.black.withOpacity(0.2),
                                  radius: 15,
                                  child: Text(
                                    e.toString(),
                                    style: TextStyle(
                                        fontSize: 8,
                                        color: (appParamState.selectedRadiusKm == e) ? Colors.black : Colors.white),
                                  ),
                                ),
                              ),
                            ))
                        .toList())
              ],
            )
          ],
        ],
      ),
    );
  }

  ///
  void _rebuildDerivedState() {
    if (!mounted) {
      return;
    }

    setState(() {
      sortedWidgetGeolocStateList = <GeolocModel>[...widget.geolocStateList]..sort((GeolocModel a, GeolocModel b) {
          final int d = '${a.year}-${a.month}-${a.day}'.compareTo('${b.year}-${b.month}-${b.day}');
          if (d != 0) {
            return d;
          }
          return a.time.compareTo(b.time);
        });

      _rebuildGStateListForCurrentMode();

      makeSelectedHourMap();
      makeMinMaxLatLng();

      _fixedCenter = _calcDefaultCenter();

      fortyEightColor = utility.getFortyEightColor();

      _rebuildMarkersIfNeeded();
      _rebuildGhostMarkersIfNeeded();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setDefaultBoundsMap();
    });
  }

  ///
  void _rebuildGStateListForCurrentMode() {
    if (appParamState.mapType == MapType.daily || appParamState.mapType == MapType.monthly) {
      gStateList = <GeolocModel>[...sortedWidgetGeolocStateList];
      firstDisplayFinished = true;
      return;
    }

    if (sortedWidgetGeolocStateList.isEmpty) {
      gStateList = <GeolocModel>[];
      firstDisplayFinished = true;
      return;
    }

    if (widget.date.yyyymm == recordStartDate.yyyymm) {
      geolocStateListFirstRecord = sortedWidgetGeolocStateList.first;

      final String target = DateTime(
        geolocStateListFirstRecord!.year.toInt(),
        geolocStateListFirstRecord!.month.toInt(),
        geolocStateListFirstRecord!.day.toInt(),
      ).yyyymmdd;

      gStateList =
          sortedWidgetGeolocStateList.where((GeolocModel e) => '${e.year}-${e.month}-${e.day}' == target).toList();
    } else {
      final String target = DateTime(widget.date.year, widget.date.month).yyyymmdd;
      gStateList =
          sortedWidgetGeolocStateList.where((GeolocModel e) => '${e.year}-${e.month}-${e.day}' == target).toList();
    }

    gStateList.sort((GeolocModel a, GeolocModel b) {
      final int d = '${a.year}-${a.month}-${a.day}'.compareTo('${b.year}-${b.month}-${b.day}');
      if (d != 0) {
        return d;
      }
      return a.time.compareTo(b.time);
    });

    firstDisplayFinished = true;
  }

  ///
  LatLng _calcDefaultCenter() {
    if (gStateList.isNotEmpty) {
      return LatLng(gStateList.last.latitude.toDouble(), gStateList.last.longitude.toDouble());
    }
    return const LatLng(35.718532, 139.586639);
  }

  ///
  void _rebuildMarkersIfNeeded() {
    final int key = Object.hash(
      gStateList.length,
      appParamState.mapType,
      appParamState.selectedTimeGeoloc?.time,
      appParamState.isMarkerShow,
      emphasisMarkers.length,
      emphasisMarkersIndices.length,
      // ignore: use_if_null_to_convert_nulls_to_bools
      widget.displayTempMap == true,
    );

    if (key == _markerCacheKey) {
      return;
    }
    _markerCacheKey = key;

    makeMarker();
  }

  ///
  void _rebuildGhostMarkersIfNeeded() {
    final int key = Object.hash(
      widget.templeGeolocNearlyDateList?.length ?? 0,
      appParamState.isDisplayGhostGeolocPolyline,
      fortyEightColor.length,
    );

    if (key == _ghostCacheKey) {
      return;
    }
    _ghostCacheKey = key;

    makeDisplayGhostGeolocDateMarker();
  }

  ///
  void setRadiusZoom(Size mapSize, int e) {
    final LatLng center = _fixedCenter ?? _calcDefaultCenter();

    final double radiusMeters = e * 1000;

    final double radiusPx = min(mapSize.width, mapSize.height) / 2;

    final double latRad = center.latitude * pi / 180;

    final double numerator = 156543.03392 * cos(latRad) * radiusPx;
    final double zoom = log(numerator / radiusMeters) / ln2;

    mapController.moveAndRotate(center, zoom.clamp(1.0, 19.0), 0.0);
  }

  ///
  void updateGStateListWhenMonthDays({required int day}) {
    setState(
      () {
        monthDaysDateStr = DateTime(widget.date.year, widget.date.month, day).yyyymmdd;

        gStateList = sortedWidgetGeolocStateList
            .where((GeolocModel element) => '${element.year}-${element.month}-${element.day}' == monthDaysDateStr)
            .toList();

        monthDaysTempleInfoList = templeState.templeInfoMap[monthDaysDateStr];

        monthDaysTemplePhotoDateList = templePhotoDateMap[monthDaysDateStr];

        _fixedCenter = _calcDefaultCenter();

        makeSelectedHourMap();
        makeMinMaxLatLng();

        _rebuildMarkersIfNeeded();
        _rebuildGhostMarkersIfNeeded();
      },
    );

    if (monthDaysTempleInfoList != null) {
      iconFadeoutOverlay(
        context: context,
        targetKey: monthDaysPageViewKey,
        icon: const Icon(FontAwesomeIcons.toriiGate),
        overlayWidth: 40,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setDefaultBoundsMap();
    });
  }

  ///
  Widget displayMapStackPartsEnclosedMarkersInfo() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        height: context.screenSize.height * 0.3,
        child: displayInnerPolygonTime(),
      ),
    );
  }

  ///
  Widget displayMapStackPartsMonthBottom() {
    return Positioned(
      bottom: 0,
      child: Stack(
        children: <Widget>[
          SizedBox(
            width: context.screenSize.width,
            child: Row(
              // ignore: always_specify_types
              children: List.generate(2, (int index) => index).map(
                (int e) {
                  final String blockYm = DateTime(
                    widget.date.yyyymmdd.split('-')[0].toInt(),
                    widget.date.yyyymmdd.split('-')[1].toInt() - (e + 1),
                  ).yyyymm;

                  return GestureDetector(
                    onTap: () {
                      if (e == 0) {
                        if (appParamState.monthGeolocAddMonthButtonLabelList.length == 2) {
                          showButtonErrorOverlay(
                            context: context,
                            buttonKey: globalKeyList[e],
                            message: '途中月の消去はできません。',
                            displayDuration: const Duration(seconds: 2),
                          );

                          return;
                        }
                      }

                      if (e == 1) {
                        if (appParamState.monthGeolocAddMonthButtonLabelList.isEmpty) {
                          showButtonErrorOverlay(
                            context: context,
                            buttonKey: globalKeyList[e],
                            message: '飛び月の追加はできません。',
                            displayDuration: const Duration(seconds: 2),
                          );

                          return;
                        }
                      }

                      appParamNotifier.setMonthGeolocAddMonthButtonLabelList(str: blockYm);

                      setState(() => firstDisplayFinished = false);

                      _rebuildDerivedState();
                    },
                    child: Container(
                      key: globalKeyList[e],
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: (appParamState.monthGeolocAddMonthButtonLabelList.contains(blockYm))
                            ? Colors.redAccent.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 10),
                          Text('-${e + 1}month', style: const TextStyle(fontSize: 10)),
                          const SizedBox(height: 5),
                          Text(blockYm),
                        ],
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
          ),
          Positioned(
            top: 10,
            right: context.screenSize.width * 0.2,
            child: Container(
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              child: IconButton(
                onPressed: () {
                  mapController.rotate(0);

                  setDefaultBoundsMap();
                },
                icon: const Icon(FontAwesomeIcons.expand),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ///
  void restrictionAreaMarkerEmphasis() {
    final LatLngBounds bounds = mapController.camera.visibleBounds;

    final Set<LatLng> set = <LatLng>{};

    for (final GeolocModel pos in gStateList) {
      if (bounds.contains(LatLng(pos.latitude.toDouble(), pos.longitude.toDouble()))) {
        set.add(LatLng(pos.latitude.toDouble(), pos.longitude.toDouble()));
      }
    }

    if (set.length > 20) {
      // ignore: always_specify_types
      Future.delayed(
        Duration.zero,
        () => error_dialog(
          // ignore: use_build_context_synchronously
          context: context,
          title: '処理続行不可',
          content: 'ピックアップされたマーカーが多すぎます。',
        ),
      );

      return;
    }

    final List<LatLng> list = <LatLng>[...set];

    final Map<String, LatLng> map = <String, LatLng>{};

    final List<String> list2 = <String>[];

    final Map<LatLng, int> map2 = <LatLng, int>{};

    for (final LatLng element in list) {
      for (final GeolocModel element2 in gStateList) {
        if (element.latitude == element2.latitude.toDouble() && element.longitude == element2.longitude.toDouble()) {
          list2.add('${element2.year}-${element2.month}-${element2.day} ${element2.time}');

          map['${element2.year}-${element2.month}-${element2.day} ${element2.time}'] = element;
        }
      }
    }

    int i = 0;

    list2
      ..sort((String a, String b) => a.compareTo(b))
      ..forEach(
        (String element) {
          if (map[element] != null) {
            map2[map[element]!] = i + 1;

            i++;
          }
        },
      );

    setState(
      () {
        emphasisMarkers = set;

        emphasisMarkersIndices = map2;

        _rebuildMarkersIfNeeded();
      },
    );
  }

  ///
  void displayEmphasisMarkersList() {
    final LatLngBounds bounds = mapController.camera.visibleBounds;

    emphasisMarkersPositions = gStateList
        .where((GeolocModel geolocModel) =>
            bounds.contains(LatLng(geolocModel.latitude.toDouble(), geolocModel.longitude.toDouble())))
        .toList();

    // ignore: inference_failure_on_function_invocation
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('可視範囲のマーカー座標'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: emphasisMarkersPositions.map((GeolocModel geolocModel) => Text(geolocModel.time)).toList(),
          ),
        ),
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))],
      ),
    );
  }

  ///
  void makeSelectedHourMap() {
    selectedHourMap = <String, List<String>>{};

    for (final GeolocModel element in gStateList) {
      (selectedHourMap[element.time.split(':')[0]] ??= <String>[]).add(element.time);
    }
  }

  ///
  void makeMinMaxLatLng() {
    latList = <double>[];
    lngList = <double>[];
    latLngList = <LatLng>[];
    latLngGeolocModelMap = <String, GeolocModel>{};

    final List<GeolocModel> effectiveList = <GeolocModel>[...gStateList];

    if (appParamState.monthGeolocAddMonthButtonLabelList.isNotEmpty) {
      for (final String ym in appParamState.monthGeolocAddMonthButtonLabelList) {
        for (final GeolocModel e in geolocState.allGeolocList) {
          if ('${e.year}-${e.month}' == ym) {
            effectiveList.add(e);
          }
        }
      }
    }

    for (final GeolocModel element in effectiveList) {
      final double lat = element.latitude.toDouble();
      final double lng = element.longitude.toDouble();

      latList.add(lat);
      lngList.add(lng);

      final LatLng latlng = LatLng(lat, lng);
      latLngList.add(latlng);

      latLngGeolocModelMap['${latlng.latitude}|${latlng.longitude}'] = element;
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
    if (gStateList.length > 1) {
      if (appParamState.mapType == MapType.monthDays) {
        final List<double> monthDaysLatList = <double>[];
        final List<double> monthDaysLngList = <double>[];

        for (final GeolocModel element in gStateList) {
          monthDaysLatList.add(element.latitude.toDouble());
          monthDaysLngList.add(element.longitude.toDouble());
        }

        minLat = monthDaysLatList.reduce(min);
        maxLat = monthDaysLatList.reduce(max);
        minLng = monthDaysLngList.reduce(min);
        maxLng = monthDaysLngList.reduce(max);
      }

      final LatLngBounds bounds = LatLngBounds.fromPoints(<LatLng>[LatLng(minLat, maxLng), LatLng(maxLat, minLng)]);

      final CameraFit cameraFit =
          CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(appParamState.currentPaddingIndex * 10));

      mapController.fitCamera(cameraFit);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final double newZoom = mapController.camera.zoom;

        setState(() => currentZoom = newZoom);

        appParamNotifier.setCurrentZoom(zoom: newZoom);
      });
    }
  }

  ///
  void makeMarker() {
    markerList = <Marker>[];

    for (final GeolocModel element in gStateList) {
      final LatLng p = LatLng(element.latitude.toDouble(), element.longitude.toDouble());

      final bool isRed = emphasisMarkers.contains(p);

      final int? badgeIndex = emphasisMarkersIndices[p];

      markerList.add(
        Marker(
          point: p,
          width: 40,
          height: 40,
          // ignore: use_if_null_to_convert_nulls_to_bools
          child: (appParamState.mapType == MapType.monthly)
              ? const Icon(Icons.ac_unit, size: 20, color: Colors.redAccent)
              : Stack(
                  children: <Widget>[
                    CircleAvatar(
                      // ignore: use_if_null_to_convert_nulls_to_bools
                      backgroundColor: isRed
                          ? Colors.redAccent.withOpacity(0.5)
                          : (appParamState.selectedTimeGeoloc != null &&
                                  appParamState.selectedTimeGeoloc!.time == element.time)
                              ? Colors.redAccent.withOpacity(0.5)

                              // ignore: use_if_null_to_convert_nulls_to_bools
                              : (widget.displayTempMap == true)
                                  ? Colors.orangeAccent.withOpacity(0.5)
                                  : Colors.green[900]?.withOpacity(0.5),
                      child: Text(element.time, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                    if (badgeIndex != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Text(badgeIndex.toString(), style: const TextStyle(fontSize: 10, color: Colors.black)),
                        ),
                      ),
                  ],
                ),
        ),
      );
    }
  }

  ///
  List<LatLng> calculateCirclePoints(LatLng center, double radiusMeters) {
    const int points = 64;

    const double earthRadius = 6378137.0;

    final double lat = center.latitude * pi / 180.0;

    final double lng = center.longitude * pi / 180.0;

    final double d = radiusMeters / earthRadius;

    final List<LatLng> circlePoints = <LatLng>[];

    for (int i = 0; i <= points; i++) {
      final double angle = 2 * pi * i / points;

      final double latOffset = asin(sin(lat) * cos(d) + cos(lat) * sin(d) * cos(angle));

      final double lngOffset = lng + atan2(sin(angle) * sin(d) * cos(lat), cos(d) - sin(lat) * sin(latOffset));

      circlePoints.add(LatLng(latOffset * 180.0 / pi, lngOffset * 180.0 / pi));
    }
    return circlePoints;
  }

  ///
  void makePolylineGeolocList({required GeolocModel geoloc}) {
    polylineGeolocList = <GeolocModel>[];

    final int pos = gStateList.indexWhere((GeolocModel element) => element.time == geoloc.time);

    if (pos > 0) {
      polylineGeolocList.add(gStateList[pos - 1]);
      polylineGeolocList.add(geoloc);
    }
  }

  ///
  void _clearPolygon() {
    setState(
      () {
        tappedPoints.clear();
        enclosedMarkers.clear();
      },
    );
  }

  ///
  void _findEnclosedMarkers() {
    if (tappedPoints.isEmpty) {
      return;
    }

    setState(() =>
        enclosedMarkers = latLngList.where((LatLng marker) => _isPointInsidePolygon(marker, tappedPoints)).toList());
  }

  ///
  bool _isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;

    for (int i = 0; i < polygon.length; i++) {
      final LatLng v1 = polygon[i];
      final LatLng v2 = polygon[(i + 1) % polygon.length];

      final bool crossesY = ((v1.latitude > point.latitude) != (v2.latitude > point.latitude));
      if (!crossesY) {
        continue;
      }

      final double dy = v2.latitude - v1.latitude;
      if (dy == 0) {
        continue;
      }

      final double xAtY = (v2.longitude - v1.longitude) * (point.latitude - v1.latitude) / dy + v1.longitude;

      if (point.longitude < xAtY) {
        intersectCount++;
      }
    }

    return intersectCount.isOdd;
  }

  ///
  Widget displayInnerPolygonTime() {
    final List<Widget> list = <Widget>[];

    final Map<String, GeolocModel> map = <String, GeolocModel>{};
    final List<String> list2 = <String>[];

    for (final LatLng element in enclosedMarkers) {
      final GeolocModel? latLngGeolocModel = latLngGeolocModelMap['${element.latitude}|${element.longitude}'];

      if (latLngGeolocModel != null) {
        final String key =
            '${latLngGeolocModel.year}-${latLngGeolocModel.month}-${latLngGeolocModel.day} ${latLngGeolocModel.time}';

        map[key] = latLngGeolocModel;

        list2.add(key);
      }
    }

    int i = 0;

    list2.toSet().toList()
      ..sort((String a, String b) => a.compareTo(b))
      ..forEach(
        (String element) {
          if (map[element] != null) {
            list.add(Text('${(i + 1).toString().padLeft(3, '0')}. $element'));

            i++;
          }
        },
      );

    return SingleChildScrollView(
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: list),
      ),
    );
  }

  ///
  Widget displayMapStackPartsLatLngAddress() {
    final AsyncValue<LatLngAddressControllerState> latLngAddressControllerState = ref.watch(
        latLngAddressControllerProvider(
            latitude: appParamState.selectedTimeGeoloc!.latitude,
            longitude: appParamState.selectedTimeGeoloc!.longitude));

    final List<LatLngAddressDetailModel>? latLngAddressList = latLngAddressControllerState.value?.latLngAddressList;

    final List<String> addressList = <String>[];
    latLngAddressList?.forEach(
        (LatLngAddressDetailModel element) => addressList.add('${element.prefecture}${element.city}${element.town}'));

    if (latLngAddressControllerState.value == null || latLngAddressList == null || addressList.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: Container(
        width: context.screenSize.width * 0.7,
        margin: const EdgeInsets.only(right: 10, left: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: addressList
                .map((String e) => Text(e, style: const TextStyle(color: Colors.black, fontSize: 12)))
                .toList(),
          ),
        ),
      ),
    );
  }

  ///
  // ignore: always_specify_types
  List<Polyline> makeGhostGeolocPolyline() {
    // ignore: always_specify_types
    final List<Polyline> polylines = <Polyline>[];

    for (int i = 0; i < widget.templeGeolocNearlyDateList!.length; i++) {
      if (templeState.templeInfoMap[widget.templeGeolocNearlyDateList![i]] != null) {
        // ignore: always_specify_types
        polylines.add(Polyline(
          points: templeState.templeInfoMap[widget.templeGeolocNearlyDateList![i]]!
              .map((TempleInfoModel t) => LatLng(t.latitude.toDouble(), t.longitude.toDouble()))
              .toList(),
          color: fortyEightColor[i % 48].withValues(alpha: 0.5),
          strokeWidth: 20,
        ));
      }
    }

    return polylines;
  }

  ///
  void makeDisplayGhostGeolocDateMarker() {
    displayGhostGeolocDateList.clear();

    if (widget.templeGeolocNearlyDateList != null) {
      for (int i = 0; i < widget.templeGeolocNearlyDateList!.length; i++) {
        if (templeState.templeInfoMap[widget.templeGeolocNearlyDateList![i]] != null) {
          int j = 0;
          for (final TempleInfoModel element in templeState.templeInfoMap[widget.templeGeolocNearlyDateList![i]]!) {
            if (j == 0) {
              displayGhostGeolocDateList.add(
                Marker(
                  point: LatLng(
                    element.latitude.toDouble(),
                    element.longitude.toDouble(),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: fortyEightColor[i % 48]),
                    ),
                    child: DefaultTextStyle(
                      style: TextStyle(color: fortyEightColor[i % 48], fontSize: 8, fontWeight: FontWeight.bold),
                      child: Column(
                        children: <Widget>[
                          const Spacer(),
                          Text(DateTime.parse(widget.templeGeolocNearlyDateList![i]).year.toString()),
                          Text(DateTime.parse(widget.templeGeolocNearlyDateList![i]).mmdd),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            j++;
          }
        }
      }
    }
  }

  ///
  List<LatLng> buildCirclePolygonPoints({required LatLng center, required double radiusMeters, int sides = 60}) {
    final double latRad = _degToRad(center.latitude);
    final double lngRad = _degToRad(center.longitude);

    const double earthRadius = 6378137.0;

    final double angularDistance = radiusMeters / earthRadius;

    final List<LatLng> points = <LatLng>[];

    for (int i = 0; i < sides; i++) {
      final double bearing = 2 * pi * (i / sides);

      final double sinLat = sin(latRad);
      final double cosLat = cos(latRad);

      final double sinAd = sin(angularDistance);
      final double cosAd = cos(angularDistance);

      final double sinLat2 = sinLat * cosAd + cosLat * sinAd * cos(bearing);
      final double lat2 = asin(sinLat2);

      final double y = sin(bearing) * sinAd * cosLat;
      final double x = cosAd - sinLat * sinLat2;
      final double lng2 = lngRad + atan2(y, x);

      points.add(LatLng(_radToDeg(lat2), _radToDeg(lng2)));
    }

    if (points.isNotEmpty) {
      points.add(points.first);
    }

    return points;
  }

  ///
  double _degToRad(double deg) => deg * pi / 180.0;

  ///
  double _radToDeg(double rad) => rad * 180.0 / pi;
}
