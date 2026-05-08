import "package:cloud_firestore/cloud_firestore.dart";

class DeveloperSupportService {
  DeveloperSupportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> submitInquiry({
    required String type,
    required String typeLabel,
    required String message,
    required String contact,
    required String platform,
  }) async {
    await _db.collection("developer_inquiries").add(<String, dynamic>{
      "type": type,
      "type_label": typeLabel,
      "message": message,
      "contact": contact,
      "device_info": <String, dynamic>{
        "platform": platform,
      },
      "created_at": FieldValue.serverTimestamp(),
      "status": "open",
      "admin_memo": "",
      "resolved_by": null,
      "resolved_at": null,
    });
  }

  Stream<List<Map<String, dynamic>>> streamDevLogs({int limit = 10}) {
    return _db
        .collection("dev_logs")
        .orderBy("created_at", descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final v = data["created_at"];
              if (v is Timestamp) {
                return <String, dynamic>{...data, "created_at": v.toDate()};
              }
              return data;
            }).toList());
  }
}

