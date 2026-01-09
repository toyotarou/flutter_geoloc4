import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../collections/kotlin_room_data.dart';
import '../../controllers/controllers_mixin.dart';
import '../../extensions/extensions.dart';
import '../../pigeon/wifi_location.dart';
import '../../ripository/kotlin_room_data_repository.dart';
import '../home_screen.dart';
import '../parts/error_dialog.dart';

class KotlinRoomDataDisplayAlert extends ConsumerStatefulWidget {
  const KotlinRoomDataDisplayAlert({super.key});

  @override
  ConsumerState<KotlinRoomDataDisplayAlert> createState() => _KotlinRoomDataDisplayAlertState();
}

class _KotlinRoomDataDisplayAlertState extends ConsumerState<KotlinRoomDataDisplayAlert>
    with ControllersMixin<KotlinRoomDataDisplayAlert> {
  bool _isRunning = false;

  bool _isLoading = false;

  List<WifiLocation> kotlinRoomData = <WifiLocation>[];

  List<KotlinRoomData>? isarKotlinRoomDataList = <KotlinRoomData>[];

  bool _isLoading2 = false;

  static const double maxTime = 5.000;

  double _remainingTime = maxTime;

  Timer? _timer;

  ///
  Future<void> _requestPermissions() async {
    final PermissionStatus locationStatus = await Permission.location.request();
    final PermissionStatus fgServiceStatus = await Permission.ignoreBatteryOptimizations.request();

    if (!locationStatus.isGranted) {
      throw Exception('位置情報の権限が拒否されました');
    }
    if (!fgServiceStatus.isGranted) {
      debugPrint('バッテリー最適化除外の許可が拒否されました（続行可能）');
    }
  }

  ///
  Future<void> _startService() async {
    setState(() => _isLoading = true);

    try {
      await _requestPermissions();

      final WifiLocationApi api = WifiLocationApi();
      await api.startLocationCollection();

      // ignore: inference_failure_on_instance_creation, always_specify_types
      await Future.delayed(const Duration(seconds: 1));
      await _checkStatus();
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ エラー: $e')));
    }

    setState(() => _isLoading = false);
  }

  ///
  Future<void> _checkStatus() async {
    final WifiLocationApi api = WifiLocationApi();
    final bool result = await api.isCollecting();
    setState(() => _isRunning = result);
  }

  ///
  Future<void> _fetchKotlinRoomData() async {
    final WifiLocationApi api = WifiLocationApi();
    final List<WifiLocation?> result = await api.getWifiLocations();
    setState(() {
      kotlinRoomData = result.whereType<WifiLocation>().toList();

      kotlinRoomData
          .sort((WifiLocation a, WifiLocation b) => '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}') * -1);
    });
  }

  ///
  @override
  void initState() {
    super.initState();

    _checkStatus();

    _fetchKotlinRoomData();

    _makeKotlinRoomDataList();
  }

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[Text('Kotlin Room Data'), SizedBox.shrink()],
                  ),
                  Divider(color: Colors.white.withOpacity(0.4), thickness: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: _isLoading ? null : _startService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                          padding: const EdgeInsets.all(5),
                        ),
                        child: const Text('取得開始'),
                      ),
                      Row(
                        children: <Widget>[
                          ElevatedButton(
                            onPressed: _checkStatus,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pinkAccent.withOpacity(0.2), padding: const EdgeInsets.all(5)),
                            child: const Text('稼働状態'),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.star,
                            color: _isRunning ? Colors.yellow : Colors.white.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: _fetchKotlinRoomData,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightGreen.withOpacity(0.2), padding: const EdgeInsets.all(5)),
                        child: const Text('Roomから取得'),
                      ),
                      ElevatedButton(
                        onPressed: () => inputKotlinRoomData(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent.withOpacity(0.2), padding: const EdgeInsets.all(5)),
                        child: const Text('isar登録'),
                      ),
                      ElevatedButton(
                        onPressed: () => _showDeleteDialog(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.2), padding: const EdgeInsets.all(5)),
                        child: const Text('Room全削除'),
                      ),
                    ],
                  ),
                  Divider(color: Colors.white.withOpacity(0.4), thickness: 2),
                  const SizedBox(height: 10),
                  Expanded(
                    child: kotlinRoomData.isEmpty
                        ? const Text('no data', style: TextStyle(color: Colors.yellowAccent))
                        : ListView.builder(
                            itemCount: kotlinRoomData.length,
                            itemBuilder: (BuildContext context, int index) {
                              final WifiLocation loc = kotlinRoomData[index];

                              final String ssid = loc.ssid.replaceAll('"', '');

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: Colors.transparent,
                                child: ListTile(
                                  title: Text(ssid),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('${loc.date} ${loc.time}'),
                                      Container(
                                          alignment: Alignment.topRight,
                                          child: Text('${loc.latitude} / ${loc.longitude}')),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading2) ...<Widget>[
            Center(
              child: Column(
                children: <Widget>[
                  SizedBox(width: context.screenSize.width),
                  const Spacer(),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(
                    _remainingTime.toStringAsFixed(3),
                    style: const TextStyle(fontSize: 30, color: Colors.yellowAccent),
                  ),
                  const Spacer(),
                ],
              ),
            )
          ],
        ],
      ),
    );
  }

  ///
  void _startCountdown() {
    _timer?.cancel();

    setState(() => _remainingTime = maxTime);

    const Duration interval = Duration(milliseconds: 10);

    final DateTime startTime = DateTime.now();

    _timer = Timer.periodic(interval, (Timer timer) {
      final double elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000;

      final double newRemaining = (maxTime - elapsed).clamp(0.0, maxTime);

      setState(() => _remainingTime = newRemaining);

      if (newRemaining <= 0.0) {
        _timer?.cancel();
      }
    });
  }

  ///
  Future<void> inputKotlinRoomData() async {
    _startCountdown();

    setState(() => _isLoading2 = true);

    if (kotlinRoomData.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        error_dialog(context: context, title: '登録できません。', content: '値を正しく入力してください。');
      });
      setState(() => _isLoading2 = false);
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // --------------------- //
    final Set<String> existingDateTimeSet = <String>{
      for (final KotlinRoomData element in isarKotlinRoomDataList!) '${element.date} ${element.time}'
    };
    final Set<String> processedDateTimeSet = <String>{};
    // --------------------- //

    final List<KotlinRoomData> inputData = <KotlinRoomData>[];

    ////////////////////////////////////////////
    for (final WifiLocation element in kotlinRoomData) {
      final DateTime dt = DateTime(
        int.parse(element.date.split('-')[0]),
        int.parse(element.date.split('-')[1]),
        int.parse(element.date.split('-')[2]),
        int.parse(element.time.split(':')[0]),
        int.parse(element.time.split(':')[1]),
      );

      final String dateTimeStr = '${element.date} ${element.time}';

      if (dt.isAfter(today) &&
          !existingDateTimeSet.contains(dateTimeStr) &&
          !processedDateTimeSet.contains(dateTimeStr)) {
        inputData.add(KotlinRoomData()
          ..date = element.date
          ..time = element.time
          ..ssid = element.ssid.replaceAll('"', '')
          ..latitude = element.latitude
          ..longitude = element.longitude);
      }
    }
    ////////////////////////////////////////////

    if (inputData.isNotEmpty) {
      await KotlinRoomDataRepository().inputKotlinRoomDataList(kotlinRoomDataList: inputData);
    }

    // ignore: always_specify_types
    Future.delayed(const Duration(seconds: 5), () => setState(() => _isLoading2 = false));
  }

  ///
  void _showDeleteDialog() {
    final Widget cancelButton = TextButton(onPressed: () => Navigator.pop(context), child: const Text('いいえ'));

    final Widget continueButton = TextButton(
      onPressed: () {
        deleteKotlinRoomList();

        Navigator.pop(context);
      },
      child: const Text('はい'),
    );

    final AlertDialog alert = AlertDialog(
      backgroundColor: Colors.blueGrey.withOpacity(0.3),
      content: const Text('kotlinのroomデータを削除しますか'),
      actions: <Widget>[cancelButton, continueButton],
    );

    // ignore: inference_failure_on_function_invocation
    showDialog(context: context, builder: (BuildContext context) => alert);
  }

  ///
  Future<void> deleteKotlinRoomList() async {
    final WifiLocationApi api = WifiLocationApi();

    await api.deleteAllWifiLocations().then(
      // ignore: always_specify_types
      (value) {
        if (mounted) {
          // 削除完了後にすぐ画面遷移
          // ignore: use_build_context_synchronously
          Navigator.pop(context);

          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            // ignore: inference_failure_on_instance_creation, always_specify_types
            MaterialPageRoute(
              builder: (BuildContext context) => HomeScreen(
                baseYm: DateTime.now().yyyymm,
                tokyoMunicipalList: appParamState.keepTokyoMunicipalList,
                tokyoMunicipalMap: appParamState.keepTokyoMunicipalMap,
              ),
            ),
          );
        }
      },
    );
  }

  ///
  Future<void> _makeKotlinRoomDataList() async {
    KotlinRoomDataRepository().getAllKotlinRoomDataList().then(
      (List<KotlinRoomData>? value) {
        if (mounted) {
          setState(() => isarKotlinRoomDataList = value);
        }
      },
    );
  }
}
