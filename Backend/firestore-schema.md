# Firestore 스키마

familyapp 화면들이 실제로 쓰는 필드 기준으로 설계함 (역할 4종 고정: 아빠/엄마/아들/딸).

## `users/{userId}` (userId = Firebase Auth uid)
| 필드 | 타입 | 비고 |
|---|---|---|
| name | string | |
| birthday | string | `yyyy-MM-dd`로 통일 (기존 화면들은 형식이 제각각이었음) |
| photoURL | string? | |
| familyId | string? | = 가족 초대 코드 |
| role | string? | 아빠/엄마/아들/딸 중 하나 |
| createdAt | timestamp | |

### `users/{userId}/settings/preferences`
notificationEnabled, screenLock, vibration (bool)

### `users/{userId}/notifications/{notificationId}`
type(`schedule`/`todayQuestion`/`familyAnswer`), title, message, createdAt(timestamp), isRead(bool), relatedId(string?) — 생성은 Cloud Functions에서만.

## `families/{familyId}`
문서 id 자체가 초대 코드(8자리, invite_screen의 "내 코드"와 동일한 것).

| 필드 | 타입 | 비고 |
|---|---|---|
| members | map<uid, role> | 최대 4명, role은 가족당 1명씩만 |
| createdAt | timestamp | |

생성/참여는 클라이언트에서 Firestore 트랜잭션으로 직접 처리(`Frontend/mira/lib/services/family_service.dart`) — Cloud Functions 배포(Blaze 요금제) 없이 동작하도록 한 것. `firestore.rules`가 "본인 uid 하나로 새 문서 생성" / "기존 멤버는 그대로 두고 본인 uid만 추가"만 허용해서 최소한의 무결성(최대 4명, 역할 중복 금지)을 보장함. `Backend/functions/index.js`에 같은 로직의 Cloud Function 버전(`createFamily`/`joinFamily`)이 남아있는데, 지금은 사용하지 않고 나중에 Blaze로 전환하면 그쪽으로 옮길 수 있음.

가족 문서 read는 `allow get`(단건 조회)만 로그인하면 허용하고 `allow list`는 막아뒀음 — 코드 생성 시 중복 확인, 참여 시 코드 유효성 확인 둘 다 "아직 멤버가 아닌 가족 문서"를 읽어야 해서, `isFamilyMember`로 read를 제한하면 코드를 알아도 조회 자체가 막히는 모순이 생김. 문서 id 자체가 8자리 랜덤 코드라 list 금지만으로도 코드를 모르면 검색해서 찾을 수 없음.

### `families/{familyId}/events/{eventId}`
title, memo, date(`yyyy-MM-dd`), alarmOption, authorUserId, authorRole, isHoliday(bool) — 캘린더는 가족 공용이므로 멤버 전원 read/write.

### `families/{familyId}/moods/{moodId}`
홈 화면 "오늘 기분" 기록. userId, role, moodTag(#기쁨 등 6종), moodText, date — 생성만 가능(수정/삭제 불가), 작성자 본인 uid로만 생성 가능.

### `families/{familyId}/dailyQuestions/{questionId}`
text, date — 생성은 스케줄 Cloud Function에서만.

#### `.../dailyQuestions/{questionId}/answers/{userId}`
text, submittedAt — 문서 id를 userId로 고정해서 "가족 전원 답변 여부"를 멤버 수와 answers 개수 비교만으로 판단 가능하게 함. 본인 uid 문서만 write 가능.

### `families/{familyId}/garden` (단일 문서, 가족 전체 공유)
cookieCount(int), progress(0~1 float), level(int), updatedAt — mood/answer 제출 시 Cloud Function이 트랜잭션으로 갱신(클라이언트 직접 쓰기 금지, race condition 방지).

### `families/{familyId}/pet/profile` (단일 문서, 가족 전체 공유)
name, breed, colorDescription, personality, updatedBy(uid), updatedAt — 반려동물은 가족당 하나. 아무 구성원이나 생성/수정 가능(한 명이 설정하면 가족 전체에 반영되고, 설정 화면에서 누구든 다시 열어 수정 가능).

### `families/{familyId}/dailyCare/{yyyy-MM-dd}` (mira 홈 화면 "오늘의 가족 돌봄")
문서 하나가 하루치. 필드는 `{uid}: {action: string, completedAt: timestamp | null}` 형태의 uid→기록 맵. `completedAt`이 null이면 오늘 할 일을 고르기만 하고 아직 실제로 하지 않은 상태(강아지 게임에서 해당 행동을 하면 서버 타임스탬프로 채워짐). 본인 uid 항목만 생성/수정 가능(다른 사람 항목 변경 불가). 홈 화면에서 실제 가족 구성원 목록과 합쳐서 "대기/진행 중/완료" 표시.

### `families/{familyId}/moments/{momentId}` (mira "가족 이야기" 탭)
authorUid, authorName, authorRole, mood(한 줄 기분), body(내용), likedBy(array\<uid\>), createdAt — 생성은 본인 uid로만, 수정은 `likedBy` 필드만 허용(좋아요 토글 전용, 그 외 필드는 생성 후 불변).

#### `.../moments/{momentId}/comments/{commentId}`
authorUid, authorName, authorRole, text, createdAt — 가족 구성원 누구나 생성 가능(본인 uid로만), 수정·삭제는 불가. 댓글 개수는 별도 카운터 없이 서브컬렉션 실시간 구독으로 표시.

### `families/{familyId}/photos/{photoId}` (mira "사진첩" 탭)
authorUid, authorName, authorRole, photo(base64 인코딩된 이미지, Firestore 문서 1MiB 제한 때문에 업로드 시 압축), body(글), likedBy(array\<uid\>), createdAt — 사진 여러 장을 고르면 장당 하나의 문서로 저장(문서당 이미지 1장). 생성은 본인 uid로만, 수정은 `likedBy`만 허용, 삭제는 작성자 본인만 가능.

#### `.../photos/{photoId}/comments/{commentId}`
authorUid, authorName, authorRole, text, createdAt — moments 댓글과 동일한 정책(생성만 가능, 수정·삭제 불가).

## 타임캡슐
별도 컬렉션 없음 — `moods`/`answers`를 date 기준(오늘 - 1년)으로 조회해서 구성. 화면에서 필요한 "1년 전 오늘" 쿼리를 Cloud Function으로 감쌀지, 클라이언트에서 직접 range query할지는 추후 결정.

## 공휴일
`holidays/{date}` (읽기 전용, 공용) — 사용자 쓰기 불가. 시딩 스크립트나 공휴일 API 연동은 추후.
