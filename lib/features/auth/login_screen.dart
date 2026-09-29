import 'package:flutter/material.dart';

import '../../di.dart';
import '../../utils/format.dart';
import '../profile/terms_screen.dart';

/// Email + 密碼登入／註冊。成功時 pop(true)。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signUp = false;
  bool _agreed = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_signUp && !_agreed) {
      _toast('請先閱讀並同意使用條款與社群規範');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_signUp) {
        await reviewRepo.signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
        );
        if (!reviewRepo.isSignedIn) {
          // Supabase 開啟「Email 確認」時會走到這裡
          _toast('註冊成功！請到信箱點擊確認連結後再登入');
          setState(() {
            _signUp = false;
            _busy = false;
          });
          return;
        }
      } else {
        await reviewRepo.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(friendlyError(e));
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_signUp ? '註冊' : '登入')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '登入後才能發表評價，瀏覽不需要登入。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (_signUp) ...[
              TextFormField(
                controller: _name,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '顯示名稱',
                  helperText: '會顯示在你的評價上',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? '請輸入顯示名稱' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : '請輸入正確的 Email',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密碼',
                helperText: '至少 6 個字',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').length < 6 ? '密碼至少 6 個字' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_signUp)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('我已閱讀並同意'),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                      ),
                      child: const Text('使用條款與社群規範'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_signUp ? '建立帳號' : '登入'),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
              child: Text(_signUp ? '已經有帳號了？登入' : '還沒有帳號？註冊'),
            ),
          ],
        ),
      ),
    );
  }
}
