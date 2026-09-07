import 'package:cloud_firestore/cloud_firestore.dart';

/// families/{familyId}/moods — 홈 화면 "오늘의 감정 한 줄 기록".
/// Backend/firestore-schema.md의 moods 컬렉션과 동일한 필드를 쓴다.
/// FamilyPage의 "오늘의 마음 기록"(moments, 가족에게 원문이 그대로 보이는 공개 피드)과는
/// 다르게, moods는 원문을 가족에게 직접 보여주지 않는 비공개 기록이다 — 가족에게는
/// AiServerService.analyzeMood가 만들어준 family_message(요약)만 알림으로 전달된다.
class MoodService {
  MoodService._();
  static final instance = MoodService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('moods');

  Future<String> addMood({
    required String familyId,
    required String userId,
    required String role,
    required String moodTag,
    required String moodText,
    required String aiEmotion,
  }) async {
    final ref = await _collection(familyId).add({
      'userId': userId,
      'role': role,
      'moodTag': moodTag,
      'moodText': moodText,
      'aiEmotion': aiEmotion,
      'date': DateTime.now().toIso8601String().split('T').first,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
}
