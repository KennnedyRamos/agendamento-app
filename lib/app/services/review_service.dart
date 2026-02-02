import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createReview({
    required String barberId,
    required int rating,
    String? comment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }
    if (rating < 1 || rating > 5) {
      throw Exception('Avaliação inválida.');
    }

    final reviewId = '${barberId}_${user.uid}';
    final data = {
      'barberId': barberId,
      'clientId': user.uid,
      'rating': rating,
      'comment': comment?.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await _db.collection('reviews').doc(reviewId).set(
            data,
            SetOptions(merge: true),
          );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Fallback for older rules: create a new review document.
        await _db.collection('reviews').add(data);
      } else {
        rethrow;
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReviewsForBarber(
      String barberId) {
    return _db
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .snapshots();
  }

  Future<bool> hasReview(String barberId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final snap = await _db
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .where('clientId', isEqualTo: user.uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<int?> getReviewRating(String barberId) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _db
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .where('clientId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final rating = snap.docs.first.data()['rating'];
    if (rating is int) return rating;
    if (rating is num) return rating.toInt();
    return null;
  }
}

