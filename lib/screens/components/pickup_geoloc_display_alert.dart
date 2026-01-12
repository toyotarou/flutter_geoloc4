import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../collections/geoloc.dart';
import '../../controllers/controllers_mixin.dart';
import '../../enums/map_type.dart';
import '../../extensions/extensions.dart';
import '../../models/geoloc_model.dart';
import '../../models/temple_latlng_model.dart';
import '../../models/walk_record_model.dart';
import '../../utilities/utilities.dart';
import '../home_screen.dart';
import '../parts/geoloc_dialog.dart';
import 'geoloc_map_alert.dart';

class PickupGeolocDisplayAlert extends ConsumerStatefulWidget {
  const PickupGeolocDisplayAlert(
      {super.key, required this.pickupGeolocList, required this.date, required this.walkRecord, this.templeInfoMap});

  final DateTime date;
  final List<Geoloc> pickupGeolocList;
  final WalkRecordModel walkRecord;
  final List<TempleInfoModel>? templeInfoMap;

  @override
  ConsumerState<PickupGeolocDisplayAlert> createState() => _PickupGeolocDisplayAlertState();
}

class _PickupGeolocDisplayAlertState extends ConsumerState<PickupGeolocDisplayAlert>
    with ControllersMixin<PickupGeolocDisplayAlert> {
  Utility utility = Utility();

  bool isLoading = false;

  ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  Container(width: context.screenSize.width),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(widget.date.yyyymmdd),
                      Row(
                        children: <Widget>[
                          if (widget.pickupGeolocList.length > 1) ...<Widget>[
                            GestureDetector(
                              onTap: () {
                                appParamNotifier.setIsMarkerShow(flag: true);

                                appParamNotifier.setSelectedTimeGeoloc();

                                final List<GeolocModel> list = <GeolocModel>[];
                                for (final Geoloc element in widget.pickupGeolocList) {
                                  list.add(
                                    GeolocModel(
                                      id: 0,
                                      year: element.date.split('-')[0],
                                      month: element.date.split('-')[1],
                                      day: element.date.split('-')[2],
                                      time: element.time,
                                      latitude: element.latitude,
                                      longitude: element.longitude,
                                    ),
                                  );
                                }

                                appParamNotifier.setMapType(type: MapType.daily);

                                List<String> templeGeolocNearlyDateList = <String>[];
                                if (templeState.templeInfoMap.isNotEmpty) {
                                  templeGeolocNearlyDateList = utility.getTempleGeolocNearlyDateList(
                                    date: widget.date.yyyymmdd,
                                    templeInfoMap: templeState.templeInfoMap,
                                  );
                                }

                                GeolocDialog(
                                  context: context,
                                  widget: GeolocMapAlert(
                                    displayMonthMap: false,
                                    date: widget.date,
                                    geolocStateList: list,
                                    displayTempMap: true,
                                    walkRecord: widget.walkRecord,
                                    templeInfoList: widget.templeInfoMap,
                                    templeGeolocNearlyDateList: templeGeolocNearlyDateList,
                                  ),
                                  executeFunctionWhenDialogClose: true,
                                  ref: ref,
                                  from: 'PickupGeolocDisplayAlert',
                                );
                              },
                              child: const Column(
                                children: <Widget>[
                                  Text('isar'),
                                  Icon(Icons.map, color: Colors.orangeAccent),
                                  Text('map')
                                ],
                              ),
                            ),
                            const SizedBox(width: 30),
                          ],
                          GestureDetector(
                            onTap: () => _showDeleteDialog(),
                            child: const Column(
                              children: <Widget>[
                                Text('delete'),
                                Icon(Icons.delete, color: Colors.greenAccent),
                                Text('mysql'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 30),
                          GestureDetector(
                            onTap: () => inputPickupGeoloc(),
                            child: const Column(children: <Widget>[Text('input'), Icon(Icons.input), Text('mysql')]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(color: Colors.white.withOpacity(0.5), thickness: 5),
                  Expanded(child: displayPickupGeolocList()),
                  Divider(color: Colors.white.withOpacity(0.5), thickness: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[const SizedBox.shrink(), Text(widget.pickupGeolocList.length.toString())],
                  ),
                ],
              ),
            ),
          ),
          if (isLoading) ...<Widget>[const Center(child: CircularProgressIndicator())],
        ],
      ),
    );
  }

  ///
  Widget displayPickupGeolocList() {
    final List<Widget> list = <Widget>[];

    int i = 0;
    String keepLat = '';
    String keepLng = '';
    for (final Geoloc element in widget.pickupGeolocList) {
      String distance = '';
      if (i == 0) {
        distance = '0';
      } else {
        distance = utility
            .calculateDistance(
              LatLng(keepLat.toDouble(), keepLng.toDouble()),
              LatLng(element.latitude.toDouble(), element.longitude.toDouble()),
            )
            .toString();
      }

      list.add(
        DefaultTextStyle(
          style: const TextStyle(fontSize: 12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox(width: 60, child: Text(element.time)),
                  const SizedBox(width: 30),
                  Expanded(child: Text(element.latitude)),
                  Expanded(child: Text(element.longitude)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const SizedBox.shrink(),
                  Container(width: 60, alignment: Alignment.topRight, child: Text('$distance m')),
                ],
              ),
            ],
          ),
        ),
      );

      keepLat = element.latitude;
      keepLng = element.longitude;
      i++;
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverList(
          delegate:
              SliverChildBuilderDelegate((BuildContext context, int index) => list[index], childCount: list.length),
        ),
      ],
    );
  }

  ///
  void _showDeleteDialog() {
    final Widget cancelButton = TextButton(onPressed: () => Navigator.pop(context), child: const Text('いいえ'));

    final Widget continueButton = TextButton(
      onPressed: () {
        deletePickupGeoloc();

        Navigator.pop(context);
      },
      child: const Text('はい'),
    );

    final AlertDialog alert = AlertDialog(
      backgroundColor: Colors.blueGrey.withOpacity(0.3),
      content: Text('${widget.date.yyyymmdd}のmysqlデータを消去しますか？'),
      actions: <Widget>[cancelButton, continueButton],
    );

    // ignore: inference_failure_on_function_invocation
    showDialog(context: context, builder: (BuildContext context) => alert);
  }

  ///
  Future<void> deletePickupGeoloc() async {
    setState(() => isLoading = true);

    geolocNotifier
        .deleteGeoloc(date: widget.date.yyyymmdd)
        // ignore: always_specify_types
        .then(
      // ignore: always_specify_types
      (value) {
        if (mounted) {
          // ignore: always_specify_types
          Future.delayed(
            const Duration(seconds: 2),
            () {
              setState(() => isLoading = false);

              // ignore: use_build_context_synchronously
              Navigator.pop(context);
              // ignore: use_build_context_synchronously
              Navigator.pop(context);

              Navigator.pushReplacement(
                // ignore: use_build_context_synchronously
                context,
                // ignore: inference_failure_on_instance_creation, always_specify_types
                MaterialPageRoute(
                  builder: (BuildContext context) => HomeScreen(
                    baseYm: widget.date.yyyymm,
                    tokyoMunicipalList: appParamState.keepTokyoMunicipalList,
                    tokyoMunicipalMap: appParamState.keepTokyoMunicipalMap,
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }

  ///
  Future<void> inputPickupGeoloc() async {
    setState(() => isLoading = true);

    // データをソート
    widget.pickupGeolocList.sort((Geoloc a, Geoloc b) => a.time.compareTo(b.time));

    // 各 Geoloc ごとに非同期処理を順次実行
    for (final Geoloc element in widget.pickupGeolocList) {
      final Map<String, String> map = <String, String>{
        'year': element.date.split('-')[0],
        'month': element.date.split('-')[1],
        'day': element.date.split('-')[2],
        'time': element.time,
        'latitude': element.latitude,
        'longitude': element.longitude,
      };

      // 非同期処理を待機しながら順次実行
      geolocNotifier.inputGeoloc(map: map);
    }

    // 全ての非同期処理が完了した後に画面遷移を行う
    if (mounted) {
      // ignore: always_specify_types
      Future.delayed(
        const Duration(seconds: 2),
        () {
          setState(() => isLoading = false);

          // ignore: use_build_context_synchronously
          Navigator.pop(context);
          // ignore: use_build_context_synchronously
          Navigator.pop(context);
          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            // ignore: inference_failure_on_instance_creation, always_specify_types
            MaterialPageRoute(
              builder: (BuildContext context) => HomeScreen(
                baseYm: widget.date.yyyymm,
                tokyoMunicipalList: appParamState.keepTokyoMunicipalList,
                tokyoMunicipalMap: appParamState.keepTokyoMunicipalMap,
              ),
            ),
          );
        },
      );
    }
  }
}
