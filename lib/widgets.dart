import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moveup/theme.dart';

// ---------------------------------------------------------------------------
// Tombol
// ---------------------------------------------------------------------------

// Aksi utama satu layar. [loading] menonaktifkan tombol supaya tidak terkirim dua kali.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  const PrimaryButton({super.key, required this.text, required this.onPressed, this.icon, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final enabled = !loading && onPressed != null;
    // Tombol berlatar gradasi aksen; dibuat pudar saat nonaktif atau sedang memuat
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.control),
          boxShadow: enabled ? AppTheme.softShadow(AppTheme.accent, alpha: 0.3) : null,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: onPrimary,
              disabledForegroundColor: onPrimary,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: onPrimary))
                else if (icon != null)
                  Icon(icon, size: 20),
                if (loading || icon != null) const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Aksi pendamping; [destructive] untuk aksi yang membuang data
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: color == null
            ? null
            : OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color, width: 1.5)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.sm)],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu
// ---------------------------------------------------------------------------

// Kartu dasar dengan padding standar; bisa diketuk kalau [onTap] diisi
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryValue;
  final String secondaryValue;
  final IconData icon;
  final VoidCallback? onTap;

  const ActivityCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryValue,
    required this.secondaryValue,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        leading: IconBadge(icon: icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(primaryValue, style: AppTheme.display(20)),
            Text(secondaryValue, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

// Tampilan saat daftar kosong; [actionLabel] + [onAction] memberi jalan keluar langsung
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accent.withValues(alpha: 0.1)),
              child: Icon(icon, size: 52, color: AppTheme.accent),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (title != null) ...[
              Text(title!, textAlign: TextAlign.center, style: AppTheme.display(24)),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 16)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

// Judul kecil di atas kelompok isian
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.display(15, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 2),
      ),
    );
  }
}

// Pesan error untuk isian yang bukan TextFormField (chip, segmented button)
class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: AppSpacing.md),
      child: Text(text!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
    );
  }
}

// Isian teks standar: selalu berlabel, dan tombol "berikutnya" di keyboard
// memindahkan fokus ke [nextFocus] (atau ke isian berikutnya kalau tidak diisi)
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.focusNode,
    this.nextFocus,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixText,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final String? suffixText;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final TextCapitalization textCapitalization;

  bool get _multiline => maxLines > 1;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      enabled: enabled,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType ?? (_multiline ? TextInputType.multiline : null),
      inputFormatters: inputFormatters,
      textInputAction: textInputAction ?? (_multiline ? TextInputAction.newline : TextInputAction.next),
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      minLines: _multiline ? 2 : null,
      maxLength: maxLength,
      onFieldSubmitted: (value) {
        nextFocus?.requestFocus();
        onSubmitted?.call(value);
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        alignLabelWithHint: _multiline,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixText: suffixText,
      ),
    );
  }
}

// Isian yang nilainya dipilih lewat dialog (tanggal, jam). Tampil seperti field teks
// dengan label dan pesan error, dan ikut divalidasi oleh Form.
class PickerField<T> extends FormField<T> {
  PickerField({
    super.key,
    required String label,
    required String Function(T? value) display,
    required Future<T?> Function(T? current) pick,
    IconData? icon,
    ValueChanged<T>? onChanged,
    super.initialValue,
    super.validator,
    super.enabled,
  }) : super(
          builder: (field) => InkWell(
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: !field.widget.enabled
                ? null
                : () async {
                    final picked = await pick(field.value);
                    if (picked == null) return;
                    field.didChange(picked);
                    onChanged?.call(picked);
                  },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: icon == null ? null : Icon(icon),
                suffixIcon: const Icon(Icons.expand_more),
                errorText: field.errorText,
                enabled: field.widget.enabled,
              ),
              child: Text(display(field.value), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
}

// Kerangka layar form: isian bisa di-scroll, aksi utama menempel di bawah.
// Scaffold mengecilkan body saat keyboard muncul, jadi tombol selalu tepat di atas keyboard.
class FormLayout extends StatelessWidget {
  const FormLayout({super.key, required this.children, required this.action, this.secondaryAction});

  final List<Widget> children;
  final Widget action;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpacing.page,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.canvasColor,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  action,
                  if (secondaryAction != null) ...[const SizedBox(height: AppSpacing.sm), secondaryAction!],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog dan pesan
// ---------------------------------------------------------------------------

// Konfirmasi sebelum aksi yang tidak bisa dibatalkan. "Batal" mendapat fokus awal
// supaya menekan Enter tidak langsung menghapus.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
  IconData icon = Icons.warning_amber_rounded,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final color = destructive ? scheme.error : scheme.primary;
      return AlertDialog(
        icon: Icon(icon, color: color, size: 32),
        title: Text(title, textAlign: TextAlign.center),
        content: SingleChildScrollView(child: Text(message, textAlign: TextAlign.center)),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: destructive ? scheme.onError : scheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}

// Pesan singkat setelah aksi berhasil atau gagal. Dipasang pada ScaffoldMessengerState
// supaya bisa dipakai setelah `await` tanpa menyentuh context yang mungkin sudah hilang.
extension AppMessages on ScaffoldMessengerState {
  void success(String message, {SnackBarAction? action}) => _show(message, Icons.check_circle_outline, action: action);

  void error(String message) => _show(message, Icons.error_outline, error: true);

  void _show(String message, IconData icon, {bool error = false, SnackBarAction? action}) {
    final color = error ? Colors.white : Theme.of(context).colorScheme.surface;
    this
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: error ? AppTheme.danger : null,
        action: action,
        content: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message, style: TextStyle(color: color))),
          ],
        ),
      ));
  }
}

