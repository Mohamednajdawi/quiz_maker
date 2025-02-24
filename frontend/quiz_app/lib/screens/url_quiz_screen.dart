import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class URLQuizScreen extends StatefulWidget {
  final String? initialUrl;
  
  const URLQuizScreen({
    super.key,
    this.initialUrl,
  });

  @override
  State<URLQuizScreen> createState() => _URLQuizScreenState();
}

class _URLQuizScreenState extends State<URLQuizScreen> {
  final _urlController = TextEditingController();
  final _quizService = QuizService();
  final _stopwatch = Stopwatch();
  Map<String, dynamic>? _quizData;
  bool _isLoading = false;
  String? _error;
  int _currentQuestionIndex = 0;
  List<int> _userAnswers = [];
  bool _showResults = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _generateQuiz();
    }
  }

  Future<void> _generateQuiz() async {
    if (_urlController.text.isEmpty) {
      setState(() => _error = 'Please enter a URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _quizData = null;
      _showResults = false;
    });

    try {
      final quiz = await _quizService.generateQuiz(_urlController.text);
      setState(() {
        _quizData = quiz;
        _isLoading = false;
        _currentQuestionIndex = 0;
        _userAnswers = List.filled(quiz['questions'].length, -1);
      });
      _stopwatch.reset();
      _stopwatch.start();
      _startTime = DateTime.now();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < (_quizData?['questions']?.length ?? 0) - 1) {
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
    // Show results immediately
    setState(() {
      _showResults = true;
    });

    // Save results in the background
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results not saved - please sign in to save your progress')),
      );
      return;
    }

    try {
      final score = _calculateScore();
      final timeTaken = DateTime.now().difference(_startTime!);
      
      // Save complete quiz data including questions and answers
      await _quizService.saveURLQuizResult(
        userId: userId,
        quizData: {
          ..._quizData!,
          'url': _urlController.text,
        },
        userAnswers: _userAnswers,
        score: score,
        timeTaken: timeTaken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz saved successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save quiz'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _submitQuiz,
            ),
          ),
        );
      }
    }
  }

  int _calculateScore() {
    if (_quizData == null) return 0;
    int score = 0;
    for (int i = 0; i < _quizData!['questions'].length; i++) {
      final question = _quizData!['questions'][i];
      final rightOption = question['right_option'];
      if (rightOption != null && _userAnswers[i] == _letterToIndex(rightOption)) {
        score++;
      }
    }
    return score;
  }

  String _getOptionText(int questionIndex, int optionIndex) {
    try {
      final options = _quizData?['questions']?[questionIndex]?['options'];
      if (options != null && optionIndex >= 0 && optionIndex < options.length) {
        final fullText = options[optionIndex].toString();
        return fullText.substring(fullText.indexOf('.') + 2);
      }
      return 'Option not available';
    } catch (e) {
      return 'Option not available';
    }
  }

  String _getFullOptionText(int questionIndex, int optionIndex) {
    try {
      final options = _quizData?['questions']?[questionIndex]?['options'];
      if (options != null && optionIndex >= 0 && optionIndex < options.length) {
        return options[optionIndex].toString();
      }
      return 'Option not available';
    } catch (e) {
      return 'Option not available';
    }
  }

  bool _isAnswerCorrect(int questionIndex) {
    try {
      final rightOption = _quizData?['questions']?[questionIndex]?['right_option'];
      return rightOption != null && _userAnswers[questionIndex] == _letterToIndex(rightOption);
    } catch (e) {
      return false;
    }
  }

  int _letterToIndex(String letter) {
    return letter.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
  }

  String _indexToLetter(int index) {
    return String.fromCharCode('a'.codeUnitAt(0) + index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Quiz Generator'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'Enter URL',
                          hintText: 'https://example.com',
                          errorText: _error,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateQuiz,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isLoading ? 'Generating...' : 'Generate Quiz'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_quizData != null && !_showResults) ...[
                const SizedBox(height: 24),
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_quizData!['questions'].length}',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          _quizData!['questions'][_currentQuestionIndex]['question'] ?? 'Question not available',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(
                          _quizData!['questions'][_currentQuestionIndex]['options']?.length ?? 0,
                          (index) => RadioListTile(
                            title: Text(_getFullOptionText(_currentQuestionIndex, index)),
                            value: index,
                            groupValue: _userAnswers[_currentQuestionIndex],
                            onChanged: (value) => _selectAnswer(value as int),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                    if (_currentQuestionIndex == _quizData!['questions'].length - 1)
                      ElevatedButton.icon(
                        onPressed: _userAnswers.contains(-1) ? null : _submitQuiz,
                        icon: const Icon(Icons.check),
                        label: const Text('Submit'),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _currentQuestionIndex < (_quizData!['questions'].length - 1)
                            ? _nextQuestion
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
                  ],
                ),
              ],
              if (_showResults && _quizData != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz Results',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _calculateScore() == _quizData!['questions'].length
                                  ? Icons.star
                                  : Icons.star_half,
                              color: Colors.amber,
                              size: 32,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Score: ${_calculateScore()} out of ${_quizData!['questions'].length}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Detailed Summary:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(
                          _quizData!['questions'].length,
                          (index) => Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: _isAnswerCorrect(index)
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _isAnswerCorrect(index)
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: _isAnswerCorrect(index)
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Question ${index + 1}',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _quizData!['questions'][index]['question'] ?? 'Question not available',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your answer: ${_getFullOptionText(index, _userAnswers[index])}',
                                    style: TextStyle(
                                      color: _isAnswerCorrect(index)
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!_isAnswerCorrect(index)) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Correct answer: ${_getFullOptionText(index, _letterToIndex(_quizData!['questions'][index]['right_option']))}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                  if (_quizData!['questions'][index]['explanation'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Explanation:',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _quizData!['questions'][index]['explanation'],
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _quizData = null;
                                  _userAnswers = [];
                                  _showResults = false;
                                  _urlController.clear();
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Start New Quiz'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.home),
                              label: const Text('Back to Home'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _stopwatch.stop();
    super.dispose();
  }
} 