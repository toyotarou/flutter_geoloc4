import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/controllers_mixin.dart';
import '../../enums/map_type.dart';
import '../../extensions/extensions.dart';
import '../../models/geoloc_model.dart';
import '../../models/temple_latlng_model.dart';
import '../../models/temple_photo_model.dart';
import '../../models/walk_record_model.dart';
import '../parts/geoloc_dialog.dart';
import 'geoloc_map_alert.dart';

class TempleVisitedDateDisplayAlert extends ConsumerStatefulWidget {
  const TempleVisitedDateDisplayAlert({super.key});

  @override
  ConsumerState<TempleVisitedDateDisplayAlert> createState() => _TempleVisitedDateDisplayAlertState();
}

class _TempleVisitedDateDisplayAlertState extends ConsumerState<TempleVisitedDateDisplayAlert>
    with ControllersMixin<TempleVisitedDateDisplayAlert> {
  Map<String, List<TemplePhotoModel>> templePhotoDateMap = <String, List<TemplePhotoModel>>{};

  ///
  @override
  void initState() {
    super.initState();

    geolocNotifier.getAllGeoloc();

    walkRecordNotifier.getAllWalkRecord();
  }

  ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Expanded(child: displayTempleVisitedDateList()),
            ],
          ),
        ),
      ),
    );
  }

  ///
  Widget displayTempleVisitedDateList() {
    final List<Widget> list = <Widget>[];

    if (templePhotoState.templePhotoDateMap.value != null) {
      templePhotoDateMap = templePhotoState.templePhotoDateMap.value!;
    }

    templeState.yearVisitedDateMap.forEach(
      (String year, List<String> value) {
        if (year.toInt() >= 2023) {
          final List<Widget> list2 = <Widget>[];

          for (final String date in value) {
            if (DateTime.parse('$date 00:00:00').isAfter(DateTime(2023, 4, 13))) {
              final List<TemplePhotoModel>? templePhotoDateList = templePhotoDateMap[date];

              list2.add(
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          GestureDetector(
                            onTap: () {
                              appParamNotifier.setIsMarkerShow(flag: false);

                              appParamNotifier.setMapType(type: MapType.daily);

                              GeolocDialog(
                                context: context,
                                widget: GeolocMapAlert(
                                  displayMonthMap: false,
                                  date: DateTime.parse('$date 00:00:00'),
                                  geolocStateList: geolocState.allGeolocMap[date] ?? <GeolocModel>[],
                                  walkRecord: walkRecordState.walkRecordMap[date] ??
                                      WalkRecordModel(id: 0, year: '', month: '', day: '', step: 0, distance: 0),
                                  templeInfoList: templeState.templeInfoMap[date],
                                  polylineModeAsTempleVisitedDate: true,
                                ),
                                executeFunctionWhenDialogClose: true,
                                ref: ref,
                                from: 'TempleVisitedDateDisplayAlert',
                              );
                            },
                            child: CircleAvatar(radius: 12, backgroundColor: Colors.white.withOpacity(0.2)),
                          ),
                          const SizedBox(width: 10),
                          Text(date),
                        ],
                      ),
                      Stack(
                        children: <Widget>[
                          Positioned(
                            right: 100,
                            child: Text(
                              (walkRecordState.walkRecordMap[date] == null)
                                  ? '-'
                                  : '${(walkRecordState.walkRecordMap[date]!.distance / 1000).toString().split('.')[0]} Km',
                              style: TextStyle(fontSize: 20, color: Colors.yellowAccent.withOpacity(0.5)),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                (walkRecordState.walkRecordMap[date] == null)
                                    ? '-'
                                    : 'step: ${walkRecordState.walkRecordMap[date]!.step} / distance: ${walkRecordState.walkRecordMap[date]!.distance}',
                              ),
                              Text((geolocState.allGeolocMap[date] == null)
                                  ? '-'
                                  : geolocState.allGeolocMap[date]!.length.toString()),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              if (templeState.templeInfoMap[date] != null) {
                list2.add(
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: templeState.templeInfoMap[date]!.map(
                        (TempleInfoModel e) {
                          TemplePhotoModel templePhoto =
                              TemplePhotoModel(date: DateTime.now(), temple: '', templephotos: <String>[]);

                          if (templePhotoDateList != null) {
                            for (final TemplePhotoModel element in templePhotoDateList) {
                              if (element.temple == e.temple) {
                                templePhoto = element;
                              }
                            }
                          }

                          return Stack(
                            children: <Widget>[
                              if (templePhoto.templephotos.isNotEmpty) ...<Widget>[
                                Positioned(
                                  bottom: 5,
                                  right: 5,
                                  child: Icon(Icons.photo, color: Colors.white.withOpacity(0.2)),
                                ),
                              ],
                              Container(
                                width: 120,
                                height: 60,
                                margin: const EdgeInsets.all(3),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: (templePhoto.templephotos.isEmpty)
                                        ? Colors.pinkAccent
                                        : Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(e.temple, maxLines: 3, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          );
                        },
                      ).toList(),
                    ),
                  ),
                );
              }

              list2.add(Divider(color: Colors.white.withOpacity(0.2), thickness: 3));
            }
          }

          list.add(
            Column(
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[Text(year), const SizedBox.shrink()],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: list2),
              ],
            ),
          );
        }
      },
    );

    return CustomScrollView(
      slivers: <Widget>[
        SliverList(
          delegate:
              SliverChildBuilderDelegate((BuildContext context, int index) => list[index], childCount: list.length),
        ),
      ],
    );
  }
}
