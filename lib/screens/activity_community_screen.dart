import 'package:flutter/material.dart';
import 'package:moveup/models/chat.dart';
import 'package:moveup/screens/user_search_screen.dart';
import 'package:moveup/services/activity_post_service.dart';
import 'package:moveup/services/chat_service.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/widgets/activity_feed_card.dart';

class ActivityCommunityScreen extends StatefulWidget {
  const ActivityCommunityScreen({super.key});

  @override
  State<ActivityCommunityScreen> createState() =>
      _ActivityCommunityScreenState();
}

class _ActivityCommunityScreenState extends State<ActivityCommunityScreen> {
  late final _feed = ActivityPostService.feed();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Komunitas')),
    body: StreamBuilder<List<ActivityPost>>(
      stream: _feed,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Gagal memuat postingan.'));
        }
        final posts = snapshot.data;
        if (posts == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (posts.isEmpty) {
          return const Center(child: Text('Belum ada postingan aktivitas.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            void openPost() => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ActivityPostScreen(postId: post.id),
              ),
            );
            return ActivityFeedCard(
              key: ValueKey(post.id),
              activity: post.activity,
              author: post.author,
              onTap: openPost,
              actions: _PostActions(post: post, onComments: openPost),
            );
          },
        );
      },
    ),
  );
}

class ActivityPostScreen extends StatefulWidget {
  const ActivityPostScreen({super.key, required this.postId});

  final String postId;

  @override
  State<ActivityPostScreen> createState() => _ActivityPostScreenState();
}

class _ActivityPostScreenState extends State<ActivityPostScreen> {
  late final _post = ActivityPostService.watch(widget.postId);
  late final _comments = ActivityPostService.comments(widget.postId);
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _comment() async {
    final profile = ProfileService.instance.profile;
    final text = _controller.text.trim();
    if (profile == null || _sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ActivityPostService.comment(widget.postId, profile, text);
      if (mounted) _controller.clear();
    } catch (_) {
      if (mounted) showErrorMessage(context, 'Gagal mengirim komentar.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _unpublish() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Tarik postingan?',
      message:
          'Postingan dan komentarnya akan disembunyikan dari Komunitas '
          'dan dari chat yang membagikannya.',
      confirmLabel: 'Tarik',
    );
    if (!confirmed || !mounted) return;
    try {
      await ActivityPostService.unpublish(widget.postId);
      if (mounted) {
        showSuccessMessage(context, 'Postingan ditarik.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showErrorMessage(context, 'Gagal menarik postingan.');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ActivityPost?>(
    stream: _post,
    builder: (context, snapshot) {
      final post = snapshot.data;
      final ownPost =
          post != null && post.ownerId == ProfileService.instance.profile?.uid;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Postingan Aktivitas'),
          actions: [
            if (ownPost)
              IconButton(
                tooltip: 'Tarik postingan',
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: _unpublish,
              ),
          ],
        ),
        body: snapshot.hasError
            ? const Center(child: Text('Postingan tidak dapat dibuka.'))
            : post != null
            ? _content(post)
            : Center(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const CircularProgressIndicator()
                    : const Text('Postingan tidak tersedia.'),
              ),
      );
    },
  );

  Widget _content(ActivityPost post) => Column(
    children: [
      Expanded(
        child: StreamBuilder(
          stream: _comments,
          builder: (context, snapshot) {
            final comments = snapshot.data?.docs ?? [];
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: comments.length + 1,
              itemBuilder: (context, index) {
                if (index > 0) {
                  final comment = comments[index - 1];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(comment['author'] as String),
                    subtitle: Text(comment['text'] as String),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ActivityFeedCard(
                      activity: post.activity,
                      author: post.author,
                      actions: _PostActions(post: post),
                    ),
                    Text(
                      'Komentar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (snapshot.hasError)
                      const Text('Gagal memuat komentar.')
                    else if (!snapshot.hasData)
                      const LinearProgressIndicator()
                    else if (comments.isEmpty)
                      const Text('Belum ada komentar.'),
                  ],
                );
              },
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_sending,
                maxLength: ActivityPostService.maxCommentLength,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Tulis komentar',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) => IconButton.filled(
                tooltip: 'Kirim komentar',
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: _sending || value.text.trim().isEmpty
                    ? null
                    : _comment,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PostActions extends StatefulWidget {
  const _PostActions({required this.post, this.onComments});

  final ActivityPost post;
  final VoidCallback? onComments;

  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions> {
  bool _sharing = false;

  Future<void> _share() async {
    final profile = ProfileService.instance.profile;
    if (profile == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final recipient = await Navigator.push<PublicProfile>(
        context,
        MaterialPageRoute(
          builder: (_) => const UserSearchScreen(selectRecipient: true),
        ),
      );
      if (recipient == null || !mounted) return;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Bagikan lewat chat?',
        message: 'Kirim postingan ini ke ${recipient.name}.',
        confirmLabel: 'Kirim',
        destructive: false,
        icon: Icons.share_outlined,
      );
      if (!confirmed || !mounted) return;
      await ChatService.send(
        fromUid: profile.uid,
        fromName: profile.name,
        toUid: recipient.uid,
        toName: recipient.name,
        text: 'Postingan aktivitas',
        activityPostId: widget.post.id,
      );
      if (mounted) showSuccessMessage(context, 'Postingan dibagikan.');
    } catch (_) {
      if (mounted) showErrorMessage(context, 'Gagal membagikan postingan.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Wrap(
      children: [
        if (widget.onComments != null)
          TextButton.icon(
            onPressed: widget.onComments,
            icon: const Icon(Icons.comment_outlined),
            label: const Text('Komentar'),
          ),
        TextButton.icon(
          onPressed: _sharing ? null : _share,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Bagikan'),
        ),
      ],
    ),
  );
}
