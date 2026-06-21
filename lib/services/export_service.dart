import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../data/repositories/practice_repository.dart';
import '../data/repositories/group_repository.dart';

class ExportService {
  static Future<void> exportAll() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final practiceRepo = PracticeRepository();
    final groupRepo = GroupRepository();

    final buf = StringBuffer();
    // UTF-8 BOM for Excel compatibility
    buf.write('﻿');

    // ── 功课记录 ──
    buf.writeln('功课记录');
    buf.writeln('功课名称,日期,数量');
    final logs = await practiceRepo.getRecentLogs(days: 3650);
    for (final log in logs) {
      buf.writeln('${_csv(log.practiceName)},${log.date},${log.count}');
    }

    buf.writeln();

    // ── 累计汇总 ──
    buf.writeln('各功课累计');
    buf.writeln('功课名称,累计数量');
    final totals = await practiceRepo.getTotalsByPractice();
    for (final e in totals.entries) {
      buf.writeln('${_csv(e.key)},${e.value}');
    }

    buf.writeln();

    // ── 共修小组 ──
    buf.writeln('共修小组');
    buf.writeln('小组名称,功课名称,我的累计');
    final groups = await groupRepo.getMyGroups();
    for (final s in groups) {
      buf.writeln('${_csv(s.group.name)},${_csv(s.group.practiceName)},${s.myTotal}');
    }

    // 写入临时文件
    final dir = await getTemporaryDirectory();
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/mala_export_$date.csv');
    await file.writeAsString(buf.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Mala 功课记录导出',
    );
  }

  static String _csv(String s) =>
      s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
}
