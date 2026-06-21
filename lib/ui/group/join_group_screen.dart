import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/group.dart';
import '../../data/repositories/group_repository.dart';

class JoinGroupScreen extends StatefulWidget {
  final String? initialCode;
  const JoinGroupScreen({super.key, this.initialCode});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _repo = GroupRepository();
  final _codeCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  Group? _group;
  int _memberCount = 0;
  bool _alreadyMember = false;
  bool _loading = false;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeCtrl.text = widget.initialCode!;
      _lookup();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _loading = true; _error = null; _group = null; });
    try {
      final g = await _repo.getGroup(code);
      if (g == null) {
        setState(() => _error = '小组「$code」不存在或已解散');
        return;
      }
      final members = await _repo.getMembers(g.id, targetType: g.targetType, targetValue: g.targetValue);
      final already = await _repo.isMember(g.id);
      setState(() {
        _group = g;
        _memberCount = members.length;
        _alreadyMember = already;
      });
    } catch (e) {
      setState(() => _error = '查询失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final g = _group;
    if (g == null) return;
    final needsTarget = g.targetType == Group.typeTotal;
    final target = int.tryParse(_targetCtrl.text) ?? 0;
    if (needsTarget && target <= 0) return;

    setState(() => _joining = true);
    try {
      await _repo.joinGroup(g.id, targetValue: needsTarget ? target : 0);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '加入失败：$e');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('加入小组')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isLoggedIn)
              const Card(child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('请先登录后再加入小组'),
              ))
            else ...[
              TextField(
                controller: _codeCtrl,
                decoration: InputDecoration(
                  labelText: '小组编号',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _lookup,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _lookup(),
              ),
              const SizedBox(height: 16),

              if (_loading) const Center(child: CircularProgressIndicator()),

              if (_error != null)
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),

              if (_group != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_group!.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _InfoRow('共修功课', _group!.practiceName),
                        _InfoRow('功课目标', GroupRepository.goalLabel(_group!)),
                        _InfoRow('组员人数', '$_memberCount 人'),
                        _InfoRow('创建者', _group!.creatorName),
                        _InfoRow('小组编号', _group!.id),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_alreadyMember) ...[
                  const Text('你已经是该小组成员', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回'),
                  ),
                ] else ...[
                  if (_group!.targetType == Group.typeTotal) ...[
                    TextField(
                      controller: _targetCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '我的总目标数量（遍）*',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: _joining ? null : _join,
                    child: _joining
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('确认加入'),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
