import 'package:flutter/material.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/models/goal.dart';
import 'package:moveup/services/goal_store.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/utils/validators.dart';
import 'package:moveup/widgets.dart';

// Form tambah target, sekaligus edit kalau [goal] diisi
class GoalFormScreen extends StatefulWidget {
  const GoalFormScreen({super.key, this.goal});

  final Goal? goal;

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late SportType? _sport = widget.goal?.sportType;
  late GoalMetric _metric = widget.goal?.metric ?? GoalMetric.distance;
  late GoalPeriod _period = widget.goal?.period ?? GoalPeriod.weekly;
  late final _targetCtrl = TextEditingController(text: widget.goal == null ? '' : widget.goal!.metric.format(widget.goal!.target));
  late String _lastSuggestion = _suggestedTitle();
  late final _titleCtrl = TextEditingController(text: widget.goal?.title ?? _lastSuggestion);
  final _titleFocus = FocusNode();
  bool _saving = false;

  bool get _editing => widget.goal != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  String _suggestedTitle() {
    final sport = _sport?.label ?? 'Olahraga';
    final per = _period == GoalPeriod.weekly ? 'per minggu' : 'per bulan';
    final target = Validators.parseNumber(_targetCtrl.text);
    final amount = target == null ? _metric.label.toLowerCase() : '${_metric.format(target)} ${_metric.unit}';
    return '$sport $amount $per';
  }

  // Judul ikut berubah selama pengguna belum menulis judul sendiri
  void _update(VoidCallback change) {
    final wasSuggested = _titleCtrl.text == _lastSuggestion;
    setState(change);
    _lastSuggestion = _suggestedTitle();
    if (wasSuggested) _titleCtrl.text = _lastSuggestion;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final goal = Goal(
      id: widget.goal?.id ?? 'goal-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      sportTypeId: _sport?.id,
      metric: _metric,
      period: _period,
      target: Validators.parseNumber(_targetCtrl.text)!,
      createdAt: widget.goal?.createdAt ?? DateTime.now(),
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final store = GoalStore.instance;
      await (_editing ? store.update(goal) : store.add(goal));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.error("Target gagal disimpan. Coba lagi.");
      return;
    }
    if (!mounted) return;
    messenger.success(_editing ? "Target diperbarui" : "Target \"${goal.title}\" ditambahkan");
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? "Edit Target" : "Target Baru")),
      body: Form(
        key: _formKey,
        child: FormLayout(
          action: PrimaryButton(
            text: _editing ? "Simpan Perubahan" : "Simpan Target",
            icon: Icons.check,
            loading: _saving,
            onPressed: _save,
          ),
          children: [
            const SectionLabel("Kategori olahraga"),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text("Semua"),
                  selected: _sport == null,
                  onSelected: (_) => _update(() => _sport = null),
                ),
                if (_sport == SportType.swim)
                  const Chip(label: Text('Renang (kategori lama)')),
                for (final type in SportType.available)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 18),
                    label: Text(type.label),
                    selected: type == _sport,
                    onSelected: (_) => _update(() => _sport = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel("Ukuran target"),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in GoalMetric.values)
                  ChoiceChip(
                    avatar: Icon(m.icon, size: 18),
                    label: Text(m.label),
                    selected: m == _metric,
                    onSelected: (_) => _update(() => _metric = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel("Periode"),
            SegmentedButton<GoalPeriod>(
              segments: [
                for (final p in GoalPeriod.values) ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_period},
              onSelectionChanged: (s) => _update(() => _period = s.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _targetCtrl,
              nextFocus: _titleFocus,
              label: "Jumlah target",
              suffixText: _metric.unit,
              keyboardType: TextInputType.numberWithOptions(decimal: _metric == GoalMetric.distance),
              // Judul saran ikut diperbarui saat angka target diketik
              onChanged: (_) => _update(() {}),
              validator: (v) {
                final error = Validators.positiveNumber(label: "Target", max: _metric.maxTarget, unit: _metric.unit)(v);
                if (error != null) return error;
                final n = Validators.parseNumber(v)!;
                if (_metric != GoalMetric.distance && n != n.roundToDouble()) return "Target harus bilangan bulat";
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              label: "Nama target",
              helper: "Terisi otomatis dari pilihan di atas; boleh diganti",
              textCapitalization: TextCapitalization.sentences,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              validator: Validators.title(label: "Nama target", max: 40),
            ),
          ],
        ),
      ),
    );
  }
}
