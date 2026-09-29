import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../di.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../models/verdict.dart';
import '../../utils/format.dart';
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
    _visitedOn = widget.existing?.visitedOn;
  }

  @override
  void dispose() {
    _body.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final files = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (files.isEmpty) return;
    setState(() {
      _photos.addAll(files.take(6 - _photos.length));
    });
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('從相簿選擇'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final f = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    if (f != null) setState(() => _receipt = f);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _visitedOn ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _visitedOn = d);
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
      );
      if (!mounted) return;
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
      appBar: AppBar(
        title: Text(widget.existing == null ? '寫評價' : '修改評價'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.place.name, style: text.titleLarge),
            Text(widget.place.address, style: text.bodySmall),
            const SizedBox(height: 20),
            Text('這家店你給什麼？', style: text.titleMedium),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
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
                if (n == null || n < 0 || n > 100000) return '請輸入 0 到 100000 的整數';
                return null;
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_visitedOn == null ? '造訪日期（選填）' : fmtDate(_visitedOn!)),
              trailing: _visitedOn == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _visitedOn = null),
                    ),
              onTap: _pickDate,
            ),
            const Divider(),
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
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  _receipt == null ? Icons.receipt_long_outlined : Icons.verified,
                  color: _receipt == null ? null : Colors.green,
                ),
                title: Text(_receipt == null ? '附上消費證明（選填）' : '已附上消費證明'),
                subtitle: const Text(
                  '收據或發票照片只有你和管理員看得到，其他人只會看到「附消費證明」標記，讓評價更可信。',
                ),
                trailing: _receipt == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _receipt = null),
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
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(widget.existing == null ? '送出評價' : '更新評價'),
            ),
            const SizedBox(height: 32),
          ],
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
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? verdict.color.withValues(alpha: 0.12)
              : scheme.surfaceContainerLow,
          border: Border.all(
            color: selected ? verdict.color : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
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
              borderRadius: BorderRadius.circular(8),
              child: snap.hasData
                  ? Image.memory(snap.data!, width: 80, height: 80, fit: BoxFit.cover)
                  : const SizedBox(width: 80, height: 80),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              icon: const Icon(Icons.cancel, size: 20),
              onPressed: onRemove,
            ),
          ),
        ],
      );
}