void showSuccessMessage(BuildContext context, String message, {SnackBarAction? action}) =>
    ScaffoldMessenger.of(context).success(message, action: action);

void showErrorMessage(BuildContext context, String message) => ScaffoldMessenger.of(context).error(message);

// Bar Chart. [barColor] dan [labelColor] bisa diganti untuk dipakai di atas latar berwarna.
class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final int? highlightIndex;
  final double height;
  final Color? barColor;
  final Color? labelColor;

  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.highlightIndex,
    this.height = 120,
    this.barColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = barColor ?? theme.colorScheme.primary;
    final muted = labelColor ?? theme.colorScheme.onSurfaceVariant;
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final dense = values.length > 10;

    return SizedBox(
      height: height + 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: dense ? 1.5 : 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: maxValue == 0 ? 0 : values[i] / maxValue),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) {
                        final active = highlightIndex == null || highlightIndex == i;
                        return Container(
                          // Batang kosong tetap terlihat tipis supaya sumbu terbaca
                          height: (t * height).clamp(4, height),
                          decoration: BoxDecoration(
                            color: values[i] == 0
                                ? muted.withValues(alpha: 0.18)
                                : color.withValues(alpha: active ? 1 : 0.45),
                            borderRadius: BorderRadius.circular(dense ? 3 : 6),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 16,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: muted,
                          fontWeight: highlightIndex == i ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Ikon kecil di atas kotak berwarna lembut, dipakai di daftar dan menu
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.color, this.size = 22});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(size * 0.45),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Icon(icon, color: c, size: size),
    );
  }
}

// Judul besar di puncak tab utama, dengan subjudul kecil beraksen dan aksi opsional di kanan
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(subtitle!.toUpperCase(), style: AppTheme.display(14, color: AppTheme.accent, letterSpacing: 2)),
              Text(title, style: AppTheme.display(34, letterSpacing: 1.5)),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

// Kartu sorotan berlatar gradien aksen; isinya sebaiknya berwarna putih
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.xl), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: radius,
        boxShadow: AppTheme.softShadow(AppTheme.accent),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // Lingkaran samar di pojok supaya gradien tidak terasa datar
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Efek butiran film seperti foto hitam-putih; ditaruh di atas latar dengan Stack
class FilmGrain extends StatelessWidget {
  final double opacity;

  const FilmGrain({super.key, this.opacity = 0.06});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _GrainPainter(opacity)),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    // Seed tetap supaya pola butiran tidak berkedip setiap kali digambar ulang
    final random = math.Random(7);
    final light = Paint()..color = Colors.white.withValues(alpha: opacity);
    final dark = Paint()..color = Colors.black.withValues(alpha: opacity);
    final count = (size.width * size.height / 30).round();
    for (var i = 0; i < count; i++) {
      final rect = Rect.fromLTWH(random.nextDouble() * size.width, random.nextDouble() * size.height, 1.2, 1.2);
      canvas.drawRect(rect, i.isEven ? light : dark);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.opacity != opacity;
}
