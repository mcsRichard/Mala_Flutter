import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  static const typeCheckin = 'CHECKIN';
  static const typeTotal = 'TOTAL';

  final String id;
  final String name;
  final String practiceName;
  final String targetType;
  final int targetValue;
  final String creatorId;
  final String creatorName;
  final int createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.practiceName,
    required this.targetType,
    required this.targetValue,
    required this.creatorId,
    required this.creatorName,
    required this.createdAt,
  });

  factory Group.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: d['name'] ?? '',
      practiceName: d['practiceName'] ?? '',
      targetType: d['targetType'] ?? typeCheckin,
      targetValue: (d['targetValue'] as num?)?.toInt() ?? 0,
      creatorId: d['creatorId'] ?? '',
      creatorName: d['creatorName'] ?? '',
      createdAt: (d['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class GroupMember {
  final String userId;
  final String displayName;
  final int total;
  final int targetValue;
  final bool doneToday;
  final int todayValue;

  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.total,
    required this.targetValue,
    required this.doneToday,
    required this.todayValue,
  });
}

class GroupStatus {
  final Group group;
  final int memberCount;
  final int todayDoneCount;
  final bool myDoneToday;
  final int myTotal;
  final int myTodayValue;
  final int myTargetValue;

  const GroupStatus({
    required this.group,
    required this.memberCount,
    required this.todayDoneCount,
    required this.myDoneToday,
    required this.myTotal,
    required this.myTodayValue,
    required this.myTargetValue,
  });
}
