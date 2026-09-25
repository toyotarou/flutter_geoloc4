import 'package:isar/isar.dart';

import '../collections/kotlin_room_data.dart';
import 'isar_repository.dart';

class KotlinRoomDataRepository {
  ///
  Future<List<KotlinRoomData>?> getAllKotlinRoomDataList() async {
    await IsarRepository.configure();
    return IsarRepository.isar.kotlinRoomDatas.where().sortByDateDesc().thenByTimeDesc().findAll();
  }

  ///
  Future<void> inputKotlinRoomDataList({required List<KotlinRoomData> kotlinRoomDataList}) async {
    await IsarRepository.configure();

    // 以前は1件ずつ（完了を待たずに）トランザクションを開いていた。1トランザクションでまとめて登録し、完了を待つ
    await IsarRepository.isar.writeTxn(() async => IsarRepository.isar.kotlinRoomDatas.putAll(kotlinRoomDataList));
  }

  ///
  Future<void> inputKotlinRoomData({required KotlinRoomData kotlinRoomData}) async {
    await IsarRepository.configure();
    await IsarRepository.isar.writeTxn(() async => IsarRepository.isar.kotlinRoomDatas.put(kotlinRoomData));
  }

  ///
  Future<void> deleteKotlinRoomDataList({required List<int> idList}) async {
    await IsarRepository.configure();

    // 以前は1件ずつ（完了を待たずに）トランザクションを開いていた。1トランザクションでまとめて削除し、完了を待つ
    await IsarRepository.isar.writeTxn(() => IsarRepository.isar.kotlinRoomDatas.deleteAll(idList));
  }

  ///
  Future<void> deleteKotlinRoomData({required int id}) async {
    await IsarRepository.configure();
    await IsarRepository.isar.writeTxn(() => IsarRepository.isar.kotlinRoomDatas.delete(id));
  }
}
