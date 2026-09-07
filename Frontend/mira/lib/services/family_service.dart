import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const familyRoles = ['아빠', '엄마', '아들', '딸'];

class FamilyServiceException implements Exception {
  FamilyServiceException(this.message);
  final String message;
}

class FamilyService {
  FamilyService._();
  static final instance = FamilyService._();

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final _firestore = FirebaseFirestore.instance;

  Future<String?> fetchMyFamilyId(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['familyId'] as String?;
  }

  Stream<List<Map<String, dynamic>>> watchFamilyMembers(String familyId) {
    return _firestore
        .collection('users')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => {...doc.data(), 'uid': doc.id}).toList(),
        );
  }

  String _generateCode() {
    final random = Random.secure();
    return List.generate(8, (_) => _codeChars[random.nextInt(_codeChars.length)]).join();
  }

  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      final doc = await _firestore.collection('families').doc(code).get();
      if (!doc.exists) return code;
    }
    throw FamilyServiceException('코드 생성에 실패했어요. 다시 시도해주세요.');
  }

  Future<Map<String, dynamic>> createFamily(String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw FamilyServiceException('로그인이 필요해요.');

    final code = await _generateUniqueCode();
    final familyRef = _firestore.collection('families').doc(code);
    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((tx) async {
      tx.set(familyRef, {
        'members': {uid: role},
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {'familyId': code, 'role': role}, SetOptions(merge: true));
    });

    return {'familyId': code, 'inviteCode': code};
  }

  Future<Map<String, dynamic>> joinFamily(String inviteCode, String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw FamilyServiceException('로그인이 필요해요.');
    if (inviteCode.trim().isEmpty) {
      throw FamilyServiceException('초대 코드를 입력해주세요.');
    }

    final code = inviteCode.trim().toUpperCase();
    final familyRef = _firestore.collection('families').doc(code);
    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(familyRef);
      if (!snapshot.exists) {
        throw FamilyServiceException('유효하지 않은 초대 코드예요.');
      }

      final members = Map<String, dynamic>.from(
        snapshot.data()?['members'] as Map? ?? const {},
      );
      if (!members.containsKey(uid)) {
        if (members.length >= familyRoles.length) {
          throw FamilyServiceException('가족 인원이 가득 찼어요.');
        }
        if (members.values.contains(role)) {
          throw FamilyServiceException('이미 "$role" 역할을 사용 중이에요.');
        }
        tx.update(familyRef, {'members.$uid': role});
      }
      tx.set(userRef, {'familyId': code, 'role': role}, SetOptions(merge: true));
    });

    return {'familyId': code};
  }
}
