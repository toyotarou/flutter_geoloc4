import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/app_params/app_params.dart';
import '../../extensions/extensions.dart';
import '../../models/geoloc_model.dart';
import '../../models/temple_latlng_model.dart';
import '../../models/temple_photo_model.dart';
import '../../screens/components/temple_photo_display_alert.dart';
import '../../screens/parts/geoloc_dialog.dart';
import '../../screens/parts/geoloc_overlay.dart';
import '../../utilities/utilities.dart';
import 'geoloc_map_control_panel_widget.dart';

mixin GeolocMapControlPanelAlertMixin on ConsumerState<GeolocMapControlPanelWidget> {
  Color _bgColor = Colors.transparent;

  RangeValues currentRange = const RangeValues(0, 23);

  final List<OverlayEntry> _bigEntries = <OverlayEntry>[];
  final List<OverlayEntry> _firstEntries = <OverlayEntry>[];
  final List<OverlayEntry> _secondEntries = <OverlayEntry>[];

  Utility utility = Utility();

  int _currentIndex = 0;

  int _taskId = 0;

  late double changeZoomDuringAutoPlay;

  ///
  void mapControllerBgColorChange() {
    setState(() => _bgColor = Colors.blue.withOpacity(0.3));

    // ignore: always_specify_types
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }

      setState(() => _bgColor = Colors.transparent);
    });
  }

  ///
  Widget buildContent(BuildContext context) {
    final AppParams appParamNotifier = ref.read(appParamsProvider.notifier);
    final AppParamsState appParamState = ref.watch(appParamsProvider);

    // final List<String> timeList = <String>[];
    // for (final GeolocModel element in widget.geolocStateList) {
    //   final List<String> exTime = element.time.split(':');
    //   if (!timeList.contains(exTime[0])) {
    //     timeList.add(exTime[0]);
    //   }
    // }

    int autoPlayTimeGeolocIndex = appParamState.selectedTimeGeolocIndex;

    if (autoPlayTimeGeolocIndex == -1) {
      autoPlayTimeGeolocIndex = 0;
    }

    // ignore: always_specify_types
    final List<GlobalKey> globalKeyList = List.generate(1000, (int index) => GlobalKey());

    return ColoredBox(
      color: _bgColor,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 100,
            right: 5,
            child: Transform(
              transform: Matrix4.diagonal3Values(1.0, 3.0, 1.0),
              child: Text(
                appParamState.mapControlDisplayDate,
                style: TextStyle(fontSize: 30, color: Colors.white.withOpacity(0.3)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              /// コントロール上部のアイコンリスト
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  ///
                  Row(
                    children: <Widget>[
                      ///
                      GestureDetector(
                        onTap: () {
                          appParamNotifier.setSelectedTimeGeoloc();

                          appParamNotifier.setIsMarkerShow(flag: !appParamState.isMarkerShow);
                        },
                        child: const Icon(Icons.stacked_line_chart),
                      ),
                      const SizedBox(width: 20),

                      ///
                      GestureDetector(
                        onTap: () {
                          appParamNotifier.setIsMarkerShow(flag: true);
                          appParamNotifier.setSelectedTimeGeoloc();
                          setDefaultBoundsMap();
                        },
                        child: const Icon(Icons.center_focus_strong),
                      ),
                      const SizedBox(width: 20),

                      ///
                      GestureDetector(
                        onTap: () {
                          int pos = 0;
                          if (appParamState.selectedTimeGeoloc != null) {
                            pos = widget.geolocStateList.indexWhere(
                                (GeolocModel element) => element.time == appParamState.selectedTimeGeoloc!.time);
                          }

                          int nextPos = pos + 1;
                          if (nextPos >= widget.geolocStateList.length) {
                            nextPos = pos;
                          }

                          appParamNotifier.setIsMarkerShow(flag: true);
                          appParamNotifier.setSelectedTimeGeoloc(geoloc: widget.geolocStateList[nextPos]);

                          widget.mapController.move(
                            LatLng(
                              widget.geolocStateList[nextPos].latitude.toDouble(),
                              widget.geolocStateList[nextPos].longitude.toDouble(),
                            ),
                            appParamState.currentZoom,
                          );

                          appParamNotifier.setPolylineGeolocModel(model: widget.geolocStateList[nextPos]);

                          scrollToIndex(index: nextPos, globalKeyList: globalKeyList);
                          appParamNotifier.setSelectedTimeGeolocIndex(index: nextPos);

                          mapControllerBgColorChange();
                        },
                        child: const Icon(Icons.play_arrow),
                      ),
                      const SizedBox(width: 20),

                      ///
                      GestureDetector(
                        onTap: () async {
                          changeZoomDuringAutoPlay = appParamState.currentZoom;

                          _taskId++;
                          final int currentTaskId = _taskId;

                          setState(() => _currentIndex = 0);

                          //--------------------------------------------------------------//
                          for (int i = autoPlayTimeGeolocIndex; i < widget.geolocStateList.length; i++) {
                            // 2秒待つ間に地図を閉じた場合、破棄済みの State で setState しないように止める
                            if (!mounted || currentTaskId != _taskId) {
                              return;
                            }

                            setState(() => _currentIndex = i);

                            appParamNotifier.setIsMarkerShow(flag: true);
                            appParamNotifier.setSelectedTimeGeoloc(geoloc: widget.geolocStateList[_currentIndex]);

                            widget.mapController.move(
                              LatLng(
                                widget.geolocStateList[_currentIndex].latitude.toDouble(),
                                widget.geolocStateList[_currentIndex].longitude.toDouble(),
                              ),
                              (appParamState.currentZoom == changeZoomDuringAutoPlay)
                                  ? appParamState.currentZoom
                                  : changeZoomDuringAutoPlay,
                            );

                            appParamNotifier.setPolylineGeolocModel(model: widget.geolocStateList[_currentIndex]);

                            appParamNotifier.setSelectedTimeGeolocIndex(index: _currentIndex);

                            scrollToIndex(index: i, globalKeyList: globalKeyList);

                            if (i < widget.geolocStateList.length - 1) {
                              // ignore: inference_failure_on_instance_creation, always_specify_types
                              await Future.delayed(const Duration(seconds: 2));
                            }
                          }

                          //--------------------------------------------------------------//

                          if (!mounted) {
                            return;
                          }

                          mapControllerBgColorChange();
                        },
                        child: const Icon(Icons.double_arrow),
                      ),
                    ],
                  ),

                  ///
                  Row(
                    children: <Widget>[
                      ///
                      SizedBox(
                        width: 40,
                        child: Column(
                          children: <Widget>[
                            Text('${appParamState.selectedTimeGeolocIndex + 1}'),
                            Text(widget.geolocStateList.length.toString()),
                          ],
                        ),
                      ),

                      ///
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          // ignore: use_if_null_to_convert_nulls_to_bools
                          backgroundColor: (widget.displayTempMap == true)
                              ? Colors.orangeAccent.withOpacity(0.2)
                              : Colors.green[900]?.withOpacity(0.2),
                        ),
                        onPressed: () {
                          if (widget.geolocStateList.length == 1 || appParamState.selectedTimeGeoloc != null) {
                            appParamNotifier.setCurrentZoom(zoom: appParamState.currentZoom + 1);

                            setState(() => changeZoomDuringAutoPlay = appParamState.currentZoom + 1);

                            widget.mapController.move(
                              (appParamState.selectedTimeGeoloc == null)
                                  ? LatLng(widget.geolocStateList[0].latitude.toDouble(),
                                      widget.geolocStateList[0].longitude.toDouble())
                                  : LatLng(appParamState.selectedTimeGeoloc!.latitude.toDouble(),
                                      appParamState.selectedTimeGeoloc!.longitude.toDouble()),
                              appParamState.currentZoom + 1,
                            );
                          } else {
                            appParamNotifier.setCurrentPaddingIndex(index: appParamState.currentPaddingIndex + 1);
                            setDefaultBoundsMap();
                          }
                        },
                        child: Text(
                          (appParamState.selectedTimeGeoloc != null) ? '狭域' : '広域',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),

                      ///
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          // ignore: use_if_null_to_convert_nulls_to_bools
                          backgroundColor: (widget.displayTempMap == true)
                              ? Colors.orangeAccent.withOpacity(0.2)
                              : Colors.green[900]?.withOpacity(0.2),
                        ),
                        onPressed: () {
                          if (widget.geolocStateList.length == 1 || appParamState.selectedTimeGeoloc != null) {
                            appParamNotifier.setCurrentZoom(zoom: appParamState.currentZoom - 1);

                            setState(() => changeZoomDuringAutoPlay = appParamState.currentZoom - 1);

                            widget.mapController.move(
                              (appParamState.selectedTimeGeoloc == null)
                                  ? LatLng(widget.geolocStateList[0].latitude.toDouble(),
                                      widget.geolocStateList[0].longitude.toDouble())
                                  : LatLng(appParamState.selectedTimeGeoloc!.latitude.toDouble(),
                                      appParamState.selectedTimeGeoloc!.longitude.toDouble()),
                              appParamState.currentZoom - 1,
                            );
                          } else {
                            int index = appParamState.currentPaddingIndex - 1;
                            if (index < 1) {
                              index = 1;
                            }
                            appParamNotifier.setCurrentPaddingIndex(index: index);
                            setDefaultBoundsMap();
                          }
                        },
                        child: Text(
                          (appParamState.selectedTimeGeoloc != null) ? '広域' : '狭域',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              /// geolocのCircleAvatar
              SizedBox(
                height: 60,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.geolocStateList.map(
                      (GeolocModel e) {
                        final int pos =
                            widget.geolocStateList.indexWhere((GeolocModel element) => element.time == e.time);

                        if (appParamState.timeGeolocDisplayStart != -1 && appParamState.timeGeolocDisplayEnd != -1) {
                          final int num = int.parse(e.time.split(':')[0]);
                          if (num < appParamState.timeGeolocDisplayStart || num > appParamState.timeGeolocDisplayEnd) {
                            return const SizedBox.shrink();
                          }
                        }

                        return Padding(
                          key: globalKeyList[pos],
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: GestureDetector(
                            onTap: () {
                              appParamNotifier.setIsMarkerShow(flag: true);
                              appParamNotifier.setSelectedTimeGeoloc(geoloc: e);

                              widget.mapController.move(
                                LatLng(e.latitude.toDouble(), e.longitude.toDouble()),
                                appParamState.currentZoom,
                              );

                              appParamNotifier.setPolylineGeolocModel(model: e);

                              final int pos =
                                  widget.geolocStateList.indexWhere((GeolocModel element) => element.time == e.time);

                              appParamNotifier.setSelectedTimeGeolocIndex(index: pos);
                            },
                            child: CircleAvatar(
                              backgroundColor: (appParamState.selectedTimeGeoloc != null &&
                                      appParamState.selectedTimeGeoloc!.time == e.time)
                                  ? Colors.redAccent.withOpacity(0.5)
                                  // ignore: use_if_null_to_convert_nulls_to_bools
                                  : (widget.displayTempMap == true)
                                      ? Colors.orangeAccent.withOpacity(0.5)
                                      : Colors.green[900]?.withOpacity(0.5),
                              child: Text(e.time, style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
              ),

              /// 表示時間限定スライダー
              Row(
                children: <Widget>[
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        // ignore: use_if_null_to_convert_nulls_to_bools
                        thumbColor: (widget.displayTempMap == true)
                            ? Colors.orangeAccent.withOpacity(0.2)
                            : Colors.green[900]?.withOpacity(0.2),
                        // ignore: use_if_null_to_convert_nulls_to_bools
                        activeTrackColor: (widget.displayTempMap == true)
                            ? Colors.orangeAccent.withOpacity(0.2)
                            : Colors.green[900]?.withOpacity(0.2),
                        inactiveTrackColor: Colors.white,
                      ),
                      child: RangeSlider(
                        values: currentRange,
                        max: 23,
                        divisions: 23,
                        labels: RangeLabels(currentRange.start.round().toString(), currentRange.end.round().toString()),
                        onChanged: (RangeValues newRange) => setState(() => currentRange = newRange),
                      ),
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      // ignore: use_if_null_to_convert_nulls_to_bools
                      backgroundColor: (widget.displayTempMap == true)
                          ? Colors.orangeAccent.withOpacity(0.2)
                          : Colors.green[900]?.withOpacity(0.2),
                    ),
                    onPressed: () => appParamNotifier.setTimeGeolocDisplay(
                      start: currentRange.start.round(),
                      end: currentRange.end.round(),
                    ),
                    child: const Column(children: <Widget>[Text('set', style: TextStyle(color: Colors.white))]),
                  ),
                ],
              ),

              /// コントロールパネル下部のテンプルリスト
              if (widget.templeInfoList != null) ...<Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.templeInfoList!.map(
                      (TempleInfoModel element) {
                        return GestureDetector(
                          onTap: () {
                            appParamNotifier.setSelectedTimeGeoloc(
                              geoloc: GeolocModel(
                                id: 0,
                                year: widget.geolocStateList[0].year,
                                month: widget.geolocStateList[0].month,
                                day: widget.geolocStateList[0].day,
                                time: '',
                                latitude: element.latitude,
                                longitude: element.longitude,
                              ),
                            );

                            appParamNotifier.setCurrentZoom(zoom: 17);
                            appParamNotifier.setIsTempleCircleShow(flag: true);
                            appParamNotifier.setCurrentCenter(
                                latLng: LatLng(element.latitude.toDouble(), element.longitude.toDouble()));
                            appParamNotifier.setSelectedTemple(temple: element);
                            appParamNotifier.setTempleGeolocTimeCircleAvatarParams(
                                bigEntries: _bigEntries, setStateCallback: setState);

                            widget.mapController
                                .move(LatLng(element.latitude.toDouble(), element.longitude.toDouble()), 17);

                            TemplePhotoModel templePhoto =
                                TemplePhotoModel(date: DateTime.now(), temple: '', templephotos: <String>[]);
                            if (widget.templePhotoDateList.isNotEmpty) {
                              templePhoto = widget.templePhotoDateList.firstWhere(
                                (TemplePhotoModel element2) => element2.temple == element.temple,
                                orElse: () => templePhoto,
                              );
                            }

                            appParamNotifier.setFirstOverlayParams(firstEntries: _firstEntries);

                            addFirstOverlay(
                              context: context,
                              setStateCallback: setState,
                              width: MediaQuery.of(context).size.width * 0.3,
                              height: 230,
                              color: Colors.blueGrey.withOpacity(0.3),
                              initialPosition: Offset(MediaQuery.of(context).size.width * 0.7, 160),
                              widget: Consumer(
                                builder: (BuildContext context, WidgetRef ref, Widget? child) {
                                  return displayTempleGeolocTimeCircleAvatarList(
                                      temple: element, templephotos: templePhoto.templephotos);
                                },
                              ),
                              firstEntries: _firstEntries,
                              secondEntries: _secondEntries,
                              onPositionChanged: (Offset newPos) => appParamNotifier.updateOverlayPosition(newPos),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.all(5),
                            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 15),
                            decoration: BoxDecoration(
                              color: (appParamState.selectedTemple != null &&
                                      element.temple == appParamState.selectedTemple!.temple)
                                  ? Colors.orangeAccent.withOpacity(0.3)
                                  : Colors.redAccent.withOpacity(0.3),
                            ),
                            child: Text(element.temple, style: const TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  ///
  Future<void> scrollToIndex(
      {required int index, required List<GlobalKey<State<StatefulWidget>>> globalKeyList}) async {
    final BuildContext target = globalKeyList[index].currentContext!;
    await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 1000));
  }

  ///
  void setDefaultBoundsMap() {
    final AppParams appParamNotifier = ref.read(appParamsProvider.notifier);
    final AppParamsState appParamState = ref.watch(appParamsProvider);

    if (widget.geolocStateList.length > 1) {
      final LatLngBounds bounds = LatLngBounds.fromPoints(
        <LatLng>[
          LatLng(widget.minMaxLatLngMap['minLat']!, widget.minMaxLatLngMap['maxLng']!),
          LatLng(widget.minMaxLatLngMap['maxLat']!, widget.minMaxLatLngMap['minLng']!),
        ],
      );

      final CameraFit cameraFit =
          CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(appParamState.currentPaddingIndex * 10));

      widget.mapController.fitCamera(cameraFit);

      final double newZoom = widget.mapController.camera.zoom;
      appParamNotifier.setCurrentZoom(zoom: newZoom);
    }
  }

  ///
  Widget displayTempleGeolocTimeCircleAvatarList(
      {required TempleInfoModel temple, required List<String> templephotos}) {
    final AppParams appParamNotifier = ref.read(appParamsProvider.notifier);
    final AppParamsState appParamState = ref.watch(appParamsProvider);

    final List<Widget> list = <Widget>[];

    for (final GeolocModel element in widget.geolocStateList) {
      final double dist = utility.calculateDistance(
        LatLng(temple.latitude.toDouble(), temple.longitude.toDouble()),
        LatLng(element.latitude.toDouble(), element.longitude.toDouble()),
      );

      if (dist <= 100.0) {
        list.add(
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor:
                  (appParamState.selectedTimeGeoloc != null && appParamState.selectedTimeGeoloc!.time == element.time)
                      ? Colors.redAccent.withOpacity(0.5)
                      // ignore: use_if_null_to_convert_nulls_to_bools
                      : (widget.displayTempMap == true)
                          ? Colors.orangeAccent.withOpacity(0.2)
                          : Colors.green[900]?.withOpacity(0.2),
            ),
            onPressed: () {
              appParamNotifier.setIsMarkerShow(flag: true);
              appParamNotifier.setSelectedTimeGeoloc(
                geoloc: GeolocModel(
                  id: 0,
                  year: widget.date.yyyymmdd.split('-')[0],
                  month: widget.date.yyyymmdd.split('-')[1],
                  day: widget.date.yyyymmdd.split('-')[2],
                  time: element.time,
                  latitude: element.latitude,
                  longitude: element.longitude,
                ),
              );

              widget.mapController
                  .move(LatLng(element.latitude.toDouble(), element.longitude.toDouble()), appParamState.currentZoom);
            },
            child: Column(
              children: <Widget>[
                Text(element.time, style: const TextStyle(color: Colors.white, fontSize: 10)),
                Container(width: MediaQuery.of(context).size.width),
              ],
            ),
          ),
        );
      }
    }

    return SizedBox(
      height: 180,
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(children: list)),
            ),
          ),
          if (templephotos.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const SizedBox.shrink(),
                GestureDetector(
                  onTap: () {
                    GeolocDialog(
                      context: context,
                      widget: TemplePhotoDisplayAlert(templephotos: templephotos),
                      clearBarrierColor: true,
                    );
                  },
                  child: const Icon(Icons.photo),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
