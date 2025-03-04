import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/question.dart';

class QuizScreen extends StatefulWidget {
  final List<Question> questions;
  final String category;

  const QuizScreen({
    super.key,
    required this.questions,
    required this.category,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  List<int?> _answers = [];
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.questions.length, null);
    _stopwatch.start();
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _answers[_currentIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _finishQuiz() {
    _stopwatch.stop();
    final score = _calculateScore();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          score: score,
          totalQuestions: widget.questions.length,
          timeTaken: _stopwatch.elapsed,
          category: widget.category,
          questions: widget.questions,
          userAnswers: _answers,
        ),
      ),
    );
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_answers[i] == widget.questions[i].correctOptionIndex) {
        score++;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} Quiz'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '${_currentIndex + 1}/${widget.questions.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.text,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (question.imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: question.imageUrl!,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ...List.generate(
              question.options.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Material(
                  color: _answers[_currentIndex] == index
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _selectAnswer(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _answers[_currentIndex] == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _answers[_currentIndex] == index
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade500,
                              ),
                              color: _answers[_currentIndex] == index
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            child: _answers[_currentIndex] == index
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${String.fromCharCode(65 + index)}. ${question.options[index]}',
                              style: TextStyle(
                                color: _answers[_currentIndex] == index
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentIndex > 0 ? _previousQuestion : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
                ElevatedButton.icon(
                  onPressed: _answers[_currentIndex] != null
                      ? _currentIndex < widget.questions.length - 1
                          ? _nextQuestion
                          : _finishQuiz
                      : null,
                  icon: Icon(
                    _currentIndex < widget.questions.length - 1
                        ? Icons.arrow_forward
                        : Icons.check,
                  ),
                  label: Text(
                    _currentIndex < widget.questions.length - 1
                        ? 'Next'
                        : 'Finish',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuizResultScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final Duration timeTaken;
  final String category;
  final List<Question> questions;
  final List<int?> userAnswers;

  const QuizResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.timeTaken,
    required this.category,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score / totalQuestions) * 100;
    final minutes = timeTaken.inMinutes;
    final seconds = timeTaken.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      percentage >= 80
                          ? '🎉 Excellent!'
                          : percentage >= 60
                              ? '👍 Good Job!'
                              : '💪 Keep Practicing!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$score/$totalQuestions correct (${percentage.round()}%)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: percentage >= 80
                                ? Colors.green
                                : percentage >= 60
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Time: $minutes:${seconds.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Question Review',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...List.generate(
              questions.length,
              (index) => Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            userAnswers[index] == questions[index].correctOptionIndex
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: userAnswers[index] == questions[index].correctOptionIndex
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
                      Text(questions[index].text),
                      if (questions[index].imageUrl != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: questions[index].imageUrl!,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Your Answer: ${userAnswers[index] != null ? questions[index].options[userAnswers[index]!] : 'Not answered'}',
                        style: TextStyle(
                          color: userAnswers[index] == questions[index].correctOptionIndex
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Correct Answer: ${questions[index].options[questions[index].correctOptionIndex]}',
                        style: const TextStyle(color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Explanation: ${questions[index].explanation}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 