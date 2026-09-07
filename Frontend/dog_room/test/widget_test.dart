import 'package:dog_room/controllers/dog_controller.dart';
import 'package:dog_room/models/dog_state.dart';
import 'package:dog_room/screens/dog_room_screen.dart';
import 'package:dog_room/services/dog_save_service.dart';
import 'package:dog_room/widgets/feeding_dog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryDogSaveService implements DogSaveService {
  DogState? stored;

  @override
  Future<DogState?> load() async => stored;

  @override
  Future<void> save(DogState state) async => stored = state;
}

void main() {
  testWidgets('작은 화면에서 대사를 다시 열고 성장 숫자는 숨긴다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = MemoryDogSaveService()
      ..stored = DogState(lastUpdated: DateTime.now(), experience: 9501);
    await tester.pumpWidget(
      MaterialApp(home: DogRoomScreen(controller: DogController(service))),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('dog-speech')), findsOneWidget);
    expect(find.textContaining('Lv.'), findsNothing);
    expect(find.textContaining('XP'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('dog-speech')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dog-speech-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('dog-speech')), findsOneWidget);
    expect(find.text('아빠 기다리기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('현관에서 기다리고 반긴 뒤 방으로 돌아온다', (tester) async {
    final controller = DogController(MemoryDogSaveService());
    await tester.pumpWidget(
      MaterialApp(home: DogRoomScreen(controller: controller)),
    );
    await tester.pump();
    await tester.tap(find.text('아빠 기다리기'));
    await tester.pump();
    expect(find.byKey(const ValueKey('entrance-background')), findsOneWidget);
    expect(find.byKey(const ValueKey('dog-speech')), findsNothing);
    expect(find.byKey(const ValueKey('dog-speech-toggle')), findsOneWidget);
    final arrival = find.widgetWithText(OutlinedButton, '아빠 왔다!');
    expect(tester.widget<OutlinedButton>(arrival).onPressed, isNull);
    await tester.pump(const Duration(milliseconds: 950));
    expect(tester.widget<OutlinedButton>(arrival).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('dog-speech-toggle')));
    await tester.pump();
    expect(find.text('아빠 언제 와? 여기서 기다릴래…'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/dog/baby_wait.png',
      ),
      findsOneWidget,
    );
    await tester.tap(arrival);
    await tester.pump();
    expect(find.text('아빠 왔다! 보고 싶었어 ♥'), findsOneWidget);
    for (var bounce = 0; bounce < 3; bounce++) {
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('room-background')), findsOneWidget);
    expect(find.text('아빠 기다리기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('경험치에 따라 성장 단계가 결정된다', () {
    final now = DateTime(2026);
    expect(DogState(lastUpdated: now, experience: 0).stage, GrowthStage.baby);
    expect(
      DogState(lastUpdated: now, experience: 1000).stage,
      GrowthStage.baby,
    );
    expect(
      DogState(lastUpdated: now, experience: 1001).stage,
      GrowthStage.child,
    );
    expect(
      DogState(lastUpdated: now, experience: 4001).stage,
      GrowthStage.teen,
    );
    expect(
      DogState(lastUpdated: now, experience: 9001).stage,
      GrowthStage.adult,
    );
    expect(GrowthStage.baby.assetPath, 'assets/dog/baby_idle.png');
    expect(GrowthStage.adult.assetPath, 'assets/dog/adult_idle.png');
  });

  test('레벨과 성체 이후 보상이 무한히 이어진다', () {
    final now = DateTime(2026);
    expect(DogState(lastUpdated: now, experience: 0).level, 1);
    expect(DogState(lastUpdated: now, experience: 1000).level, 5);
    expect(DogState(lastUpdated: now, experience: 1001).level, 6);
    expect(DogState(lastUpdated: now, experience: 4001).level, 16);
    expect(DogState(lastUpdated: now, experience: 9001).level, 31);
    expect(DogState(lastUpdated: now, experience: 9501).level, 32);
    expect(
      DogState(lastUpdated: now, experience: 9501).nextAdultReward,
      AdultReward.motion,
    );
  });

  test('접속하지 않은 동안 상태가 감소하되 0보다 작아지지 않는다', () {
    final before = DateTime(2026, 1, 1, 12);
    final result = DogController.applyOfflineDecay(
      DogState(lastUpdated: before, hunger: 5, cleanliness: 5),
      before.add(const Duration(hours: 1)),
    );
    expect(result.hunger, 0);
    expect(result.cleanliness, 0);
  });

  testWidgets('밥 주기를 누르면 배부름과 경험치가 증가한다', (tester) async {
    final service = MemoryDogSaveService();
    final controller = DogController(service);
    await tester.pumpWidget(
      MaterialApp(home: DogRoomScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.text('밥 주기'), findsOneWidget);
    await tester.tap(find.text('밥 주기'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(controller.state.hunger, 94);
    expect(controller.state.experience, 12);
    expect(service.stored?.experience, 12);
    expect(find.byType(FeedingDog), findsOneWidget);
    await tester.tap(find.text('밥 주기'));
    await tester.pump(const Duration(milliseconds: 2200));
    expect(controller.state.experience, 12);
    expect(find.byType(FeedingDog), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.byType(FeedingDog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
