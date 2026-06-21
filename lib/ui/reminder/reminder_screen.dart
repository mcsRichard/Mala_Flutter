import 'package:flutter/material.dart';
import '../../services/reminder_service.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  List<Reminder> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ReminderService.loadReminders();
    if (mounted) setState(() { _reminders = list; _loading = false; });
  }

  Future<void> _addReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: '选择提醒时间',
    );
    if (picked == null) return;
    try {
      final updated = await ReminderService.addReminder(
          _reminders, picked.hour, picked.minute);
      if (mounted) setState(() => _reminders = updated);
    } catch (e) {
      // Scheduling may fail (permission denied) but data is saved — reload from storage
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提醒已保存，但通知调度失败：$e')),
        );
      }
    }
  }

  Future<void> _toggle(int id, bool enabled) async {
    try {
      final updated = await ReminderService.toggleReminder(_reminders, id, enabled);
      if (mounted) setState(() => _reminders = updated);
    } catch (_) {
      await _load();
    }
  }

  Future<void> _delete(int id) async {
    try {
      final updated = await ReminderService.deleteReminder(_reminders, id);
      if (mounted) setState(() => _reminders = updated);
    } catch (_) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('提醒设置')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('暂无提醒'),
                      const SizedBox(height: 8),
                      const Text('点击右下角 + 添加每日提醒',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reminders.length,
                  itemBuilder: (_, i) {
                    final r = _reminders[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.alarm,
                          color: r.enabled
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          r.timeLabel,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: r.enabled
                                    ? null
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                        ),
                        subtitle: Text(r.enabled ? '已开启' : '已关闭'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: r.enabled,
                              onChanged: (v) => _toggle(r.id, v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () => _delete(r.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
