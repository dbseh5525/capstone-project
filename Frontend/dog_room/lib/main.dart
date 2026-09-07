import 'package:flutter/material.dart';

import 'controllers/dog_controller.dart';
import 'screens/dog_room_screen.dart';
import 'services/dog_save_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DogRoomApp());
}

class DogRoomApp extends StatelessWidget {
  const DogRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '포메의 방',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF29B76),
          surface: const Color(0xFFFFF7ED),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF7ED),
        useMaterial3: true,
      ),
      home: DogRoomScreen(
        controller: DogController(SharedPreferencesDogSaveService()),
      ),
    );
  }
}
