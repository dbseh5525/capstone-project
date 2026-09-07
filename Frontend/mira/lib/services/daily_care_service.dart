import 'package:cloud_firestore/cloud_firestore.dart';

// dog_room의 실제 돌봄 버튼(밥 주기/목욕/놀기/재우기)과 맞춤.
const careActions = ['🍚 밥 주기', '🛁 목욕', '🎾 놀기', '😴 재우기'];

class DailyCareService {
  DailyCareService._();
  static final instance = DailyCareService._();

  final _firestore = FirebaseFirestore.instance;

  String _todayId() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  DocumentReference<Map<String, dynamic>> _doc(String familyId) => _firestore
      .collection('families')
      .doc(familyId)
      .collection('dailyCare')
      .doc(_todayId());

  Stream<Map<String, dynamic>> watchToday(String familyId) {
    return _doc(familyId).snapshots().map((snapshot) => snapshot.data() ?? {});
  }

  // 오늘 할 일을 고르기만 한 상태 - 실제로 강아지 게임에서 그 행동을 해야 완료로 바뀐다.
  Future<void> selectAction({
    required String familyId,
    required String uid,
    required String action,
  }) {
    return _doc(familyId).set({
      uid: {'action': action, 'completedAt': null},
    }, SetOptions(merge: true));
  }

  Future<void> completeSelectedAction({
    required String familyId,
    required String uid,
    required String action,
  }) async {
    final snapshot = await _doc(familyId).get();
    final record = snapshot.data()?[uid] as Map<String, dynamic>?;
    if (record == null || record['action'] != action || record['completedAt'] != null) {
      return;
    }
    await _doc(familyId).set({
      uid: {'action': action, 'completedAt': FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }
}
