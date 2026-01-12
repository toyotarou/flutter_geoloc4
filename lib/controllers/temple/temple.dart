import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/http/client.dart';
import '../../extensions/extensions.dart';
import '../../models/temple_latlng_model.dart';
import '../../models/temple_model.dart';
import '../../utilities/utilities.dart';

part 'temple.freezed.dart';

part 'temple.g.dart';

@freezed
class TempleControllerState with _$TempleControllerState {
  const factory TempleControllerState({
    @Default(<TempleInfoModel>[]) List<TempleInfoModel> templeInfoList,
    @Default(<String, List<TempleInfoModel>>{}) Map<String, List<TempleInfoModel>> templeInfoMap,
    @Default(<String, List<String>>{}) Map<String, List<String>> templeVisitedDateMap,
    @Default(<String, List<String>>{}) Map<String, List<String>> yearVisitedDateMap,
    @Default(<List<String>>[]) List<List<String>> templeSearchValueList,
  }) = _TempleControllerState;
}

@Riverpod(keepAlive: true)
class TempleController extends _$TempleController {
  final Utility utility = Utility();

  ///
  @override
  TempleControllerState build() => const TempleControllerState();

  ///
  Future<void> getAllTempleModel() async {
    final HttpClient client = ref.read(httpClientProvider);

    // ignore: always_specify_types
    await client.get(path: 'temple').then((templeValue) async {
      final List<TempleInfoModel> templeInfoList = <TempleInfoModel>[];
      final Map<String, List<TempleInfoModel>> templeInfoMap = <String, List<TempleInfoModel>>{};

      final Map<String, List<String>> templeVisitedDateMap = <String, List<String>>{};

      final Map<String, List<String>> yearVisitedDateMap = <String, List<String>>{};

      final List<List<String>> templeSearchValueList = <List<String>>[];

      //===============================================================================//

      final Map<String, TempleInfoModel> latlngModel = <String, TempleInfoModel>{};

      // ignore: always_specify_types
      await client.get(path: 'temple/latlng').then((templeLatLngValue) {
        // ignore: avoid_dynamic_calls
        for (int i = 0; i < templeLatLngValue.length.toString().toInt(); i++) {
          // ignore: avoid_dynamic_calls
          final TempleLatlngModel val3 = TempleLatlngModel.fromJson(templeLatLngValue[i] as Map<String, dynamic>);

          latlngModel[val3.temple] =
              TempleInfoModel(temple: val3.temple, address: val3.address, latitude: val3.lat, longitude: val3.lng);
        }
        // ignore: always_specify_types
      }).catchError((error, _) {
        utility.showError('予期せぬエラーが発生しました2');
      });

      //===============================================================================//

      // ignore: avoid_dynamic_calls
      for (int i = 0; i < templeValue.length.toString().toInt(); i++) {
        // ignore: avoid_dynamic_calls
        final TempleModel val = TempleModel.fromJson(templeValue[i] as Map<String, dynamic>);

        templeInfoMap['${val.year}-${val.month}-${val.day}'] = <TempleInfoModel>[];

        yearVisitedDateMap[val.year] = <String>[];

        ////////////////////////////////////////////
        templeVisitedDateMap[val.temple] = <String>[];

        val.memo?.split('、').forEach((String element) => templeVisitedDateMap[element] = <String>[]);

        ////////////////////////////////////////////
      }

      // ignore: avoid_dynamic_calls
      for (int i = 0; i < templeValue.length.toString().toInt(); i++) {
        // ignore: avoid_dynamic_calls
        final TempleModel val2 = TempleModel.fromJson(templeValue[i] as Map<String, dynamic>);

        final String date = '${val2.year}-${val2.month}-${val2.day}';

        /// templeとmemoを分割した神社名をリストに入れる
        final List<String> templeName = <String>[val2.temple];
        val2.memo?.split('、').forEach((String element) => templeName.add(element));

        templeSearchValueList.add(templeName);

        ///

        templeVisitedDateMap[val2.temple]?.add(date);

        //___________________________________________________________
        for (final String element2 in templeName) {
          final TempleInfoModel? templeInfoModelValueData = latlngModel[element2];

          //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
          if (templeInfoModelValueData != null) {
            final TempleInfoModel templeInfoModel = TempleInfoModel(
                temple: templeInfoModelValueData.temple,
                address: templeInfoModelValueData.address,
                latitude: templeInfoModelValueData.latitude,
                longitude: templeInfoModelValueData.longitude);

            templeInfoList.add(templeInfoModel);

            templeInfoMap[date]?.add(templeInfoModel);
          }
          //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

          templeVisitedDateMap[element2]?.add(date);
        }
        //___________________________________________________________

        yearVisitedDateMap[val2.year]?.add(date);
      }

      state = state.copyWith(
        templeInfoList: templeInfoList,
        templeInfoMap: templeInfoMap,
        templeVisitedDateMap: templeVisitedDateMap,
        yearVisitedDateMap: yearVisitedDateMap,
        templeSearchValueList: templeSearchValueList,
      );
      // ignore: always_specify_types
    }).catchError((error, _) {
      utility.showError('予期せぬエラーが発生しました');
    });
  }
}
