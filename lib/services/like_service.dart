import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:moveup/services/auth_service.dart';

class LikeService extends ChangeNotifier {
  LikeService._();

  static final instance = LikeService._();
  final Map<String, bool> _localLikes = {};

  String targetId(String type, String id) => '$type:$id';

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (AuthService.skipLogin ? AuthService.demoUid : '');

  DocumentReference<Map<String, dynamic>> _targetRef(String targetId) =>
      FirebaseFirestore.instance.collection('likes').doc(targetId);

  Stream<int> countStream(String type, String id) {
    final targetId = this.targetId(type, id);
    if (_uid.isEmpty) {
      return Stream.value(_localLikes[targetId] == true ? 1 : 0);
    }
    if (AuthService.skipLogin) {
      return Stream.value(_localLikes[targetId] == true ? 1 : 0);
    }
    return _targetRef(targetId).snapshots().map((snap) {
      final count = snap.data()?['likeCount'];
      return count is num ? count.toInt() : 0;
    });
  }

  Stream<bool> likedStream(String type, String id) {
    final targetId = this.targetId(type, id);
    final uid = _uid;
    if (uid.isEmpty) return Stream.value(_localLikes[targetId] == true);
    if (AuthService.skipLogin) {
      return Stream.value(_localLikes[targetId] == true);
    }
    return _targetRef(targetId)
        .collection('likers')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  bool isLiked(String type, String id) =>
      _localLikes[targetId(type, id)] == true;

  Future<void> toggle(String type, String id) async {
    final key = targetId(type, id);
    final uid = _uid;

    if (uid.isEmpty || AuthService.skipLogin) {
      _localLikes[key] = !(_localLikes[key] ?? false);
      notifyListeners();
      return;
    }

    final target = _targetRef(key);
    final liker = target.collection('likers').doc(uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final targetSnap = await transaction.get(target);
      final likerSnap = await transaction.get(liker);
      final currentCount =
          (targetSnap.data()?['likeCount'] as num?)?.toInt() ?? 0;

      if (likerSnap.exists) {
        transaction.delete(liker);
        transaction.set(target, {
          'type': type,
          'itemId': id,
          'likeCount': currentCount > 0 ? currentCount - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        transaction.set(liker, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(target, {
          'type': type,
          'itemId': id,
          'likeCount': currentCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }
}
