import 'package:cloud_firestore/cloud_firestore.dart';

/// users/{userId}/notifications — Backend/firestore-schema.md 참고.
/// 감정 분석 결과가 부정적일 때 다른 가족 구성원에게 보낼 "가족 소식" 알림에 사용한다.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  /// [moodText]는 절대 저장하지 않는다 — family_message(요약)만 전달해서 일기 원문을
  /// 가족에게 그대로 노출하지 않는다는 정책을 서버뿐 아니라 클라이언트에서도 지킨다.
  Future<void> sendMoodAlert({
    required String toUserId,
    required String message,
    required String relatedMoodId,
  }) {
    return _collection(toUserId).add({
      'type': 'moodAlert',
      'title': '가족 소식',
      'message': message,
      'isRead': false,
      'relatedId': relatedMoodId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchUnread(String userId) {
    return _collection(userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> markRead(String userId, String notificationId) {
    return _collection(userId).doc(notificationId).update({'isRead': true});
  }
}
