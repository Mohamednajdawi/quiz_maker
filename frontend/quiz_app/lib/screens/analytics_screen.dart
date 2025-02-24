import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/quiz_service.dart';
import 'dart:ui';
import 'dart:math' as math;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  bool _isLoading = true;
  Map<String, dynamic>? _analyticsData;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _loadAnalytics();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
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

      // Combine both histories
      final allHistory = [...history, ...urlHistory];
      
      // Calculate analytics data
      final totalQuizzes = allHistory.length;
      int totalScore = 0;
      int totalQuestions = 0;
      final Map<String, int> categoryAttempts = {};
      final List<int> scores = [];
      final Map<String, double> categoryAccuracy = {};
      
      for (final quiz in allHistory) {
        final score = quiz['score'] as int;
        final total = quiz['totalQuestions'] as int;
        final category = quiz['category'] as String? ?? 'Unknown';
        
        totalScore += score;
        totalQuestions += total;
        scores.add(score);
        categoryAttempts[category] = (categoryAttempts[category] ?? 0) + 1;
        
        final categoryScore = categoryAccuracy[category] ?? 0;
        categoryAccuracy[category] = categoryScore + (score / total);
      }

      // Calculate averages
      for (final category in categoryAccuracy.keys) {
        categoryAccuracy[category] = categoryAccuracy[category]! / 
            (categoryAttempts[category] ?? 1);
      }

      // Sort history by timestamp
      allHistory.sort((a, b) => 
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime)
      );

      setState(() {
        _analyticsData = {
          'totalQuizzes': totalQuizzes,
          'averageScore': totalQuizzes > 0 ? (totalScore / totalQuestions) * 100 : 0,
          'categoryAttempts': categoryAttempts,
          'categoryAccuracy': categoryAccuracy,
          'scores': scores,
          'recentHistory': allHistory.take(5).toList(),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAnalytics();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analyticsData == null || _analyticsData!['totalQuizzes'] == 0
              ? _buildEmptyState()
              : _buildAnalytics(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Quiz Data Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Take some quizzes to see your analytics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start a Quiz'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 24),
            _buildPerformanceChart(),
            const SizedBox(height: 24),
            _buildCategoryAnalysis(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Quizzes',
          _analyticsData!['totalQuizzes'].toString(),
          Icons.quiz,
          [Colors.blue.shade400, Colors.blue.shade700],
        ),
        _buildStatCard(
          'Average Score',
          '${_analyticsData!['averageScore'].toStringAsFixed(1)}%',
          Icons.score,
          [Colors.purple.shade400, Colors.purple.shade700],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, List<Color> gradient) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 32 * _animation.value,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceChart() {
    final scores = _analyticsData!['scores'] as List<int>;
    if (scores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Trend',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: CustomPaint(
            size: const Size(double.infinity, 200),
            painter: PerformanceChartPainter(
              scores: scores,
              animation: _animation,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryAnalysis() {
    final categoryAccuracy = _analyticsData!['categoryAccuracy'] as Map<String, double>;
    if (categoryAccuracy.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Performance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...categoryAccuracy.entries.map((entry) {
          final accuracy = (entry.value * 100).roundToDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: accuracy / 100 * _animation.value,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                        minHeight: 12,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  '${(accuracy * _animation.value).round()}% Accuracy',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final recentHistory = _analyticsData!['recentHistory'] as List;
    if (recentHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...recentHistory.map((quiz) {
          final score = quiz['score'] as int;
          final total = quiz['totalQuestions'] as int;
          final accuracy = (score / total * 100).round();
          final category = quiz['category'] as String? ?? 'Unknown';
          final timestamp = quiz['timestamp'] is DateTime 
              ? quiz['timestamp'] as DateTime
              : DateTime.parse(quiz['timestamp'].toString());

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Text(
                  '$accuracy%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(category),
              subtitle: Text(
                'Score: $score/$total • ${_formatDate(timestamp)}',
              ),
              trailing: Icon(
                accuracy >= 80 ? Icons.emoji_events : Icons.score,
                color: accuracy >= 80 ? Colors.amber : null,
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class PerformanceChartPainter extends CustomPainter {
  final List<int> scores;
  final Animation<double> animation;
  final Color color;

  PerformanceChartPainter({
    required this.scores,
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (scores.isEmpty) return;

    final maxScore = scores.reduce(math.max).toDouble();
    final points = <Offset>[];
    final width = size.width;
    final height = size.height;
    final horizontalStep = width / (scores.length - 1);

    for (var i = 0; i < scores.length; i++) {
      final x = i * horizontalStep;
      final y = height - (scores[i] / maxScore * height * animation.value);
      points.add(Offset(x, y));
    }

    // Draw line
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      path.lineTo(p1.dx, p1.dy);
    }
    canvas.drawPath(path, paint);

    // Draw dots
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 