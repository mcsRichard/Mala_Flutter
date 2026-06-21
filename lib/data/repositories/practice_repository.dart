import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/practice.dart';

class PracticeRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _practices =>
      _db.collection('users').doc(_uid).collection('practices');

  CollectionReference get _logs =>
      _db.collection('users').doc(_uid).collection('practice_log');

  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ── 功课管理 ──────────────────────────────────────────────────────────

  Stream<List<Practice>> watchPractices() {
    return _practices.snapshots().map((s) {
      final list = s.docs.map(Practice.fromDoc).toList();
      list.sort((a, b) {
        // Docs without sortOrder get value 0; use doc id as tiebreaker
        final c = a.sortOrder.compareTo(b.sortOrder);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
      return list;
    });
  }

  Future<void> addPractice({
    required String name,
    required String goalType,
    required int targetCount,
    String? deadlineDate,
  }) async {
    final snap = await _practices.get();
    final maxSort = snap.docs.fold<int>(0, (max, doc) {
      final v = ((doc.data() as Map)['sortOrder'] as num?)?.toInt() ?? 0;
      return v > max ? v : max;
    });
    await _practices.add({
      'name': name,
      'goalType': goalType,
      'targetCount': targetCount,
      if (deadlineDate != null) 'deadlineDate': deadlineDate,
      'isActive': true,
      'sortOrder': maxSort + 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePractice(
    String id, {
    required String name,
    required String goalType,
    required int targetCount,
    String? deadlineDate,
  }) async {
    await _practices.doc(id).update({
      'name': name,
      'goalType': goalType,
      'targetCount': targetCount,
      'deadlineDate': deadlineDate,
    });
  }

  Future<void> deletePractice(String id) async {
    await _practices.doc(id).delete();
  }

  Future<void> updateSortOrders(List<Practice> ordered) async {
    final batch = _db.batch();
    for (int i = 0; i < ordered.length; i++) {
      batch.update(_practices.doc(ordered[i].id), {'sortOrder': i});
    }
    await batch.commit();
  }

  // ── 打卡记录 ──────────────────────────────────────────────────────────

  Future<void> logPractice(
      String practiceId, String practiceName, int count) async {
    await _logs.add({
      'practiceId': practiceId,
      'practiceName': practiceName,
      'count': count,
      'date': _today(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<PracticeLog>> watchTodayLogs() {
    return _logs
        .where('date', isEqualTo: _today())
        .snapshots()
        .map((s) => s.docs.map(PracticeLog.fromDoc).toList());
  }

  Future<Map<String, int>> getTotalsByPractice() async {
    final snap = await _logs.get();
    final totals = <String, int>{};
    for (final doc in snap.docs) {
      final log = PracticeLog.fromDoc(doc);
      // Use practiceId as key; fall back to name for legacy logs imported without an id
      final key = log.practiceId.isNotEmpty ? log.practiceId : log.practiceName;
      totals[key] = (totals[key] ?? 0) + log.count;
    }
    return totals;
  }

  Future<List<PracticeLog>> getRecentLogs({int days = 30}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final fromStr = DateFormat('yyyy-MM-dd').format(from);
    final snap = await _logs
        .where('date', isGreaterThanOrEqualTo: fromStr)
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map(PracticeLog.fromDoc).toList();
  }

  /// Dates that have at least one log entry, for the past [days] days.
  Future<Set<String>> getActiveDates({int days = 90}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final fromStr = DateFormat('yyyy-MM-dd').format(from);
    final snap = await _logs
        .where('date', isGreaterThanOrEqualTo: fromStr)
        .get();
    return snap.docs.map((d) => (d.data() as Map)['date'] as String? ?? '').toSet();
  }

  /// How many consecutive days ending today (or yesterday) have practice logs.
  Future<int> getStreak() async {
    final activeDates = await getActiveDates(days: 400);
    final fmt = DateFormat('yyyy-MM-dd');
    int streak = 0;
    var day = DateTime.now();
    // If today has no log, start checking from yesterday
    if (!activeDates.contains(fmt.format(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    while (activeDates.contains(fmt.format(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Total number of distinct days with at least one log.
  Future<int> getTotalActiveDays() async {
    final activeDates = await getActiveDates(days: 3650);
    return activeDates.length;
  }

  /// For each of the last 7 days (oldest first), count of distinct practice
  /// IDs logged on that day. Returns list of [date, count] pairs.
  Future<List<_DayStats>> getWeekStats(List<Practice> practices) async {
    final dailyPractices = practices.where((p) => p.hasDaily).toList();
    final total = dailyPractices.length;
    final now = DateTime.now();
    final result = <_DayStats>[];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      final snap = await _logs.where('date', isEqualTo: dateStr).get();
      if (total == 0) {
        result.add(_DayStats(date: day, done: snap.docs.isEmpty ? 0 : 1, total: 1));
        continue;
      }
      final loggedIds = snap.docs
          .map((d) => (d.data() as Map)['practiceId'] as String? ?? '')
          .toSet();
      final done = dailyPractices.where((p) => loggedIds.contains(p.id)).length;
      result.add(_DayStats(date: day, done: done, total: total));
    }
    return result;
  }
}

class _DayStats {
  final DateTime date;
  final int done;
  final int total;

  const _DayStats({required this.date, required this.done, required this.total});
}
