import 'package:flutter/material.dart';
import '../../models/question_model.dart';

class ReviewQuestionsScreen extends StatefulWidget {
  final List<QuestionModel> questions;

  const ReviewQuestionsScreen({super.key, required this.questions});

  @override
  State<ReviewQuestionsScreen> createState() => _ReviewQuestionsScreenState();
}

class _ReviewQuestionsScreenState extends State<ReviewQuestionsScreen> {
  late List<QuestionModel> _questions;
  int? _editingIndex;
  
  // Controllers for editing
  final TextEditingController _editQuestionController = TextEditingController();
  final List<TextEditingController> _editOptionControllers = [];
  int _editCorrectIndex = 0;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.questions);
    debugPrint('REVIEW: Screen opened with ${_questions.length} questions');
  }

  @override
  void dispose() {
    _editQuestionController.dispose();
    for (var controller in _editOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startEditing(int index) {
    debugPrint('REVIEW: Edit mode ON for Q${index + 1}');
    setState(() {
      _editingIndex = index;
      _editQuestionController.text = _questions[index].questionText;
      _editCorrectIndex = _questions[index].correctIndex;
      
      // Clear and re-initialize option controllers
      for (var controller in _editOptionControllers) {
        controller.dispose();
      }
      _editOptionControllers.clear();
      for (var option in _questions[index].options) {
        _editOptionControllers.add(TextEditingController(text: option));
      }
    });
  }

  void _saveEdit(int index) {
    if (_editQuestionController.text.trim().isEmpty) return;
    for (var controller in _editOptionControllers) {
      if (controller.text.trim().isEmpty) return;
    }

    setState(() {
      _questions[index] = QuestionModel(
        id: _questions[index].id,
        questionText: _editQuestionController.text.trim(),
        options: _editOptionControllers.map((c) => c.text.trim()).toList(),
        correctIndex: _editCorrectIndex,
      );
      _editingIndex = null;
    });
    debugPrint('REVIEW: Q${index + 1} saved with new text');
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
    });
  }

  void _showDeleteDialog(int index) {
    debugPrint('REVIEW: Delete dialog shown for Q${index + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('Are you sure you want to delete this question? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _questions.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Question deleted')),
              );
              debugPrint('DELETE: Question ${index + 1} deleted');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddQuestionSheet() {
    final int optionCount = _questions.isNotEmpty ? _questions[0].options.length : 4;
    final TextEditingController newQuestionController = TextEditingController();
    final List<TextEditingController> newOptionControllers = List.generate(
      optionCount, 
      (index) => TextEditingController()
    );
    int newCorrectIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Question Manually',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: newQuestionController,
                  decoration: const InputDecoration(
                    labelText: 'Question Text',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ...List.generate(optionCount, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: newCorrectIndex,
                          onChanged: (val) => setSheetState(() => newCorrectIndex = val!),
                        ),
                        Expanded(
                          child: TextField(
                            controller: newOptionControllers[i],
                            decoration: InputDecoration(
                              labelText: 'Option ${String.fromCharCode(65 + i)}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (newQuestionController.text.trim().isEmpty) return;
                    for (var c in newOptionControllers) {
                      if (c.text.trim().isEmpty) return;
                    }

                    setState(() {
                      _questions.add(QuestionModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        questionText: newQuestionController.text.trim(),
                        options: newOptionControllers.map((c) => c.text.trim()).toList(),
                        correctIndex: newCorrectIndex,
                      ));
                    });
                    Navigator.pop(context);
                    debugPrint('MANUAL_ADD: New question added, total: ${_questions.length}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add Question'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Questions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _questions),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('REVIEW: Done tapped, returning ${_questions.length} questions');
              Navigator.pop(context, _questions);
            },
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questions.length + 1,
        itemBuilder: (context, index) {
          if (index == _questions.length) {
            return _buildAddManualButton();
          }

          final q = _questions[index];
          final bool isEditing = _editingIndex == index;

          return Card(
            key: ValueKey(q.id),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isEditing ? Colors.blueAccent : Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isEditing ? _buildEditMode(index) : _buildViewMode(index, q),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewMode(int index, QuestionModel q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Q${index + 1}',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
              onPressed: () => _startEditing(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
              onPressed: () => _showDeleteDialog(index),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          q.questionText,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...List.generate(q.options.length, (optIndex) {
          final bool isCorrect = optIndex == q.correctIndex;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCorrect ? Colors.green : Colors.grey.shade200,
              ),
            ),
            child: Text(
              '${String.fromCharCode(65 + optIndex)}. ${q.options[optIndex]}',
              style: TextStyle(
                color: isCorrect ? Colors.green.shade800 : Colors.black87,
                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEditMode(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Edit Question', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        const SizedBox(height: 12),
        TextField(
          controller: _editQuestionController,
          decoration: const InputDecoration(
            labelText: 'Question Text',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        ...List.generate(_editOptionControllers.length, (optIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Radio<int>(
                  value: optIndex,
                  groupValue: _editCorrectIndex,
                  onChanged: (val) => setState(() => _editCorrectIndex = val!),
                ),
                Expanded(
                  child: TextField(
                    controller: _editOptionControllers[optIndex],
                    decoration: InputDecoration(
                      labelText: 'Option ${String.fromCharCode(65 + optIndex)}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _saveEdit(index),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddManualButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: OutlinedButton.icon(
        onPressed: _showAddQuestionSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Question Manually'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
