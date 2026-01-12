import 'dart:async';
import 'dart:io';

import 'package:background_task/background_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../collections/geoloc.dart';
import '../collections/kotlin_room_data.dart';
import '../controllers/controllers_mixin.dart';
import '../enums/map_type.dart';
import '../extensions/extensions.dart';
import '../models/geoloc_model.dart';
import '../models/municipal_model.dart';
import '../models/temple_latlng_model.dart';
import '../models/walk_record_model.dart';
import '../ripository/geolocs_repository.dart';
import '../ripository/isar_repository.dart';
import '../ripository/kotlin_room_data_repository.dart';
import '../utilities/utilities.dart';
import 'components/daily_geoloc_display_alert.dart';
import 'components/geoloc_data_list_alert.dart';
import 'components/geoloc_map_alert.dart';
import 'components/history_geoloc_list_alert.dart';
import 'components/kotlin_room_data_display_alert.dart';
import 'components/kotlin_room_data_list_alert.dart';
import 'components/temple_visited_date_display_alert.dart';
import 'parts/geoloc_dialog.dart';
import 'parts/menu_head_icon.dart';

@pragma('vm:entry-point')
void backgroundHandler(Location data) {
  // ignore: always_specify_types
  Future(() async {
    GeolocRepository().getRecentOneGeoloc().then((Geoloc? value) async {
      /////////////////////
      final DateTime now = DateTime.now();
      final DateFormat timeFormat = DateFormat('HH:mm:ss');
      final String currentTime = timeFormat.format(now);

      final Geoloc geoloc = Geoloc()
        ..date = DateTime.now().yyyymmdd
        ..time = currentTime
        ..latitude = data.lat.toString()
        ..longitude = data.lng.toString();
      /////////////////////

      bool isInsert = false;

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
      } else {
        /// 初回
        isInsert = true;
      }

      if (secondDiff >= 60) {
        isInsert = true;
      }

      if (isInsert) {
        await IsarRepository.configure();
        IsarRepository.isar.writeTxnSync(() => IsarRepository.isar.geolocs.putSync(geoloc));
      }
    });
  });
}

// ignore: unreachable_from_main, must_be_immutable
class HomeScreen extends ConsumerStatefulWidget {
  // ignore: unreachable_from_main
  HomeScreen({super.key, this.baseYm, required this.tokyoMunicipalList, required this.tokyoMunicipalMap});

  // ignore: unreachable_from_main
  String? baseYm;

  // ignore: unreachable_from_main
  final List<MunicipalModel> tokyoMunicipalList;

