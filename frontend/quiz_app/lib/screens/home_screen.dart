import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/quiz_service.dart';
import 'quiz/quiz_screen.dart';
import '../models/question.dart';
import 'url_quiz_screen.dart';
import 'quiz_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final QuizService _quizService = QuizService();
  bool _isLoading = true;
  bool _isRetrying = false;
  List<String> _categories = [];
  Map<String, int> _userProgress = {};
  String? _error;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  static const int maxRetryAttempts = 3;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _isRetrying = false;
    });

    try {
      final categories = await _quizService.getCategories();
      
      if (!mounted) return;

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final history = await _quizService.getUserQuizHistory(userId);

      if (!mounted) return;

      // Calculate progress per category
      final progress = <String, int>{};
      for (final result in history) {
        final category = result['category'] as String;
        final score = result['score'] as int;
        final total = result['totalQuestions'] as int;
        progress[category] = ((score / total) * 100).round();
      }

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _userProgress = progress;
        _isLoading = false;
        _retryAttempt = 0;
      });
    } catch (e) {
      if (!mounted) return;
      
      _retryAttempt++;
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isRetrying = _retryAttempt < maxRetryAttempts;
      });

      if (_retryAttempt < maxRetryAttempts) {
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(seconds: _retryAttempt * 2), () {
          if (mounted) {
            _loadData();
          }
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_retryAttempt < maxRetryAttempts 
              ? 'Error loading data, retrying in ${_retryAttempt * 2} seconds...' 
              : 'Error loading data: $e'),
          action: SnackBarAction(
            label: 'Retry Now',
            onPressed: () {
              _retryTimer?.cancel();
              _loadData();
            },
          ),
          duration: Duration(seconds: _retryAttempt * 2),
        ),
      );
    }
  }

  Future<void> _startQuiz(String category) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final questions = await _quizService.getRandomQuestions(category, 10);
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            questions: questions,
            category: category,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting quiz: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _startQuiz(category),
          ),
        ),
      );
    }
  }

  Future<void> _startDummyQuiz() async {
    final dummyQuestions = [
      Question(
        id: '1',
        text: 'What is Flutter?',
        options: [
          'A mobile development framework',
          'A bird',
          'A web browser',
          'A database',
        ],
        correctOptionIndex: 0,
        explanation: 'Flutter is Google\'s UI toolkit for building beautiful, natively compiled applications for mobile, web, and desktop from a single codebase.',
        category: 'Flutter',
        difficulty: 1,
        tags: ['flutter', 'basics'],
      ),
      Question(
        id: '2',
        text: 'What programming language is Flutter built with?',
        options: [
          'JavaScript',
          'Java',
          'Dart',
          'Python',
        ],
        correctOptionIndex: 2,
        explanation: 'Flutter uses Dart, a programming language also developed by Google.',
        category: 'Flutter',
        difficulty: 1,
        tags: ['flutter', 'dart', 'basics'],
      ),
      Question(
        id: '3',
        text: 'What is a Widget in Flutter?',
        options: [
          'A database table',
          'A UI element',
          'A network request',
          'A file format',
        ],
        correctOptionIndex: 1,
        explanation: 'In Flutter, everything is a widget. Widgets are the basic building blocks of a Flutter app\'s user interface.',
        category: 'Flutter',
        difficulty: 1,
        tags: ['flutter', 'widgets', 'basics'],
      ),
      Question(
        id: '4',
        text: 'What is "Hot Reload" in Flutter?',
        options: [
          'A way to restart the app',
          'A way to update code without restarting',
          'A way to clear cache',
          'A way to compile code',
        ],
        correctOptionIndex: 1,
        explanation: 'Hot Reload allows you to see changes in your code reflected in your app instantly without losing the current state.',
        category: 'Flutter',
        difficulty: 2,
        tags: ['flutter', 'development', 'tools'],
      ),
      Question(
        id: '5',
        text: 'What is StatefulWidget in Flutter?',
        options: [
          'A widget that never changes',
          'A widget that can change over time',
          'A widget for images only',
          'A widget for text only',
        ],
        correctOptionIndex: 1,
        explanation: 'StatefulWidget is a widget that can change its appearance in response to events or user actions.',
        category: 'Flutter',
        difficulty: 2,
        tags: ['flutter', 'widgets', 'state'],
      ),
    ];

    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          questions: dummyQuestions,
          category: 'Flutter Basics',
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    if (_isLoading) return;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isLoading ? null : _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (_isRetrying) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Retrying... (Attempt ${_retryAttempt}/$maxRetryAttempts)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primaryContainer,
                                Theme.of(context).colorScheme.primary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              Text(
                                FirebaseAuth.instance.currentUser?.email ?? 'User',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Quick Actions
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.play_circle,
                                label: 'Random Quiz',
                                onTap: _categories.isEmpty ? _startDummyQuiz : () {
                                  final random = _categories[DateTime.now().millisecondsSinceEpoch % _categories.length];
                                  _startQuiz(random);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.history,
                                label: 'History',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const QuizHistoryScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Categories Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Categories',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            TextButton.icon(
                              onPressed: () {
                                // TODO: Show all categories
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Coming soon!')),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final progress = _userProgress[category] ?? 0;
                            return _CategoryCard(
                              title: category,
                              progress: progress,
                              onTap: () => _startQuiz(category),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const URLQuizScreen()),
                            );
                          },
                          icon: const Icon(Icons.link),
                          label: const Text('Generate Quiz from URL'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final int progress;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.primary,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (progress > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$progress%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Temporary data model for categories
class Category {
  final String title;
  final IconData icon;
  final Color color;

  const Category({
    required this.title,
    required this.icon,
    required this.color,
  });
}

// Sample categories data
final List<Category> categories = [
  Category(
    title: 'TypeScript',
    icon: Icons.code,
    color: Colors.blue,
  ),
  Category(
    title: 'Angular',
    icon: Icons.web,
    color: Colors.red,
  ),
  Category(
    title: 'Firebase',
    icon: Icons.storage,
    color: Colors.orange,
  ),
  Category(
    title: 'Flutter',
    icon: Icons.mobile_friendly,
    color: Colors.blue,
  ),
]; 