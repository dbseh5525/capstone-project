import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'design/mira_icons.dart';
import 'dog_room/controllers/dog_controller.dart';
import 'dog_room/services/character_save_service.dart';
import 'dog_room/services/dog_save_service.dart';
import 'dog_room/screens/dog_room_screen.dart';
import 'firebase_options.dart';
import 'memories/memory_page.dart';
import 'mood/mood_diary_sheet.dart';
import 'privacy/privacy_screen.dart';
import 'services/ai_server_service.dart';
import 'services/auth_service.dart';
import 'services/character_server_service.dart';
import 'services/daily_care_service.dart';
import 'services/family_service.dart';
import 'services/moment_service.dart';
import 'services/notification_service.dart';
import 'services/pet_service.dart';
import 'widgets/author_avatar.dart';

const textScaleKey = 'text_scale_v1';
final textScaleNotifier = ValueNotifier<double>(1.0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Web/Android는 아직 Firebase 앱 등록 전이라 화면 미리보기용으로 무시.
  }
  try {
    final savedScale = await SharedPreferencesAsync().getDouble(textScaleKey);
    if (savedScale != null) textScaleNotifier.value = savedScale;
  } catch (_) {
    /* 기본 배율(1.0) 유지 */
  }
  runApp(const MiraApp());
}
const ink = Color(0xFF263E34),
    violet = Color(0xFF315E50),
    cream = Color(0xFFF7F8F3);

class MiraApp extends StatelessWidget {
  const MiraApp({this.home, super.key});
  final Widget? home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MIRA',
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      fontFamily: 'Pretendard',
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: ink),
        bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: ink),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Color(0xFF68766D),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFFD3DDD3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE3E8DF),
        thickness: 1,
      ),
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: violet, surface: cream),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFFFFFEFB),
        indicatorColor: Color(0xFFE3EBDF),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(18),
        ),
        contentPadding: const EdgeInsets.all(17),
      ),
    ),
    builder: (context, child) => ValueListenableBuilder<double>(
      valueListenable: textScaleNotifier,
      builder: (context, scale, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: ColoredBox(
          color: const Color(0xFFE9EEE7),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ClipRect(child: child!),
            ),
          ),
        ),
      ),
    ),
    home: home ?? const AppFlow(),
  );
}

enum Stage { onboarding, privacy, auth, profile, pet, app }

class AppFlow extends StatefulWidget {
  const AppFlow({this.skipOnboarding = false, super.key});
  final bool skipOnboarding;
  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  Stage stage = Stage.onboarding;

  @override
  void initState() {
    super.initState();
    if (widget.skipOnboarding) {
      stage = Stage.auth;
      _start();
    }
  }

  Future<void> _start() async {
    String? record;
    try {
      record = await SharedPreferencesAsync().getString(privacyKey);
    } catch (_) {
      /* Show the notice if storage is unavailable. */
    }
    if (record?.startsWith('$privacyVersion|') != true) {
      if (mounted) setState(() => stage = Stage.privacy);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => stage = Stage.auth);
        return;
      }

      final familyId = await FamilyService.instance.fetchMyFamilyId(user.uid);
      if (mounted) {
        setState(() => stage = familyId == null ? Stage.profile : Stage.app);
      }
    } catch (_) {
      // Firebase 미설정 플랫폼(화면 미리보기 등)에서는 로그인 화면부터 보여준다.
      if (mounted) setState(() => stage = Stage.auth);
    }
  }

  @override
  Widget build(BuildContext context) => switch (stage) {
    Stage.onboarding => Onboarding(onDone: _start),
    Stage.privacy => PrivacyScreen(
      onDone: () => setState(() => stage = Stage.auth),
    ),
    Stage.auth => AuthScreen(onDone: _start),
    Stage.profile => ProfileSetup(
      onDone: () => setState(() => stage = Stage.pet),
    ),
    Stage.pet => PetSetup(onDone: () => setState(() => stage = Stage.app)),
    Stage.app => const MainShell(),
  };
}

