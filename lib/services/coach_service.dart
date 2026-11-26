import 'package:flutter/foundation.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/goal_store.dart';
import 'package:moveup/services/local_coach.dart';
import 'package:moveup/services/profile_service.dart';

enum ChatRole { user, coach }

class ChatMessage {
  ChatMessage(this.role, this.text);

  final ChatRole role;
  String text;
}

// Riwayat tetap tersedia selama sesi agar pengguna bisa membuka ulang layar chat.
class CoachService extends ChangeNotifier {
  CoachService._();

  static final instance = CoachService._();

  final List<ChatMessage> messages = [];
  Object? _pendingReply;

  bool get busy => _pendingReply != null;

  void reset() {
    _pendingReply = null;
    messages.clear();
    notifyListeners();
  }

  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || busy) return;

    final reply = ChatMessage(ChatRole.coach, '');
    final pending = _pendingReply = Object();
    messages.addAll([ChatMessage(ChatRole.user, question), reply]);
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_pendingReply != pending) return;

    reply.text = LocalCoach(
      profile: ProfileService.instance.profile,
      activities: ActivityStore.instance.activities,
      goals: GoalStore.instance.goals,
      now: DateTime.now(),
    ).reply(question);
    _pendingReply = null;
    notifyListeners();
  }
}
