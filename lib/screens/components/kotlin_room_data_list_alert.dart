import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../collections/kotlin_room_data.dart';
import '../../controllers/controllers_mixin.dart';
import '../../extensions/extensions.dart';
import '../../ripository/kotlin_room_data_repository.dart';
import '../home_screen.dart';
import '../parts/error_dialog.dart';

class KotlinRoomDataListAlert extends ConsumerStatefulWidget {
  const KotlinRoomDataListAlert({super.key});

  @override
  ConsumerState<KotlinRoomDataListAlert> createState() => _KotlinRoomDataListAlertState();
}

class _KotlinRoomDataListAlertState extends ConsumerState<KotlinRoomDataListAlert>
    with ControllersMixin<KotlinRoomDataListAlert> {
  List<KotlinRoomData>? kotlinRoomDataList;

  bool isLoading = false;

  final AutoScrollController autoScrollController = AutoScrollController();

  ///
  @override
  void initState() {
    super.initState();

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
                children: <Widget>[
                  Container(width: context.screenSize.width),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Kotlin Room Data List'),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              GestureDetector(
                                  onTap: () {
                                    if (kotlinRoomDataList != null) {
                                      autoScrollController.scrollToIndex(kotlinRoomDataList!.length);
                                    }
                                  },
                                  child: const Icon(Icons.arrow_downward_outlined)),
                              const SizedBox(width: 20),
                              GestureDetector(
                                onTap: () => autoScrollController.scrollToIndex(0),
                                child: const Icon(Icons.arrow_upward_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          IconButton(onPressed: () => _showDP(), icon: const Icon(Icons.calendar_month)),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _showDeleteDialog(),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent.withOpacity(0.2)),
                            child: const Text('delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(color: Colors.white.withOpacity(0.5), thickness: 5),
                  Expanded(child: displayKotlinRoomDataList()),
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
  void _makeKotlinRoomDataList() {
    KotlinRoomDataRepository().getAllKotlinRoomDataList().then((List<KotlinRoomData>? value) {
      if (mounted) {
        setState(() => kotlinRoomDataList = value);
      }
    });
  }

  ///
  Widget displayKotlinRoomDataList() {
    final List<Widget> list = <Widget>[];

    int i = 0;
    kotlinRoomDataList
      ?..sort((KotlinRoomData a, KotlinRoomData b) => '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}'))
      ..forEach((KotlinRoomData element) {
        list.add(AutoScrollTag(
          // ignore: always_specify_types
          key: ValueKey(i),
          index: i,
          controller: autoScrollController,
          child: Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.3)))),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[Text(element.date), Text(element.time)],
                  ),
                ),
                Expanded(child: Text(element.latitude)),
                Expanded(child: Text(element.longitude)),
                Checkbox(
                  value: appParamState.selectedKotlinRoomDataListForDelete.contains(element),
                  onChanged: (bool? value) =>
                      appParamNotifier.setSelectedKotlinRoomDataListForDelete(kotlinRoomData: element),
                  activeColor: Colors.greenAccent.withValues(alpha: 0.2),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ),
        ));

        i++;
      });

    return CustomScrollView(
      controller: autoScrollController,
      slivers: <Widget>[
        SliverList(
          delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) =>
                  DefaultTextStyle(style: const TextStyle(fontSize: 12), child: list[index]),
              childCount: list.length),
        ),
      ],
    );
  }

  ///
  void _showDeleteDialog() {
    final Widget cancelButton = TextButton(onPressed: () => Navigator.pop(context), child: const Text('いいえ'));

    final Widget continueButton = TextButton(
        onPressed: () {
          _deleteKotlinRoomDataList();

          Navigator.pop(context);
        },
        child: const Text('はい'));

    final AlertDialog alert = AlertDialog(
      backgroundColor: Colors.blueGrey.withOpacity(0.3),
      content: const Text('isarデータを消去しますか？'),
      actions: <Widget>[cancelButton, continueButton],
    );

    // ignore: inference_failure_on_function_invocation
    showDialog(context: context, builder: (BuildContext context) => alert);
  }

  ///
  Future<void> _deleteKotlinRoomDataList() async {
    setState(() => isLoading = true);

    if (appParamState.selectedKotlinRoomDataListForDelete.isNotEmpty) {
      final List<int> idList = <int>[];
      for (final KotlinRoomData element in appParamState.selectedKotlinRoomDataListForDelete) {
        idList.add(element.id);
      }

      if (idList.isNotEmpty) {
        KotlinRoomDataRepository().deleteKotlinRoomDataList(idList: idList).then(
          // ignore: always_specify_types
          (value) {
            if (mounted) {
              // ignore: always_specify_types
              Future.delayed(
                const Duration(seconds: 2),
                () {
                  setState(() => isLoading = false);

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
                },
              );
            }
          },
        );
      }
    }
  }

  ///
  Future<void> _showDP() async {
    final DateTime? selectedDate = await showDatePicker(
        barrierColor: Colors.transparent,
        locale: const Locale('ja'),
        context: context,
        firstDate: DateTime(DateTime.now().year - 2),
        lastDate: DateTime(DateTime.now().year + 3),
        initialDate: DateTime.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: Colors.black.withOpacity(0.1),
              canvasColor: Colors.black.withOpacity(0.1),
              cardColor: Colors.black.withOpacity(0.1),
              dividerColor: Colors.indigo,
              primaryColor: Colors.black.withOpacity(0.1),
              secondaryHeaderColor: Colors.black.withOpacity(0.1),
              dialogBackgroundColor: Colors.black.withOpacity(0.1),
              primaryColorDark: Colors.black.withOpacity(0.1),
              highlightColor: Colors.black.withOpacity(0.1),
            ),
            child: child!,
          );
        });

    if (selectedDate != null) {
      if (selectedDate.yyyymmdd != DateTime.now().yyyymmdd) {
        kotlinRoomDataList?.forEach((KotlinRoomData element) {
          if (selectedDate.yyyymmdd == element.date) {
            appParamNotifier.setSelectedKotlinRoomDataListForDelete(kotlinRoomData: element);
          }
        });
      } else {
        // ignore: always_specify_types
        Future.delayed(
          Duration.zero,
          () => error_dialog(
            // ignore: use_build_context_synchronously
            context: context,
            title: '削除不可',
            content: '本日分のデータは削除できません。',
          ),
        );

        return;
      }
    }
  }
}
