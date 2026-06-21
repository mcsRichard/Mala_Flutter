import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        await cred.user?.updateDisplayName(_nameCtrl.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _authError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(String code) => switch (code) {
    'user-not-found' => '账号不存在',
    'wrong-password' => '密码错误',
    'email-already-in-use' => '邮箱已被注册',
    'weak-password' => '密码至少 6 位',
    'invalid-email' => '邮箱格式不正确',
    _ => '操作失败，请重试',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🙏', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(
                    'Mala',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '每日功课，共修精进',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 40),
                  if (!_isLogin)
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '昵称',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入昵称' : null,
                    ),
                  if (!_isLogin) const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? '请输入有效邮箱' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.length < 6) ? '密码至少 6 位' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLogin ? '登录' : '注册'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        setState(() { _isLogin = !_isLogin; _error = null; }),
                    child: Text(_isLogin ? '没有账号？点击注册' : '已有账号？点击登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
