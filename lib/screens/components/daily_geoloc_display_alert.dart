import 'dart:async';

import 'package:flutter/material.dart';

import '../../collections/geoloc.dart';
import '../../collections/kotlin_room_data.dart';
import '../../extensions/extensions.dart';
import '../../models/geoloc_model.dart';
import '../../models/temple_latlng_model.dart';
import '../../models/walk_record_model.dart';
import '../../ripository/geolocs_repository.dart';
import '../../ripository/isar_repository.dart';
import '../../utilities/utilities.dart';
import '../parts/geoloc_dialog.dart';
import 'pickup_geoloc_display_alert.dart';

class DailyGeolocDisplayAlert extends StatefulWidget {
  const DailyGeolocDisplayAlert({
    super.key,
    required this.date,
    required this.geolocStateList,
    required this.walkRecord,
    this.templeInfoMap,
    this.kotlinRoomDataList,
  });

  final DateTime date;
  final List<GeolocModel> geolocStateList;
  final WalkRecordModel walkRecord;
  final List<TempleInfoModel>? templeInfoMap;
  final List<KotlinRoomData>? kotlinRoomDataList;

  @override
  State<DailyGeolocDisplayAlert> createState() => _DailyGeolocDisplayAlertState();
}

class _DailyGeolocDisplayAlertState extends State<DailyGeolocDisplayAlert> {
  List<Geoloc>? geolocList = <Geoloc>[];

  List<Geoloc> pickupGeolocList = <Geoloc>[];

  String diffSeconds = '';

  Utility utility = Utility();

  Map<String, List<Geoloc>> geolocMap = <String, List<Geoloc>>{};

  bool isLoading = false;

  /// Isar の変更監視（以前は build のたびに全件読み込み → setState → build … を繰り返していた）
  IsarChangeWatcher? _isarChangeWatcher;

  /// 最新の記録（経過秒数の表示に使う）
  Geoloc? _recentGeoloc;

  bool _recentGeolocLoaded = false;

  /// 経過秒数は1秒ごとにこの部分だけ更新する（画面全体は作り直さない）
  final ValueNotifier<String> _diffSecondsNotifier = ValueNotifier<String>('');

  Timer? _diffTimer;

  ///
  @override
  void initState() {
    super.initState();

    _init();

    _diffTimer = Timer.periodic(const Duration(seconds: 1), (_) => makeDiffSeconds());

    // ignore: always_specify_types
    Future(() async {
      await IsarRepository.configure();

      if (!mounted) {
        return;
      }

      _isarChangeWatcher = IsarChangeWatcher(
        streams: <Stream<void>>[IsarRepository.isar.geolocs.watchLazy()],
        onChanged: _init,
      );
    });
  }

  ///
  @override
  void dispose() {
    _isarChangeWatcher?.dispose();
    _diffTimer?.cancel();
    _diffSecondsNotifier.dispose();

    super.dispose();
  }

  ///
  void _init() {
    _makeGeolocList();

    _makeRecentGeoloc();
  }

