const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const ROLES = ["아빠", "엄마", "아들", "딸"];
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 헷갈리는 0/O, 1/I 제외

function generateInviteCode() {
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
  }
  return code;
}

function requireAuth(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return uid;
}

function requireRole(role) {
  if (!ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", "role은 아빠/엄마/아들/딸 중 하나여야 합니다.");
  }
}

exports.createFamily = onCall(async (request) => {
  const uid = requireAuth(request);
  const { role } = request.data ?? {};
  requireRole(role);

  let familyId = generateInviteCode();
  let familyRef = db.collection("families").doc(familyId);

  // 코드 충돌 시 재생성 (8자리 33^8 조합이라 사실상 거의 발생하지 않음)
  for (let attempt = 0; attempt < 5 && (await familyRef.get()).exists; attempt++) {
    familyId = generateInviteCode();
    familyRef = db.collection("families").doc(familyId);
  }

  await db.runTransaction(async (tx) => {
    tx.set(familyRef, {
      members: { [uid]: role },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection("users").doc(uid),
      { familyId, role },
      { merge: true }
    );
  });

  return { familyId, inviteCode: familyId };
});

exports.joinFamily = onCall(async (request) => {
  const uid = requireAuth(request);
  const { inviteCode, role } = request.data ?? {};
  requireRole(role);
  if (!inviteCode || typeof inviteCode !== "string") {
    throw new HttpsError("invalid-argument", "초대 코드가 필요합니다.");
  }

  const familyRef = db.collection("families").doc(inviteCode.toUpperCase());

  return db.runTransaction(async (tx) => {
    const familyDoc = await tx.get(familyRef);
    if (!familyDoc.exists) {
      throw new HttpsError("not-found", "유효하지 않은 초대 코드입니다.");
    }

    const members = familyDoc.data().members ?? {};
    if (members[uid]) {
      return { familyId: familyRef.id };
    }
    if (Object.keys(members).length >= ROLES.length) {
      throw new HttpsError("failed-precondition", "가족 인원이 가득 찼습니다.");
    }
    if (Object.values(members).includes(role)) {
      throw new HttpsError("failed-precondition", `이미 "${role}" 역할을 사용 중입니다.`);
    }

    tx.update(familyRef, { [`members.${uid}`]: role });
    tx.set(
      db.collection("users").doc(uid),
      { familyId: familyRef.id, role },
      { merge: true }
    );

    return { familyId: familyRef.id };
  });
});
