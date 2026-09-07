import 'package:cloud_firestore/cloud_firestore.dart';

class MomentService {
  MomentService._();
  static final instance = MomentService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('moments');

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchMoments(String familyId) {
    return _collection(familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> addMoment({
    required String familyId,
    required String authorUid,
    required String authorName,
    required String authorRole,
    required String mood,
    required String body,
  }) {
    return _collection(familyId).add({
      'authorUid': authorUid,
      'authorName': authorName,
      'authorRole': authorRole,
      'mood': mood,
      'body': body,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike({
    required String familyId,
    required String momentId,
    required String uid,
    required bool currentlyLiked,
  }) {
    return _collection(familyId).doc(momentId).update({
      'likedBy': currentlyLiked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchComments(
    String familyId,
    String momentId,
  ) {
    return _collection(familyId)
        .doc(momentId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> addComment({
    required String familyId,
    required String momentId,
    required String authorUid,
    required String authorName,
    required String authorRole,
    required String text,
  }) {
    return _collection(familyId).doc(momentId).collection('comments').add({
      'authorUid': authorUid,
      'authorName': authorName,
      'authorRole': authorRole,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
