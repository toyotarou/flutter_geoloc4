import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/controllers_mixin.dart';
import '../../extensions/extensions.dart';
import '../home_screen.dart';

class HistoryGeolocListAlert extends ConsumerStatefulWidget {
  const HistoryGeolocListAlert({super.key});

  @override
  ConsumerState<HistoryGeolocListAlert> createState() => _HistoryGeolocListAlertState();
}

class _HistoryGeolocListAlertState extends ConsumerState<HistoryGeolocListAlert>
    with ControllersMixin<HistoryGeolocListAlert> {
  ///
  @override
  void initState() {
    super.initState();

    geolocNotifier.getOldestGeoloc();

    geolocNotifier.getRecentGeoloc();
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
            Expanded(child: displayHistoryGeolocYearMonthList()),
          ],
        ),
      )),
    );
  }

  ///
  Widget displayHistoryGeolocYearMonthList() {
    final List<Widget> list = <Widget>[];

    if (geolocState.oldestGeolocModel != null) {
      if (geolocState.recentGeolocList.isNotEmpty) {
        final DateTime startDate = DateTime(geolocState.oldestGeolocModel!.year.toInt(),
            geolocState.oldestGeolocModel!.month.toInt(), geolocState.oldestGeolocModel!.day.toInt());

        final DateTime endDate = DateTime(geolocState.recentGeolocList[0].year.toInt(),
            geolocState.recentGeolocList[0].month.toInt(), geolocState.recentGeolocList[0].day.toInt());

        final List<DateTime> dateList = generateDateList(startDate, endDate);

        final List<String> yearmonth = <String>[];
        for (final DateTime date in dateList) {
          if (!yearmonth.contains(date.yyyymm)) {
            list.add(Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.3))),
              ),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.pushReplacement(
                        context,
                        // ignore: inference_failure_on_instance_creation, always_specify_types
                        MaterialPageRoute(
                          builder: (BuildContext context) => HomeScreen(
                            baseYm: date.yyyymm,
                            tokyoMunicipalList: appParamState.keepTokyoMunicipalList,
                            tokyoMunicipalMap: appParamState.keepTokyoMunicipalMap,
                          ),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: const Text('', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(date.yyyymm),
                ],
              ),
            ));
          }

          yearmonth.add(date.yyyymm);
        }
      }
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
  List<DateTime> generateDateList(DateTime startDate, DateTime endDate) {
    final List<DateTime> dates = <DateTime>[];
    DateTime currentDate = startDate;

    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1)); // 1日ずつ増やす
    }

    return dates;
  }
}
