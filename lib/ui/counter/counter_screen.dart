import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/practice.dart';
import '../../data/repositories/practice_repository.dart';

class CounterScreen extends StatefulWidget {
  final Practice practice;
  const CounterScreen({super.key, required this.practice});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen>
    with SingleTickerProviderStateMixin {
  final _repo = PracticeRepository();

  int _sessionCount = 0;
  int _todayCount = 0;
  bool _loading = true;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
    _loadTodayCount();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Keep screen on
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _loadTodayCount() async {
    final logs = await _repo.watchTodayLogs().first;
    final count = logs
        .where((l) => l.practiceId == widget.practice.id)
        .fold(0, (sum, l) => sum + l.count);
    if (mounted) setState(() { _todayCount = count; _loading = false; });
  }

  Future<void> _increment(int amount) async {
    HapticFeedback.selectionClick();
    _animCtrl.forward().then((_) => _animCtrl.reverse());
    setState(() {
      _sessionCount += amount;
      _todayCount += amount;
    });
    await _repo.logPractice(widget.practice.id, widget.practice.name, amount);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) return _buildLandscape();
    return _buildPortrait();
  }

  Widget _buildPortrait() {
    final target = widget.practice.targetCount;
    final hasTarget = target > 0;
    final progress =
        hasTarget ? (_todayCount / target).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.practice.name),
      ),
      body: Column(
        children: [
          // Progress card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('今日',
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          hasTarget ? '$_todayCount / $target' : '$_todayCount 遍',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                    if (hasTarget) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    if (_sessionCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '本次 +$_sessionCount',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Big bead button
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => _increment(1),
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              '$_todayCount',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Quick-add row
          Padding(
            padding: const EdgeInsets.only(bottom: 48, left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [7, 21, 108].map((n) => OutlinedButton(
                    onPressed: () => _increment(n),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: Text('+$n'),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscape() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Practice name
            Positioned(
              top: 16,
              left: 56,
              child: Text(
                widget.practice.name,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            // Full-screen tap area + count
            GestureDetector(
              onTap: () => _increment(1),
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Text(
                    '$_todayCount',
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // Quick-add chips at bottom
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [7, 21, 108].map((n) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ActionChip(
                        label: Text('+$n',
                            style: const TextStyle(color: Colors.white)),
                        backgroundColor: Colors.white24,
                        onPressed: () => _increment(n),
                      ),
                    )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
