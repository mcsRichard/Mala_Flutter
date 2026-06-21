import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/practice.dart';
import '../../data/repositories/practice_repository.dart';

class AddPracticeScreen extends StatefulWidget {
  final String initialName;
  final Practice? existing; // non-null = edit mode

  const AddPracticeScreen({
    super.key,
    this.initialName = '',
    this.existing,
  });

  @override
  State<AddPracticeScreen> createState() => _AddPracticeScreenState();
}

class _AddPracticeScreenState extends State<AddPracticeScreen> {
  final _repo = PracticeRepository();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  String _goalType = GoalType.dailyCount;
  DateTime? _deadlineDate;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  bool get _needsTarget =>
      _goalType == GoalType.dailyCount ||
      _goalType == GoalType.lifetime ||
      _goalType == GoalType.course ||
      _goalType == GoalType.deadline;

  bool get _needsDeadline => _goalType == GoalType.deadline;

  String get _targetHint {
    switch (_goalType) {
      case GoalType.course:   return '课程总数（课）';
      case GoalType.deadline: return '总目标数量（遍）';
      default:                return '目标数量（遍）';
    }
  }

  String? get _dailyPreview {
    if (_goalType != GoalType.deadline) return null;
    if (_deadlineDate == null) return null;
    final total = int.tryParse(_targetCtrl.text) ?? 0;
    if (total <= 0) return null;
    final daysLeft =
        _deadlineDate!.difference(DateTime.now()).inDays + 1;
    if (daysLeft <= 0) return null;
    final daily = (total + daysLeft - 1) ~/ daysLeft;
    return '距截止日还有 $daysLeft 天，每日需完成 $daily 遍';
  }

  bool get _isValid {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_needsTarget && _targetCtrl.text.isEmpty) return false;
    if (_needsDeadline && _deadlineDate == null) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameCtrl.text = p.name;
      _goalType = p.goalType;
      if (p.targetCount > 0) _targetCtrl.text = '${p.targetCount}';
      if (p.deadlineDate != null) {
        _deadlineDate = DateTime.tryParse(p.deadlineDate!);
      }
    } else {
      _nameCtrl.text = widget.initialName;
    }
    _nameCtrl.addListener(() => setState(() {}));
    _targetCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: '选择截止日期',
    );
    if (picked != null) setState(() => _deadlineDate = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      final target = int.tryParse(_targetCtrl.text) ?? 0;
      final deadline = _needsDeadline && _deadlineDate != null
          ? DateFormat('yyyy-MM-dd').format(_deadlineDate!)
          : null;

      if (_isEdit) {
        await _repo.updatePractice(
          widget.existing!.id,
          name: name,
          goalType: _goalType,
          targetCount: target,
          deadlineDate: deadline,
        );
      } else {
        await _repo.addPractice(
          name: name,
          goalType: _goalType,
          targetCount: target,
          deadlineDate: deadline,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑功课' : '添加功课'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 功课名称 ──────────────────────────────────────────
            TextField(
              controller: _nameCtrl,
              autofocus: widget.initialName.isEmpty && !_isEdit,
              decoration: const InputDecoration(
                labelText: '功课名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ── 目标类型 ──────────────────────────────────────────
            Text('目标类型',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    )),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GoalType.dailyCount,
                GoalType.checkin,
                GoalType.lifetime,
                GoalType.course,
                GoalType.deadline,
              ].map((type) {
                final selected = _goalType == type;
                return FilterChip(
                  label: Text(GoalType.label(type)),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _goalType = type;
                    if (type == GoalType.checkin) _targetCtrl.clear();
                    if (type != GoalType.deadline) _deadlineDate = null;
                  }),
                  selectedColor: cs.primaryContainer,
                  checkmarkColor: cs.onPrimaryContainer,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── 数量目标 ──────────────────────────────────────────
            if (_needsTarget) ...[
              TextField(
                controller: _targetCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _targetHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── 截止日期 ──────────────────────────────────────────
            if (_needsDeadline) ...[
              OutlinedButton.icon(
                onPressed: _pickDeadline,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _deadlineDate != null
                      ? DateFormat('yyyy年M月d日').format(_deadlineDate!)
                      : '选择截止日期',
                ),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
              if (_dailyPreview != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dailyPreview!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                      ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            // ── 保存 ─────────────────────────────────────────────
            FilledButton(
              onPressed: (_isValid && !_saving) ? _save : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
