import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../extensions/extensions.dart';
import '../models/temple_latlng_model.dart';

class Utility {
  /// 背景取得
  // ignore: always_specify_types
  Widget getBackGround({context}) {
    return Image.asset('assets/images/bg.png',
        fit: BoxFit.fitHeight, color: Colors.black.withOpacity(0.7), colorBlendMode: BlendMode.darken);
  }

  ///
  void showError(String msg) {
    // navigatorKey が MaterialApp に接続されていない（context が null）ときに、
    // null チェック例外で元のエラー処理を壊さないようにする
    final BuildContext? context = NavigationService.navigatorKey.currentContext;

    if (context == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
  }

  ///
  Color getYoubiColor({
    required String date,
    required String youbiStr,
    required Map<String, String> holidayMap,
  }) {
    Color color = Colors.black.withOpacity(0.2);

    switch (youbiStr) {
      case 'Sunday':
        color = Colors.redAccent.withOpacity(0.2);

      case 'Saturday':
        color = Colors.blueAccent.withOpacity(0.2);

      default:
        color = Colors.black.withOpacity(0.2);
    }

    if (holidayMap[date] != null) {
      color = Colors.greenAccent.withOpacity(0.2);
    }

    return color;
  }

  ///
  double calculateDistance(LatLng p1, LatLng p2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, p1, p2);
  }

  ///
  List<Color> getFortyEightColor() => _fortyEightColor;

  /// 呼び出しのたびに48色のリストを生成しないよう const で保持
  static const List<Color> _fortyEightColor = <Color>[
    Color(0xFFE53935), // 赤
    Color(0xFF1E88E5), // 青
    Color(0xFF43A047), // 緑
    Color(0xFF8E24AA), // 紫
    Color(0xFFFFA726), // オレンジ
    Color(0xFF00ACC1), // シアン
    Color(0xFFFDD835), // 黄
    Color(0xFF6D4C41), // 茶
    Color(0xFFD81B60), // ピンク
    Color(0xFF3949AB), // インディゴ
    Color(0xFF00897B), // ティール
    Color(0xFF7CB342), // ライムグリーン
    Color(0xFF5E35B1), // ディープパープル
    Color(0xFFFB8C00), // 濃いオレンジ
    Color(0xFF00838F), // 濃いシアン
    Color(0xFFF4511E), // 赤橙
    Color(0xFF558B2F), // 濃い黄緑
    Color(0xFF6A1B9A), // 濃い紫
    Color(0xFF2E7D32), // ダークグリーン
    Color(0xFF283593), // ダークブルー
    Color(0xFFAD1457), // ダークピンク
    Color(0xFF4E342E), // ダークブラウン
    Color(0xFF1565C0), // 濃い青
    Color(0xFF9E9D24), // オリーブ
    Color(0xCC42A5F5), // 明るい青 (80%)
    Color(0xCC66BB6A), // 明るい緑 (80%)
    Color(0xCCAB47BC), // 明るい紫 (80%)
    Color(0xCCFFB74D), // 明るいオレンジ (80%)
    Color(0xCC26C6DA), // 明るいシアン (80%)
    Color(0xCCFFF176), // 明るい黄 (80%)
    Color(0xCC8D6E63), // 明るい茶 (80%)
    Color(0xCCF06292), // 明るいピンク (80%)
    Color(0xCC5C6BC0), // 明るいインディゴ (80%)
    Color(0xCC26A69A), // 明るいティール (80%)
    Color(0xCC9CCC65), // 明るいライム (80%)
    Color(0xCC9575CD), // 明るいパープル (80%)
    Color(0x99FFCC80), // 淡いオレンジ (60%)
    Color(0x9980DEEA), // 淡いシアン (60%)
    Color(0x99FFAB91), // サーモン (60%)
    Color(0x99C5E1A5), // 淡い緑 (60%)
    Color(0x99B39DDB), // 淡い紫 (60%)
    Color(0x99A5D6A7), // ミントグリーン (60%)
    Color(0x999FA8DA), // 淡い青 (60%)
    Color(0x99F48FB1), // 淡いピンク (60%)
    Color(0x99BCAAA4), // 淡いブラウン (60%)
    Color(0xCCEF5350), // 明るい赤 (80%)
    Color(0xFFBDBDBD), // グレー
    Color(0xFFE0E0E0), // ライトグレー
  ];

  ///
  List<String> getTempleGeolocNearlyDateList(
      {required String date, required Map<String, List<TempleInfoModel>> templeInfoMap}) {
    final Set<String> templeGeolocNearlyDateSet = <String>{};

    if (templeInfoMap[date] != null) {
      for (final TempleInfoModel element in templeInfoMap[date]!) {
        final LatLng baseLatLng = LatLng(element.latitude.toDouble(), element.longitude.toDouble());

        templeInfoMap.forEach((String key, List<TempleInfoModel> value) {
          if (value.length > 1) {
            for (final TempleInfoModel element2 in value) {
              if (double.tryParse(element2.latitude) != null && double.tryParse(element2.longitude) != null) {
                final LatLng targetLatLng = LatLng(element2.latitude.toDouble(), element2.longitude.toDouble());

                final double dist = calculateDistance(baseLatLng, targetLatLng);

                if (dist < 100.0) {
                  if (key != date) {
                    templeGeolocNearlyDateSet.add(key);

                    continue;
                  }
                }
              }
            }
          }
        });
      }
    }

    final List<String> list = templeGeolocNearlyDateSet.toList()..sort();

    return list;
  }
}

/// Isar のコレクション変更（isar.xxx.watchLazy()）などを監視し、変更があったらコールバックを呼ぶ。
/// 短時間に何度も変更が来た場合は、最後の変更から [debounce] 後に1回だけ呼ぶ。
///
/// 以前は画面の build の中で毎回 Isar を読み直し → setState → build … を繰り返して最新化していた
/// （画面を開いている間ずっと全件読み込みが走り続けていた）ため、その代わりに使う。
class IsarChangeWatcher {
  IsarChangeWatcher({
    required List<Stream<void>> streams,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 150),
  }) {
    for (final Stream<void> stream in streams) {
      _subscriptions.add(stream.listen((_) => notify()));
    }
  }

  final VoidCallback onChanged;

  final Duration debounce;

  final List<StreamSubscription<void>> _subscriptions = <StreamSubscription<void>>[];

  Timer? _timer;

  /// 監視対象以外のきっかけ（位置情報の受信など）で読み直したいときに呼ぶ
  void notify() {
    _timer?.cancel();
    _timer = Timer(debounce, onChanged);
  }

  ///
  void dispose() {
    _timer?.cancel();

    for (final StreamSubscription<void> subscription in _subscriptions) {
      subscription.cancel();
    }

    _subscriptions.clear();
  }
}

class NavigationService {
  const NavigationService._();

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
