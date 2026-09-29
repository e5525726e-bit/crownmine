import 'package:flutter/material.dart';

import '../../config/env.dart';

/// 使用條款與社群規範。
/// 上架前請請律師檢視並補上公司／個人名稱、管轄法院等資訊。
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _sections = <(String, String)>[
    (
      '一、關於這個 App',
      '本 App 提供的店家基本資料（店名、地址、營業時間等）來自 Google，'
          '所有評價皆由本 App 的使用者發表，與 Google 無關，也不代表本 App 的立場。'
    ),
    (
      '二、社群規範（零容忍）',
      '1. 只寫親身消費經歷，不得捏造、不得代寫、不得收費刷評。\n'
          '2. 可以批評餐點、價格、服務與環境，但不得對特定人進行人身攻擊、歧視或仇恨言論。\n'
          '3. 不得刊登他人可識別的個資（人臉照片、姓名、電話、車牌等）。\n'
          '4. 不得張貼廣告、垃圾訊息或與店家無關的內容。\n'
          '違反者的內容會被移除，帳號可能被停權。'
    ),
    (
      '三、檢舉與處理',
      '每則評價都可以檢舉。被多位使用者檢舉的評價會先自動隱藏，'
          '我們會在 24 小時內審核並決定恢復或移除，並對違規使用者採取停權措施。'
          '你也可以封鎖任何使用者，之後將不再看到對方的內容。'
    ),
    (
      '四、你的責任',
      '你對自己發表的內容負完全責任。若因不實陳述導致法律爭議（例如誹謗），'
          '由發表者自行承擔。請確保你寫的都是事實與個人真實感受。'
    ),
    (
      '五、帳號與資料',
      '你可以隨時在「我的」頁面刪除帳號，所有評價、照片與消費證明會一併刪除。'
          '消費證明照片僅供本 App 管理員審核使用，不會公開。'
    ),
    (
      '六、聯絡我們',
      '任何問題請寄信到 ${Env.supportEmail}。'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('使用條款與社群規範')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (title, body) in _sections) ...[
            Text(title, style: text.titleMedium),
            const SizedBox(height: 6),
            Text(body, style: text.bodyMedium),
            const SizedBox(height: 20),
          ],
          Text('最後更新：2026 年 9 月', style: text.bodySmall),
        ],
      ),
    );
  }
}
