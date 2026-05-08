import "package:cloud_firestore/cloud_firestore.dart";

class MpuService {
  MpuService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Map<String, dynamic>>> streamPrograms() {
    return _db
        .collection("core_competencies")
        .doc("all")
        .collection("programs")
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}

