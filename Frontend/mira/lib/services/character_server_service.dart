import 'dart:typed_data';

import 'package:http/http.dart' as http;

// Backend/character-server(Stable Diffusion, GPU 필요)의 주소.
// 로컬에 GPU가 없다면 Colab에서 띄우고 ngrok 주소로 바꿔주세요.
// 자세한 실행 방법은 Backend/character-server/README.md 참고.
const _characterServerBaseUrl = 'http://localhost:5000';

class CharacterServerException implements Exception {
  CharacterServerException(this.message);
  final String message;
}

class CharacterServerService {
  CharacterServerService._();
  static final instance = CharacterServerService._();

  /// 견종/색상/성격(한국어)으로 강아지 마스코트 캐릭터 이미지를 생성한다.
  /// 같은 [seed]를 넘기면 같은 이미지가 다시 나온다.
  Future<Uint8List> generate({
    required String breed,
    required String color,
    required String personality,
    int seed = 42,
  }) async {
    final uri = Uri.parse('$_characterServerBaseUrl/generate');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            body: {
              'breed': breed,
              'color': color,
              'personality': personality,
              'seed': '$seed',
            },
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      throw CharacterServerException(
        '캐릭터 생성 서버에 연결하지 못했어요. character-server가 실행 중인지 확인해주세요.',
      );
    }

    if (response.statusCode != 200) {
      throw CharacterServerException('캐릭터를 만들지 못했어요. (${response.statusCode})');
    }
    return response.bodyBytes;
  }
}
