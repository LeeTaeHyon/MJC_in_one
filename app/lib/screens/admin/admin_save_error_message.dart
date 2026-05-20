import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";

/// 관리자 글 저장 실패 시 사용자용 안내 문구.
String adminSaveErrorMessage(FirebaseException e, {String? uid}) {
  final bool permissionLike = e.code == "unauthorized" ||
      e.code == "permission-denied" ||
      e.code == "storage/unauthorized";

  if (!permissionLike) {
    return "저장 실패 (${e.plugin}/${e.code}): ${e.message ?? ""}";
  }

  final StringBuffer buf = StringBuffer(
    "저장 권한이 거부되었습니다 (${e.plugin}/${e.code}).\n",
  );

  if (e.plugin == "firebase_storage") {
    buf.writeln("· Storage 규칙 배포: firebase deploy --only storage");
    buf.writeln(
      "· 콘솔 Storage에서 「cross-service rules」 IAM 역할 허용했는지 확인",
    );
    buf.writeln("· 사진 경로: …/images/0.jpg (구형 image.jpg만 허용하는 규칙이면 거부됨)");
  } else {
    buf.writeln("· Firestore 규칙·admin/users UID 확인");
  }

  if (uid != null && uid.isNotEmpty) {
    buf.writeln("· 로그인 UID: $uid → admin/users 의 uids 배열에 포함되어야 함");
  }

  return buf.toString().trim();
}
