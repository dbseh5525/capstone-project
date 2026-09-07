# MIRA 화면 통합

## 실행과 검증

프로젝트 루트(capstone)에서 Windows PowerShell로 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Frontend/mira/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Frontend/mira/run.ps1 -Mode verify
powershell -NoProfile -ExecutionPolicy Bypass -File Frontend/mira/run.ps1 -Mode build
```

`run.ps1`은 한글 사용자 경로에서 발생하는 Flutter 셰이더 컴파일러 및 테스트 실행기 오류를 피하기 위해 임시 드라이브 경로를 사용합니다. 프로젝트나 SDK를 이동하지 않으며, 종료 시 경로 연결과 임시 환경 변수 설정을 복구합니다. Flutter가 PATH에 있어야 합니다.

그 밖의 환경에서는 `Frontend/mira`에서 일반적인 `flutter pub get`, `flutter run -d chrome`, `flutter analyze`, `flutter test`, `flutter build web`을 사용할 수 있습니다.

## 통합 구조

- `lib/dog_room`: 기존 dog_room의 모델, 저장 서비스, 돌봄/성장 로직과 애니메이션을 이식했습니다. 원본 `Frontend/dog_room`은 독립 실행 프로젝트로 유지됩니다.
- `MainShell`이 `DogController` 하나를 소유합니다. 홈과 펫 전환 시 경험치와 돌봄 수치를 공유하며, 현재 보이는 화면에만 강아지 애니메이션을 생성합니다. 초기화는 한 번만 실행되고 상태 저장은 순서대로 처리됩니다.
- 홈은 큰 상호작용 카드, 펫은 내비게이션 위의 전체 영역을 사용합니다. 낮은 화면과 큰 글자에서는 펫 영역을 스크롤할 수 있습니다.
- `lib/memories/memory_page.dart`: 실제 사진 선택, 정사각형 4열 썸네일, 확대 보기, 글 수정, 좋아요, 댓글 등록/삭제, 사진 삭제를 제공합니다. 저장 실패 시 작성 중인 사진과 글을 유지합니다.
- `lib/privacy/privacy_screen.dart`: 첫 시작에 이용 안내와 개인정보 처리방침을 각각 확인하며, 확인한 버전과 일시를 저장합니다. 설정에서 문서를 다시 열거나 기기 데이터를 삭제할 수 있습니다.
- `lib/design/mira_icons.dart`: 홈·펫·가족·사진첩·MIRA·설정에 맞춘 6종의 선형 아이콘을 Canvas로 그립니다. Pretendard, 짙은 녹색, 아이보리, 일관된 모서리와 버튼 크기를 사용합니다. 넓은 브라우저에서도 콘텐츠 너비는 최대 480px입니다.

## 저장 및 서비스 범위

사진/글/댓글/좋아요, 강아지 상태, 안내 확인 기록은 `SharedPreferencesAsync`로 **해당 기기에만 저장**됩니다. 사진은 선택 시 크기를 줄이고, 장당 최대 2MB, 한 번에 최대 8장, 사진첩 전체 JSON 약 15MB로 제한합니다. 플랫폼에서 더 작은 저장 한도를 적용하면 오류를 표시하고 작성 내용을 유지합니다. 기기 간 동기화와 실제 가족 간 공유는 구현되어 있지 않습니다.

로그인, 가족 프로필, 기존 가족·퀘스트·AI 화면은 기존 시제품 흐름입니다. 실제 인증, AI 처리, 푸시 전송을 구현했다고 표시하지 않습니다. 사진첩 기본 강아지 사진 8장은 예시임을 명시합니다. iOS 사진 선택을 위해 `NSPhotoLibraryUsageDescription`을 추가했습니다. Android/iOS 실기기 빌드는 이 Windows 환경에서 검증하지 않았습니다.

## 개인정보 안내를 실제 서비스에 적용하기 전

현재 문구는 실제 구현된 기기 저장 기능을 설명하는 체험판 안내입니다. 체크박스는 안내 확인이며, 실제 계정 인증 또는 법정대리인 동의 검증을 대신하지 않습니다. 서버 연동 시 아래 내용을 실제 운영 방식에 맞게 확정하고 문구/버전을 갱신해야 합니다.

- 운영자 및 개인정보 보호 담당자 연락처
- 실제 수집 항목, 처리 목적, 보유 기간, 삭제 및 권리 행사 절차
- 가족에게 공개할 범위와 기본값, 위탁/제3자 제공/국외 이전 여부
- 만 14세 미만 아동의 법정대리인 동의 확인 절차
- 사진첩 서버 저장과 접근 제어, 사용자별 데이터 분리

참고: [개인정보보호위원회 개인정보 포털](https://www.privacy.go.kr/), [어린이·청소년 개인정보 관련 안내](https://www.privacy.go.kr/front/contents/cntntsView.do?contsNo=275). 서비스 제공자의 실제 정책에 관한 법률 검토를 대체하는 문서가 아닙니다.

## 검증

기능 테스트는 첫 안내의 확인 조건·버전 유지, 실제 사진 선택 플랫폼과 저장 연결, 작은 화면/큰 글자에서 전체 탭 배치, 홈과 펫 상태 공유, 사진첩 좋아요/댓글의 재시작 유지, 사진 삭제 확인/취소, 강아지 저장 및 오프라인 수치 하한을 확인합니다.

화면 검토용 이미지는 `flutter test --dart-define=CAPTURE_UI=true --update-goldens`로 저장할 수 있습니다. 출력은 저장소 루트 `.mira-work/`이며 Git에서 제외합니다. 일반 테스트 실행에는 이미지 갱신이 필요하지 않습니다.
