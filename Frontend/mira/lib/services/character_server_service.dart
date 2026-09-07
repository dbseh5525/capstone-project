import 'dart:typed_data';

import 'package:http/http.dart' as http;

// Backend/character-server(Stable Diffusion, GPU 필요)의 주소.
// 로컬에 GPU가 없다면 Colab에서 띄우고 ngrok 주소로 바꿔주세요.
// 자세한 실행 방법은 Backend/character-server/README.md 참고.
// TODO: Colab 세션이 끊기면 ngrok 주소가 바뀌니 그때마다 여기 업데이트 필요.
const _characterServerBaseUrl = 'https://contents-revenue-opossum.ngrok-free.dev';

class CharacterServerException implements Exception {
  CharacterServerException(this.message);
  final String message;
}

class CharacterServerService {
  CharacterServerService._();
  static final instance = CharacterServerService._();

  /// 견종/색상/성격(한국어)으로 강아지 마스코트 캐릭터 이미지를 생성한다.
  /// 업로드한 사진 자체는 반영하지 않는다 — SD1.5 img2img로 시도해봤지만 사진마다
  /// 결과가 너무 들쭉날쭉해서(형태가 깨지거나 스타일 변환이 거의 안 되거나) 포기했다.
  /// 항상 서버 쪽 기준 이미지(baby_idle.png)에서 시작해 텍스트로만 반영한다.
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
