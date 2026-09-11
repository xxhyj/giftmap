import '../domain/history_entry.dart';

/// MVP 저장소.
///
/// 현재 프로젝트에는 로컬 영속화 패키지가 없으므로 인메모리로 구현한다.
/// 영속화는 저장 패키지 승인 후 같은 계약으로 교체한다.
final class InMemoryHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> _entries = <HistoryEntry>[];

  @override
  Future<List<HistoryEntry>> loadAll() async =>
      List<HistoryEntry>.unmodifiable(_entries);

  @override
  Future<void> save(HistoryEntry entry) async {
    _entries
      ..removeWhere((HistoryEntry e) => e.id == entry.id)
      ..insert(0, entry);
  }

  @override
  Future<void> delete(String id) async {
    _entries.removeWhere((HistoryEntry e) => e.id == id);
  }

  @override
  Future<void> clear() async => _entries.clear();
}
