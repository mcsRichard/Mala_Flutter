import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/group.dart';
import '../../data/repositories/group_repository.dart';
import 'group_detail_screen.dart';
import 'join_group_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _repo = GroupRepository();
  List<GroupStatus> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final groups = await _repo.getMyGroups();
      if (mounted) setState(() => _groups = groups);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final practiceCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    String targetType = Group.typeCheckin;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('创建小组'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '小组名称 *', border: OutlineInputBorder()),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: practiceCtrl,
                  decoration: const InputDecoration(labelText: '共修功课名称 *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                const Text('功课目标类型'),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: Group.typeCheckin, label: Text('当日完成')),
                    ButtonSegment(value: Group.typeTotal, label: Text('总目标')),
                  ],
                  selected: {targetType},
                  onSelectionChanged: (s) {
                    setDialogState(() {
                      targetType = s.first;
                      targetCtrl.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: targetType == Group.typeCheckin
                        ? '每人每日目标数量 *'
                        : '我的总目标数量 *',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final name = nameCtrl.text.trim();
      final practice = practiceCtrl.text.trim();
      final target = int.tryParse(targetCtrl.text) ?? 0;
      if (name.isNotEmpty && practice.isNotEmpty && target > 0) {
        await _repo.createGroup(
          name: name,
          practiceName: practice,
          targetType: targetType,
          targetValue: target,
        );
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('共修小组'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
            ).then((_) => _load()),
            tooltip: '加入小组',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          const Text('还没有加入任何小组'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
                            ).then((_) => _load()),
                            icon: const Icon(Icons.group_add),
                            label: const Text('加入小组'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _groups.length,
                      itemBuilder: (_, i) => _GroupCard(
                        status: _groups[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                GroupDetailScreen(groupId: _groups[i].group.id),
                          ),
                        ).then((_) => _load()),
                      ),
                    ),
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupStatus status;
  final VoidCallback onTap;

  const _GroupCard({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = status.group;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(g.name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Icon(
                    status.myDoneToday
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: status.myDoneToday
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                g.practiceName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '我的累计 ${status.myTotal} 遍',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '今日 ${status.todayDoneCount}/${status.memberCount} 人完成',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
