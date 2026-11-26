import 'package:flutter/material.dart';
import 'package:moveup/services/like_service.dart';

class LikeButton extends StatelessWidget {
  const LikeButton({
    super.key,
    required this.type,
    required this.id,
    this.compact = false,
  });

  final String type;
  final String id;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final service = LikeService.instance;
    return StreamBuilder<bool>(
      stream: service.likedStream(type, id),
      initialData: false,
      builder: (context, likedSnapshot) {
        final liked = likedSnapshot.data ?? false;
        return StreamBuilder<int>(
          stream: service.countStream(type, id),
          initialData: 0,
          builder: (context, countSnapshot) {
            final count = countSnapshot.data ?? 0;
            final color = liked
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant;

            return TextButton.icon(
              style: compact
                  ? TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              onPressed: () async {
                try {
                  await service.toggle(type, id);
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Gagal menyimpan like.")),
                  );
                }
              },
              icon: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: compact ? 18 : 20,
                color: color,
              ),
              label: Text('$count', style: TextStyle(color: color)),
            );
          },
        );
      },
    );
  }
}
