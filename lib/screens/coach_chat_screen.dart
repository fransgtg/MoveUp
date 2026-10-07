import 'package:flutter/material.dart';
import 'package:moveup/services/coach_service.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/widgets.dart';

// Chat dengan MoveUp Coach, pelatih virtual yang menjawab berdasarkan data latihan pengguna
class CoachChatScreen extends StatefulWidget {
  const CoachChatScreen({super.key});

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  static const _suggestions = [
    "Bagaimana progres latihanku minggu ini?",
    "Buatkan rencana latihan untuk minggu depan",
    "Tips meningkatkan pace lari",
    "Apa yang sebaiknya kumakan sebelum latihan?",
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _coach = CoachService.instance;

  @override
  void initState() {
    super.initState();
    _coach.addListener(_onCoachChanged);
  }

  @override
  void dispose() {
    _coach.removeListener(_onCoachChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onCoachChanged() {
    final failed = _coach.takeFailedQuestion();
    if (failed != null && _input.text.isEmpty) _input.text = failed;
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _send([String? text]) {
    final message = text ?? _input.text;
    if (message.trim().isEmpty || _coach.busy) return;
    _input.clear();
    _coach.send(message);
  }

  Future<void> _confirmReset() async {
    final ok = await showConfirmDialog(
      context,
      title: "Mulai percakapan baru?",
      message: "Riwayat chat saat ini akan dihapus. Coach akan membaca ulang data latihan terbarumu.",
      confirmLabel: "Mulai Baru",
      icon: Icons.refresh,
      destructive: false,
    );
    if (ok) _coach.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MOVEUP COACH"),
        actions: [
          ListenableBuilder(
            listenable: _coach,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Percakapan baru",
              onPressed: _coach.messages.isEmpty ? null : _confirmReset,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _coach,
        builder: (context, _) => Column(
          children: [
            Expanded(child: _coach.messages.isEmpty ? _buildWelcome() : _buildMessages()),
            if (_coach.error != null) _ErrorLine(message: _coach.error!),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: AppSpacing.page,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.accentGradient,
              boxShadow: AppTheme.softShadow(AppTheme.accent),
            ),
            child: const Icon(Icons.sports_gymnastics, size: 44, color: Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text("Halo! Aku Coach-mu.", textAlign: TextAlign.center, style: AppTheme.display(28)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Tanya apa saja soal latihan, pemulihan, atau target. Aku membaca data aktivitasmu untuk memberi saran yang pas.",
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Chip(
            avatar: Icon(CoachService.isOnline ? Icons.cloud_outlined : Icons.offline_bolt_outlined, size: 18),
            label: Text(CoachService.isOnline ? "AI online (Claude)" : "Mode offline"),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel("Coba tanyakan"),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
              onTap: () => _send(s),
              child: Row(
                children: [
                  Expanded(child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600))),
                  const Icon(Icons.north_east, size: 18, color: AppTheme.accent),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessages() {
    final messages = _coach.messages;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      itemCount: messages.length,
      itemBuilder: (context, i) => _Bubble(message: messages[i]),
    );
  }

  Widget _buildComposer() {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: "Tanya Coach...",
                    counterText: "",
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                tooltip: "Kirim",
                onPressed: _coach.busy ? null : _send,
                icon: _coach.busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_upward),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.role == ChatRole.user;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? null : scheme.surface,
        gradient: mine ? AppTheme.accentGradient : null,
        borderRadius: radius,
        border: mine ? null : Border.all(color: scheme.outline),
      ),
      child: message.text.isEmpty
          ? const _TypingDots()
          : SelectableText.rich(
              _formatted(message.text, TextStyle(color: mine ? Colors.white : scheme.onSurface, height: 1.4)),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.accent,
              child: Icon(Icons.sports_gymnastics, size: 16, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  // Mendukung **tebal** dari jawaban Coach; teks lain ditampilkan apa adanya
  static TextSpan _formatted(String text, TextStyle style) {
    final parts = text.split('**');
    return TextSpan(
      style: style,
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(text: parts[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null),
      ],
    );
  }
}

// Tiga titik berkedip selama Coach belum mengirim kata pertama
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: "Coach sedang mengetik",
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Opacity(
                  // Tiap titik menyala bergantian
                  opacity: ((_controller.value * 3 - i) % 3) < 1 ? 1 : 0.3,
                  child: CircleAvatar(radius: 3.5, backgroundColor: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      color: error.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: TextStyle(color: error, fontSize: 13))),
        ],
      ),
    );
  }
}
