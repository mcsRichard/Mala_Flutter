import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Transmission {
  final String id;
  final String name;
  final String teacher;
  final String date;
  final String place;
  final String notes;

  const Transmission({
    required this.id,
    required this.name,
    required this.teacher,
    required this.date,
    required this.place,
    required this.notes,
  });

  factory Transmission.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Transmission(
      id: doc.id,
      name: d['name'] ?? '',
      teacher: d['teacher'] ?? '',
      date: d['date'] ?? '',
      place: d['place'] ?? '',
      notes: d['notes'] ?? '',
    );
  }
}

class TransmissionScreen extends StatefulWidget {
  const TransmissionScreen({super.key});

  @override
  State<TransmissionScreen> createState() => _TransmissionScreenState();
}

class _TransmissionScreenState extends State<TransmissionScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<Transmission> _list = [];
  bool _loading = true;

  CollectionReference get _col => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('transmissions');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snap = await _col.orderBy('date', descending: true).get();
    if (mounted) {
      setState(() {
        _list = snap.docs.map(Transmission.fromDoc).toList();
        _loading = false;
      });
    }
  }

  Future<void> _showDialog({Transmission? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name);
    final teacherCtrl = TextEditingController(text: existing?.teacher);
    final placeCtrl = TextEditingController(text: existing?.place);
    final notesCtrl = TextEditingController(text: existing?.notes);
    String selectedDate = existing?.date ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? '添加传承灌顶' : '编辑传承灌顶'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: '传承/灌顶名称 *', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: teacherCtrl,
                decoration: const InputDecoration(
                    labelText: '上师 *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.tryParse(selectedDate) ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: '日期 *', border: OutlineInputBorder()),
                  child: Text(selectedDate),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: placeCtrl,
                decoration: const InputDecoration(
                    labelText: '地点 *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                    labelText: '备注', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error),
                child: const Text('删除'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('保存')),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (confirmed == 'delete' && existing != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除传承'),
          content: Text('确定删除「${existing.name}」？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _col.doc(existing.id).delete();
        _load();
      }
    } else if (confirmed == 'save') {
      final name = nameCtrl.text.trim();
      final teacher = teacherCtrl.text.trim();
      final place = placeCtrl.text.trim();
      if (name.isEmpty || teacher.isEmpty || place.isEmpty) return;
      final data = {
        'name': name,
        'teacher': teacher,
        'date': selectedDate,
        'place': place,
        'notes': notesCtrl.text.trim(),
      };
      if (existing == null) {
        await _col.add(data);
      } else {
        await _col.doc(existing.id).update(data);
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('传承灌顶')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('暂无传承灌顶记录'),
                      const SizedBox(height: 8),
                      const Text('点击右下角 + 添加', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _list.length,
                  itemBuilder: (_, i) {
                    final t = _list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _showDialog(existing: t),
                        title: Text(t.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t.teacher} · ${t.date} · ${t.place}'),
                            if (t.notes.isNotEmpty)
                              Text(t.notes,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: t.notes.isNotEmpty,
                      ),
                    );
                  },
                ),
    );
  }
}
