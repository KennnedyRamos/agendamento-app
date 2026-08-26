import 'package:agendamento_app/app/models/app_notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationHistoryService {
  final FirebaseFirestore _db;

  NotificationHistoryService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notifications(String userId) {
    return _db.collection('users').doc(userId).collection('notifications');
  }

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _notifications(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(AppNotification.fromDocument)
            .toList(growable: false));
  }

  Stream<int> watchUnreadCount(String userId) {
    return _notifications(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAllAsRead(String userId) async {
    while (true) {
      final snapshot = await _notifications(userId)
          .where('isRead', isEqualTo: false)
          .limit(400)
          .get();
      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      for (final document in snapshot.docs) {
        batch.update(document.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<void> clearAll(String userId) async {
    while (true) {
      final snapshot = await _notifications(userId).limit(400).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
