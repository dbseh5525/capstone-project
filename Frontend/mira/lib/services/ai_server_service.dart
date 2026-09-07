import 'dart:convert';

import 'package:http/http.dart' as http;

// 로컬 개발용 ai-server 주소. 실기기(Android 에뮬레이터 등)에서 테스트할 땐 값이 달라질 수 있음.
const _aiServerBaseUrl = 'http://localhost:8000';

class AiServerException implements Exception {
  AiServerException(this.message);
  final String message;
}

class PetPhotoAnalysis {
  PetPhotoAnalysis({required this.breed, required this.colorDescription});
  final String breed;
  final String colorDescription;
}

/// klue/bert-base 감정 분류 6종. Backend/ai-server/app/emotion_model.py의 LABELS와 동일해야 한다.
const moodTags = ['기쁨', '슬픔', '분노', '불안', '상처', '당황'];

class MoodAnalysisResult {
  MoodAnalysisResult({
    required this.aiEmotion,
    required this.selfMessage,
    required this.familyMessage,
  });
  final String aiEmotion;
  final String selfMessage;
  final String familyMessage;

  /// "기쁨"이 아니면 가족에게 알림을 보낼 만큼 마음이 안 좋은 상태로 취급한다.
  bool get isNegative => aiEmotion != '기쁨';
}

class AiServerService {
  AiServerService._();
  static final instance = AiServerService._();

  /// 오늘의 감정 한 줄 기록을 kobert로 분석하고, 본인용/가족용 공감 메시지를 생성한다.
  /// family_message는 일기 원문을 그대로 노출하지 않고 요약해서 전달하도록 서버에서 만들어준다.
  Future<MoodAnalysisResult> analyzeMood({
    required String moodText,
    required String moodTag,
    required String userRole,
    required List<String> familyRoles,
  }) async {
    final uri = Uri.parse('$_aiServerBaseUrl/analyze-mood');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mood_text': moodText,
              'mood_tag': moodTag,
              'user_role': userRole,
              'family_roles': familyRoles,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw AiServerException('AI 서버에 연결하지 못했어요. ai-server가 실행 중인지 확인해주세요.');
    }

    if (response.statusCode != 200) {
      String detail;
      try {
        detail = (jsonDecode(response.body) as Map)['detail'] as String? ?? response.body;
      } catch (_) {
        detail = response.body;
      }
      throw AiServerException(detail);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return MoodAnalysisResult(
      aiEmotion: data['ai_emotion'] as String,
      selfMessage: data['self_message'] as String,
      familyMessage: data['family_message'] as String,
    );
  }

  Future<PetPhotoAnalysis> analyzePetPhotos(List<List<int>> images) async {
    final uri = Uri.parse('$_aiServerBaseUrl/analyze-pet-photo');
    final request = http.MultipartRequest('POST', uri);
    for (var i = 0; i < images.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes('images', images[i], filename: 'photo_$i.jpg'),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      String detail;
      try {
        detail = (jsonDecode(response.body) as Map)['detail'] as String? ?? response.body;
      } catch (_) {
        detail = response.body;
      }
      throw AiServerException(detail);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PetPhotoAnalysis(
      breed: data['breed'] as String,
      colorDescription: data['color_description'] as String,
    );
  }
}
