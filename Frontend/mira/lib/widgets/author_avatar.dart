import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const roleEmoji = {'아빠': '👨', '엄마': '👩', '아들': '👦', '딸': '👧'};

// 작성자의 최신 프로필 사진을 실시간으로 반영 - 게시물에 사진을 복사해 저장하지 않고
// users/{uid} 문서를 구독해서 보여주므로 나중에 사진을 바꿔도 과거 글/댓글에 함께 반영됨.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({required this.uid, this.role, this.radius = 16, super.key});
  final String? uid;
  final String? role;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final uid = this.uid;
    if (uid == null) {
      return CircleAvatar(radius: radius, child: Text(roleEmoji[role] ?? '👤'));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final photoBase64 = snapshot.data?.data()?['photo'] as String?;
        return CircleAvatar(
          radius: radius,
          backgroundImage: photoBase64 != null ? MemoryImage(base64Decode(photoBase64)) : null,
          child: photoBase64 == null ? Text(roleEmoji[role] ?? '👤') : null,
        );
      },
    );
  }
}