  ///
  @override
  Widget build(BuildContext context) {
    makePickupGeolocList();

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(widget.date.yyyymmdd),
                          const SizedBox(height: 10),
                          Text(
                            (widget.kotlinRoomDataList != null) ? widget.kotlinRoomDataList!.length.toString() : '0',
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          GeolocDialog(
                            // ignore: use_build_context_synchronously
                            context: context,
                            widget: PickupGeolocDisplayAlert(
                              date: widget.date,
                              pickupGeolocList: pickupGeolocList,
                              walkRecord: widget.walkRecord,
                              templeInfoMap: widget.templeInfoMap,
                            ),
                          );
                        },
                        child: const Column(children: <Widget>[Text('select'), Icon(Icons.list), Text('list')]),
                      ),
                    ],
                  ),
                  Divider(color: Colors.white.withOpacity(0.5), thickness: 5),
                  Expanded(child: displayGeolocList()),
                  Divider(color: Colors.white.withOpacity(0.5), thickness: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const SizedBox.shrink(),
                      ValueListenableBuilder<String>(
                        valueListenable: _diffSecondsNotifier,
                        builder: (BuildContext context, String value, Widget? child) => Text(value),
                      ),
                    ],
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
  Future<void> _makeGeolocList() async {
    await GeolocRepository().getAllIsarGeoloc().then(
      (List<Geoloc>? value) {
        if (mounted) {
          setState(
            () {
              geolocList = value;

              // 読み込みが終わってから入れ替える
              final Map<String, List<Geoloc>> map = <String, List<Geoloc>>{};

              if (value!.isNotEmpty) {
                for (final Geoloc element in value) {
                  (map[element.date] ??= <Geoloc>[]).add(element);
                }
              }

              geolocMap = map;
            },
          );
        }
      },
    );
  }

  ///
  Future<void> _makeRecentGeoloc() async {
    final Geoloc? value = await GeolocRepository().getRecentOneGeoloc();

    if (!mounted) {
      return;
    }

    _recentGeoloc = value;
    _recentGeolocLoaded = true;

    makeDiffSeconds();
  }

  ///
  Widget displayGeolocList() {
    final List<Widget> list = <Widget>[];

    final List<Geoloc> roopGeolocList = <Geoloc>[];

    geolocList?.forEach(
      (Geoloc element) {
        if (widget.date.yyyymmdd == element.date) {
          roopGeolocList.add(element);
        }
      },
    );

    final List<Geoloc> roopGeolocList2 = <Geoloc>[];

    // List.contains（線形探索）ではなく Set で判定
    final Set<String> timeList = <String>{};
    for (final Geoloc element in roopGeolocList) {
      timeList.add('${element.time.split(':')[0]}:${element.time.split(':')[1]}');
    }

    widget.kotlinRoomDataList?.forEach(
      (KotlinRoomData element) {
        if (!timeList.contains('${element.time.split(':')[0]}:${element.time.split(':')[1]}')) {
          roopGeolocList2.add(Geoloc()
            ..id = 0
            ..date = element.date
            ..time = element.time
            ..latitude = element.latitude
            ..longitude = element.longitude);
        }
      },
    );

    roopGeolocList.addAll(roopGeolocList2);

    roopGeolocList
      ..sort((Geoloc a, Geoloc b) => a.time.compareTo(b.time) * -1)
      ..forEach(
        (Geoloc element) {
          list.add(
            DefaultTextStyle(
              style: const TextStyle(fontSize: 12),
              child: Stack(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 50,
                        child: Text(element.id.toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ),
                      SizedBox(width: 50, child: Text(element.time)),
                      const SizedBox(width: 20),
                      Expanded(child: Text(element.latitude)),
                      Expanded(child: Text(element.longitude)),
                    ],
                  ),
                  if (element.id == 0) ...<Widget>[
                    Container(
                      width: context.screenSize.width,
                      height: 12,
                      decoration: BoxDecoration(color: Colors.pinkAccent.withValues(alpha: 0.2)),
                    ),
                  ],
                ],
              ),
            ),
          );
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

  ///
  Future<void> makePickupGeolocList() async {
    pickupGeolocList = <Geoloc>[];

    String keepLat = '';
    String keepLng = '';

    List<Geoloc> roopGeolocList = <Geoloc>[];

    if (geolocMap[widget.date.yyyymmdd] != null) {
      // コピーしてから加工する（以前は geolocMap 内のリストに直接 addAll していたため、
      // build のたびに Kotlin 側の記録が元データへ追記され続けていた）
      roopGeolocList = <Geoloc>[...geolocMap[widget.date.yyyymmdd]!];

      final List<Geoloc> roopGeolocList2 = <Geoloc>[];

      // List.contains（線形探索）ではなく Set で判定
      final Set<String> timeList = <String>{};
      for (final Geoloc element in roopGeolocList) {
        timeList.add('${element.time.split(':')[0]}:${element.time.split(':')[1]}');
      }

      widget.kotlinRoomDataList?.forEach(
        (KotlinRoomData element) {
          if (!timeList.contains('${element.time.split(':')[0]}:${element.time.split(':')[1]}')) {
            roopGeolocList2.add(Geoloc()
              ..id = 0
              ..date = element.date
              ..time = element.time
              ..latitude = element.latitude
              ..longitude = element.longitude);
          }
        },
      );

      roopGeolocList.addAll(roopGeolocList2);

      roopGeolocList
        ..sort((Geoloc a, Geoloc b) => a.time.compareTo(b.time))
        ..forEach(
          (Geoloc element) {
            if (<String>{keepLat, keepLng, element.latitude, element.longitude}.toList().length >= 3) {
              pickupGeolocList.add(element);
            }

            keepLat = element.latitude;
            keepLng = element.longitude;
          },
        );
    }
  }

  ///
  void makeDiffSeconds() {
    // 以前は build のたびに DB から最新1件を取り直していた。読み込み済みの最新記録から計算する
    if (!_recentGeolocLoaded) {
      return;
    }

    final Geoloc? value = _recentGeoloc;

    int secondDiff = 0;

    if (value != null) {
      secondDiff = DateTime.now()
          .difference(
            DateTime(
              value.date.split('-')[0].toInt(),
              value.date.split('-')[1].toInt(),
              value.date.split('-')[2].toInt(),
              value.time.split(':')[0].toInt(),
              value.time.split(':')[1].toInt(),
              value.time.split(':')[2].toInt(),
            ),
          )
          .inSeconds;
    }

    diffSeconds = secondDiff.toString().padLeft(2, '0');

    _diffSecondsNotifier.value = diffSeconds;
  }
}
