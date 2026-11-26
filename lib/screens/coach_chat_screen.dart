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
    ('Progres minggu ini', 'Bagaimana progres latihanku minggu ini?'),
    ('Rencana latihan', 'Buatkan rencana latihan untuk minggu depan'),
    ('Tips pace lari', 'Bagaimana cara meningkatkan pace lari?'),
    ('Makan sebelum latihan', 'Apa yang sebaiknya aku makan sebelum latihan?'),
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _coach = CoachService.instance;
  final _greeting = ChatMessage(
    ChatRole.coach,
    'Halo! Aku MoveUp Coach. Mau cek progres, '
    'menyiapkan latihan berikutnya, atau membahas targetmu?',
  );

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final message = (text ?? _input.text).trim();
    if (message.isEmpty || _coach.busy) return;
    if (_input.text.trim() == message) _input.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);
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
    if (ok && mounted) {
      _input.clear();
      _coach.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const _CoachAvatar(),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MoveUp Coach', overflow: TextOverflow.ellipsis),
                  Text(
                    'Mode offline',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: _coach,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'Percakapan baru',
              onPressed: _coach.messages.isEmpty ? null : _confirmReset,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _coach,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: _coach.messages.isEmpty
                  ? _buildWelcome()
                  : _buildMessages(),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return ListView(
      padding: AppSpacing.page,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _Bubble(message: _greeting),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (label, question) in _suggestions)
              ActionChip(label: Text(label), onPressed: () => _send(question)),
          ],
        ),
      ],
    );
  }

  Widget _buildMessages() {
    final messages = _coach.messages;
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      itemCount: messages.length + 1,
      itemBuilder: (context, i) {
        if (i == messages.length) return _Bubble(message: _greeting);
        final message = messages[messages.length - i - 1];
        return _Bubble(key: ObjectKey(message), message: message);
      },
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
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
                    hintText: "Tulis pesan ke Coach",
                    counterText: "",
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (context, value, _) => IconButton.filled(
                  tooltip: 'Kirim pesan',
                  onPressed: _coach.busy || value.text.trim().isEmpty
                      ? null
                      : _send,
                  icon: const Icon(Icons.arrow_upward),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 15,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: const Icon(Icons.smart_toy_outlined, size: 17),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message});

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
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
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
              mine ? TextSpan(text: message.text) : _formatted(message.text),
              style: TextStyle(
                color: mine ? Colors.white : scheme.onSurface,
                height: 1.4,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            const _CoachAvatar(),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  // Mendukung **tebal** dari jawaban Coach; teks lain ditampilkan apa adanya
  static TextSpan _formatted(String text) {
    final parts = text.split('**');
    return TextSpan(
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(
            text: parts[i],
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
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

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

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
