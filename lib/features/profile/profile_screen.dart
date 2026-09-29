import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env.dart';
import '../../di.dart';
import '../../utils/format.dart';
import '../auth/login_screen.dart';
import 'my_reviews_screen.dart';
import 'terms_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: StreamBuilder<AuthState>(
        stream: reviewRepo.authChanges,
        builder: (context, _) =>
            reviewRepo.isSignedIn ? const _SignedIn() : const _SignedOut(),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.person_outline, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text(
            '登入後可以發表評價、檢舉不當內容、封鎖使用者。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Text('登入 / 註冊'),
          ),
          const SizedBox(height: 32),
          const _CommonTiles(),
        ],
      );
}

class _SignedIn extends StatefulWidget {
  const _SignedIn();

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  late Future<String?> _name = reviewRepo.myDisplayName();

  Future<void> _rename() async {
    final controller = TextEditingController(text: await _name);
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改顯示名稱'),
        content: TextField(
          controller: controller,
          maxLength: 30,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await reviewRepo.updateDisplayName(name);
      setState(() => _name = reviewRepo.myDisplayName());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除帳號？'),
        content: const Text('你的所有評價、照片與消費證明都會被永久刪除，無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('永久刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await reviewRepo.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = reviewRepo.currentUser?.email ?? '';
    return ListView(
      children: [
        FutureBuilder<String?>(
          future: _name,
          builder: (_, snap) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(snap.data ?? '…'),
            subtitle: Text(email),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _rename,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.rate_review_outlined),
          title: const Text('我的評價'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyReviewsScreen()),
          ),
        ),
        const _CommonTiles(),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('登出'),
          onTap: reviewRepo.signOut,
        ),
        ListTile(
          leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
          title: Text('刪除帳號', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: _deleteAccount,
        ),
      ],
    );
  }
}

class _CommonTiles extends StatelessWidget {
  const _CommonTiles();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('使用條款與社群規範'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('聯絡我們'),
            subtitle: const Text(Env.supportEmail),
            onTap: () => launchUrl(Uri.parse('mailto:${Env.supportEmail}')),
          ),
        ],
      );
}