class Onboarding extends StatefulWidget {
  const Onboarding({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final page = PageController();
  int index = 0;
  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  final data = const [
    (
      '가족의 하루가\n하나의 이야기가 되도록',
      '감정과 일상, 함께한 순간을 MIRA가 다정하게 이어드려요.',
      CupertinoIcons.heart_fill,
      Color(0xFFFFD7CF),
    ),
    (
      '말하지 않아도\n놓치지 않는 작은 신호',
      '일기는 안전하게 지키고, 가족에게는 필요한 마음만 전해요.',
      CupertinoIcons.sparkles,
      Color(0xFFDCD8FF),
    ),
    (
      '우리 가족이 함께\n돌보는 새로운 친구',
      '매일 한 사람, 한 번의 참여가 가족의 세계를 키워요.',
      Icons.pets_rounded,
      Color(0xFFD9EFD7),
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        PageView.builder(
          controller: page,
          itemCount: 3,
          onPageChanged: (v) => setState(() => index = v),
          itemBuilder: (_, i) {
            final d = data[i];
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 130),
                children: [
                  Row(
                    children: [
                      const Text(
                        'MIRA',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: violet,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onDone,
                        child: const Text('건너뛰기'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      color: d.$4.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/dog/${['baby_idle', 'child_idle', 'baby_tail_01'][i]}.png',
                          height: 225,
                        ),
                        Positioned(
                          right: 24,
                          top: 24,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              [
                                CupertinoIcons.heart,
                                CupertinoIcons.sparkles,
                                CupertinoIcons.house,
                              ][i],
                              color: violet,
                              size: 25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  Text(
                    d.$1,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.9,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    d.$2,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: Color(0xFF68766D),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          left: 28,
          right: 28,
          bottom: 34,
          child: Row(
            children: [
              ...List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: i == index ? 28 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(
                    color: i == index ? ink : ink.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const Spacer(),
              FloatingActionButton(
                onPressed: () {
                  if (index == 2) {
                    widget.onDone();
                  } else {
                    page.nextPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  }
                },
                backgroundColor: ink,
                foregroundColor: Colors.white,
                child: Icon(index == 2 ? Icons.check : Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool signup = false;
  bool _submitting = false;
  String? _errorText;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = '이메일과 비밀번호를 입력해주세요');
      return;
    }
    if (signup && password != _passwordConfirmController.text) {
      setState(() => _errorText = '비밀번호가 일치하지 않아요');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      if (signup) {
        await AuthService.instance.signUp(
          email: email,
          password: password,
          name: _nameController.text.trim(),
        );
      } else {
        await AuthService.instance.signIn(email: email, password: password);
      }
      widget.onDone();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = AuthService.instance.messageFor(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 42),
            const Text(
              'MIRA',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              signup ? '가족의 첫 페이지를\n만들어 볼까요?' : '다시 만나서\n반가워요',
              style: const TextStyle(
                fontSize: 34,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              signup ? '가족 프로필을 설정하고 둘러보세요.' : '우리 가족의 오늘을 확인해 보세요.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (signup) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일',
                prefixIcon: Icon(CupertinoIcons.envelope),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                prefixIcon: Icon(CupertinoIcons.lock),
              ),
            ),
            if (signup) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _passwordConfirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  padding: const EdgeInsets.all(18),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(signup ? '프로필 만들기' : '로그인'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() => signup = !signup),
                child: Text(signup ? '이미 계정이 있어요 · 로그인' : '처음이신가요? · 회원가입'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SetupFrame extends StatelessWidget {
  const SetupFrame({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });
  final String step, title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step,
              style: const TextStyle(
                color: violet,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 32,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 32),
            child,
          ],
        ),
      ),
    ),
  );
}

class ProfileSetup extends StatefulWidget {
  const ProfileSetup({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  String role = '딸';
  bool _submitting = false;
  String? _errorText;
  DateTime? _birthday;
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
        _birthdayController.text =
            '${picked.year}. ${picked.month.toString().padLeft(2, '0')}. ${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveProfileFields() async {
    final name = _nameController.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && (name.isNotEmpty || _birthday != null)) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        if (name.isNotEmpty) 'name': name,
        if (_birthday != null)
          'birthday':
              '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
      }, SetOptions(merge: true));
    }
  }

  Future<void> _handleCreate() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await _saveProfileFields();
      await FamilyService.instance.createFamily(role);
      widget.onDone();
    } on FamilyServiceException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleJoin() async {
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) {
      setState(() => _errorText = '초대 코드를 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await _saveProfileFields();
      await FamilyService.instance.joinFamily(inviteCode, role);
      widget.onDone();
    } on FamilyServiceException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SetupFrame(
    step: '01 / 02',
    title: '가족에게 나는\n어떤 사람인가요?',
    subtitle: '첫 로그인에 한 번만 설정하면 돼요.',
    child: Column(
      children: [
        Wrap(
          spacing: 8,
          children: familyRoles
              .map(
                (e) => ChoiceChip(
                  avatar: Text(
                    _roleEmoji[e]!,
                  ),
                  label: Text(e),
                  selected: role == e,
                  onSelected: (_) => setState(() => role = e),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '이름', hintText: '이름을 입력하세요'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _birthdayController,
          readOnly: true,
          onTap: _pickBirthday,
          decoration: const InputDecoration(
            labelText: '생년월일',
            hintText: '예) 2002. 03. 14',
            suffixIcon: Icon(CupertinoIcons.calendar),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(_errorText!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 28),
        const Text('처음이신가요?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _handleCreate,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('가족 코드 생성하기'),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const Text('이미 가족 코드가 있으신가요?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _inviteCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: '가족 초대 코드',
            hintText: '가족에게 받은 코드를 입력하세요',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _submitting ? null : _handleJoin,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(18)),
            child: const Text('가족 코드 등록하기'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: widget.onDone,
            child: const Text('백엔드 연동 없이 화면만 보기'),
          ),
        ),
      ],
    ),
  );
}

class PetSetup extends StatefulWidget {
  const PetSetup({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<PetSetup> createState() => _PetSetupState();
}

class _PetSetupState extends State<PetSetup> {
  bool photo = true;
  String personality = '활발함';
  final _breedController = TextEditingController();
  final _colorController = TextEditingController();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final List<Uint8List> _photoBytes = [];
  bool _analyzing = false;
  bool _saving = false;
  bool _loadingExisting = true;
  bool _hadExistingPet = false;
  String? _analysisError;
  Uint8List? _characterImage;
  bool _generatingCharacter = false;
  String? _characterError;
  int _characterSeed = 42;
  String? _saveError;
  String? _familyId;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingExisting = false);
      return;
    }
    final familyId = await FamilyService.instance.fetchMyFamilyId(uid);
    final pet = familyId == null ? null : await PetService.instance.fetchPet(familyId);
    if (!mounted) return;
    setState(() {
      _familyId = familyId;
      _loadingExisting = false;
      if (pet != null) {
        _hadExistingPet = true;
        photo = false;
        _nameController.text = pet['name'] as String? ?? '';
        _breedController.text = pet['breed'] as String? ?? '';
        _colorController.text = pet['colorDescription'] as String? ?? '';
        personality = pet['personality'] as String? ?? personality;
      }
    });
  }

  @override
  void dispose() {
    _breedController.dispose();
    _colorController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _generateCharacter({bool reroll = false}) async {
    final breed = _breedController.text.trim();
    final color = _colorController.text.trim();
    if (breed.isEmpty || color.isEmpty) {
      setState(() => _characterError = '견종과 색상을 먼저 입력해주세요.');
      return;
    }
    if (reroll) _characterSeed = DateTime.now().millisecondsSinceEpoch % 100000;
    setState(() {
      _generatingCharacter = true;
      _characterError = null;
    });
    try {
      final bytes = await CharacterServerService.instance.generate(
        breed: breed,
        color: color,
        personality: personality,
        seed: _characterSeed,
      );
      setState(() => _characterImage = bytes);
    } on CharacterServerException catch (e) {
      setState(() => _characterError = e.message);
    } catch (_) {
      setState(() => _characterError = '캐릭터를 만들지 못했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _generatingCharacter = false);
    }
  }

  Future<void> _handleSubmit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _familyId == null) {
      widget.onDone();
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await PetService.instance.savePet(
        familyId: _familyId!,
        updatedByUid: uid,
        name: _nameController.text.trim(),
        breed: _breedController.text.trim(),
        colorDescription: _colorController.text.trim(),
        personality: personality,
      );
      final image = _characterImage;
      if (image != null) {
        await CharacterSaveService.instance.save(image);
      }
      widget.onDone();
    } catch (_) {
      setState(() => _saveError = '저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80, limit: 5);
    if (picked.isEmpty) return;
    final bytesList = await Future.wait(picked.map((file) => file.readAsBytes()));
    setState(() {
      _photoBytes
        ..clear()
        ..addAll(bytesList);
      _analysisError = null;
    });
  }

  Future<void> _analyzePhotos() async {
    if (_photoBytes.isEmpty) return;
    setState(() {
      _analyzing = true;
      _analysisError = null;
    });
    try {
      final result = await AiServerService.instance.analyzePetPhotos(_photoBytes);
      setState(() {
        _breedController.text = result.breed;
        _colorController.text = result.colorDescription;
      });
    } on AiServerException catch (e) {
      setState(() => _analysisError = e.message);
    } catch (_) {
      setState(() => _analysisError = 'AI 서버에 연결하지 못했어요. ai-server가 실행 중인지 확인해주세요.');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SetupFrame(
    step: '02 / 02',
    title: '우리 가족의 친구를\n소개해 주세요',
    subtitle: '사진을 올리면 AI가 품종과 색상을 분석해줘요.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('사진으로 만들기'),
              icon: Icon(CupertinoIcons.sparkles),
            ),
            ButtonSegment(
              value: false,
              label: Text('직접 꾸미기'),
              icon: Icon(CupertinoIcons.slider_horizontal_3),
            ),
          ],
          selected: {photo},
          onSelectionChanged: (v) => setState(() => photo = v.first),
        ),
        const SizedBox(height: 18),
        if (photo) ...[
          GestureDetector(
            onTap: _pickPhotos,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9F8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: violet.withValues(alpha: .25)),
              ),
              child: _photoBytes.isEmpty
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 24),
                        Icon(
                          CupertinoIcons.photo_on_rectangle,
                          size: 44,
                          color: violet,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '강아지 사진 최대 5장',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '눌러서 사진 선택',
                          style: TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                        SizedBox(height: 24),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final bytes in _photoBytes)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              bytes,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        InkWell(
                          onTap: _pickPhotos,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: violet.withValues(alpha: .4)),
                            ),
                            child: const Icon(CupertinoIcons.pencil, color: violet),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (_photoBytes.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _analyzing ? null : _analyzePhotos,
                icon: _analyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.sparkles),
                label: Text(_analyzing ? '분석 중...' : 'AI로 분석하기'),
              ),
            ),
          ],
          if (_analysisError != null) ...[
            const SizedBox(height: 8),
            Text(_analysisError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          if (_breedController.text.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('분석 결과', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('품종: ${_breedController.text}'),
            Text('색상: ${_colorController.text}'),
          ],
        ] else
          Column(
            children: [
              TextField(
                controller: _breedController,
                decoration: const InputDecoration(labelText: '견종', hintText: '토이 푸들'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: '털 색상과 특징',
                  hintText: '크림색 · 곱슬',
                ),
              ),
            ],
          ),
        const SizedBox(height: 22),
        const Text('성격', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ['활발함', '애교쟁이', '호기심', '차분함']
              .map(
                (e) => ChoiceChip(
                  label: Text(e),
                  selected: personality == e,
                  onSelected: (_) => setState(() => personality = e),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 22),
        const Text('AI 캐릭터', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          '견종·색상·성격으로 우리 아이만의 마스코트를 만들어요.',
          style: TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (_characterImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: const Color(0xFFEDE9F8),
              padding: const EdgeInsets.all(12),
              child: Image.memory(_characterImage!, height: 160),
            ),
          ),
        if (_characterError != null) ...[
          const SizedBox(height: 8),
          Text(_characterError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _generatingCharacter
                ? null
                : () => _generateCharacter(reroll: _characterImage != null),
            icon: _generatingCharacter
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.wand_stars),
            label: Text(
              _generatingCharacter
                  ? '만드는 중...'
                  : _characterImage == null
                  ? 'AI 캐릭터 만들기'
                  : '다시 만들기',
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '이름', hintText: '보리'),
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          Text(_saveError!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_saving || _loadingExisting) ? null : _handleSubmit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_hadExistingPet ? '저장하기' : 'MIRA 시작하기'),
          ),
        ),
      ],
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  late final DogController dog = DogController(
    SharedPreferencesDogSaveService(),
  );
  @override
  void dispose() {
    dog.dispose();
    super.dispose();
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기에 저장한 데이터를 삭제할까요?'),
        content: const Text(
          '사진·글·댓글·좋아요와 강아지 성장, 안내 확인 기록이 삭제돼요. 원본 사진은 지워지지 않아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final prefs = SharedPreferencesAsync();
      await dog.flush();
      for (final key in ['dog_state_v1', privacyKey]) {
        await prefs.remove(key);
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AppFlow()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제를 완료하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onAttendance: _attendance,
        onMoodDiary: () => showMoodDiarySheet(context),
        dog: dog,
        active: index == 0,
        onOpenPet: () => setState(() => index = 1),
      ),
      index == 1 ? PetPage(controller: dog) : const SizedBox.shrink(),
      const FamilyPage(),
      MemoryPage(active: index == 3),
      const AiPage(),
      SettingsPage(onClearData: _clearData),
    ];
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: index, children: pages),
            const _MoodAlertListener(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          for (final item in const [
            (MiraSymbol.home, '홈'),
            (MiraSymbol.paw, '펫'),
            (MiraSymbol.family, '가족'),
            (MiraSymbol.album, '사진첩'),
            (MiraSymbol.sparkle, 'MIRA'),
            (MiraSymbol.settings, '설정'),
          ])
            NavigationDestination(
              icon: MiraIcon(item.$1),
              selectedIcon: MiraIcon(item.$1, selected: true),
              label: item.$2,
            ),
        ],
      ),
    );
  }

  void _attendance() => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('오늘의 돌봄 현황'),
      content: const SizedBox(width: 320, child: _FamilyCareSection()),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('닫기')),
      ],
    ),
  );
}

class _FamilyCareSection extends StatelessWidget {
  const _FamilyCareSection();

  Future<void> _pickAction(BuildContext context, String familyId, String uid) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('오늘 무엇을 할까요?'),
        children: [
          for (final action in careActions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, action),
              child: Text(action),
            ),
        ],
      ),
    );
    if (action != null) {
      await DailyCareService.instance.selectAction(familyId: familyId, uid: uid, action: action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Text('로그인이 필요해요.', style: TextStyle(color: Colors.black54));
    }
    return FutureBuilder<String?>(
      future: FamilyService.instance.fetchMyFamilyId(myUid),
      builder: (context, familyIdSnapshot) {
        final familyId = familyIdSnapshot.data;
        if (familyIdSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (familyId == null) {
          return const Text('아직 가족에 소속되어 있지 않아요.', style: TextStyle(color: Colors.black54));
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FamilyService.instance.watchFamilyMembers(familyId),
          builder: (context, memberSnapshot) {
            final members = memberSnapshot.data ?? const [];
            return StreamBuilder<Map<String, dynamic>>(
              stream: DailyCareService.instance.watchToday(familyId),
              builder: (context, careSnapshot) {
                final care = careSnapshot.data ?? const {};
                if (members.isEmpty) {
                  return const Text('가족 구성원이 없어요.', style: TextStyle(color: Colors.black54));
                }
                final doneCount = members.where((m) {
                  final record = care[m['uid']] as Map<String, dynamic>?;
                  return record?['completedAt'] != null;
                }).length;
                return Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Row(
                          children: [
                            const Text(
                              '오늘 현황',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$doneCount / ${members.length} 완료',
                              style: const TextStyle(
                                fontSize: 12,
                                color: violet,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final member in members)
                        Builder(
                          builder: (context) {
                            final uid = member['uid'] as String;
                            final name = member['name'] as String? ?? '이름 없음';
                            final role = member['role'] as String?;
                            final record = care[uid] as Map<String, dynamic>?;
                            final avatar = _roleEmoji[role] ?? '👤';
                            final isDone = record?['completedAt'] != null;
                            if (isDone) {
                              return CareLine('$avatar $name', '${record!['action']} · 완료');
                            }
                            if (uid == myUid) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        record != null
                                            ? '$avatar $name · ${record['action']} 하면 완료돼요'
                                            : '$avatar $name',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _pickAction(context, familyId, uid),
                                      child: Text(record != null ? '변경하기' : '선택하기'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return CareLine(
                              '$avatar $name',
                              record != null ? '${record['action']} · 진행 중' : '대기',
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverAppBar(
        floating: true,
        backgroundColor: cream,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
        actions: actions,
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 35),
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );
}

/// 다른 가족 구성원이 "오늘의 감정 한 줄 기록"에서 힘든 마음을 남기면,
/// AI가 요약한 소식을 화면 어디에 있든 팝업으로 보여준다.
class _MoodAlertListener extends StatelessWidget {
  const _MoodAlertListener();

  @override
  Widget build(BuildContext context) {
    // IndexedStack 밖(항상 그려지는 자리)에 있는 위젯이라, Firebase 미설정 플랫폼에서
    // FirebaseAuth.instance가 던지는 예외를 여기서 막지 않으면 에러 박스가 모든 탭 위에
    // 덮어씌워진다. main()의 Firebase.initializeApp try/catch와 같은 이유.
    String? maybeUid;
    try {
      maybeUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return const SizedBox.shrink();
    }
    final uid = maybeUid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: NotificationService.instance.watchUnread(uid),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final first = docs.first;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) return;
          await NotificationService.instance.markRead(uid, first.id);
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(first.data()['title'] as String? ?? '가족 소식'),
              content: Text(first.data()['message'] as String? ?? ''),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        });
        return const SizedBox.shrink();
      },
    );
  }
}

/// PetSetup에서 AI로 만든 캐릭터 이미지가 있으면 작은 원형 프로필로 보여준다.
/// 없으면 아무것도 그리지 않는다 ("직접 꾸미기"로 건너뛴 경우 등).
class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar();

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: CharacterSaveService.instance.load(),
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null) return const SizedBox.shrink();
      return CircleAvatar(radius: 18, backgroundImage: MemoryImage(bytes));
    },
  );
}

class HomePage extends StatelessWidget {
  const HomePage({
    required this.onAttendance,
    required this.onMoodDiary,
    required this.dog,
    required this.active,
    required this.onOpenPet,
    super.key,
  });
  final DogController dog;
  final bool active;
  final VoidCallback onOpenPet;
  final VoidCallback onAttendance;
  final VoidCallback onMoodDiary;
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'MIRA',
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Chip(
          avatar: const Icon(
            CupertinoIcons.leaf_arrow_circlepath,
            size: 16,
            color: violet,
          ),
          label: const Text('우리 가족의 하루'),
          side: BorderSide.none,
          backgroundColor: const Color(0xFFE7EDE2),
        ),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${DateTime.now().month}월 ${DateTime.now().day}일 · 오늘도 함께',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Color(0xFF9C9891),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '함께라서 좋은 하루예요.',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const _CharacterAvatar(),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '우리 집 작은 친구',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: onOpenPet,
              icon: const Icon(
                CupertinoIcons.arrow_up_left_arrow_down_right,
                size: 16,
              ),
              label: const Text('크게 보기'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: SizedBox(
            height: 590,
            child: active
                ? _CareCompletingDogRoom(controller: dog)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onAttendance,
            icon: const Icon(CupertinoIcons.sun_max),
            label: const Text(
              '오늘의 출석 체크  →',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              padding: const EdgeInsets.all(19),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Section('가족 퀘스트', '오늘 1 / 2'),
        const SizedBox(height: 12),
        const QuestCard(
          icon: '🍽️',
          title: '저녁 식탁에서 오늘 일 하나씩',
          detail: '가족 모두 참여 · Family Energy +40',
          progress: .66,
          color: Color(0xFFFFE8CF),
        ),
        const SizedBox(height: 12),
        const QuestCard(
          icon: '📷',
          title: '우리 가족 오늘 한 컷',
          detail: '사진 1장을 추억에 남겨 보세요',
          progress: 0,
          color: Color(0xFFDDECE3),
        ),
        const SizedBox(height: 28),
        _DailyQuestsSection(onMoodDiary: onMoodDiary),
        const SizedBox(height: 28),
        const Section('오늘의 가족 돌봄', ''),
        const SizedBox(height: 12),
        const _FamilyCareSection(),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Metric('☀️', 'Family Mood', '82')),
            SizedBox(width: 10),
            Expanded(child: Metric('⚡', 'Family Energy', '680')),
          ],
        ),
      ],
    ),
  );
}

class _DailyQuestsSection extends StatelessWidget {
  const _DailyQuestsSection({required this.onMoodDiary});
  final VoidCallback onMoodDiary;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Text('로그인이 필요해요.', style: TextStyle(color: Colors.black54));
    }
    return FutureBuilder<String?>(
      future: FamilyService.instance.fetchMyFamilyId(myUid),
      builder: (context, familyIdSnapshot) {
        final familyId = familyIdSnapshot.data;
        if (familyId == null) {
          return const Text('아직 가족에 소속되어 있지 않아요.', style: TextStyle(color: Colors.black54));
        }
        return StreamBuilder<Map<String, dynamic>>(
          stream: DailyCareService.instance.watchToday(familyId),
          builder: (context, careSnapshot) {
            final myCareRecord =
                (careSnapshot.data ?? const {})[myUid] as Map<String, dynamic>?;
            final cared = myCareRecord?['completedAt'] != null;
            return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: MomentService.instance.watchMoments(familyId),
              builder: (context, momentSnapshot) {
                final docs = momentSnapshot.data ?? const [];
                final now = DateTime.now();
                final postedToday = docs.any((doc) {
                  final data = doc.data();
                  if (data['authorUid'] != myUid) return false;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  return createdAt != null &&
                      createdAt.year == now.year &&
                      createdAt.month == now.month &&
                      createdAt.day == now.day;
                });
                final reacted = docs.any((doc) {
                  final data = doc.data();
                  final likedBy = List<String>.from(data['likedBy'] as List? ?? const []);
                  return data['authorUid'] != myUid && likedBy.contains(myUid);
                });
                final quests = [
                  (icon: '🐾', title: '오늘의 강아지 돌봄', done: cared, onTap: null),
                  (
                    icon: '✍️',
                    title: '오늘의 감정 한 줄 기록',
                    done: postedToday,
                    onTap: onMoodDiary,
                  ),
                  (icon: '💬', title: '가족 일기에 반응 남기기', done: reacted, onTap: null),
                ];
                final doneCount = quests.where((q) => q.done).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Section('나의 일일 퀘스트', '$doneCount / ${quests.length} 완료'),
                    const SizedBox(height: 12),
                    for (final quest in quests) ...[
                      DailyQuest(
                        icon: quest.icon,
                        title: quest.title,
                        done: quest.done,
                        onTap: quest.onTap,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class PetPage extends StatelessWidget {
  const PetPage({required this.controller, super.key});
  final DogController controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimumHeight =
          600.0 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 5;
      if (constraints.maxHeight >= minimumHeight) {
        return _CareCompletingDogRoom(controller: controller);
      }
      return SingleChildScrollView(
        child: SizedBox(
          height: minimumHeight,
          child: _CareCompletingDogRoom(controller: controller),
        ),
      );
    },
  );
}

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});
  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

const _roleEmoji = {'아빠': '👨', '엄마': '👩', '아들': '👦', '딸': '👧'};

const _careActionLabels = {
  CareAction.feed: '🍚 밥 주기',
  CareAction.wash: '🛁 목욕',
  CareAction.play: '🎾 놀기',
  CareAction.sleep: '😴 재우기',
};

// 강아지 게임에서 실제로 그 행동을 해야 오늘의 돌봄이 완료로 바뀌도록 연결.
class _CareCompletingDogRoom extends StatelessWidget {
  const _CareCompletingDogRoom({required this.controller});
  final DogController controller;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return DogRoomScreen(
      controller: controller,
      onCareAction: myUid == null
          ? null
          : (action) async {
              final label = _careActionLabels[action];
              if (label == null) return;
              final familyId = await FamilyService.instance.fetchMyFamilyId(myUid);
              if (familyId == null) return;
              await DailyCareService.instance.completeSelectedAction(
                familyId: familyId,
                uid: myUid,
                action: label,
              );
            },
    );
  }
}

class _FamilyPageState extends State<FamilyPage> {
  @override
  Widget build(BuildContext context) => AppPage(
    title: '가족 이야기',
    actions: [
      IconButton(
        onPressed: () => _write(context),
        icon: const Icon(Icons.edit_square),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Section('우리 가족', ''),
        const SizedBox(height: 12),
        const _FamilyMembersSection(),
        const SizedBox(height: 22),
        const Section('오늘의 가족 마음', ''),
        const SizedBox(height: 12),
        const _MomentsSection(),
        const SizedBox(height: 22),
        const Section('가족 상호작용', '최근 7일 +18%'),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: .78,
                  minHeight: 9,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                SizedBox(height: 12),
                Text(
                  '댓글 14 · 좋아요 31 · 함께한 활동 5',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _write(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final familyId = await FamilyService.instance.fetchMyFamilyId(uid);
    if (familyId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가족에 먼저 참여해주세요.')),
        );
      }
      return;
    }
    final profile = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final authorName = profile.data()?['name'] as String? ?? '이름 없음';
    final authorRole = profile.data()?['role'] as String? ?? '';

    final moodController = TextEditingController();
    final bodyController = TextEditingController();
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          5,
          22,
          MediaQuery.viewInsetsOf(c).bottom + 25,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘의 마음 기록',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: moodController,
              decoration: const InputDecoration(hintText: '오늘 기분을 한 줄로 표현해보세요.'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyController,
              maxLines: 5,
              decoration: const InputDecoration(hintText: '가족과 나누고 싶은 이야기를 적어보세요.'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final body = bodyController.text.trim();
                  if (body.isEmpty) return;
                  await MomentService.instance.addMoment(
                    familyId: familyId,
                    authorUid: uid,
                    authorName: authorName,
                    authorRole: authorRole,
                    mood: moodController.text.trim(),
                    body: body,
                  );
                  if (c.mounted) Navigator.pop(c);
                },
                child: const Text('기록하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCommentsSheet({
  required BuildContext context,
  required String familyId,
  required String momentId,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> comments,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final controller = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('댓글', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            Expanded(
              child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                stream: MomentService.instance.watchComments(familyId, momentId),
                initialData: comments,
                builder: (context, snapshot) {
                  final docs = snapshot.data ?? const [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('아직 댓글이 없어요.', style: TextStyle(color: Colors.black54)),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final doc in docs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AuthorAvatar(
                                uid: doc.data()['authorUid'] as String?,
                                role: doc.data()['authorRole'] as String?,
                                radius: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.data()['authorName'] as String? ?? '이름 없음',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(doc.data()['text'] as String? ?? ''),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (uid != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.paperplane_fill),
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        final profile = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .get();
                        await MomentService.instance.addComment(
                          familyId: familyId,
                          momentId: momentId,
                          authorUid: uid,
                          authorName: profile.data()?['name'] as String? ?? '이름 없음',
                          authorRole: profile.data()?['role'] as String? ?? '',
                          text: text,
                        );
                        controller.clear();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
}

class _MomentsSection extends StatelessWidget {
  const _MomentsSection();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Text('로그인 후 가족 이야기를 볼 수 있어요.', style: TextStyle(color: Colors.black54));
    }
    return FutureBuilder<String?>(
      future: FamilyService.instance.fetchMyFamilyId(uid),
      builder: (context, familyIdSnapshot) {
        final familyId = familyIdSnapshot.data;
        if (familyIdSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (familyId == null) {
          return const Text('아직 가족에 소속되어 있지 않아요.', style: TextStyle(color: Colors.black54));
        }
        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: MomentService.instance.watchMoments(familyId),
          builder: (context, snapshot) {
            final docs = snapshot.data ?? const [];
            if (docs.isEmpty) {
              return const Text('아직 기록된 가족 이야기가 없어요.', style: TextStyle(color: Colors.black54));
            }
            return Column(
              children: [
                for (final doc in docs) ...[
                  Builder(
                    builder: (context) {
                      final data = doc.data();
                      final likedBy = List<String>.from(
                        data['likedBy'] as List? ?? const [],
                      );
                      final isLiked = likedBy.contains(uid);
                      return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                        stream: MomentService.instance.watchComments(familyId, doc.id),
                        builder: (context, commentSnapshot) {
                          final commentDocs = commentSnapshot.data ?? const [];
                          return DiaryCard(
                            name: data['authorName'] as String? ?? '이름 없음',
                            mood: data['mood'] as String? ?? '',
                            body: data['body'] as String? ?? '',
                            authorUid: data['authorUid'] as String?,
                            authorRole: data['authorRole'] as String?,
                            likes: likedBy.length,
                            comments: commentDocs.length,
                            isLiked: isLiked,
                            onLike: () => MomentService.instance.toggleLike(
                              familyId: familyId,
                              momentId: doc.id,
                              uid: uid,
                              currentlyLiked: isLiked,
                            ),
                            onComment: () => _showCommentsSheet(
                              context: context,
                              familyId: familyId,
                              momentId: doc.id,
                              comments: commentDocs,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _FamilyMembersSection extends StatelessWidget {
  const _FamilyMembersSection();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Text('로그인 후 가족 구성원을 볼 수 있어요.', style: TextStyle(color: Colors.black54));
    }
    return FutureBuilder<String?>(
      future: FamilyService.instance.fetchMyFamilyId(uid),
      builder: (context, familyIdSnapshot) {
        final familyId = familyIdSnapshot.data;
        if (familyIdSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (familyId == null) {
          return const Text('아직 가족에 소속되어 있지 않아요.', style: TextStyle(color: Colors.black54));
        }
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FamilyService.instance.watchFamilyMembers(familyId),
          builder: (context, snapshot) {
            final members = snapshot.data ?? const [];
            if (members.isEmpty) {
              return const Text('아직 참여한 가족 구성원이 없어요.', style: TextStyle(color: Colors.black54));
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final member in members)
                  Chip(
                    avatar: AuthorAvatar(
                      uid: member['uid'] as String?,
                      role: member['role'] as String?,
                      radius: 12,
                    ),
                    label: Text(
                      '${member['name'] ?? '이름 없음'} · ${member['role'] ?? '역할 미설정'}',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class DiaryCard extends StatelessWidget {
  const DiaryCard({
    required this.name,
    required this.mood,
    required this.body,
    required this.likes,
    required this.comments,
    this.authorUid,
    this.authorRole,
    this.isLiked = false,
    this.onLike,
    this.onComment,
    super.key,
  });
  final String name, mood, body;
  final String? authorUid, authorRole;
  final int likes, comments;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuthorAvatar(uid: authorUid, role: authorRole),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    mood,
                    style: const TextStyle(fontSize: 12, color: violet),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(body, style: const TextStyle(height: 1.6)),
          const Divider(height: 28),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(
                  isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  size: 19,
                  color: isLiked ? Colors.redAccent : null,
                ),
                label: Text('$likes'),
              ),
              TextButton.icon(
                onPressed: onComment,
                icon: const Icon(CupertinoIcons.chat_bubble, size: 18),
                label: Text('$comments'),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz),
            ],
          ),
        ],
      ),
    ),
  );
}

class AiPage extends StatelessWidget {
  const AiPage({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'MIRA 인사이트',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.sparkles, color: Color(0xFFDCD8FF), size: 30),
              SizedBox(height: 24),
              Text(
                '이번 주, 우리 가족은\n조금 더 가까워졌어요.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '긍정적인 직접 상호작용이 18% 늘었어요.',
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Section('살펴볼 신호', '최근 14일'),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Insight('대화', '↑ 18%', '댓글과 답장이 늘었어요'),
                Divider(height: 28),
                Insight('함께한 활동', '→ 유지', '주말 산책을 이어가 보세요'),
                Divider(height: 28),
                Insight('아빠 ↔ 나', '↓ 8%', '짧은 안부 대화를 추천해요'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const TextField(
          decoration: InputDecoration(
            hintText: 'MIRA에게 우리 가족에 대해 물어보세요',
            suffixIcon: Icon(Icons.arrow_upward_rounded),
          ),
        ),
      ],
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.onClearData, super.key});
  final VoidCallback onClearData;
  @override
  Widget build(BuildContext context) => AppPage(
    title: '설정',
    child: Column(
      children: [
        _ProfileCard(),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              setting(
                CupertinoIcons.person_2,
                '가족 관리',
                '초대 코드 · 구성원',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FamilyManagementScreen()),
                ),
              ),
              setting(
                CupertinoIcons.paw,
                '반려견 설정',
                '프로필 · 커스터마이징',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PetSetup(onDone: () => Navigator.of(context).pop()),
                  ),
                ),
              ),
              setting(
                CupertinoIcons.bell,
                '알림',
                '돌봄 · 댓글 · 일정',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.lock_shield),
                title: const Text('개인정보 처리방침'),
                subtitle: const Text('저장하는 정보 · 사진 접근 · 삭제'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                onTap: () => showPrivacyDocument(context),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.doc_text),
                title: const Text('이용 안내'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                onTap: () => showPrivacyDocument(context, terms: true),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.trash),
                title: const Text('기기에 저장한 데이터 삭제'),
                subtitle: const Text('사진첩 · 강아지 성장 · 안내 확인 기록'),
                onTap: onClearData,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              setting(
                CupertinoIcons.paintbrush,
                '화면 설정',
                '글자 크기',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DisplaySettingsScreen()),
                ),
              ),
              setting(
                CupertinoIcons.question_circle,
                '도움말',
                '자주 묻는 질문',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),
              setting(
                CupertinoIcons.info_circle,
                '앱 정보',
                'MIRA 1.0.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'MIRA',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '팀 에이원하조',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(CupertinoIcons.square_arrow_right, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await AuthService.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const AppFlow(skipOnboarding: true),
                  ),
                  (_) => false,
                );
              }
            },
          ),
        ),
      ],
    ),
  );
  static Widget setting(
    IconData icon,
    String title,
    String sub, {
    VoidCallback? onTap,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(sub),
    trailing: const Icon(CupertinoIcons.chevron_right),
    onTap: onTap,
  );
}

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});
  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  bool _loading = true;
  String? _familyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final familyId = uid == null ? null : await FamilyService.instance.fetchMyFamilyId(uid);
    if (mounted) {
      setState(() {
        _familyId = familyId;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('가족 관리')),
      body: uid == null
          ? const Center(child: Text('로그인이 필요해요.'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _familyId == null
          ? _JoinOrCreateFamilyForm(
              onSuccess: (familyId) => setState(() => _familyId = familyId),
            )
          : _FamilyDetails(familyId: _familyId!),
    );
  }
}

class _FamilyDetails extends StatelessWidget {
  const _FamilyDetails({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('초대 코드', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          title: Text(
            familyId,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          subtitle: const Text('가족에게 이 코드를 공유해주세요'),
          trailing: IconButton(
            icon: const Icon(CupertinoIcons.doc_on_doc),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: familyId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('초대 코드를 복사했어요.')),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Text('가족 구성원', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: FamilyService.instance.watchFamilyMembers(familyId),
        builder: (context, memberSnapshot) {
          final members = memberSnapshot.data ?? const [];
          if (members.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Text('구성원이 없어요.'),
            );
          }
          return Card(
            child: Column(
              children: [
                for (final member in members)
                  ListTile(
                    leading: AuthorAvatar(
                      uid: member['uid'] as String?,
                      role: member['role'] as String?,
                    ),
                    title: Text(member['name'] as String? ?? '이름 없음'),
                    subtitle: Text(member['role'] as String? ?? ''),
                  ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _JoinOrCreateFamilyForm extends StatefulWidget {
  const _JoinOrCreateFamilyForm({required this.onSuccess});
  final ValueChanged<String> onSuccess;
  @override
  State<_JoinOrCreateFamilyForm> createState() => _JoinOrCreateFamilyFormState();
}

class _JoinOrCreateFamilyFormState extends State<_JoinOrCreateFamilyForm> {
  String role = '딸';
  bool _submitting = false;
  String? _errorText;
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final result = await FamilyService.instance.createFamily(role);
      widget.onSuccess(result['familyId'] as String);
    } on FamilyServiceException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleJoin() async {
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) {
      setState(() => _errorText = '초대 코드를 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final result = await FamilyService.instance.joinFamily(inviteCode, role);
      widget.onSuccess(result['familyId'] as String);
    } on FamilyServiceException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        '아직 가족에 소속되어 있지 않아요',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      const SizedBox(height: 6),
      const Text(
        '가족을 새로 만들거나, 초대 코드로 참여해보세요.',
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 20),
      const Text('내 역할', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: familyRoles
            .map(
              (e) => ChoiceChip(
                avatar: Text(_roleEmoji[e]!),
                label: Text(e),
                selected: role == e,
                onSelected: (_) => setState(() => role = e),
              ),
            )
            .toList(),
      ),
      if (_errorText != null) ...[
        const SizedBox(height: 12),
        Text(_errorText!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 24),
      const Text('처음이신가요?', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _submitting ? null : _handleCreate,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('가족 코드 생성하기'),
        ),
      ),
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 16),
      const Text('이미 가족 코드가 있으신가요?', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      TextField(
        controller: _inviteCodeController,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: '가족 초대 코드',
          hintText: '가족에게 받은 코드를 입력하세요',
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _submitting ? null : _handleJoin,
          child: const Text('가족 코드 등록하기'),
        ),
      ),
    ],
  );
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const _careKey = 'notif_care_v1';
  static const _commentKey = 'notif_comment_v1';
  static const _scheduleKey = 'notif_schedule_v1';

  bool _care = true;
  bool _comment = true;
  bool _schedule = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = SharedPreferencesAsync();
    final care = await prefs.getBool(_careKey);
    final comment = await prefs.getBool(_commentKey);
    final schedule = await prefs.getBool(_scheduleKey);
    if (mounted) {
      setState(() {
        _care = care ?? true;
        _comment = comment ?? true;
        _schedule = schedule ?? true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('알림')),
    body: ListView(
      children: [
        SwitchListTile(
          title: const Text('돌봄 알림'),
          subtitle: const Text('가족이 반려동물을 돌봐야 할 때 알려드려요'),
          value: _care,
          onChanged: (v) {
            setState(() => _care = v);
            SharedPreferencesAsync().setBool(_careKey, v);
          },
        ),
        SwitchListTile(
          title: const Text('댓글 알림'),
          subtitle: const Text('가족이 내 기록에 댓글을 남기면 알려드려요'),
          value: _comment,
          onChanged: (v) {
            setState(() => _comment = v);
            SharedPreferencesAsync().setBool(_commentKey, v);
          },
        ),
        SwitchListTile(
          title: const Text('일정 알림'),
          subtitle: const Text('다가오는 가족 일정을 알려드려요'),
          value: _schedule,
          onChanged: (v) {
            setState(() => _schedule = v);
            SharedPreferencesAsync().setBool(_scheduleKey, v);
          },
        ),
      ],
    ),
  );
}

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('화면 설정')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('글자 크기', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: textScaleNotifier,
            builder: (context, scale, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: scale,
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  label: '${(scale * 100).round()}%',
                  onChanged: (v) {
                    textScaleNotifier.value = v;
                    SharedPreferencesAsync().setDouble(textScaleKey, v);
                  },
                ),
                const SizedBox(height: 8),
                const Text('가족과 함께 볼 땐 이 정도가 딱 좋아요.'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    ('MIRA는 무엇인가요?', '가족이 함께 반려동물을 돌보며 서로의 하루를 나누는 앱이에요.'),
    ('가족 초대 코드는 어디서 확인하나요?', '설정 → 가족 관리에서 확인하고 공유할 수 있어요.'),
    ('반려견 사진 분석은 어떻게 하나요?', '반려견 설정에서 사진을 올리고 "AI로 분석하기"를 누르면 품종과 색상을 자동으로 알려줘요.'),
    ('내 기록은 가족에게 전부 공개되나요?', '가족 이야기에 직접 작성한 내용만 공개되고, 개인 정보는 안전하게 보호돼요.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('도움말')),
    body: ListView(
      children: [
        for (final item in _faq)
          ExpansionTile(
            title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(item.$2, style: const TextStyle(color: Colors.black54)),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Card(
        child: ListTile(
          leading: CircleAvatar(child: Text('👤')),
          title: Text('로그인 정보 없음'),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['name'] as String? ?? '이름 없음';
        final role = data?['role'] as String?;
        return Card(
          child: ListTile(
            leading: AuthorAvatar(uid: uid, role: role),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(role != null ? '우리 가족 · $role' : '역할 미설정'),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
            ),
          ),
        );
      },
    );
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  DateTime? _birthday;
  bool _loading = true;
  bool _saving = false;
  bool _pickingPhoto = false;
  String? _error;
  String? _existingPhotoBase64;
  Uint8List? _newPhotoBytes;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    _nameController.text = data?['name'] as String? ?? '';
    _existingPhotoBase64 = data?['photo'] as String?;
    final birthdayStr = data?['birthday'] as String?;
    if (birthdayStr != null) {
      final parsed = DateTime.tryParse(birthdayStr);
      if (parsed != null) {
        _birthday = parsed;
        _birthdayController.text =
            '${parsed.year}. ${parsed.month.toString().padLeft(2, '0')}. ${parsed.day.toString().padLeft(2, '0')}';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
        _birthdayController.text =
            '${picked.year}. ${picked.month.toString().padLeft(2, '0')}. ${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _pickingPhoto = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 300 * 1024) {
        if (mounted) setState(() => _error = '프로필 사진은 300KB 이하로 선택해 주세요.');
        return;
      }
      final decoded = await decodeImageFromList(bytes);
      decoded.dispose();
      if (mounted) {
        setState(() {
          _newPhotoBytes = bytes;
          _removePhoto = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 열지 못했어요. 사진 접근 권한을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _clearPhoto() {
    setState(() {
      _newPhotoBytes = null;
      _existingPhotoBase64 = null;
      _removePhoto = true;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해주세요.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        if (_birthday != null)
          'birthday':
              '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
        if (_newPhotoBytes != null) 'photo': base64Encode(_newPhotoBytes!),
        if (_removePhoto && _newPhotoBytes == null) 'photo': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('프로필 수정')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickingPhoto ? null : _pickPhoto,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage: _newPhotoBytes != null
                            ? MemoryImage(_newPhotoBytes!)
                            : _existingPhotoBase64 != null
                            ? MemoryImage(base64Decode(_existingPhotoBase64!))
                            : null,
                        child: _pickingPhoto
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : (_newPhotoBytes == null && _existingPhotoBase64 == null)
                            ? const Icon(CupertinoIcons.camera, size: 28)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _pickingPhoto ? null : _pickPhoto,
                          child: const Text('사진 바꾸기'),
                        ),
                        if (_newPhotoBytes != null || _existingPhotoBase64 != null)
                          TextButton(
                            onPressed: _clearPhoto,
                            child: const Text('사진 제거'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름', hintText: '이름을 입력하세요'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _birthdayController,
                readOnly: true,
                onTap: _pickBirthday,
                decoration: const InputDecoration(
                  labelText: '생년월일',
                  hintText: '예) 2002. 03. 14',
                  suffixIcon: Icon(CupertinoIcons.calendar),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('저장하기'),
                ),
              ),
            ],
          ),
  );
}

class QuestCard extends StatelessWidget {
  const QuestCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.progress,
    required this.color,
    super.key,
  });
  final String icon, title, detail;
  final double progress;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(icon, style: const TextStyle(fontSize: 25)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: Color(0xFF77716A)),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: .65),
                  color: ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ],
    ),
  );
}

class DailyQuest extends StatelessWidget {
  const DailyQuest({
    required this.icon,
    required this.title,
    required this.done,
    this.onTap,
    super.key,
  });
  final String icon, title;
  final bool done;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE6DF)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 21)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: done ? const Color(0xFF928E87) : ink,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? ink : Colors.transparent,
              border: Border.all(
                color: done ? ink : const Color(0xFFD7D2CA),
                width: 1.5,
              ),
            ),
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        ],
      ),
    ),
  );
}

class CareLine extends StatelessWidget {
  const CareLine(this.who, this.action, {super.key});
  final String who, action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            who,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(action, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric(this.icon, this.label, this.value, {super.key});
  final String icon, label, value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$icon  $label',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class Section extends StatelessWidget {
  const Section(this.title, this.tail, {super.key});
  final String title, tail;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      const Spacer(),
      Text(
        tail,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: violet,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class Insight extends StatelessWidget {
  const Insight(this.label, this.value, this.desc, {super.key});
  final String label, value, desc;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              desc,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      Text(
        value,
        style: const TextStyle(color: violet, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
