import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../di.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../models/verdict.dart';
import '../../utils/format.dart';
import '../../theme/motion.dart';
import '../../widgets/apple_bars.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tag_icon.dart';
import '../../widgets/verdict_icon.dart';

class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key, required this.place, this.existing});

  final Place place;
  final Review? existing;

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _form = GlobalKey<FormState>();
  final _picker = ImagePicker();

  Verdict? _verdict;
  final Set<ReviewTag> _tags = {};
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  late final _price =
      TextEditingController(text: widget.existing?.pricePaid?.toString() ?? '');
  DateTime? _visitedOn;
  final List<XFile> _photos = [];
  XFile? _receipt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _verdict = widget.existing?.verdict;
    _tags.addAll(widget.existing?.tags ?? const []);
    _visitedOn = widget.existing?.visitedOn;
  }

  @override
  void dispose() {
    _body.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final files =
        await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (files.isEmpty) return;
    setState(() {
      _photos.addAll(files.take(6 - _photos.length));
    });
  }

  Future<void> _pickReceipt() async {
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('消費證明'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text('拍照'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('從相簿選擇'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
    if (source == null) return;
    final f = await _picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1600);
    if (f != null) setState(() => _receipt = f);
  }

  Future<void> _pickDate() async {
    var picked = _visitedOn ?? DateTime.now();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: Theme.of(ctx).cardTheme.color,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () {
                      setState(() => _visitedOn = picked);
                      Navigator.pop(ctx);
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: picked,
                  minimumDate: DateTime(2015),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_verdict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選一個標記')),
      );
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await reviewRepo.submitReview(
        place: widget.place,
        verdict: _verdict!,
        body: _body.text,
        pricePaid: int.tryParse(_price.text.trim()),
        visitedOn: _visitedOn,
        photos: _photos,
        receipt: _receipt,
        tags: _tags.toList(),
      );
      if (!mounted) return;
      // 完成回饋：與畫面關閉同一時刻
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppleAppBar(
        title: Text(widget.existing == null ? '寫評價' : '修改評價'),
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
          child: ListView(
            padding: barInsets(context, top: 16, bottom: 32)
                .add(const EdgeInsets.symmetric(horizontal: 16)),
            children: [
              Text(widget.place.name, style: text.headlineMedium),
              Text(widget.place.address, style: text.bodySmall),
              const SizedBox(height: 24),
              Text('這家店你給什麼？', style: text.titleMedium),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.22,
                children: [
                  for (final v in Verdict.values)
                    _VerdictOption(
                      verdict: v,
                      selected: _verdict == v,
                      onTap: () => setState(() => _verdict = v),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('這家店的特色（選填，可複選）', style: text.titleMedium),
              const SizedBox(height: 8),
              for (final t in ReviewTag.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TagOption(
                    tag: t,
                    selected: _tags.contains(t),
                    onTap: () => setState(() {
                      if (!_tags.add(t)) {
                      _tags.remove(t);
                    }
                    }),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _body,
                minLines: 4,
                maxLines: 10,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: '說說你的真實體驗',
                  hintText: '吃了什麼、花了多少、服務和環境如何……',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 10) return '至少寫 10 個字，讓其他人看得懂';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '每人消費金額（選填）',
                  prefixText: r'$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0 || n > 100000) {
                    return '請輸入 0 到 100000 的整數';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(CupertinoIcons.calendar),
                  title: Text(
                      _visitedOn == null ? '造訪日期（選填）' : fmtDate(_visitedOn!)),
                  trailing: _visitedOn == null
                      ? const Icon(CupertinoIcons.chevron_right)
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() => _visitedOn = null),
                          child: const Icon(CupertinoIcons.xmark_circle_fill),
                        ),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 24),
              Text('照片（選填，最多 6 張）', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _photos)
                    _Thumb(
                      file: f,
                      onRemove: () => setState(() => _photos.remove(f)),
                    ),
                  if (_photos.length < 6)
                    InkWell(
                      onTap: _pickPhotos,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.camera),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    _receipt == null
                        ? CupertinoIcons.doc_text
                        : CupertinoIcons.checkmark_seal_fill,
                    color: _receipt == null ? null : const Color(0xFF34C759),
                  ),
                  title: Text(_receipt == null ? '附上消費證明（選填）' : '已附上消費證明'),
                  subtitle: const Text(
                    '收據或發票照片只有你和管理員看得到，其他人只會看到「附消費證明」標記，讓評價更可信。',
                  ),
                  trailing: _receipt == null
                      ? const Icon(CupertinoIcons.chevron_right)
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() => _receipt = null),
                          child: const Icon(CupertinoIcons.xmark_circle_fill),
                        ),
                  onTap: _pickReceipt,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '送出即表示你同意本 App 的使用條款與社群規範：只寫親身經歷、不做人身攻擊、不洩漏他人個資。',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(CupertinoIcons.paperplane_fill),
                label: Text(widget.existing == null ? '送出評價' : '更新評價'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictOption extends StatelessWidget {
  const _VerdictOption({
    required this.verdict,
    required this.selected,
    required this.onTap,
  });

  final Verdict verdict;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? verdict.color.withValues(alpha: 0.10)
              : Theme.of(context).cardTheme.color,
          border: Border.all(
            color: selected ? verdict.color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VerdictIcon(verdict, size: 44),
            const SizedBox(height: 6),
            Text(
              verdict.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: selected ? verdict.color : null,
                  ),
            ),
            Text(
              verdict.hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TagOption extends StatelessWidget {
  const _TagOption({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final ReviewTag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressScale(
      onTap: onTap,
      haptic: true,
      scale: 0.985,
      child: AnimatedContainer(
        duration: reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? tag.color.withValues(alpha: 0.10)
              : theme.cardTheme.color,
          border: Border.all(
              color: selected ? tag.color : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            TagIcon(tag, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag.label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: selected ? tag.color : null)),
                  Text(tag.hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: selected
                  ? tag.color
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.file, required this.onRemove});
  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (_, snap) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: snap.hasData
                  ? Image.memory(snap.data!,
                      width: 80, height: 80, fit: BoxFit.cover)
                  : const SizedBox(width: 80, height: 80),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20),
              onPressed: onRemove,
            ),
          ),
        ],
      );
}
