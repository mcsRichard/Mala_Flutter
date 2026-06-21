import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/practice.dart';
import '../../data/models/group.dart';
import '../../data/repositories/practice_repository.dart';
import '../../data/repositories/group_repository.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _practiceRepo = PracticeRepository();
  final _groupRepo = GroupRepository();

  List<Practice> _practices = [];
  Map<String, int> _totals = {};
  List<_DayData> _weekData = [];
  List<GroupStatus> _groupStatuses = [];
  int _totalDays = 0;
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _practiceRepo.watchPractices().listen((list) {
      if (mounted) setState(() => _practices = list);
    });
    // Auto-refresh aggregates when today's logs change (e.g., logged on another device)
    _practiceRepo.watchTodayLogs().listen((_) {
      if (mounted) _load();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _practiceRepo.getTotalsByPractice(),
        _practiceRepo.getTotalActiveDays(),
        _practiceRepo.getStreak(),
        _groupRepo.getMyGroups(),
      ]);
      final practices = await _practiceRepo.watchPractices().first;
      final weekStats = await _practiceRepo.getWeekStats(practices);

      if (mounted) {
        setState(() {
          _totals = results[0] as Map<String, int>;
          _totalDays = results[1] as int;
          _streak = results[2] as int;
          _groupStatuses = results[3] as List<GroupStatus>;
          _weekData = weekStats
              .map((s) => _DayData(
                    label: _weekdayLabel(s.date),
                    done: s.done,
                    total: s.total,
                  ))
              .toList();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 概览 ────────────────────────────────────────
                  Text('概览', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _OverviewCard(
                              value: '${_practices.length}',
                              label: '总功课',
                              unit: '个')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _OverviewCard(
                              value: '$_totalDays',
                              label: '打卡天数',
                              unit: '天')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _OverviewCard(
                              value: '$_streak',
                              label: '当前连续',
                              unit: '天')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── 7-day chart ─────────────────────────────────
                  if (_weekData.isNotEmpty) ...[
                    Text('近7日完成',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _WeekChart(days: _weekData),
                    const SizedBox(height: 24),
                  ],

                  // ── Per-practice totals ──────────────────────────
                  if (_practices.isNotEmpty) ...[
                    Text('各功课统计',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ..._practices.map((p) {
                      final total = _totals[p.id] ?? _totals[p.name] ?? 0;
                      return _PracticeStatRow(
                        practice: p,
                        total: total,
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // ── Groups ───────────────────────────────────────
                  if (_groupStatuses.isNotEmpty) ...[
                    Text('共修小组',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ..._groupStatuses.map((s) => _GroupStatCard(status: s)),
                  ],

                  if (_practices.isEmpty && _groupStatuses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(Icons.bar_chart,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(height: 12),
                            const Text('暂无记录，开始打卡后将显示统计'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _DayData {
  final String label;
  final int done;
  final int total;

  const _DayData(
      {required this.label, required this.done, required this.total});

  double get ratio => total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
  String get fraction => total == 0 ? '-' : '$done/$total';
}

class _OverviewCard extends StatelessWidget {
  final String value;
  final String label;
  final String unit;

  const _OverviewCard(
      {required this.value, required this.label, required this.unit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(width: 2),
              Text(unit,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                      )),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<_DayData> days;

  const _WeekChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const maxHeight = 80.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((d) {
        final barH = d.ratio == 0 ? 4.0 : maxHeight * d.ratio;
        final isToday = d == days.last;
        return Expanded(
          child: Column(
            children: [
              Text(d.fraction,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: barH,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: d.ratio >= 1.0
                        ? cs.primary
                        : d.ratio > 0
                            ? cs.primary.withValues(alpha: 0.4)
                            : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(d.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isToday ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      )),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PracticeStatRow extends StatelessWidget {
  final Practice practice;
  final int total;

  const _PracticeStatRow({required this.practice, required this.total});

  String get _totalLabel {
    if (practice.targetCount > 0) return '$total / ${practice.targetCount} 遍';
    return '累计 $total 遍';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasTarget = practice.targetCount > 0;
    final progress = hasTarget
        ? (total / practice.targetCount).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(practice.name,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 2),
                        Text(GoalType.label(practice.goalType),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                )),
                      ],
                    ),
                  ),
                  Text(
                    _totalLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              if (hasTarget) ...[
                const SizedBox(height: 6),
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
        const Divider(height: 1),
      ],
    );
  }
}

class _GroupStatCard extends StatelessWidget {
  final GroupStatus status;

  const _GroupStatCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final g = status.group;
    final cs = Theme.of(context).colorScheme;
    final isTotal = g.targetType == Group.typeTotal;
    final progress = (isTotal && status.myTargetValue > 0)
        ? (status.myTotal / status.myTargetValue).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.name, style: Theme.of(context).textTheme.titleMedium),
            Text(g.practiceName,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('我的累计：${status.myTotal} 遍'),
                if (isTotal && status.myTargetValue > 0)
                  Text('目标：${status.myTargetValue} 遍',
                      style:
                          TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            if (progress > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(4)),
            ],
            const SizedBox(height: 4),
            Text(
              '小组 ${status.todayDoneCount}/${status.memberCount} 人今日完成',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
