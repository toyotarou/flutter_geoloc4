import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/http/client.dart';
import '../../models/geoloc_model.dart';
import '../../utilities/utilities.dart';

part 'geoloc.freezed.dart';

part 'geoloc.g.dart';

@freezed
class GeolocControllerState with _$GeolocControllerState {
  const factory GeolocControllerState({
    @Default(<GeolocModel>[]) List<GeolocModel> geolocList,
    @Default(<String, List<GeolocModel>>{}) Map<String, List<GeolocModel>> geolocMap,
    GeolocModel? oldestGeolocModel,
    @Default(<GeolocModel>[]) List<GeolocModel> recentGeolocList,
    @Default(<String, List<GeolocModel>>{}) Map<String, List<GeolocModel>> recentGeolocMap,
    @Default(<GeolocModel>[]) List<GeolocModel> allGeolocList,
    @Default(<String, List<GeolocModel>>{}) Map<String, List<GeolocModel>> allGeolocMap,
  }) = _GeolocControllerState;
}

@Riverpod(keepAlive: true)
class GeolocController extends _$GeolocController {
  final Utility utility = Utility();

  ///
  @override
  GeolocControllerState build() => const GeolocControllerState();

  ///
  Future<void> getYearMonthGeoloc({required String yearmonth}) async {
    final HttpClient client = ref.read(httpClientProvider);

    // ignore: always_specify_types
    await client.get(path: 'geoloc/yearmonth/$yearmonth').then((value) {
      final List<GeolocModel> list = <GeolocModel>[];
      final Map<String, List<GeolocModel>> map = <String, List<GeolocModel>>{};

      // 以前は同じ JSON を2回パースしていた。1回の走査で「日付ごとのリスト」まで作る（キーの並び順・中身は同じ）
      // ignore: avoid_dynamic_calls
      for (final dynamic item in value as List<dynamic>) {
        final GeolocModel val = GeolocModel.fromJson(item as Map<String, dynamic>);

        list.add(val);

        (map['${val.year}-${val.month}-${val.day}'] ??= <GeolocModel>[]).add(val);
      }

      state = state.copyWith(geolocList: list, geolocMap: map);
      // ignore: always_specify_types
    }).catchError((error, _) {
      utility.showError('予期せぬエラーが発生しました');
    });
  }

  ///
  Future<void> inputGeoloc({required Map<String, dynamic> map}) async {
    // ignore: always_specify_types
    await ref.read(httpClientProvider).post(path: 'geoloc', body: map).then((value) {}).catchError((error, _) {
      utility.showError('予期せぬエラーが発生しました');
    });
  }

  ///
  Future<void> deleteGeoloc({required String date}) async {
    // ignore: always_specify_types
    await ref
        .read(httpClientProvider)
        .deleteReturnBodyString(path: 'geoloc/date/$date')
        // ignore: always_specify_types
        .then((value) {})
        // ignore: always_specify_types
        .catchError((error, _) {
      utility.showError('予期せぬエラーが発生しました');
    });
  }

  ///
  Future<void> getOldestGeoloc() async {
    final HttpClient client = ref.read(httpClientProvider);

    // ignore: always_specify_types
    await client.get(path: 'geoloc/oldest').then((value) {
      GeolocModel geoloc = GeolocModel(id: 0, year: '', month: '', day: '', time: '', latitude: '', longitude: '');

      if (value != null) {
        // ignore: avoid_dynamic_calls
        geoloc = GeolocModel.fromJson(value[0] as Map<String, dynamic>);
      }

      state = state.copyWith(oldestGeolocModel: geoloc);

      // ignore: always_specify_types
    }).catchError((error, _) {
      utility.showError('予期せぬエラーが発生しました');
    });
  }

  ///
  Future<void> getRecentGeoloc() async {
    final HttpClient client = ref.read(httpClientProvider);

    // ignore: always_specify_types
    await client.get(path: 'geoloc/recent').then((value) {
      final List<GeolocModel> list = <GeolocModel>[];
      final Map<String, List<GeolocModel>> map = <String, List<GeolocModel>>{};

      // 以前は同じ JSON を2回パースしていた。1回の走査で「日付ごとのリスト」まで作る（キーの並び順・中身は同じ）
      // ignore: avoid_dynamic_calls
      for (final dynamic item in value as List<dynamic>) {
        final GeolocModel val = GeolocModel.fromJson(item as Map<String, dynamic>);

        list.add(val);

        (map['${val.year}-${val.month}-${val.day}'] ??= <GeolocModel>[]).add(val);
      }

      state = state.copyWith(recentGeolocList: list, recentGeolocMap: map);
      // ignore: always_specify_types
    }).catchError((error, _) {
      utility.showError('予期せぬエラーが発生しました');
    });
  }

  //---------------------------------------------------------------//

  ///
  Future<GeolocControllerState> _fetchAllGeolocData() async {
    final HttpClient client = ref.read(httpClientProvider);

    try {
      // ignore: always_specify_types
      final dynamic value = await client.get(path: 'geoloc');

      final List<GeolocModel> list = <GeolocModel>[];
      final Map<String, List<GeolocModel>> map = <String, List<GeolocModel>>{};

      // 以前は同じ JSON を2回パースしていた。1回の走査で「日付ごとのリスト」まで作る（キーの並び順・中身は同じ）
      // ignore: avoid_dynamic_calls
      for (final dynamic item in value as List<dynamic>) {
        final GeolocModel val = GeolocModel.fromJson(item as Map<String, dynamic>);

        list.add(val);

        (map['${val.year}-${val.month}-${val.day}'] ??= <GeolocModel>[]).add(val);
      }

      return state.copyWith(allGeolocList: list, allGeolocMap: map);
    } catch (e) {
      utility.showError('予期せぬエラーが発生しました');
      rethrow; // これにより呼び出し元でキャッチできる
    }
  }

  ///
  Future<void> getAllGeoloc() async {
    try {
      final GeolocControllerState newState = await _fetchAllGeolocData();

      state = newState;
    } catch (_) {}
  }

//---------------------------------------------------------------//
}
