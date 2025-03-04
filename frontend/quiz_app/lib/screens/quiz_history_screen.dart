import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/quiz_service.dart';

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  final _quizService = QuizService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _urlQuizHistory = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Load both regular and URL quiz history
      final [history, urlHistory] = await Future.wait([
        _quizService.getUserQuizHistory(userId),
        _quizService.getUserURLQuizHistory(userId),
      ]);

      setState(() {
        _history = history;
        _urlQuizHistory = urlHistory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showQuizDetails(Map<String, dynamic> quiz) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quiz['topic'] ?? quiz['category'] ?? 'Quiz',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                if (quiz['sourceType'] == 'pdf' && quiz['sourceInfo'] != null) ...[
                  Text(
                    'PDF File:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quiz['sourceInfo'],
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else if (quiz['sourceType'] == 'url' && quiz['sourceInfo'] != null) ...[
                  Text(
                    'Source URL:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(quiz['sourceInfo']),
                  const SizedBox(height: 16),
                ] else if (quiz['sourceUrl'] != null) ...[
                  // Legacy support for older quiz records
                  Text(
                    'Source URL:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(quiz['sourceUrl']),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Questions:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  (quiz['questions'] as List).length,
                  (index) {
                    final question = quiz['questions'][index];
                    final userAnswer = quiz['userAnswers'][index];
                    final correctAnswer = _letterToIndex(question['right_option']);
                    final isCorrect = userAnswer == correctAnswer;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isCorrect
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isCorrect ? Icons.check_circle : Icons.cancel,
                                  color: isCorrect ? Colors.green : Colors.red,
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
                              question['question'],
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your answer: ${question['options'][userAnswer]}',
                              style: TextStyle(
                                color: isCorrect ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!isCorrect) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Correct answer: ${question['options'][correctAnswer]}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _letterToIndex(String letter) {
    return letter.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final allHistory = [..._history, ..._urlQuizHistory]
      ..sort((a, b) => (b['timestamp'] as DateTime)
          .compareTo(a['timestamp'] as DateTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : allHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No quiz history yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete some quizzes to see them here',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: allHistory.length,
                        itemBuilder: (context, index) {
                          final quiz = allHistory[index];
                          final score = quiz['score'] as int;
                          final total = quiz['totalQuestions'] as int;
                          final percentage = (score / total * 100).round();
                          final timeTaken = Duration(seconds: quiz['timeTaken'] as int);
                          final timestamp = quiz['timestamp'] as DateTime;
                          final isUrlQuiz = quiz['questions'] != null;
                          
                          // Determine quiz type icon
                          IconData quizTypeIcon;
                          Color quizTypeColor;
                          if (quiz['type'] == 'pdf' || quiz['sourceType'] == 'pdf') {
                            quizTypeIcon = Icons.picture_as_pdf_rounded;
                            quizTypeColor = Colors.red.shade700;
                          } else if (quiz['type'] == 'url' || quiz['sourceType'] == 'url' || quiz['sourceUrl'] != null) {
                            quizTypeIcon = Icons.link_rounded;
                            quizTypeColor = Colors.blue.shade700;
                          } else {
                            quizTypeIcon = Icons.quiz_rounded;
                            quizTypeColor = Colors.purple.shade700;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: isUrlQuiz ? () => _showQuizDetails(quiz) : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          percentage >= 80
                                              ? Icons.star
                                              : percentage >= 50
                                                  ? Icons.star_half
                                                  : Icons.star_border,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            quiz['topic'] ?? quiz['category'] ?? 'Quiz',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        ),
                                        Icon(quizTypeIcon, size: 20, color: quizTypeColor),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Score: $score/$total ($percentage%)',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: percentage >= 80
                                                ? Colors.green
                                                : percentage >= 50
                                                    ? Colors.orange
                                                    : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 16),
                                        const SizedBox(width: 4),
                                        Text('Time: ${_formatDuration(timeTaken)}'),
                                        const Spacer(),
                                        const Icon(Icons.calendar_today, size: 16),
                                        const SizedBox(width: 4),
                                        Text(_formatDate(timestamp)),
                                      ],
                                    ),
                                    if (isUrlQuiz) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to view details',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
} 