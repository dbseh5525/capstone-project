import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoService {
  PhotoService._();
  static final instance = PhotoService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('photos');

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchPhotos(String familyId) {
    return _collection(familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> addPhoto({
    required String familyId,
    required String authorUid,
    required String authorName,
    required String authorRole,
    required String photoBase64,
    required String body,
  }) {
    return _collection(familyId).add({
      'authorUid': authorUid,
      'authorName': authorName,
      'authorRole': authorRole,
      'photo': photoBase64,
      'body': body,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike({
    required String familyId,
    required String photoId,
    required String uid,
    required bool currentlyLiked,
  }) {
    return _collection(familyId).doc(photoId).update({
      'likedBy': currentlyLiked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> deletePhoto({required String familyId, required String photoId}) {
    return _collection(familyId).doc(photoId).delete();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchComments(
    String familyId,
    String photoId,
  ) {
    return _collection(familyId)
        .doc(photoId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> addComment({
    required String familyId,
    required String photoId,
    required String authorUid,
    required String authorName,
    required String authorRole,
    required String text,
  }) {
    return _collection(familyId).doc(photoId).collection('comments').add({
      'authorUid': authorUid,
      'authorName': authorName,
      'authorRole': authorRole,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
