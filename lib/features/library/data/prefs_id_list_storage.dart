import 'package:shared_preferences/shared_preferences.dart';

import '../domain/id_list_storage.dart';

/// 기기 로컬 저장소 구현.
///
/// 앱을 다시 켜도 찜과 최근 본 상품이 유지되도록 한다.
/// 저장소를 쓸 수 없는 환경(예: 플러그인이 없는 테스트)에서는 예외를 삼키고
/// 빈 목록처럼 동작해 화면이 깨지지 않게 한다.
final class PrefsIdListStorage implements IdListStorage {
  const PrefsIdListStorage();

  @override
  Future<List<String>> read(String key) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key) ?? const <String>[];
    } on Object {
      return const <String>[];
    }
  }

  @override
  Future<void> write(String key, List<String> ids) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, ids);
    } on Object {
      // 저장 실패는 사용자 흐름을 막지 않는다. 메모리 상태는 그대로 유지된다.
    }
  }
}
