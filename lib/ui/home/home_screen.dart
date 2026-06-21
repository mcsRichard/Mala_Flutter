import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/practice.dart';
import '../../data/models/group.dart';
import '../../data/repositories/practice_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../services/reminder_service.dart';
import '../counter/counter_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _practiceRepo = PracticeRepository();
  final _groupRepo = GroupRepository();

  List<Practice> _practices = [];
  List<PracticeLog> _todayLogs = [];
  bool _todayLogsReady = false;
  Map<String, int> _totals = {};
  List<GroupStatus> _groupStatuses = [];
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _practiceRepo.watchPractices().listen((p) {
      if (mounted) {
        setState(() => _practices = p);
        // Only update reminders once both lists are available
        if (_todayLogsReady) ReminderService.updateDailyStatus(p, _todayLogs);
      }
    });
    _practiceRepo.watchTodayLogs().listen((l) {
      if (mounted) {
        _todayLogsReady = true;
        setState(() => _todayLogs = l);
        if (_practices.isNotEmpty) {
          ReminderService.updateDailyStatus(_practices, l);
        }
        // Refresh accumulated totals whenever today's logs change (another device may have logged)
        _practiceRepo.getTotalsByPractice().then((t) {
          if (mounted) setState(() => _totals = t);
        });
      }
    });
    _loadAsync();
  }

  Future<void> _loadAsync() async {
    final results = await Future.wait([
      _practiceRepo.getStreak(),
      _groupRepo.getMyGroups(),
      _practiceRepo.getTotalsByPractice(),
    ]);
    if (!mounted) return;
    setState(() {
      _streak = results[0] as int;
      _groupStatuses = results[1] as List<GroupStatus>;
      _totals = results[2] as Map<String, int>;
    });
  }

  int _todayCount(String practiceId) => _todayLogs
      .where((l) => l.practiceId == practiceId)
      .fold(0, (sum, l) => sum + l.count);

  bool _isDone(Practice p, int todayCount, int totalSoFar) {
    if (p.goalType == GoalType.checkin) return todayCount >= 1;
    if (p.goalType == GoalType.deadline &&
        p.deadlineDate != null &&
        p.targetCount > 0) {
      try {
        final d = DateTime.parse(p.deadlineDate!);
        final daysLeft = d.difference(DateTime.now()).inDays + 1;
        final remaining = (p.targetCount - totalSoFar).clamp(0, p.targetCount);
        final needed =
            daysLeft > 0 ? (remaining / daysLeft).ceil() : remaining;
        return needed > 0 ? todayCount >= needed : remaining <= 0;
      } catch (_) {
        return false;
      }
    }
    return p.targetCount > 0 && todayCount >= p.targetCount;
  }

  int get _todayDone {
    return _practices.where((p) {
      if (!p.hasDaily) return false;
      if (p.goalType == GoalType.checkin) return _todayCount(p.id) >= 1;
      return p.targetCount > 0 && _todayCount(p.id) >= p.targetCount;
    }).length;
  }

  int get _todayTotal => _practices.where((p) => p.hasDaily).length;

  Future<void> _checkIn(Practice practice) async {
    final alreadyDone = _todayCount(practice.id) >= 1;
    if (alreadyDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${practice.name}」今日已打卡'), duration: const Duration(seconds: 2)),
      );
      return;
    }
    await _practiceRepo.logPractice(practice.id, practice.name, 1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${practice.name}」打卡成功'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _showLogDialog(Practice practice) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(practice.name),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '本次数量（遍）',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final count = int.tryParse(ctrl.text) ?? 0;
      if (count > 0) {
        await _practiceRepo.logPractice(practice.id, practice.name, count);
      }
    }
  }

  Future<void> _showGroupCheckInDialog(GroupStatus status) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status.group.practiceName),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '本次数量（遍）',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (confirmed == true) {
      final count = int.tryParse(ctrl.text) ?? 0;
      if (count > 0) {
        await _groupRepo.checkIn(status.group.id, count);
        final statuses = await _groupRepo.getMyGroups();
        if (mounted) setState(() => _groupStatuses = statuses);
      }
    }
  }

  void _pickAndLaunchCounter() async {
    if (_practices.isEmpty) return;
    if (_practices.length == 1) {
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CounterScreen(practice: _practices.first)));
      return;
    }
    final picked = await showModalBottomSheet<Practice>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('选择功课', style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ..._practices.map((p) => ListTile(
                title: Text(p.name),
                onTap: () => Navigator.pop(ctx, p),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (picked != null && mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CounterScreen(practice: picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? '');
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    final colorScheme = Theme.of(context).colorScheme;
    final today = DateFormat('EEEE, MMMM d', 'zh_CN').format(DateTime.now());

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAsync,
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              today,
                              style:
                                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                            ),
                          ],
                        ),
                      ),
                      // Counter launcher button
                      GestureDetector(
                        onTap: _pickAndLaunchCounter,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Summary cards ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: '今日完成',
                          value: '$_todayDone / $_todayTotal',
                          highlight: _todayTotal > 0 && _todayDone == _todayTotal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: '连续打卡',
                          value: '$_streak 天',
                          highlight: _streak > 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Section header ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('待完成',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '长按功课名可启动计数器',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── Practice list ─────────────────────────────────────
              if (_practices.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.auto_awesome_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          const Text('前往「功课」标签添加功课'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final p = _practices[i];
                      final today = _todayCount(p.id);
                      final totalSoFar = _totals[p.id] ?? _totals[p.name] ?? 0;
                      final done = _isDone(p, today, totalSoFar);
                      return _PracticeItem(
                        practice: p,
                        todayCount: today,
                        totalCount: _totals[p.id] ?? _totals[p.name] ?? 0,
                        isDone: done,
                        onTap: () => p.goalType == GoalType.checkin
                            ? _checkIn(p)
                            : _showLogDialog(p),
                        onLongPress: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CounterScreen(practice: p)),
                        ),
                      );
                    },
                    childCount: _practices.length,
                  ),
                ),

              // ── Group practices ───────────────────────────────────
              if (_groupStatuses.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text('共修功课',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final s = _groupStatuses[i];
                      return _GroupItem(
                          status: s,
                          onTap: () => _showGroupCheckInDialog(s));
                    },
                    childCount: _groupStatuses.length,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryCard(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  )),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: highlight ? cs.primary : cs.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _PracticeItem extends StatelessWidget {
  final Practice practice;
  final int todayCount;
  final int totalCount;
  final bool isDone;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PracticeItem({
    required this.practice,
    required this.todayCount,
    required this.totalCount,
    required this.isDone,
    required this.onTap,
    this.onLongPress,
  });

  // How many needed today for deadline practices
  int _deadlineTodayNeeded() {
    if (practice.deadlineDate == null) return 0;
    try {
      final d = DateTime.parse(practice.deadlineDate!);
      final daysLeft = d.difference(DateTime.now()).inDays + 1;
      final remaining = (practice.targetCount - totalCount).clamp(0, practice.targetCount);
      return daysLeft > 0 ? (remaining / daysLeft).ceil() : remaining;
    } catch (_) {
      return 0;
    }
  }

  int _deadlineDaysLeft() {
    if (practice.deadlineDate == null) return 0;
    try {
      final d = DateTime.parse(practice.deadlineDate!);
      return d.difference(DateTime.now()).inDays + 1;
    } catch (_) {
      return 0;
    }
  }

  String get _subtitle {
    switch (practice.goalType) {
      case GoalType.dailyCount:
        return practice.targetCount > 0
            ? '今日目标 ${practice.targetCount} 遍'
            : '每日数量';
      case GoalType.checkin:
        return '每日打卡';
      case GoalType.lifetime:
        return practice.targetCount > 0
            ? '终生累计·目标 ${practice.targetCount} 遍'
            : '终生发愿';
      case GoalType.course:
        return '第 $totalCount 课 / ${practice.targetCount} 课';
      case GoalType.deadline:
        final needed = _deadlineTodayNeeded();
        final days = _deadlineDaysLeft();
        if (days <= 0) return '限期完成·已过期';
        if (todayCount >= needed && needed > 0) {
          return '限期完成·今日已完成·还剩 $days 天';
        }
        return '限期完成·今日需 $needed 遍·还剩 $days 天';
      default:
        return GoalType.label(practice.goalType);
    }
  }

  String get _trailing {
    switch (practice.goalType) {
      case GoalType.checkin:
        return isDone ? '已打卡' : '未打卡';
      case GoalType.dailyCount:
        return practice.targetCount > 0
            ? '$todayCount / ${practice.targetCount}'
            : '今日 $todayCount 遍';
      case GoalType.lifetime:
        return '累计 $totalCount 遍';
      case GoalType.course:
        if (practice.targetCount > 0) {
          final pct = (totalCount / practice.targetCount * 100).round();
          return '$pct%';
        }
        return '累计 $totalCount 课';
      case GoalType.deadline:
        final needed = _deadlineTodayNeeded();
        if (needed <= 0) return '累计 $totalCount 遍';
        if (todayCount >= needed) return '今日已完成';
        return '还需 ${needed - todayCount} 遍';
      default:
        return '累计 $totalCount 遍';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showDailyProgress = practice.goalType == GoalType.dailyCount &&
        practice.targetCount > 0;
    final showTotalProgress = (practice.goalType == GoalType.deadline ||
            practice.goalType == GoalType.lifetime ||
            practice.goalType == GoalType.course) &&
        practice.targetCount > 0;
    final progress = showDailyProgress
        ? (todayCount / practice.targetCount).clamp(0.0, 1.0)
        : showTotalProgress
            ? (totalCount / practice.targetCount).clamp(0.0, 1.0)
            : 0.0;
    final showProgress = showDailyProgress || showTotalProgress;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isDone
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isDone ? cs.primary : cs.outlineVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(practice.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          )),
                  const SizedBox(height: 2),
                  Text(_subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          )),
                  if (showProgress) ...[
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                      minHeight: 3,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _trailing,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDone ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupItem extends StatelessWidget {
  final GroupStatus status;
  final VoidCallback onTap;

  const _GroupItem({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = status.group;
    final cs = Theme.of(context).colorScheme;
    final done = status.myDoneToday;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              done ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: done ? cs.primary : cs.outlineVariant,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.practiceName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          )),
                  Text(g.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          )),
                ],
              ),
            ),
            Text(
              '${status.myTodayValue}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
