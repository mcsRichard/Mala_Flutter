import 'package:cloud_firestore/cloud_firestore.dart';

class GoalType {
  static const dailyCount = 'daily_count';
  static const checkin = 'checkin';
  static const lifetime = 'lifetime';
  static const course = 'course';
  static const deadline = 'deadline';

  static String label(String type) {
    switch (type) {
      case dailyCount: return '每日数量';
      case checkin:    return '每日打卡';
      case lifetime:   return '终生发愿';
      case course:     return '课程进度';
      case deadline:   return '限期完成';
      default:         return '每日数量';
    }
  }
}

class Practice {
  final String id;
  final String name;
  final String goalType;    // GoalType.*
  final int targetCount;    // daily target (daily_count), total (lifetime/deadline), lessons (course)
  final String? deadlineDate; // 'yyyy-MM-dd', only for deadline
  final bool isActive;
  final int sortOrder;

  const Practice({
    required this.id,
    required this.name,
    required this.goalType,
    required this.targetCount,
    this.deadlineDate,
    required this.isActive,
    required this.sortOrder,
  });

  factory Practice.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final tc = (d['targetCount'] as num?)?.toInt() ?? 0;
    // Infer goalType for practices created before this field existed
    final rawGoalType = d['goalType'] as String?;
    final goalType = rawGoalType ??
        (tc > 0 ? GoalType.dailyCount : GoalType.lifetime);
    return Practice(
      id: doc.id,
      name: d['name'] ?? '',
      goalType: goalType,
      targetCount: tc,
      deadlineDate: d['deadlineDate'] as String?,
      isActive: d['isActive'] ?? true,
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'goalType': goalType,
        'targetCount': targetCount,
        if (deadlineDate != null) 'deadlineDate': deadlineDate,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };

  bool get hasDaily =>
      goalType == GoalType.dailyCount || goalType == GoalType.checkin;
}

class PracticeLog {
  final String id;
  final String practiceId;
  final String practiceName;
  final int count;
  final String date;
  final DateTime createdAt;

  const PracticeLog({
    required this.id,
    required this.practiceId,
    required this.practiceName,
    required this.count,
    required this.date,
    required this.createdAt,
  });

  factory PracticeLog.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PracticeLog(
      id: doc.id,
      practiceId: d['practiceId'] ?? '',
      practiceName: d['practiceName'] ?? '',
      count: (d['count'] as num?)?.toInt() ?? 0,
      date: d['date'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