  // ignore: unreachable_from_main
  final Map<String, MunicipalModel> tokyoMunicipalMap;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with ControllersMixin<HomeScreen> {
  String bgText = 'no start';
  String statusText = 'status';
  bool isEnabledEvenIfKilled = true;

  late final StreamSubscription<Location> _bgDisposer;
  late final StreamSubscription<StatusEvent> _statusDisposer;

  DateTime _calendarMonthFirst = DateTime.now();
  final List<String> _youbiList = <String>[
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  List<String> _calendarDays = <String>[];

  Map<String, String> _holidayMap = <String, String>{};

  final Utility utility = Utility();

  bool baseYmSetFlag = false;

  List<Geoloc>? geolocList = <Geoloc>[];
  Map<String, List<Geoloc>> geolocMap = <String, List<Geoloc>>{};

  ///
  @override
  void initState() {
    super.initState();

    _bgDisposer = BackgroundTask.instance.stream.listen((Location event) {
      final String message = '${DateTime.now()}: ${event.lat}, ${event.lng}';

      // debugPrint(message);

      setState(() => bgText = message);
    });

    // ignore: always_specify_types
    Future(() async {
      final PermissionStatus result = await Permission.notification.request();
      // debugPrint('notification: $result');

      if (Platform.isAndroid) {
        if (result.isGranted) {
          await BackgroundTask.instance.setAndroidNotification(
            title: 'バックグラウンド処理',
            message: 'バックグラウンド処理を実行中',
          );
        }
      }
    });

    _statusDisposer = BackgroundTask.instance.status.listen((StatusEvent event) {
      final String message = 'status: ${event.status.value}, message: ${event.message}';

      setState(() => statusText = message);
    });

    geolocNotifier.getYearMonthGeoloc(yearmonth: (widget.baseYm != null) ? widget.baseYm! : DateTime.now().yyyymm);

    walkRecordNotifier.getYearWalkRecord(yearmonth: (widget.baseYm != null) ? widget.baseYm! : DateTime.now().yyyymm);

    templeNotifier.getAllTempleModel();
  }

  ///
  @override
  void dispose() {
    _bgDisposer.cancel();
    _statusDisposer.cancel();
    super.dispose();
  }

  ///
  void _init() {
    /// setState地獄に陥るのでisarからのデータ取得を追加してはいけない
    _makeGeolocList();
  }

  ///
  @override
  Widget build(BuildContext context) {
    // ignore: always_specify_types
    Future(_init);

    if (widget.baseYm != null && !baseYmSetFlag) {
      // ignore: always_specify_types
      Future(() => calendarNotifier.setCalendarYearMonth(baseYm: widget.baseYm));

      baseYmSetFlag = true;
    }

    // ignore: always_specify_types
    final List<GeolocModel> monthGeolocModelList = List.from(geolocState.geolocList);
//    final List<GeolocModel> monthGeolocModelList = List.from(geolocStateList);

    if (geolocMap.isNotEmpty) {
      geolocMap.forEach((String key, List<Geoloc> value) {
        for (final Geoloc element in value) {
          monthGeolocModelList.add(
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
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      appParamNotifier.setKeepTokyoMunicipalList(list: widget.tokyoMunicipalList);
      appParamNotifier.setKeepTokyoMunicipalMap(map: widget.tokyoMunicipalMap);

      //===========================================//

      final List<List<List<List<double>>>> allPolygonsList = <List<List<List<double>>>>[];

      for (final MunicipalModel element in widget.tokyoMunicipalList) {
        allPolygonsList.addAll(element.polygons);
      }

      ///////////////////////

      // ignore: always_specify_types
      Future(() {
        appParamNotifier.setKeepAllPolygonsList(list: allPolygonsList);
      });
      //===========================================//
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(calendarState.baseYearMonth),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconButton(
                          onPressed: () => _goPrevMonth(),
                          icon: Icon(Icons.arrow_back_ios, color: Colors.white.withOpacity(0.8), size: 14)),
                      IconButton(
                        onPressed: () => (DateTime.now().yyyymm == calendarState.baseYearMonth) ? null : _goNextMonth(),
                        icon: Icon(Icons.arrow_forward_ios,
                            size: 14,
                            color: (DateTime.now().yyyymm == calendarState.baseYearMonth)
                                ? Colors.grey.withOpacity(0.6)
                                : Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Row(
              children: <Widget>[
                IconButton(
                    onPressed: () {
                      GeolocDialog(context: context, widget: const KotlinRoomDataDisplayAlert());
                    },
                    icon: Icon(FontAwesomeIcons.k, color: Colors.white.withOpacity(0.3))),
                IconButton(
                  onPressed: () {
                    GeolocDialog(
                      context: context,
                      widget: const TempleVisitedDateDisplayAlert(),
                    );
                  },
                  icon: Icon(FontAwesomeIcons.toriiGate, size: 20, color: Colors.white.withOpacity(0.3)),
                ),
              ],
            ),
          ],
        ),
      ),
      endDrawer: _dispDrawer(),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          utility.getBackGround(),
          Column(children: <Widget>[Expanded(child: _getCalendar())]),
          if (monthGeolocModelList.isNotEmpty) ...<Widget>[
            Positioned(
              bottom: 45,
              right: 10,
              child: Row(
                children: <Widget>[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.withOpacity(0.2)),
                    onPressed: () {
                      appParamNotifier.setIsMarkerShow(flag: true);

                      appParamNotifier.setSelectedTimeGeoloc();

                      appParamNotifier.setMapType(type: MapType.monthDays);

                      // ------------------------------------------- //
                      bool monthDaysFirstDateTempleExists = false;

                      if (widget.baseYm != null) {
                        /// 他月
                        if (templeState.templeInfoMap['${widget.baseYm}-01'] != null) {
                          monthDaysFirstDateTempleExists = true;
                        }
                      } else {
                        /// 今月
                        if (templeState.templeInfoMap['${DateTime.now().yyyymm}-01'] != null) {
                          monthDaysFirstDateTempleExists = true;
                        }
                      }
                      // ------------------------------------------- //

                      GeolocDialog(
                        context: context,
                        widget: GeolocMapAlert(
                          displayMonthMap: false,

                          ///

                          date:
                              (widget.baseYm == null) ? DateTime.now() : DateTime.parse('${widget.baseYm}-01 00:00:00'),
                          geolocStateList: monthGeolocModelList,
                          walkRecord: WalkRecordModel(
                            id: 0,
                            year: '',
                            month: '',
                            day: '',
                            step: 0,
                            distance: 0,
                          ),
                          templeInfoList: (widget.baseYm == null)
                              ? templeState.templeInfoMap['${DateTime.now().yyyymm}-01']
                              : templeState.templeInfoMap['${widget.baseYm}-01'],
                          monthDaysFirstDateTempleExists: monthDaysFirstDateTempleExists,
                        ),
                        executeFunctionWhenDialogClose: true,
                        ref: ref,
                        from: 'HomeScreen',
                      );
                    },
                    child: const Text('month days'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.withOpacity(0.2)),
                    onPressed: () {
                      appParamNotifier.setIsMarkerShow(flag: true);

                      appParamNotifier.setSelectedTimeGeoloc();

                      appParamNotifier.setMapType(type: MapType.monthly);

                      GeolocDialog(
                        context: context,
                        widget: GeolocMapAlert(
                          displayMonthMap: true,
                          date:
                              (widget.baseYm == null) ? DateTime.now() : DateTime.parse('${widget.baseYm}-01 00:00:00'),
                          geolocStateList: monthGeolocModelList,
                          walkRecord: WalkRecordModel(
                            id: 0,
                            year: '',
                            month: '',
                            day: '',
                            step: 0,
                            distance: 0,
                          ),
                        ),
                        executeFunctionWhenDialogClose: true,
                        ref: ref,
                        from: 'HomeScreen',
                      );
                    },
                    child: const Text('month'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  ///
  Widget _dispDrawer() {
    return Drawer(
      backgroundColor: Colors.blueGrey.withOpacity(0.2),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.only(left: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 60),
              GestureDetector(
                onTap: () async {
                  final PermissionStatus status = await Permission.location.request();
                  final PermissionStatus statusAlways = await Permission.locationAlways.request();

                  if (status.isGranted && statusAlways.isGranted) {
                    await BackgroundTask.instance.start(isEnabledEvenIfKilled: isEnabledEvenIfKilled);
                    setState(() => bgText = 'start');
                  }

                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Row(
                  children: <Widget>[
                    const MenuHeadIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                        margin: const EdgeInsets.all(5),
                        child: const Text('Start'),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final bool isRunning = await BackgroundTask.instance.isRunning;

                  if (context.mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('isRunning: $isRunning'),
                        action: SnackBarAction(
                          label: 'close',
                          onPressed: () => ScaffoldMessenger.of(context).clearSnackBars(),
                        ),
                      ),
                    );
                  }
                },
                child: Row(
                  children: <Widget>[
                    const MenuHeadIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                        margin: const EdgeInsets.all(5),
                        child: const Text('Status'),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.4), thickness: 5),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  // ignore: inference_failure_on_instance_creation, always_specify_types
                  MaterialPageRoute(
                    builder: (BuildContext context) => HomeScreen(
                      baseYm: (widget.baseYm != null) ? widget.baseYm : DateTime.now().yyyymm,
                      tokyoMunicipalList: widget.tokyoMunicipalList,
                      tokyoMunicipalMap: widget.tokyoMunicipalMap,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const MenuHeadIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                        margin: const EdgeInsets.all(5),
                        child: const Text('Reload'),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    // ignore: inference_failure_on_instance_creation, always_specify_types
                    MaterialPageRoute(
                      builder: (BuildContext context) => HomeScreen(
                        baseYm: DateTime.now().yyyymm,
                        tokyoMunicipalList: widget.tokyoMunicipalList,
                        tokyoMunicipalMap: widget.tokyoMunicipalMap,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: <Widget>[
                    const MenuHeadIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                        margin: const EdgeInsets.all(5),
                        child: const Text('Today'),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => GeolocDialog(context: context, widget: const HistoryGeolocListAlert()),
                child: Row(
                  children: <Widget>[
                    const MenuHeadIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                        margin: const EdgeInsets.all(5),
                        child: const Text('History'),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.4), thickness: 5),
              GestureDetector(
                onTap: () => GeolocDialog(
                    context: context,
                    widget: GeolocDataListAlert(geolocList: geolocList, geolocStateMap: geolocState.geolocMap)),
                child: Row(
                  children: <Widget>[
                    const MenuHeadIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                        margin: const EdgeInsets.all(5),
                        child: const Text('Geoloc data list'),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => GeolocDialog(context: context, widget: const KotlinRoomDataListAlert()),
                child: Row(
                  children: <Widget>[
                    const MenuHeadIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                        margin: const EdgeInsets.all(5),
                        child: const Text('Kotlin Room data list'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ///
  Widget _getCalendar() {
    if (holidaysState.holidayMap.value != null) {
      _holidayMap = holidaysState.holidayMap.value!;
    }

    _calendarMonthFirst = DateTime.parse('${calendarState.baseYearMonth}-01 00:00:00');

    final DateTime monthEnd = DateTime.parse('${calendarState.nextYearMonth}-00 00:00:00');

    final int diff = monthEnd.difference(_calendarMonthFirst).inDays;
    final int monthDaysNum = diff + 1;

    final String youbi = _calendarMonthFirst.youbiStr;
    final int youbiNum = _youbiList.indexWhere((String element) => element == youbi);

    final int weekNum = ((monthDaysNum + youbiNum) <= 35) ? 5 : 6;

    // ignore: always_specify_types
    _calendarDays = List.generate(weekNum * 7, (int index) => '');

    for (int i = 0; i < (weekNum * 7); i++) {
      if (i >= youbiNum) {
        final DateTime gendate = _calendarMonthFirst.add(Duration(days: i - youbiNum));

        if (_calendarMonthFirst.month == gendate.month) {
          _calendarDays[i] = gendate.day.toString();
        }
      }
    }

    final List<Widget> list = <Widget>[];
    for (int i = 0; i < weekNum; i++) {
      list.add(
        _getCalendarRow(
          week: i,
          geolocStateMap: geolocState.geolocMap,
          walkRecordMap: walkRecordState.walkRecordMap,
          templeInfoMap: templeState.templeInfoMap,
        ),
      );
    }

    return SingleChildScrollView(
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 10),
        child: Column(
          children: <Widget>[Column(children: list), const SizedBox(height: 45)],
        ),
      ),
    );
  }

  ///
  Widget _getCalendarRow(
      {required int week,
      required Map<String, List<GeolocModel>> geolocStateMap,
      required Map<String, WalkRecordModel> walkRecordMap,
      required Map<String, List<TempleInfoModel>> templeInfoMap}) {
    final List<Widget> list = <Widget>[];

    for (int i = week * 7; i < ((week + 1) * 7); i++) {
      final String generateYmd = (_calendarDays[i] == '')
          ? ''
          : DateTime(_calendarMonthFirst.year, _calendarMonthFirst.month, _calendarDays[i].toInt()).yyyymmdd;

      final String youbiStr = (_calendarDays[i] == '')
          ? ''
          : DateTime(_calendarMonthFirst.year, _calendarMonthFirst.month, _calendarDays[i].toInt()).youbiStr;

      list.add(
        Expanded(
          child: Stack(
            children: <Widget>[
              if (templeInfoMap[generateYmd] != null) ...<Widget>[
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Icon(FontAwesomeIcons.toriiGate, size: 15, color: Colors.white.withOpacity(0.5)),
                ),
              ],
              Container(
                margin: const EdgeInsets.all(1),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: (_calendarDays[i] == '')
                        ? Colors.transparent
                        : (generateYmd == DateTime.now().yyyymmdd)
                            ? Colors.orangeAccent.withOpacity(0.4)
                            : Colors.white.withOpacity(0.1),
                    width: 3,
                  ),
                  color: (_calendarDays[i] == '')
                      ? Colors.transparent
                      : (DateTime.parse('$generateYmd 00:00:00').isAfter(DateTime.now()))
                          ? Colors.white.withOpacity(0.1)
                          : utility.getYoubiColor(date: generateYmd, youbiStr: youbiStr, holidayMap: _holidayMap),
                ),
                child: (_calendarDays[i] == '')
                    ? const Text('')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(_calendarDays[i].padLeft(2, '0')),
                              Icon(
                                Icons.directions_walk,
                                size: 12,
                                color: (walkRecordMap[generateYmd] != null)
                                    ? Colors.yellowAccent.withOpacity(0.4)
                                    : Colors.grey.withOpacity(0.4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ConstrainedBox(
                            constraints: BoxConstraints(minHeight: context.screenSize.height / 9),
                            child: (DateTime.parse('$generateYmd 00:00:00').isAfter(DateTime.now()))
                                ? null
                                : Column(
                                    children: <Widget>[
                                      /////

                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          backgroundColor: (geolocMap[generateYmd] == null)
                                              ? null
                                              : Colors.blueAccent.withOpacity(0.1),
                                        ),
                                        onPressed: (geolocMap[generateYmd] == null)
                                            ? null
                                            : () async {
                                                //================================================
                                                // ignore: prefer_final_locals
                                                List<KotlinRoomData>? list = <KotlinRoomData>[];

                                                await KotlinRoomDataRepository().getAllKotlinRoomDataList().then(
                                                      (List<KotlinRoomData>? value) => value?.forEach(
                                                        (KotlinRoomData element) {
                                                          if (generateYmd == element.date) {
                                                            list.add(element);
                                                          }
                                                        },
                                                      ),
                                                    );

                                                //================================================

                                                //////

                                                GeolocDialog(
                                                  // ignore: use_build_context_synchronously
                                                  context: context,
                                                  widget: DailyGeolocDisplayAlert(
                                                    date: DateTime.parse('$generateYmd 00:00:00'),
                                                    geolocStateList: geolocStateMap[generateYmd] ?? <GeolocModel>[],
                                                    walkRecord: walkRecordMap[generateYmd] ??
                                                        WalkRecordModel(
                                                          id: 0,
                                                          year: '',
                                                          month: '',
                                                          day: '',
                                                          step: 0,
                                                          distance: 0,
                                                        ),
                                                    templeInfoMap: templeInfoMap[generateYmd],
                                                    kotlinRoomDataList: list,
                                                  ),
                                                );
                                              },
                                        child: Text(
                                          (geolocMap[generateYmd] != null)
                                              ? geolocMap[generateYmd]!.length.toString()
                                              : '',
                                          style: const TextStyle(fontSize: 8, color: Colors.white),
                                        ),
                                      ),

                                      /////

                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          backgroundColor: (geolocStateMap[generateYmd] == null)
                                              ? null
                                              : Colors.greenAccent.withOpacity(0.1),
                                        ),
                                        onPressed: (geolocStateMap[generateYmd] == null)
                                            ? null
                                            : () {
                                                appParamNotifier.setIsMarkerShow(flag: true);

                                                appParamNotifier.setMapType(type: MapType.daily);

                                                List<String> templeGeolocNearlyDateList = <String>[];
                                                if (templeState.templeInfoMap.isNotEmpty) {
                                                  templeGeolocNearlyDateList = utility.getTempleGeolocNearlyDateList(
                                                    date: generateYmd,
                                                    templeInfoMap: templeState.templeInfoMap,
                                                  );
                                                }

                                                GeolocDialog(
                                                  context: context,
                                                  widget: GeolocMapAlert(
                                                      displayMonthMap: false,
                                                      date: DateTime.parse('$generateYmd 00:00:00'),
                                                      geolocStateList: geolocStateMap[generateYmd] ?? <GeolocModel>[],
                                                      walkRecord: walkRecordMap[generateYmd] ??
                                                          WalkRecordModel(
                                                              id: 0,
                                                              year: '',
                                                              month: '',
                                                              day: '',
                                                              step: 0,
                                                              distance: 0),
                                                      templeInfoList: templeInfoMap[generateYmd],
                                                      templeGeolocNearlyDateList: templeGeolocNearlyDateList),
                                                  executeFunctionWhenDialogClose: true,
                                                  ref: ref,
                                                  from: 'HomeScreen',
                                                );
                                              },
                                        child: Text(
                                          (geolocStateMap[generateYmd] != null)
                                              ? geolocStateMap[generateYmd]!.length.toString()
                                              : '',
                                          style: const TextStyle(fontSize: 8, color: Colors.white),
                                        ),
                                      ),

                                      /////
                                    ],
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: list);
  }

  ///
  void _goPrevMonth() => Navigator.pushReplacement(
        context,
        // ignore: inference_failure_on_instance_creation, always_specify_types
        MaterialPageRoute(
          builder: (BuildContext context) => HomeScreen(
            baseYm: calendarState.prevYearMonth,
            tokyoMunicipalList: widget.tokyoMunicipalList,
            tokyoMunicipalMap: widget.tokyoMunicipalMap,
          ),
        ),
      );

  ///
  void _goNextMonth() => Navigator.pushReplacement(
        context,
        // ignore: inference_failure_on_instance_creation, always_specify_types
        MaterialPageRoute(
          builder: (BuildContext context) => HomeScreen(
            baseYm: calendarState.nextYearMonth,
            tokyoMunicipalList: widget.tokyoMunicipalList,
            tokyoMunicipalMap: widget.tokyoMunicipalMap,
          ),
        ),
      );

  ///
  Future<void> _makeGeolocList() async {
    geolocMap.clear();

    GeolocRepository().getAllIsarGeoloc().then((List<Geoloc>? value) {
      if (mounted) {
        setState(() {
          geolocList = value;

          if (value!.isNotEmpty) {
            for (final Geoloc element in value) {
              (geolocMap[element.date] ??= <Geoloc>[]).add(element);
            }
          }
        });
      }
    });
  }
}
