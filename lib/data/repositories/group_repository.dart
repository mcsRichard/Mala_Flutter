import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/group.dart';

class GroupRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';
  String get _myName {
    final user = _auth.currentUser;
    if (user == null) return '佚名';
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    return user.email?.split('@').first ?? '佚名';
  }

  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  DocumentReference _groupDoc(String groupId) =>
      _db.collection('groups').doc(groupId);

  DocumentReference _pointerDoc(String groupId) => _db
      .collection('users')
      .doc(_uid)
      .collection('groups')
      .doc(groupId);

  // ── 创建 ──────────────────────────────────────────────────────────────

  Future<String> createGroup({
    required String name,
    required String practiceName,
    required String targetType,
    required int targetValue,
  }) async {
    var code = _generateCode();
    for (int i = 0; i < 5; i++) {
      if (!(await _groupDoc(code).get()).exists) break;
      code = _generateCode();
    }
    final groupTarget = targetType == Group.typeCheckin ? targetValue : 0;
    await _groupDoc(code).set({
      'name': name,
      'practiceName': practiceName,
      'targetType': targetType,
      'targetValue': groupTarget,
      'creatorId': _uid,
      'creatorName': _myName,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _addMembership(
      code,
      targetType == Group.typeTotal ? targetValue : 0,
    );
    return code;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── 查询 ──────────────────────────────────────────────────────────────

  Future<Group?> getGroup(String groupId) async {
    final doc = await _groupDoc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromDoc(doc);
  }

  Future<List<GroupMember>> getMembers(
    String groupId, {
    String targetType = Group.typeCheckin,
    int targetValue = 0,
  }) async {
    final today = _today();
    final memberDocs =
        await _groupDoc(groupId).collection('members').get();
    final checkinDocs = await _groupDoc(groupId)
        .collection('checkins')
        .where('date', isEqualTo: today)
        .get();

    final todayMap = {
      for (final d in checkinDocs.docs)
        (d.data()['userId'] as String? ?? ''): (d.data()['value'] as num?)?.toInt() ?? 0
    };

    final members = memberDocs.docs.map((d) {
      final data = d.data();
      final todayVal = todayMap[d.id] ?? 0;
      final memberTarget = (data['targetValue'] as num?)?.toInt() ?? 0;
      final doneToday = (targetType == Group.typeCheckin && targetValue > 0)
          ? todayVal >= targetValue
          : todayVal > 0;
      return GroupMember(
        userId: d.id,
        displayName: data['displayName'] ?? '',
        total: (data['total'] as num?)?.toInt() ?? 0,
        targetValue: memberTarget,
        doneToday: doneToday,
        todayValue: todayVal,
      );
    }).toList();

    members.sort((a, b) => b.total.compareTo(a.total));
    return members;
  }

  Future<bool> isMember(String groupId) async {
    return (await _groupDoc(groupId)
            .collection('members')
            .doc(_uid)
            .get())
        .exists;
  }

  Future<List<GroupStatus>> getMyGroups() async {
    if (_uid.isEmpty) return [];
    final pointers = await _db
        .collection('users')
        .doc(_uid)
        .collection('groups')
        .get();

    final results = <GroupStatus>[];
    for (final p in pointers.docs) {
      final group = await getGroup(p.id);
      if (group == null) {
        await p.reference.delete();
        continue;
      }
      final members = await getMembers(
        p.id,
        targetType: group.targetType,
        targetValue: group.targetValue,
      );
      final me = members.where((m) => m.userId == _uid).firstOrNull;
      results.add(GroupStatus(
        group: group,
        memberCount: members.length,
        todayDoneCount: members.where((m) => m.doneToday).length,
        myDoneToday: me?.doneToday ?? false,
        myTotal: me?.total ?? 0,
        myTodayValue: me?.todayValue ?? 0,
        myTargetValue: me?.targetValue ?? 0,
      ));
    }
    return results;
  }

  // ── 加入 / 退出 ───────────────────────────────────────────────────────

  Future<void> joinGroup(String groupId, {int targetValue = 0}) async {
    await _addMembership(groupId, targetValue);
  }

  Future<void> _addMembership(String groupId, int targetValue) async {
    await _groupDoc(groupId).collection('members').doc(_uid).set(
      {
        'displayName': _myName,
        'joinedAt': DateTime.now().millisecondsSinceEpoch,
        'total': 0,
        'targetValue': targetValue,
      },
      SetOptions(merge: true),
    );
    await _pointerDoc(groupId)
        .set({'joinedAt': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> leaveGroup(String groupId) async {
    await _groupDoc(groupId).collection('members').doc(_uid).delete();
    await _pointerDoc(groupId).delete();
  }

  // ── 打卡 ──────────────────────────────────────────────────────────────

  Future<void> checkIn(String groupId, int value) async {
    final today = _today();
    await _groupDoc(groupId)
        .collection('checkins')
        .doc('${_uid}_$today')
        .set(
      {
        'userId': _uid,
        'date': today,
        'value': FieldValue.increment(value),
        'displayName': _myName,
      },
      SetOptions(merge: true),
    );
    await _groupDoc(groupId)
        .collection('members')
        .doc(_uid)
        .update({'total': FieldValue.increment(value)});
  }

  Future<void> updateMemberTarget(String groupId, int targetValue) async {
    await _groupDoc(groupId)
        .collection('members')
        .doc(_uid)
        .update({'targetValue': targetValue});
  }

  // ── 管理员操作 ────────────────────────────────────────────────────────

  Future<void> updateGoal(
      String groupId, String targetType, int targetValue) async {
    await _groupDoc(groupId).update({
      'targetType': targetType,
      'targetValue': targetValue,
    });
  }

  Future<void> deleteGroup(String groupId) async {
    final members =
        await _groupDoc(groupId).collection('members').get();
    for (final d in members.docs) {
      await d.reference.delete();
    }
    final checkins =
        await _groupDoc(groupId).collection('checkins').get();
    for (final d in checkins.docs) {
      await d.reference.delete();
    }
    await _groupDoc(groupId).delete();
    await _pointerDoc(groupId).delete();
  }

  // ── 工具 ──────────────────────────────────────────────────────────────

  static String goalLabel(Group group) {
    if (group.targetType == Group.typeCheckin) {
      return '每日 ${group.targetValue} 遍';
    }
    return '个人总目标';
  }
}
