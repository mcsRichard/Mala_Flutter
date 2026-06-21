import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/group.dart';
import '../../data/repositories/group_repository.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _repo = GroupRepository();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Group? _group;
  List<GroupMember> _members = [];
  bool _loading = false;
  String? _error;

  bool get _isAdmin => _group?.creatorId == _uid;
  GroupMember? get _me => _members.where((m) => m.userId == _uid).firstOrNull;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final g = await _repo.getGroup(widget.groupId);
      if (g == null) { setState(() => _error = '小组不存在'); return; }
      final members = await _repo.getMembers(widget.groupId,
          targetType: g.targetType, targetValue: g.targetValue);
      if (mounted) setState(() { _group = g; _members = members; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCheckInDialog() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_group?.practiceName ?? '打卡'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              labelText: '本次数量（遍）', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed == true) {
      final count = int.tryParse(ctrl.text) ?? 0;
      if (count > 0) {
        await _repo.checkIn(widget.groupId, count);
        _refresh();
      }
    }
  }

  Future<void> _showEditMyTargetDialog() async {
    final ctrl = TextEditingController(text: _me?.targetValue.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置我的目标'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              labelText: '我的总目标数量（遍）', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (confirmed == true) {
      final v = int.tryParse(ctrl.text) ?? 0;
      if (v > 0) {
        await _repo.updateMemberTarget(widget.groupId, v);
        _refresh();
      }
    }
  }

  Future<void> _showEditGoalDialog() async {
    final ctrl = TextEditingController(text: _group?.targetValue.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改每日目标'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              labelText: '每人每日目标数量（遍）', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (confirmed == true) {
      final v = int.tryParse(ctrl.text) ?? 0;
      if (v > 0) {
        await _repo.updateGoal(widget.groupId, _group!.targetType, v);
        _refresh();
      }
    }
  }

  Future<void> _shareGroup() async {
    final url = 'https://mcsrichard.github.io/Mala/join.html?code=${widget.groupId}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('邀请链接已复制到剪贴板')),
      );
    }
  }

  Future<void> _confirmLeaveOrDelete() async {
    final isAdmin = _isAdmin;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdmin ? '解散小组' : '退出小组'),
        content: Text(isAdmin ? '解散后所有数据将被删除，无法恢复。' : '确定退出该小组？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAdmin ? '解散' : '退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (isAdmin) {
        await _repo.deleteGroup(widget.groupId);
      } else {
        await _repo.leaveGroup(widget.groupId);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    final isCheckin = g?.targetType == Group.typeCheckin;
    final me = _me;

    return Scaffold(
      appBar: AppBar(
        title: Text(g?.name ?? '小组详情'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareGroup, tooltip: '分享'),
          if (_isAdmin && isCheckin)
            IconButton(icon: const Icon(Icons.edit), onPressed: _showEditGoalDialog, tooltip: '修改目标'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh, tooltip: '刷新'),
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: _confirmLeaveOrDelete,
                child: Text(_isAdmin ? '解散小组' : '退出小组',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 我的打卡卡片
                      if (g != null) Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(g.practiceName,
                                        style: Theme.of(context).textTheme.titleMedium),
                                  ),
                                  if (!isCheckin)
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: _showEditMyTargetDialog,
                                      tooltip: '设置我的目标',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (isCheckin) ...[
                                Text('今日目标：${g.targetValue} 遍',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                if (me != null) ...[
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: g.targetValue > 0
                                        ? (me.todayValue / g.targetValue).clamp(0.0, 1.0)
                                        : 0,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('今日：${me.todayValue} 遍'),
                                ],
                              ] else if (me != null) ...[
                                if (me.targetValue > 0) ...[
                                  Text('我的目标：${me.targetValue} 遍',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: (me.total / me.targetValue).clamp(0.0, 1.0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ] else
                                  Text('尚未设置目标',
                                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                const SizedBox(height: 4),
                                Text('累计：${me.total} 遍'),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _showCheckInDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('打卡'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(
                        '成员（${_members.length}人，今日${_members.where((m) => m.doneToday).length}人完成）',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),

                      ..._members.asMap().entries.map((e) {
                        final i = e.key;
                        final m = e.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${i + 1}')),
                            title: Row(
                              children: [
                                Text(m.displayName),
                                if (m.userId == _uid) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('我',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onPrimaryContainer)),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: isCheckin
                                ? Text('今日 ${m.todayValue} 遍 · 累计 ${m.total} 遍')
                                : m.targetValue > 0
                                    ? Text('${m.total} / ${m.targetValue} 遍')
                                    : Text('累计 ${m.total} 遍'),
                            trailing: Icon(
                              m.doneToday ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: m.doneToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
