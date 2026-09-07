import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/main.dart';
import 'package:mira/dog_room/controllers/dog_controller.dart';
import 'package:mira/dog_room/models/dog_state.dart';
import 'package:mira/dog_room/screens/dog_room_screen.dart';
import 'package:mira/dog_room/services/dog_save_service.dart';
import 'package:mira/memories/memory_page.dart';
import 'package:mira/privacy/privacy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> phone(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  await expectLater(
    find.byType(MiraApp),
    matchesGoldenFile('../../../.mira-work/$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });

  testWidgets('첫 시작은 두 안내 확인 후에만 로그인으로 진행한다', (tester) async {
    await phone(tester);
    await tester.pumpWidget(const MiraApp());
    await tester.pumpAndSettle();
    await capture(tester, 'onboarding');
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);
    await capture(tester, 'privacy');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '확인하고 시작하기'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('이용 안내 확인'));
    await tester.tap(find.text('이용 안내 확인'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '확인하고 시작하기'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('개인정보 처리방침 확인'));
    await tester.tap(find.text('개인정보 처리방침 확인'));
    await tester.pump();
    await tester.ensureVisible(find.text('확인하고 시작하기'));
    await tester.tap(find.text('확인하고 시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(
      await SharedPreferencesAsync().getString(privacyKey),
      startsWith('$privacyVersion|'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('같은 버전 안내를 확인한 사용자는 반복 확인하지 않는다', (tester) async {
    await SharedPreferencesAsync().setString(
      privacyKey,
      '$privacyVersion|2026-09-06',
    );
    await phone(tester);
    await tester.pumpWidget(const MiraApp());
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  // 사진첩이 로컬 저장(MemoryStore)에서 Firestore 기반(PhotoService)으로 바뀌면서,
  // 업로드·좋아요·댓글·삭제 같은 실제 데이터 흐름은 더 이상 이 테스트 파일만으로는
  // 검증할 수 없다 — family_service/photo_service 등이 FirebaseFirestore.instance를
  // 직접 참조해서 fake_cloud_firestore 같은 걸 끼워 넣으려면 서비스들이 인스턴스를
  // 주입받는 구조로 먼저 바뀌어야 한다. 그 전까지는 "로그인 안 했을 때 안내 문구만
  // 보여주고 죽지 않는다" 정도의 스모크 테스트로 대체한다.
  testWidgets('로그인하지 않으면 사진첩 대신 안내 문구를 보여준다', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      const MiraApp(home: Scaffold(body: MemoryPage(active: true))),
    );
    await tester.pump();
    expect(find.text('로그인 후 사진첩을 볼 수 있어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 모바일 화면의 모든 탭과 가입 화면에 레이아웃 오류가 없다', (tester) async {
    await phone(tester, width: 320, height: 640);
    for (final page in [
      AuthScreen(onDone: () {}),
      ProfileSetup(onDone: () {}),
      PetSetup(onDone: () {}),
      const MainShell(),
    ]) {
      await tester.pumpWidget(
        MiraApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.4)),
              child: page,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
    for (final label in ['펫', '가족', '사진첩', 'MIRA', '설정', '홈']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('모바일 홈과 전체 펫 화면이 돌봄 상태를 공유한다', (tester) async {
    await phone(tester);
    await tester.pumpWidget(const MiraApp(home: MainShell()));
    await tester.pump(const Duration(milliseconds: 100));
    // Precache images outside the fake clock, without waiting on repeating dog animations.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    expect(find.byType(DogRoomScreen), findsOneWidget);
    final homeDog = tester
        .widget<DogRoomScreen>(find.byType(DogRoomScreen))
        .controller;
    await capture(tester, 'home');
    await homeDog.care(CareAction.feed);
    final experience = homeDog.state.experience;
    await tester.tap(find.text('펫'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final petDog = tester
        .widget<DogRoomScreen>(find.byType(DogRoomScreen))
        .controller;
    expect(identical(homeDog, petDog), isTrue);
    expect(petDog.state.experience, experience);
    expect(find.text('밥 주기'), findsOneWidget);
    await capture(tester, 'pet');
    await tester.tap(find.text('홈'));
    await tester.pump();
    expect(
      tester
          .widget<DogRoomScreen>(find.byType(DogRoomScreen))
          .controller
          .state
          .experience,
      experience,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('320px 화면과 큰 글자에서 개인정보·사진첩·펫이 넘치지 않는다', (tester) async {
    await phone(tester, width: 320, height: 640);
    final dog = DogController(_DogStorage());
    for (final page in [
      PrivacyScreen(onDone: () {}),
      const Scaffold(body: MemoryPage(active: true)),
      PetPage(controller: dog),
    ]) {
      await tester.pumpWidget(
        MiraApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.4)),
              child: page,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await capture(tester, 'pet-large-text');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    dog.dispose();
  });

  test('돌봄 상태를 다시 불러와도 경험치를 덮어쓰지 않는다', () async {
    final storage = _DogStorage();
    final dog = DogController(storage);
    await dog.initialize();
    await dog.care(CareAction.play);
    await dog.initialize();
    expect(dog.state.experience, 18);
    expect(storage.loads, 1);
    final reopened = DogController(storage);
    await reopened.initialize();
    expect(reopened.state.experience, 18);
    dog.dispose();
    reopened.dispose();
  });

  test('오래 쉬어도 강아지 상태는 음수가 되지 않는다', () {
    final now = DateTime(2026, 9, 6);
    final state = DogController.applyOfflineDecay(
      DogState(lastUpdated: now.subtract(const Duration(days: 100))),
      now,
    );
    expect(state.hunger, 0);
    expect(state.energy, 0);
    expect(state.experience, 0);
  });
}

class _DogStorage implements DogSaveService {
  DogState? state;
  int loads = 0;
  @override
  Future<DogState?> load() async {
    loads++;
    return state;
  }

  @override
  Future<void> save(DogState state) async {
    this.state = state;
  }
}
