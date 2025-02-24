import 'package:flutter/material.dart';
import '../../models/question.dart';
import '../../services/quiz_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final QuizService _quizService = QuizService();
  List<Question> _questions = [];
  List<String> _categories = [];
  bool _isLoading = true;
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _quizService.getCategories();
      if (categories.isNotEmpty) {
        _selectedCategory = categories.first;
        final questions =
            await _quizService.getQuestionsByCategory(_selectedCategory!);
        setState(() {
          _categories = categories;
          _questions = questions;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    try {
      await _quizService.deleteQuestion(questionId);
      setState(() {
        _questions.removeWhere((q) => q.id == questionId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting question: $e')),
        );
      }
    }
  }

  void _showAddEditQuestionDialog([Question? question]) {
    showDialog(
      context: context,
      builder: (context) => QuestionFormDialog(
        question: question,
        categories: _categories,
        onSave: (newQuestion) async {
          try {
            if (question == null) {
              final id = await _quizService.addQuestion(newQuestion);
              setState(() {
                _questions.add(Question(
                  id: id,
                  text: newQuestion.text,
                  options: newQuestion.options,
                  correctOptionIndex: newQuestion.correctOptionIndex,
                  imageUrl: newQuestion.imageUrl,
                  explanation: newQuestion.explanation,
                  tags: newQuestion.tags,
                  category: newQuestion.category,
                  difficulty: newQuestion.difficulty,
                ));
              });
            } else {
              await _quizService.updateQuestion(newQuestion);
              setState(() {
                final index = _questions.indexWhere((q) => q.id == question.id);
                if (index != -1) {
                  _questions[index] = newQuestion;
                }
              });
            }
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    question == null
                        ? 'Question added successfully'
                        : 'Question updated successfully',
                  ),
                ),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving question: $e')),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Questions'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestionsTab(),
          _buildCategoriesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditQuestionDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuestionsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search questions...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // TODO: Implement search functionality
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedCategory,
                items: _categories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                    final questions =
                        await _quizService.getQuestionsByCategory(value);
                    setState(() => _questions = questions);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final question = _questions[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: ListTile(
                  title: Text(question.text),
                  subtitle: Text(
                    'Category: ${question.category} • Difficulty: ${question.difficulty}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showAddEditQuestionDialog(question),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteQuestion(question.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_categories[index]),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // TODO: Implement category deletion
            },
          ),
        );
      },
    );
  }
}

class QuestionFormDialog extends StatefulWidget {
  final Question? question;
  final List<String> categories;
  final Function(Question) onSave;

  const QuestionFormDialog({
    super.key,
    this.question,
    required this.categories,
    required this.onSave,
  });

  @override
  State<QuestionFormDialog> createState() => _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<QuestionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _textController;
  late TextEditingController _imageUrlController;
  late TextEditingController _explanationController;
  late TextEditingController _tagsController;
  late String _selectedCategory;
  late int _difficulty;
  List<TextEditingController> _optionControllers = [];
  int _correctOptionIndex = 0;

  @override
  void initState() {
    super.initState();
    final question = widget.question;
    _textController = TextEditingController(text: question?.text);
    _imageUrlController = TextEditingController(text: question?.imageUrl);
    _explanationController = TextEditingController(text: question?.explanation);
    _tagsController = TextEditingController(
      text: question?.tags.join(', '),
    );
    _selectedCategory = question?.category ?? widget.categories.first;
    _difficulty = question?.difficulty ?? 1;
    _correctOptionIndex = question?.correctOptionIndex ?? 0;

    _optionControllers = List.generate(
      4,
      (index) => TextEditingController(
        text: question != null && question.options.length > index
            ? question.options[index]
            : '',
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _imageUrlController.dispose();
    _explanationController.dispose();
    _tagsController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final question = Question(
      id: widget.question?.id ?? '',
      text: _textController.text,
      options: _optionControllers.map((c) => c.text).toList(),
      correctOptionIndex: _correctOptionIndex,
      imageUrl: _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
      explanation: _explanationController.text,
      tags: _tagsController.text.split(',').map((e) => e.trim()).toList(),
      category: _selectedCategory,
      difficulty: _difficulty,
    );

    widget.onSave(question);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'Add Question' : 'Edit Question'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Question Text',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter question text' : null,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ...List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Option ${index + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Please enter option text'
                              : null,
                        ),
                      ),
                      Radio<int>(
                        value: index,
                        groupValue: _correctOptionIndex,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _correctOptionIndex = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _explanationController,
                decoration: const InputDecoration(
                  labelText: 'Explanation',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter explanation' : null,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter at least one tag' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: widget.categories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _difficulty,
                items: [1, 2, 3]
                    .map((level) => DropdownMenuItem(
                          value: level,
                          child: Text('Difficulty: $level'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _difficulty = value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: const Text('Save'),
        ),
      ],
    );
  }
} 