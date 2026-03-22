import 'package:flutter/material.dart';
import '../../models/question_model.dart';
import '../../services/kie_ai_service.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final TextEditingController _contentController = TextEditingController();
  List<QuestionModel> _questions = [];
  bool _isLoading = false;
  int _questionCount = 5;
  int _optionCount = 4;
  String _difficulty = 'medium';

  Future<void> _generateQuestions() async {
    print('CreateExam: Generate button pressed');
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste some content first')),
      );
      return;
    }

    print('CreateExam: content length: ${_contentController.text.length}, questions: $_questionCount, options: $_optionCount, difficulty: $_difficulty');
    setState(() => _isLoading = true);

    try {
      final questions = await KieAiService.generateQuestions(
        content: _contentController.text.trim(),
        questionCount: _questionCount,
        optionCount: _optionCount,
        difficulty: _difficulty,
      );
      print('CreateExam: Questions received: ${questions.length}');
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      print('CreateExam: Error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Exam'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildContentInputCard(),
              const SizedBox(height: 16),
              _buildSettingsRow(),
              const SizedBox(height: 24),
              _buildGenerateButton(),
              if (_questions.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildQuestionsHeader(),
                const SizedBox(height: 16),
                _buildQuestionsList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentInputCard() {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste syllabus or topic content',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter text here...',
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown<int>(
            label: 'Questions',
            value: _questionCount,
            items: [3, 5, 10, 15],
            onChanged: (val) => setState(() => _questionCount = val!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown<int>(
            label: 'Options',
            value: _optionCount,
            items: [3, 4],
            onChanged: (val) => setState(() => _optionCount = val!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown<String>(
            label: 'Difficulty',
            value: _difficulty,
            items: ['easy', 'medium', 'hard'],
            onChanged: (val) => setState(() => _difficulty = val!),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(item.toString()),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generateQuestions,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Generate MCQs with AI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildQuestionsHeader() {
    return Text(
      'Generated Questions (${_questions.length})',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildQuestionsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Q${index + 1}: ${q.questionText}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit coming soon')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _questions.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(q.options.length, (optIndex) {
                  final isCorrect = optIndex == q.correctIndex;
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
            ),
          ),
        );
      },
    );
  }
}
