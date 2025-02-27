import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const String baseUrl = 'http://localhost:8000'; // Update with your backend URL

  // Enable persistence
  static Future<void> initialize() async {
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
  }

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

  // Get user's URL quiz history
  Future<List<Map<String, dynamic>>> getUserURLQuizHistory(String userId) async {
    return _withRetry(() async {
      final snapshot = await _firestore
          .collection('url_quizzes')
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

  // Generate quiz from URL
  Future<Map<String, dynamic>> generateQuiz(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to generate quiz: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error generating quiz: $e');
    }
  }

  // Get specific URL quiz details
  Future<Map<String, dynamic>?> getURLQuizDetails(String quizId) async {
    return _withRetry(() async {
      final doc = await _firestore
          .collection('url_quizzes')
          .doc(quizId)
          .get();

      if (!doc.exists) return null;

      return {
        'id': doc.id,
        ...doc.data()!,
        'timestamp': (doc.data()!['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      };
    });
  }

  // Save URL quiz result
  Future<void> saveURLQuizResult({
    required String userId,
    required Map<String, dynamic> quizData,
    required List<int> userAnswers,
    required int score,
    required Duration timeTaken,
  }) async {
    return _withRetry(() async {
      final quizDoc = await _firestore.collection('url_quizzes').add({
        'userId': userId,
        'topic': quizData['topic'] ?? 'URL Quiz',
        'questions': quizData['questions'],
        'userAnswers': userAnswers,
        'score': score,
        'totalQuestions': quizData['questions'].length,
        'timeTaken': timeTaken.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
        'sourceUrl': quizData['url'] ?? '',
      });

      await quizDoc.get();

      final resultDoc = await _firestore.collection('results').add({
        'userId': userId,
        'category': quizData['topic'] ?? 'URL Quiz',
        'score': score,
        'totalQuestions': quizData['questions'].length,
        'timeTaken': timeTaken.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
        'quizRef': quizDoc.id,
        'type': 'url',
      });

      await resultDoc.get();
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
      final docRef = await _firestore.collection('results').add({
        'userId': userId,
        'category': category,
        'score': score,
        'totalQuestions': totalQuestions,
        'timeTaken': timeTaken.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await docRef.get();
    });
  }

  // Get all available quizzes from the backend
  Future<List<Map<String, dynamic>>> getAllAvailableQuizzes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/topics'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch quizzes: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching quizzes: $e');
    }
  }
  
  // Get a specific quiz by topic ID
  Future<Map<String, dynamic>> getQuizByTopicId(int topicId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/quiz/$topicId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch quiz: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching quiz: $e');
    }
  }
} 