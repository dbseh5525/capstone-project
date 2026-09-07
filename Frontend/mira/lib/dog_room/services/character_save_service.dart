import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// PetSetup에서 AI로 생성한 강아지 캐릭터 마스코트 이미지를 기기에 저장한다.
/// DogRoomScreen의 산책/식사/수면 애니메이션은 정해진 프레임 PNG 세트를 쓰기 때문에
/// 이 이미지로 교체하지 않고, 프로필 표시용(홈 화면 · 설정)으로만 쓴다.
class CharacterSaveService {
  CharacterSaveService._();
  static final instance = CharacterSaveService._();

  static const _key = 'pet_character_v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<Uint8List?> load() async {
    final encoded = await _preferences.getString(_key);
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(Uint8List bytes) =>
      _preferences.setString(_key, base64Encode(bytes));

  Future<void> clear() => _preferences.remove(_key);
}
