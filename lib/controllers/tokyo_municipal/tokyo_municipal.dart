import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/municipal_model.dart';
import '../../utilities/functions.dart';
import '../../utilities/utilities.dart';

part 'tokyo_municipal.freezed.dart';

part 'tokyo_municipal.g.dart';

@freezed
class TokyoMunicipalState with _$TokyoMunicipalState {
  const factory TokyoMunicipalState({
    @Default(<MunicipalModel>[]) List<MunicipalModel> tokyoMunicipalList,
    @Default(<String, MunicipalModel>{}) Map<String, MunicipalModel> tokyoMunicipalMap,
  }) = _TokyoMunicipalState;
}

@riverpod
class TokyoMunicipal extends _$TokyoMunicipal {
  final Utility utility = Utility();

  ///
  @override
  TokyoMunicipalState build() => const TokyoMunicipalState();

  //============================================== api

  ///
  Future<TokyoMunicipalState> fetchAllTokyoMunicipalData() async {
    try {
      const String kAssetPath = 'assets/json/tokyo_municipal.geojson';

      final String text = await rootBundle.loadString(kAssetPath);

      // GeoJSON の解析は重いので別 isolate で実行する（起動直後の UI カクつき防止）
      final List<MunicipalModel> list = await parseMunicipalGeoJsonInBackground(text);

      final Map<String, MunicipalModel> map = <String, MunicipalModel>{
        for (final MunicipalModel val in list) val.name: val,
      };

      return state.copyWith(tokyoMunicipalList: list, tokyoMunicipalMap: map);
    } catch (e) {
      utility.showError('予期せぬエラーが発生しました');
      rethrow;
    }
  }

  ///
  Future<void> getAllTokyoMunicipalData() async {
    try {
      final TokyoMunicipalState newState = await fetchAllTokyoMunicipalData();

      state = newState;
    } catch (_) {}
  }

//============================================== api
}
