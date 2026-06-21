import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';
import '../transmission/transmission_screen.dart';
import '../reminder/reminder_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _exporting = false;
  bool _importing = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _displayName {
    final u = _user;
    if (u == null) return '';
    if (u.displayName != null && u.displayName!.isNotEmpty) return u.displayName!;
    return u.email?.split('@').first ?? '用户';
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _displayName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: '昵称', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await _user?.updateDisplayName(ctrl.text.trim());
      await _user?.reload();
      if (mounted) setState(() {});
    }
  }

  Future<void> _showLanguageDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('语言设置'),
        children: [
          SimpleDialogOption(
            child: const Row(children: [
              Text('🇨🇳  '),
              Text('中文（简体）'),
            ]),
            onPressed: () => Navigator.pop(ctx),
          ),
          SimpleDialogOption(
            child: const Row(children: [
              Text('🇬🇧  '),
              Text('English (Coming soon)'),
            ]),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final path = await ImportService.pickCsvFile();
    if (path == null) return;
    setState(() => _importing = true);
    try {
      final result = await ImportService.importFromCsv(path);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入结果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('导入成功：${result.imported} 条'),
              Text('跳过重复：${result.skipped} 条'),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('错误：${result.errors.join('\n')}',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontSize: 13)),
              ],
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await ExportService.exportAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (confirmed == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          const SizedBox(height: 24),

          // 头像 + 昵称
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 36,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: _editName,
                tooltip: '修改昵称',
              ),
            ],
          ),
          if (_user?.email != null)
            Center(
              child: Text(
                _user!.email!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          const SizedBox(height: 24),
          const Divider(height: 1),

          // 传承灌顶
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('传承灌顶'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransmissionScreen())),
          ),
          const Divider(height: 1),

          // 导出全部记录
          ListTile(
            leading: _exporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            title: const Text('导出全部记录'),
            subtitle: const Text('导出为 CSV 文件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exporting ? null : _export,
          ),
          const Divider(height: 1),

          // 导入历史记录
          ListTile(
            leading: _importing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_outlined),
            title: const Text('导入历史记录'),
            subtitle: const Text('从旧版导出的 CSV 文件导入'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importing ? null : _import,
          ),
          const Divider(height: 1),

          // 提醒设置
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('提醒设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReminderScreen())),
          ),
          const Divider(height: 1),

          // 语言设置
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLanguageDialog,
          ),
          const Divider(height: 1),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // 退出登录
          ListTile(
            leading: Icon(Icons.logout,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              '退出登录',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: _logout,
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
