import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../collections/config.dart';
import '../collections/geoloc.dart';
import '../collections/kotlin_room_data.dart';

class IsarRepository {
  IsarRepository._();

  static Isar get isar => _isar!;

  static Isar? _isar;

  /// 初期化中の Future（同時に複数回呼ばれても Isar.open を1回だけにするため）
  static Future<void>? _opening;

  static Future<void> configure() {
    if (_isar != null) {
      return Future<void>.value();
    }

    // 以前は configure() がほぼ同時に2回呼ばれると、両方が Isar.open まで進んで
    // 「既に開かれている」例外になる恐れがあった。初期化中なら同じ Future を待たせる
    return _opening ??= _open();
  }

  ///
  static Future<void> _open() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();

      // ignore: strict_raw_type, always_specify_types
      _isar = await Isar.open(<CollectionSchema>[GeolocSchema, ConfigSchema, KotlinRoomDataSchema], directory: dir.path);
    } finally {
      // 失敗した場合は次回の呼び出しで再試行できるようにする
      _opening = null;
    }
  }
}
