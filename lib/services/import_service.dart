import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/practice.dart';

class ImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const ImportResult(
      {required this.imported, required this.skipped, required this.errors});
}

class ImportService {
  static Future<String?> pickCsvFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  static Future<ImportResult> importFromCsv(String filePath) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const ImportResult(imported: 0, skipped: 0, errors: ['未登录']);
    }

    final raw = await File(filePath).readAsString();
    final content = raw.startsWith('﻿') ? raw.substring(1) : raw;
    final lines = content.split('\n').map((l) => l.trimRight()).toList();

    // Detect format: Android app uses "## SectionName", Flutter app uses plain names
    if (lines.any((l) => l.startsWith('## '))) {
      return _importAndroidFormat(uid, lines);
    } else {
      return _importFlutterFormat(uid, lines);
    }
  }

  // ── Android app export ────────────────────────────────────────────────────
  // "## 功课记录" header; columns: 功课名称,类型,目标类型,目标数量,截止日期,累计完成次数,创建时间
  // Imports practice definitions + accumulated total as a single historical log entry.
  static Future<ImportResult> _importAndroidFormat(
      String uid, List<String> lines) async {
    int imported = 0, skipped = 0;
    final errors = <String>[];

    // Find "## 功课记录" section
    int sectionLine = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim() == '## 功课记录') {
        sectionLine = i;
        break;
      }
    }
    if (sectionLine == -1) {
      return const ImportResult(
          imported: 0,
          skipped: 0,
          errors: ['未找到「功课记录」段，请确认导出文件格式正确']);
    }

    final headerLine = sectionLine + 1;
    if (headerLine >= lines.length) {
      return const ImportResult(
          imported: 0, skipped: 0, errors: ['功课记录段缺少表头']);
    }

    final header = _parseCsvRow(lines[headerLine]);
    final nameIdx   = _findCol(header, ['功课名称', 'name']);
    final goalIdx   = _findCol(header, ['目标类型', 'goalType']);
    final targetIdx = _findCol(header, ['目标数量', 'target', 'targetValue']);
    final dlIdx     = _findCol(header, ['截止日期', 'deadline', 'deadlineDate']);
    final totalIdx  = _findCol(header, ['累计完成次数', 'total', 'count']);
    final dateIdx   = _findCol(header, ['创建时间', 'createdAt', 'date']);

    if (nameIdx == -1) {
      return ImportResult(
          imported: 0,
          skipped: 0,
          errors: ['无法识别表头：${header.join(",")}']);
    }

    final db = FirebaseFirestore.instance;
    final practicesCol =
        db.collection('users').doc(uid).collection('practices');
    final logsCol =
        db.collection('users').doc(uid).collection('practice_log');

    // Load existing practices (name → docId)
    final existingPractices = await practicesCol.get();
    final practicesByName = <String, String>{};
    int maxSort = 0;
    for (final doc in existingPractices.docs) {
      final n = (doc.data()['name'] as String? ?? '').trim();
      if (n.isNotEmpty) practicesByName[n] = doc.id;
      final s = (doc.data()['sortOrder'] as num?)?.toInt() ?? 0;
      if (s > maxSort) maxSort = s;
    }

    // Load existing log keys for dedup
    final existingLogs = await logsCol.get();
    final existingKeys = existingLogs.docs.map((d) {
      final data = d.data();
      return '${data['practiceName']}_${data['date']}';
    }).toSet();

    // Parse data rows (stop at blank line or next ## section)
    final rows = <_PracticeRow>[];
    for (int i = headerLine + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#')) break;
      final cols = _parseCsvRow(line);

      String _col(int idx) =>
          (idx != -1 && idx < cols.length) ? cols[idx].trim() : '';

      final name = _col(nameIdx);
      if (name.isEmpty) continue;

      rows.add(_PracticeRow(
        name: name,
        goalType: _mapGoalType(_col(goalIdx)),
        targetCount: int.tryParse(_col(targetIdx)) ?? 0,
        deadline: _col(dlIdx).isNotEmpty ? _col(dlIdx) : null,
        total: int.tryParse(_col(totalIdx)) ?? 0,
        createdDate: _normalizeDate(_col(dateIdx)) ?? '2020-01-01',
      ));
    }

    if (rows.isEmpty) {
      return const ImportResult(
          imported: 0, skipped: 0, errors: ['功课记录段无有效数据']);
    }

    var batch = db.batch();
    int batchCount = 0;

    for (final row in rows) {
      // 1. Upsert practice definition
      if (practicesByName.containsKey(row.name)) {
        // Update goal settings on existing practice
        await practicesCol.doc(practicesByName[row.name]!).update({
          'goalType': row.goalType,
          'targetCount': row.targetCount,
          'deadlineDate': row.deadline,
        });
      } else {
        maxSort++;
        final ref = practicesCol.doc();
        await ref.set({
          'name': row.name,
          'goalType': row.goalType,
          'targetCount': row.targetCount,
          if (row.deadline != null) 'deadlineDate': row.deadline,
          'isActive': true,
          'sortOrder': maxSort,
          'createdAt': FieldValue.serverTimestamp(),
        });
        practicesByName[row.name] = ref.id;
      }

      // 2. Import accumulated total as one historical log entry
      if (row.total <= 0) {
        skipped++;
        continue;
      }
      final key = '${row.name}_${row.createdDate}';
      if (existingKeys.contains(key)) {
        skipped++;
        continue;
      }

      final ref = logsCol.doc();
      batch.set(ref, {
        'practiceId': practicesByName[row.name] ?? '',
        'practiceName': row.name,
        'count': row.total,
        'date': row.createdDate,
        'createdAt': FieldValue.serverTimestamp(),
        'imported': true,
      });
      existingKeys.add(key);
      batchCount++;
      imported++;

      if (batchCount >= 450) {
        try {
          await batch.commit();
        } catch (e) {
          errors.add('批量写入失败：$e');
        }
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      try {
        await batch.commit();
      } catch (e) {
        errors.add('最终写入失败：$e');
      }
    }

    // Also import 传承灌顶 section if present
    final empowermentResult = await _importEmpowerments(uid, lines);
    return ImportResult(
      imported: imported + empowermentResult.imported,
      skipped: skipped + empowermentResult.skipped,
      errors: [...errors, ...empowermentResult.errors],
    );
  }

  // ── 传承灌顶 ──────────────────────────────────────────────────────────────
  // "## 传承灌顶" header; columns: 名称,上师,时间,地点,备注
  static Future<ImportResult> _importEmpowerments(
      String uid, List<String> lines) async {
    int sectionLine = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim() == '## 传承灌顶') {
        sectionLine = i;
        break;
      }
    }
    if (sectionLine == -1) return const ImportResult(imported: 0, skipped: 0, errors: []);

    final headerLine = sectionLine + 1;
    if (headerLine >= lines.length) return const ImportResult(imported: 0, skipped: 0, errors: []);

    final header = _parseCsvRow(lines[headerLine]);
    final nameIdx    = _findCol(header, ['名称', 'name']);
    final teacherIdx = _findCol(header, ['上师', 'teacher', 'guru']);
    final dateIdx    = _findCol(header, ['时间', 'date', '日期']);
    final placeIdx   = _findCol(header, ['地点', 'place', 'location']);
    final notesIdx   = _findCol(header, ['备注', 'notes', 'remark']);

    if (nameIdx == -1) return const ImportResult(imported: 0, skipped: 0, errors: []);

    final db = FirebaseFirestore.instance;
    final col = db.collection('users').doc(uid).collection('transmissions');

    // Load existing records for dedup (by name+date)
    final existing = await col.get();
    final existingKeys = existing.docs.map((d) {
      final data = d.data();
      return '${data['name']}_${data['date']}';
    }).toSet();

    String _col(List<String> cols, int idx) =>
        (idx != -1 && idx < cols.length) ? cols[idx].trim() : '';

    int imported = 0, skipped = 0;
    final errors = <String>[];
    var batch = db.batch();
    int batchCount = 0;

    for (int i = headerLine + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#')) break;
      final cols = _parseCsvRow(line);
      final name = _col(cols, nameIdx);
      if (name.isEmpty) continue;
      final date = _normalizeDate(_col(cols, dateIdx)) ?? _col(cols, dateIdx);
      final key = '${name}_$date';
      if (existingKeys.contains(key)) {
        skipped++;
        continue;
      }
      final ref = col.doc();
      batch.set(ref, {
        'name': name,
        'teacher': _col(cols, teacherIdx),
        'date': date,
        'place': _col(cols, placeIdx),
        'notes': _col(cols, notesIdx),
        'createdAt': FieldValue.serverTimestamp(),
      });
      existingKeys.add(key);
      batchCount++;
      imported++;
      if (batchCount >= 450) {
        try { await batch.commit(); } catch (e) { errors.add('传承写入失败：$e'); }
        batch = db.batch();
        batchCount = 0;
      }
    }
    if (batchCount > 0) {
      try { await batch.commit(); } catch (e) { errors.add('传承最终写入失败：$e'); }
    }
    return ImportResult(imported: imported, skipped: skipped, errors: errors);
  }

  // ── Flutter app export ────────────────────────────────────────────────────
  // Plain "功课记录" header; columns: 功课名称,日期,数量 (daily log entries)
  static Future<ImportResult> _importFlutterFormat(
      String uid, List<String> lines) async {
    int sectionStart = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim() == '功课记录') {
        sectionStart = i + 1;
        break;
      }
    }
    if (sectionStart == -1) {
      return const ImportResult(
          imported: 0,
          skipped: 0,
          errors: ['未找到「功课记录」段，请确认导出文件格式正确']);
    }

    final header = _parseCsvRow(lines[sectionStart]);
    final nameIdx  = _findCol(header, ['功课名称', '名称', 'name']);
    final dateIdx  = _findCol(header, ['日期', 'date']);
    final countIdx = _findCol(header, ['数量', '次数', 'count', '遍']);

    if (nameIdx == -1 || dateIdx == -1 || countIdx == -1) {
      return ImportResult(
          imported: 0,
          skipped: 0,
          errors: ['无法识别列格式，header: ${header.join(",")}']);
    }

    final logs = <Map<String, dynamic>>[];
    for (int i = sectionStart + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) break;
      final cols = _parseCsvRow(line);
      final maxIdx =
          [nameIdx, dateIdx, countIdx].reduce((a, b) => a > b ? a : b);
      if (cols.length <= maxIdx) continue;
      final name  = cols[nameIdx].trim();
      final date  = cols[dateIdx].trim();
      final count = int.tryParse(cols[countIdx].trim()) ?? 0;
      if (name.isEmpty || date.isEmpty || count <= 0) continue;
      logs.add({'name': name, 'date': date, 'count': count});
    }

    if (logs.isEmpty) {
      return const ImportResult(
          imported: 0, skipped: 0, errors: ['功课记录段为空']);
    }

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('practice_log');

    final existing = await col.get();
    final existingKeys = existing.docs.map((d) {
      final data = d.data();
      return '${data['practiceName']}_${data['date']}';
    }).toSet();

    int imported = 0, skipped = 0;
    final errors = <String>[];
    var batch = FirebaseFirestore.instance.batch();
    int batchCount = 0;

    for (final log in logs) {
      final key = '${log['name']}_${log['date']}';
      if (existingKeys.contains(key)) {
        skipped++;
        continue;
      }
      final ref = col.doc();
      batch.set(ref, {
        'practiceId': '',
        'practiceName': log['name'],
        'count': log['count'],
        'date': log['date'],
        'createdAt': FieldValue.serverTimestamp(),
        'imported': true,
      });
      batchCount++;
      imported++;
      if (batchCount >= 450) {
        try {
          await batch.commit();
        } catch (e) {
          errors.add('批量写入失败：$e');
        }
        batch = FirebaseFirestore.instance.batch();
        batchCount = 0;
      }
    }
    if (batchCount > 0) {
      try {
        await batch.commit();
      } catch (e) {
        errors.add('最终写入失败：$e');
      }
    }

    return ImportResult(imported: imported, skipped: skipped, errors: errors);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _mapGoalType(String raw) {
    switch (raw.trim()) {
      case '限期完成': return GoalType.deadline;
      case '每日数量': return GoalType.dailyCount;
      case '终生累计': return GoalType.lifetime;
      case '课程进度': return GoalType.course;
      case '每日打卡': return GoalType.checkin;
      default:       return GoalType.dailyCount;
    }
  }

  static String? _normalizeDate(String raw) {
    if (raw.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;
    final m = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(raw);
    return m?.group(1);
  }

  static int _findCol(List<String> header, List<String> candidates) {
    for (final c in candidates) {
      final idx = header.indexWhere(
          (h) => h.trim().toLowerCase() == c.toLowerCase());
      if (idx != -1) return idx;
    }
    return -1;
  }

  static List<String> _parseCsvRow(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuote = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuote = !inQuote;
        }
      } else if (ch == ',' && !inQuote) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString());
    return result;
  }
}

class _PracticeRow {
  final String name;
  final String goalType;
  final int targetCount;
  final String? deadline;
  final int total;
  final String createdDate;

  const _PracticeRow({
    required this.name,
    required this.goalType,
    required this.targetCount,
    this.deadline,
    required this.total,
    required this.createdDate,
  });
}
