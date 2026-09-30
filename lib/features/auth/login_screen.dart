import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../di.dart';
import '../../widgets/apple_bars.dart';
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

  /// 記住上次登入的 Email（密碼交給瀏覽器／手機的密碼管理，不自己存）。
  bool _remember = true;
  static const _kEmail = 'remembered_email';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_kEmail);
      if (saved != null && saved.isNotEmpty && mounted && _email.text.isEmpty) {
        setState(() => _email.text = saved);
      }
    }).catchError((_) {});
  }

  Future<void> _saveEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_remember) {
        await prefs.setString(_kEmail, _email.text.trim());
      } else {
        await prefs.remove(_kEmail);
      }
    } catch (_) {}
  }

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
      await _saveEmail();
      // 通知瀏覽器／iOS 鑰匙圈可以儲存這組帳密
      TextInput.finishAutofillContext();
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
      extendBodyBehindAppBar: true,
      appBar: AppleAppBar(
        title: Text(_signUp ? '註冊' : '登入'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('取消'),
        ),
        leadingWidth: 72,
      ),
      body: Builder(
        builder: (context) => Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: barInsets(context, top: 24, bottom: 24)
                  .add(const EdgeInsets.symmetric(horizontal: 24)),
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
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email
                  ],
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
                  autofillHints: [
                    _signUp ? AutofillHints.newPassword : AutofillHints.password
                  ],
                  decoration: const InputDecoration(
                    labelText: '密碼',
                    helperText: '至少 8 個字',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').length < (_signUp ? 8 : 6)
                    ? '密碼至少 ${_signUp ? 8 : 6} 個字'
                    : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_signUp)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        CupertinoSwitch(
                          value: _agreed,
                          onChanged: (v) => setState(() => _agreed = v),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('我已閱讀並同意'),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                onPressed: () => Navigator.of(context).push(
                                  CupertinoPageRoute(
                                      builder: (_) => const TermsScreen()),
                                ),
                                child: const Text('使用條款與社群規範'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_signUp)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        CupertinoSwitch(
                          value: _remember,
                          onChanged: (v) => setState(() => _remember = v),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('記住我的 Email')),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_signUp ? '建立帳號' : '登入'),
                ),
                TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _signUp = !_signUp),
                  child: Text(_signUp ? '已經有帳號了？登入' : '還沒有帳號？註冊'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
