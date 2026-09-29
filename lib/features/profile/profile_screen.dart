import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env.dart';
import '../../di.dart';
import '../../utils/format.dart';
import '../../widgets/apple_dialogs.dart';
import '../../widgets/inset_group.dart';
import '../auth/login_screen.dart';
import 'my_reviews_screen.dart';
import 'terms_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<AuthState>(
          stream: reviewRepo.authChanges,
          builder: (context, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child:
                    Text('我的', style: Theme.of(context).textTheme.displayLarge),
              ),
              if (reviewRepo.isSignedIn)
                const _SignedIn()
              else
                const _SignedOut(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Icon(CupertinoIcons.person_crop_circle,
                    size: 72,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  '登入後可以發表評價、檢舉不當內容、封鎖使用者。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                        builder: (_) => const LoginScreen(),
                        fullscreenDialog: true),
                  ),
                  child: const Text('登入 / 註冊'),
                ),
              ],
            ),
          ),
          const _CommonGroup(),
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
  late Future<int> _count = reviewRepo.myReviews().then((r) => r.length);

  Future<void> _rename() async {
    final current = await _name;
    if (!mounted) return;
    final name = await showTextPrompt(
      context,
      title: '修改顯示名稱',
      initial: current ?? '',
      placeholder: '顯示名稱',
      maxLength: 30,
    );
    if (name == null || name.isEmpty) return;
    try {
      await reviewRepo.updateDisplayName(name);
      setState(() => _name = reviewRepo.myDisplayName());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showConfirm(
      context,
      title: '刪除帳號？',
      message: '你的所有評價、照片與消費證明都會被永久刪除，無法復原。',
      confirmLabel: '永久刪除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await reviewRepo.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = reviewRepo.currentUser?.email ?? '';
    final error = Theme.of(context).colorScheme.error;
    return Column(
      children: [
        InsetGroup(
          children: [
            FutureBuilder<String?>(
              future: _name,
              builder: (_, snap) => ListTile(
                leading: const Icon(CupertinoIcons.person_crop_circle_fill,
                    size: 40),
                title: Text(snap.data ?? '…'),
                subtitle: Text(email),
                trailing: const Chevron(),
                onTap: _rename,
              ),
            ),
          ],
        ),
        InsetGroup(
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.chat_bubble_2_fill),
              title: const Text('我的評價'),
              subtitle: FutureBuilder<int>(
                future: _count,
                builder: (_, snap) => Text(
                  snap.hasData ? '已寫 ${snap.data} 則' : '…',
                ),
              ),
              trailing: const Chevron(),
              onTap: () async {
                await Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const MyReviewsScreen()),
                );
                setState(() => _count = reviewRepo.myReviews().then((r) => r.length));
              },
            ),
          ],
        ),
        const _CommonGroup(),
        InsetGroup(
          children: [
            ListTile(
              title: Text('登出',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
              onTap: reviewRepo.signOut,
            ),
            ListTile(
              title: Text('刪除帳號',
                  textAlign: TextAlign.center, style: TextStyle(color: error)),
              onTap: _deleteAccount,
            ),
          ],
        ),
      ],
    );
  }
}

class _CommonGroup extends StatelessWidget {
  const _CommonGroup();

  @override
  Widget build(BuildContext context) => InsetGroup(
        children: [
          ListTile(
            leading: const Icon(CupertinoIcons.doc_text_fill),
            title: const Text('使用條款與社群規範'),
            trailing: const Chevron(),
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const TermsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.mail_solid),
            title: const Text('聯絡我們'),
            subtitle: const Text(Env.supportEmail),
            trailing: const Chevron(),
            onTap: () => launchUrl(Uri.parse('mailto:${Env.supportEmail}')),
          ),
        ],
      );
}
