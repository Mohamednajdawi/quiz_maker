import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PDFQuizScreen extends StatefulWidget {
  final String? initialDifficulty;
  final int? initialNumQuestions;
  
  const PDFQuizScreen({
    super.key,
    this.initialDifficulty,
    this.initialNumQuestions,
  });

  @override
  State<PDFQuizScreen> createState() => _PDFQuizScreenState();
}

class _PDFQuizScreenState extends State<PDFQuizScreen> {
  final _quizService = QuizService();
  final _stopwatch = Stopwatch();
  Map<String, dynamic>? _quizData;
  bool _isLoading = false;
  String? _error;
  int _currentQuestionIndex = 0;
  List<int> _userAnswers = [];
  bool _showResults = false;
  DateTime? _startTime;
  
  // Modified to handle both web and native platforms
  dynamic _selectedPDFFile;
  String? _selectedFileName;
  
  // Added state variables for difficulty and number of questions
  String _selectedDifficulty = 'medium';
  int _numQuestions = 5;
  
  // List of available difficulty levels
  final List<String> _difficultyLevels = ['easy', 'medium', 'hard'];

  @override
  void initState() {
    super.initState();
    if (widget.initialDifficulty != null) {
      _selectedDifficulty = widget.initialDifficulty!;
    }
    if (widget.initialNumQuestions != null) {
      _numQuestions = widget.initialNumQuestions!;
    }
  }

  Future<void> _pickPDFFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb, // Get file bytes for web
      );
      
      if (result != null) {
        setState(() {
          if (kIsWeb) {
            // For web, store the bytes and filename
            _selectedPDFFile = {
              'bytes': result.files.single.bytes!,
              'name': result.files.single.name
            };
            _selectedFileName = result.files.single.name;
          } else {
            // For native platforms, store the File
            _selectedPDFFile = File(result.files.single.path!);
            _selectedFileName = result.files.single.name;
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking PDF file: $e';
      });
    }
  }

  Future<void> _generateQuiz() async {
    if (_selectedPDFFile == null) {
      setState(() => _error = 'Please select a PDF file');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _quizData = null;
      _showResults = false;
    });

    try {
      final quiz = await _quizService.generateQuizFromPDF(
        _selectedPDFFile,
        numQuestions: _numQuestions,
        difficulty: _selectedDifficulty,
      );
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
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _finishQuiz() {
    _stopwatch.stop();
    setState(() {
      _showResults = true;
    });
    _saveQuizResult();
  }

  Future<void> _saveQuizResult() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _quizData != null) {
        await _quizService.saveURLQuizResult(
          userId: user.uid,
          quizData: _quizData!,
          userAnswers: _userAnswers,
          score: _calculateScore(),
          timeTaken: _stopwatch.elapsed,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving result: $e')),
        );
      }
    }
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < _userAnswers.length; i++) {
      if (_userAnswers[i] != -1) {
        final question = _quizData!['questions'][i];
        final correctAnswerLetter = question['right_option'];
        final correctAnswerIndex = correctAnswerLetter.codeUnitAt(0) - 'a'.codeUnitAt(0);
        if (_userAnswers[i] == correctAnswerIndex) {
          score++;
        }
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Quiz Generator'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _quizData == null
            ? _buildQuizGenerationForm()
            : _showResults
                ? _buildResultsView()
                : _buildQuizView(),
      ),
    );
  }

  Widget _buildQuizGenerationForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generate Quiz from PDF',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // PDF File Selection
                  ElevatedButton.icon(
                    onPressed: _pickPDFFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select PDF File'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFileName!,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _selectedPDFFile = null;
                                _selectedFileName = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Difficulty Selection
                  const Text(
                    'Difficulty:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    value: _selectedDifficulty,
                    items: _difficultyLevels.map((String difficulty) {
                      return DropdownMenuItem<String>(
                        value: difficulty,
                        child: Text(
                          difficulty[0].toUpperCase() + difficulty.substring(1),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedDifficulty = newValue;
                        });
                      }
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Number of Questions
                  const Text(
                    'Number of Questions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _numQuestions.toDouble(),
                          min: 1,
                          max: 20,
                          divisions: 19,
                          label: _numQuestions.toString(),
                          onChanged: (double value) {
                            setState(() {
                              _numQuestions = value.round();
                            });
                          },
                        ),
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          _numQuestions.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _generateQuiz,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Generate Quiz'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizView() {
    final questions = _quizData!['questions'] as List;
    final currentQuestion = questions[_currentQuestionIndex];
    final options = currentQuestion['options'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quiz Info
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _quizData!['topic'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_quizData!['category']} > ${_quizData!['subcategory']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / questions.length,
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 4),
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Question
        Expanded(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentQuestion['question'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        return RadioListTile<int>(
                          title: Text(options[index]),
                          value: index,
                          groupValue: _userAnswers[_currentQuestionIndex],
                          onChanged: (value) {
                            if (value != null) {
                              _selectAnswer(value);
                            }
                          },
                          activeColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Navigation Buttons
        Row(
          children: [
            if (_currentQuestionIndex > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousQuestion,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Previous'),
                ),
              ),
            if (_currentQuestionIndex > 0) const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _userAnswers[_currentQuestionIndex] == -1 ? null : _nextQuestion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _currentQuestionIndex < questions.length - 1 ? 'Next' : 'Finish',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    final score = _calculateScore();
    final totalQuestions = _quizData!['questions'].length;
    final percentage = (score / totalQuestions) * 100;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Quiz Results',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: percentage >= 70
                          ? Colors.green.shade100
                          : percentage >= 40
                              ? Colors.orange.shade100
                              : Colors.red.shade100,
                    ),
                    child: Text(
                      '$score/$totalQuestions',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: percentage >= 70
                            ? Colors.green.shade800
                            : percentage >= 40
                                ? Colors.orange.shade800
                                : Colors.red.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    percentage >= 70
                        ? 'Excellent!'
                        : percentage >= 40
                            ? 'Good effort!'
                            : 'Keep practicing!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Time: ${(_stopwatch.elapsed.inMinutes).toString().padLeft(2, '0')}:${(_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Back to Home'),
          ),
          
          const SizedBox(height: 16),
          
          OutlinedButton(
            onPressed: () {
              setState(() {
                _quizData = null;
                _selectedPDFFile = null;
                _selectedFileName = null;
                _error = null;
                _showResults = false;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Create Another Quiz'),
          ),
        ],
      ),
    );
  }
} 