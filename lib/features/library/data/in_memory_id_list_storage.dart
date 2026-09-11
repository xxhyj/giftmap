import '../domain/id_list_storage.dart';

/// 테스트와 저장소 초기화 실패 시 사용하는 인메모리 구현.
final class InMemoryIdListStorage implements IdListStorage {
  InMemoryIdListStorage([Map<String, List<String>>? seed])
    : _values = <String, List<String>>{...?seed};

  final Map<String, List<String>> _values;

  @override
  Future<List<String>> read(String key) async =>
      List<String>.of(_values[key] ?? const <String>[]);

  @override
  Future<void> write(String key, List<String> ids) async {
    _values[key] = List<String>.of(ids);
  }
}
