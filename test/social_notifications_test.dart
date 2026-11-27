import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moveup/services/social_notifications.dart';

void main() {
  final time = Timestamp.fromMillisecondsSinceEpoch(1800000000000);
  test('permintaan baru hanya memberi notifikasi ke penerima', () {
    final request = {
      'senderId': 'Ana',
      'members': ['Ana', 'Budi'],
      'status': 'pending',
      'createdAt': time,
    };
    expect(
      SocialEvent.friend.incoming('Budi', request)?.event,
      SocialEvent.friend,
    );
    expect(SocialEvent.friend.incoming('Ana', request), isNull);
    expect(SocialEvent.friend.incoming('Evi', request), isNull);
    expect(
      SocialEvent.friend.incoming('Budi', {...request, 'status': 'accepted'}),
      isNull,
    );
  });

  test('notifikasi chat membuka percakapan dengan pengirim yang sesuai', () {
    final chat = {
      'members': ['Ana', 'Budi'],
      'names': {'Ana': 'Ana Putri'},
      'updatedAt': time,
      'lastSenderId': 'Ana',
    };
    expect(SocialEvent.message.incoming('Ana', chat), isNull);
    expect(SocialEvent.message.incoming('Evi', chat), isNull);
    final alert = SocialEvent.message.incoming('Budi', chat)!;
    final tap = SocialAlert.parse(alert.payload)!;
    expect(tap.event, SocialEvent.message);
    expect(tap.recipient, 'Budi');
    expect(tap.sender, 'Ana');
    expect(tap.title, contains('Ana Putri'));
    expect(tap.time, time.microsecondsSinceEpoch);
    expect(SocialAlert.parse(null), isNull);
  });
}
