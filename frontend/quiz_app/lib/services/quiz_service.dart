import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';
import 'dart:async';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          throw Exception('Failed after $maxRetries attempts: ${e.toString()}');
        }
        await Future.delayed(retryDelay * attempts);
      }
    }
    throw Exception('Failed after $maxRetries attempts');
  }

  // Get all categories
  Future<List<String>> getCategories() async {
    return _withRetry(() async {
      final snapshot = await _firestore
          .collection('categories')
          .get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  // Get questions by category
  Future<List<Question>> getQuestionsByCategory(String category, {int? limit}) async {
    return _withRetry(() async {
      var query = _firestore
          .collection('questions')
          .where('category', isEqualTo: category);
      
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs
          .map((doc) => Question.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Get questions by tags
  Future<List<Question>> getQuestionsByTags(List<String> tags) async {
    final snapshot = await _firestore
        .collection('questions')
        .where('tags', arrayContainsAny: tags)
        .get();
    return snapshot.docs
        .map((doc) => Question.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  // Add a new question
  Future<String> addQuestion(Question question) async {
    final docRef = await _firestore.collection('questions').add(question.toJson());
    return docRef.id;
  }

  // Update an existing question
  Future<void> updateQuestion(Question question) async {
    await _firestore
        .collection('questions')
        .doc(question.id)
        .update(question.toJson());
  }

  // Delete a question
  Future<void> deleteQuestion(String questionId) async {
    await _firestore.collection('questions').doc(questionId).delete();
  }

  // Get random questions from a category
  Future<List<Question>> getRandomQuestions(String category, int count) async {
    return _withRetry(() async {
      final snapshot = await _firestore
          .collection('questions')
          .where('category', isEqualTo: category)
          .limit(count)
          .get(const GetOptions(source: Source.serverAndCache));
      
      return snapshot.docs
          .map((doc) => Question.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Save quiz result
  Future<void> saveQuizResult({
    required String userId,
    required String category,
    required int score,
    required int totalQuestions,
    required Duration timeTaken,
  }) async {
    return _withRetry(() async {
      await _firestore.collection('results').add({
        'userId': userId,
        'category': category,
        'score': score,
        'totalQuestions': totalQuestions,
        'timeTaken': timeTaken.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // Get user's quiz history
  Future<List<Map<String, dynamic>>> getUserQuizHistory(String userId) async {
    return _withRetry(() async {
      final snapshot = await _firestore
          .collection('results')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
                'timestamp': (doc.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              })
          .toList();
    });
  }
} 