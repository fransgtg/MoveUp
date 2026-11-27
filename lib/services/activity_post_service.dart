import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/models/user_profile.dart';
import 'package:moveup/services/auth_service.dart';

class ActivityPost {
  ActivityPost.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
    : id = doc.id,
      ownerId = doc['ownerId'] as String,
      author = doc['author'] as String,
      activity = Activity(
        id: doc.id,
        title: doc['title'] as String,
        description: doc['description'] as String,
        type: SportType.fromName(doc['sport'] as String),
        startTime: (doc['startTime'] as Timestamp).toDate(),
        movingSeconds: doc['movingSeconds'] as int,
        distanceMeters: (doc['distanceMeters'] as num).toDouble(),
      );

  final String id;
  final String ownerId;
  final String author;
  final Activity activity;
}

class ActivityPostService {
  static const maxCommentLength = 500;

  static CollectionReference<Map<String, dynamic>> get _posts =>
      FirebaseFirestore.instance.collection('activityPosts');

  static Stream<List<ActivityPost>> feed() => _posts
      .where('published', isEqualTo: true)
      .orderBy('postedAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ActivityPost.fromSnapshot).toList());

  static Stream<ActivityPost?> watch(String id) => _posts
      .doc(id)
      .snapshots()
      .map(
        (doc) => doc.data()?['published'] == true
            ? ActivityPost.fromSnapshot(doc)
            : null,
      );

  static Future<void> publish(Activity activity, UserProfile profile) =>
      _posts.doc('${profile.uid}:${activity.id}').set({
        'ownerId': profile.uid,
        'author': profile.name,
        'title': activity.title,
        'description': activity.description,
        'sport': activity.type.name,
        'startTime': Timestamp.fromDate(activity.startTime),
        'movingSeconds': activity.movingSeconds,
        'distanceMeters': activity.distanceMeters,
        'published': true,
        'postedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> unpublish(String id) =>
      _posts.doc(id).update({'published': false});

  static CollectionReference<Map<String, dynamic>> _comments(String id) =>
      _posts.doc(id).collection('comments');

  static Stream<QuerySnapshot<Map<String, dynamic>>> comments(String id) =>
      _comments(id)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots();

  static Future<void> comment(
    String id,
    UserProfile profile,
    String text,
  ) async {
    final body = text.trim();
    if (body.isEmpty || body.runes.length > maxCommentLength) {
      throw const AuthFailure('Komentar harus berisi 1–500 karakter.');
    }
    await _comments(id).add({
      'senderId': profile.uid,
      'author': profile.name,
      'text': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
