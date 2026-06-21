import 'package:flutter/material.dart';
import '../../data/models/practice.dart';
import '../../data/repositories/practice_repository.dart';
import 'add_practice_screen.dart';
import 'practice_library_screen.dart';

class PracticeListScreen extends StatefulWidget {
  const PracticeListScreen({super.key});

  @override
  State<PracticeListScreen> createState() => _PracticeListScreenState();
}

class _PracticeListScreenState extends State<PracticeListScreen> {
  final _repo = PracticeRepository();
  List<Practice> _practices = [];

  @override
  void initState() {
    super.initState();
    _repo.watchPractices().listen((list) {
      if (mounted) setState(() => _practices = list);
    });
  }

  void _openLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeLibraryScreen(
          onSelectTemplate: (name) {
            // Pop library, then open AddPractice with pre-filled name
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddPracticeScreen(initialName: name),
              ),
            );
          },
          onCustomInput: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddPracticeScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  void _editPractice(Practice p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPracticeScreen(existing: p),
      ),
    );
  }

  Future<void> _confirmDelete(Practice p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除功课'),
        content: Text('确定要删除「${p.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _repo.deletePractice(p.id);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final list = List<Practice>.from(_practices);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() => _practices = list);
    await _repo.updateSortOrders(list);
  }

  String _typeLabel(Practice p) {
    switch (p.goalType) {
      case GoalType.dailyCount:
        return p.targetCount > 0 ? '每日 ${p.targetCount} 遍' : '每日数量';
      case GoalType.checkin:
        return '每日打卡';
      case GoalType.lifetime:
        return p.targetCount > 0 ? '终生累计·目标 ${p.targetCount} 遍' : '终生发愿';
      case GoalType.course:
        return '课程进度·${p.targetCount} 课';
      case GoalType.deadline:
        return p.deadlineDate != null
            ? '限期完成·${p.deadlineDate}'
            : '限期完成';
      default:
        return GoalType.label(p.goalType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('功课管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openLibrary,
        child: const Icon(Icons.add),
      ),
      body: _practices.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_books_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('暂无功课，点击 + 从功课库添加'),
                ],
              ),
            )
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _practices.length,
              onReorder: _onReorder,
              itemBuilder: (ctx, i) {
                final p = _practices[i];
                return _PracticeRow(
                  key: ValueKey(p.id),
                  index: i,
                  practice: p,
                  typeLabel: _typeLabel(p),
                  onEdit: () => _editPractice(p),
                  onDelete: () => _confirmDelete(p),
                );
              },
            ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  final int index;
  final Practice practice;
  final String typeLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PracticeRow({
    super.key,
    required this.index,
    required this.practice,
    required this.typeLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(practice.name,
                      style: Theme.of(context).textTheme.bodyLarge),
                  Text(typeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          )),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: cs.onSurfaceVariant,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: cs.error,
              onPressed: onDelete,
            ),
          ],
        ),
        const Divider(height: 1, indent: 56),
      ],
    );
  }
}
