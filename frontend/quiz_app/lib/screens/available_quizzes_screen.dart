import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class AvailableQuizzesScreen extends StatefulWidget {
  const AvailableQuizzesScreen({super.key});

  @override
  State<AvailableQuizzesScreen> createState() => _AvailableQuizzesScreenState();
}

class _AvailableQuizzesScreenState extends State<AvailableQuizzesScreen> {
  final _quizService = QuizService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableQuizzes = [];
  String? _error;
  Map<String, dynamic>? _selectedQuiz;
  bool _loadingQuiz = false;
  int _currentQuestionIndex = 0;
  List<int> _userAnswers = [];
  bool _showResults = false;
  final _stopwatch = Stopwatch();
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _fetchAvailableQuizzes();
  }

  Future<void> _fetchAvailableQuizzes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quizzes = await _quizService.getAllAvailableQuizzes();
      setState(() {
        _availableQuizzes = quizzes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadQuiz(int topicId) async {
    setState(() {
      _loadingQuiz = true;
      _error = null;
    });

    try {
      final quiz = await _quizService.getQuizByTopicId(topicId);
      setState(() {
        _selectedQuiz = quiz;
        _loadingQuiz = false;
        _currentQuestionIndex = 0;
        _userAnswers = List.filled(quiz['questions'].length, -1);
        _showResults = false;
      });
      _stopwatch.reset();
      _stopwatch.start();
      _startTime = DateTime.now();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingQuiz = false;
      });
    }
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < (_selectedQuiz?['questions']?.length ?? 0) - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitQuiz() async {
    _stopwatch.stop();
    
    // Calculate score
    int score = 0;
    for (int i = 0; i < _userAnswers.length; i++) {
      // Convert letter-based right_option to numeric index (a=0, b=1, c=2, d=3)
      String rightOption = _selectedQuiz!['questions'][i]['right_option'];
      int correctIndex = rightOption.codeUnitAt(0) - 'a'.codeUnitAt(0);
      
      if (_userAnswers[i] == correctIndex) {
        score++;
      }
    }

    // Show results
    setState(() {
      _showResults = true;
    });

    // Save results in the background
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await _quizService.saveQuizResult(
          userId: userId,
          category: _selectedQuiz!['topic'],
          score: score,
          totalQuestions: _userAnswers.length,
          timeTaken: Duration(milliseconds: _stopwatch.elapsedMilliseconds),
        );
      } catch (e) {
        // Silently handle error
        debugPrint('Error saving quiz result: $e');
      }
    }
  }

  void _resetQuiz() {
    setState(() {
      _selectedQuiz = null;
      _currentQuestionIndex = 0;
      _userAnswers = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Available Quizzes'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Available Quizzes'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchAvailableQuizzes,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedQuiz != null) {
      // Show quiz questions
      return _buildQuizScreen();
    }

    // Show list of available quizzes
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Quizzes'),
      ),
      body: _availableQuizzes.isEmpty
          ? const Center(
              child: Text(
                'No quizzes available yet.\nGenerate a quiz from a URL first!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _availableQuizzes.length,
              itemBuilder: (context, index) {
                final quiz = _availableQuizzes[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => _loadQuiz(quiz['id']),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz['topic'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Quiz ID: ${quiz['id']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAvailableQuizzes,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildQuizScreen() {
    if (_loadingQuiz) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_selectedQuiz!['topic']),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_showResults) {
      return _buildResultsScreen();
    }

    final currentQuestion = _selectedQuiz!['questions'][_currentQuestionIndex];
    final options = List<String>.from(currentQuestion['options']);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedQuiz!['topic']),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _resetQuiz,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _selectedQuiz!['questions'].length,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1}/${_selectedQuiz!['questions'].length}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Score: ${_userAnswers.where((a) => a != -1).length}/${_selectedQuiz!['questions'].length} answered',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        currentQuestion['question'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Options
                    ...List.generate(
                      options.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _selectAnswer(index),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _userAnswers[_currentQuestionIndex] == index
                                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _userAnswers[_currentQuestionIndex] == index
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _userAnswers[_currentQuestionIndex] == index
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.withOpacity(0.2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index), // A, B, C, D...
                                      style: TextStyle(
                                        color: _userAnswers[_currentQuestionIndex] == index
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    options[index],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Previous'),
                  ),
                  if (_currentQuestionIndex == _selectedQuiz!['questions'].length - 1)
                    ElevatedButton(
                      onPressed: _userAnswers.contains(-1) ? null : _submitQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Submit'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Next'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    // Calculate score
    int score = 0;
    for (int i = 0; i < _userAnswers.length; i++) {
      // Convert letter-based right_option to numeric index (a=0, b=1, c=2, d=3)
      String rightOption = _selectedQuiz!['questions'][i]['right_option'];
      int correctIndex = rightOption.codeUnitAt(0) - 'a'.codeUnitAt(0);
      
      if (_userAnswers[i] == correctIndex) {
        score++;
      }
    }

    final percentage = (score / _userAnswers.length) * 100;
    final timeTaken = _stopwatch.elapsed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _resetQuiz,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                _selectedQuiz!['topic'],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 8,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score/${_userAnswers.length}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildResultItem(
                        icon: Icons.timer,
                        title: 'Time Taken',
                        value: '${timeTaken.inMinutes}m ${timeTaken.inSeconds % 60}s',
                      ),
                      const Divider(),
                      _buildResultItem(
                        icon: Icons.check_circle,
                        title: 'Correct Answers',
                        value: '$score',
                      ),
                      const Divider(),
                      _buildResultItem(
                        icon: Icons.cancel,
                        title: 'Wrong Answers',
                        value: '${_userAnswers.length - score}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Return to previous screen
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Back to Home'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _resetQuiz,
                child: const Text('Try Another Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 