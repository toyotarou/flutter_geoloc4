import 'package:isar/isar.dart';

import '../collections/geoloc.dart';
import 'isar_repository.dart';

class GeolocRepository {
  ///
  Future<List<Geoloc>?> getAllIsarGeoloc() async {
    await IsarRepository.configure();
    return IsarRepository.isar.geolocs.where().sortByDateDesc().thenByTimeDesc().findAll();
  }

  ///
  Future<Geoloc?> getRecentOneGeoloc() async {
    await IsarRepository.configure();

    // バックグラウンドで位置を受け取るたびに呼ばれる。
    // 以前は date / time にインデックスが無いため、毎回全件を並べ替えて先頭を取っていた（件数が増えるほど電池を消費）。
    // 記録は常に「現在時刻」で追加されるので、最後に追加されたもの（id が最大）が最新。主キーから1件だけ取得する
    return IsarRepository.isar.geolocs.where(sort: Sort.desc).anyId().findFirst();
  }

  ///
  Future<void> deleteGeolocList({required List<Geoloc>? geolocList}) async {
    if (geolocList == null || geolocList.isEmpty) {
      return;
    }

    await IsarRepository.configure();

    // 以前は1件ずつ（完了を待たずに）トランザクションを開いていた。1トランザクションでまとめて削除し、完了を待つ
    await IsarRepository.isar
        .writeTxn(() => IsarRepository.isar.geolocs.deleteAll(geolocList.map((Geoloc e) => e.id).toList()));
  }

  ///
  Future<void> deleteGeoloc({required int id}) async {
    await IsarRepository.configure();
    await IsarRepository.isar.writeTxn(() => IsarRepository.isar.geolocs.delete(id));
  }
}
