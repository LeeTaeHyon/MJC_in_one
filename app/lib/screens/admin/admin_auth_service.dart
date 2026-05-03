import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";

/// 관리자 인증/권한 검사 헬퍼.
///
/// - Firebase Auth Email/Password 로그인 사용
/// - `admin/users` 단일 문서의 `uids` 배열에 본인 UID 가 있어야 관리자
class AdminAuthService {
  AdminAuthService._({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static final AdminAuthService instance = AdminAuthService._();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// `admin/users` 문서의 `uids` 배열로 권한 검사.
  Future<bool> isAdmin(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final snap = await _firestore.collection("admin").doc("users").get();
      final data = snap.data();
      if (data == null) return false;
      final raw = data["uids"];
      if (raw is List) {
        return raw.map((e) => e.toString()).contains(uid);
      }
      return false;
    } catch (e) {
      debugPrint("admin check error: $e");
      return false;
    }
  }
}
