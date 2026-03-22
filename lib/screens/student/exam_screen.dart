import 'package:flutter/material.dart';
import '../../models/question_model.dart';

class StudentExamScreen extends StatefulWidget {
  const StudentExamScreen({super.key});

  @override
  State<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends State<StudentExamScreen> {
  int _currentQuestionIndex = 0;
  List<int?> _selectedAnswers = [];
  bool _examSubmitted = false;
  List<QuestionModel> _questions = [];

  @override
  void initState() {
    super.initState();
    _questions = [
      QuestionModel(
        id: '1',
        questionText: 'What is Flutter?',
        options: [
          'A Java framework',
          'A Google UI toolkit',
          'A database',
          'An iOS only framework'
        ],
        correctIndex: 1,
      ),
      QuestionModel(
        id: '2',
        questionText: 'Which language does Flutter use?',
        options: ['Java', 'Swift', 'Dart', 'Kotlin'],
        correctIndex: 2,
      ),
      QuestionModel(
        id: '3',
        questionText: 'What is a Widget in Flutter?',
        options: [
          'A database table',
          'A network call',
          'Building block of UI',
          'A test file'
        ],
        correctIndex: 2,
      ),
    ];
    _selectedAnswers = List.filled(_questions.length, null);
  }

  int get _score {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctIndex) {
        score++;
      }
    }
    return score;
  }

  void _submitExam() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: const Text('Are you sure you want to submit your answers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _examSubmitted = true);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_examSubmitted) {
      return _buildResultScreen();
    }
    return _buildExamScreen();
  }

  Widget _buildExamScreen() {
    final q = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                '10:00',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.questionText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(q.options.length, (index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedAnswers[_currentQuestionIndex] == index
                                ? Colors.blueAccent
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          color: _selectedAnswers[_currentQuestionIndex] == index
                              ? Colors.blueAccent.withOpacity(0.05)
                              : Colors.transparent,
                        ),
                        child: RadioListTile<int>(
                          title: Text(q.options[index]),
                          value: index,
                          groupValue: _selectedAnswers[_currentQuestionIndex],
                          onChanged: (val) {
                            setState(() {
                              _selectedAnswers[_currentQuestionIndex] = val;
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentQuestionIndex > 0
                      ? () => setState(() => _currentQuestionIndex--)
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Previous'),
                ),
                if (_currentQuestionIndex == _questions.length - 1)
                  ElevatedButton(
                    onPressed: _submitExam,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Submit'),
                  )
                else
                  ElevatedButton(
                    onPressed: _currentQuestionIndex < _questions.length - 1
                        ? () => setState(() => _currentQuestionIndex++)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Next'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final score = _score;
    final total = _questions.length;
    final wrong = total - score;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent, width: 8),
                ),
                child: Center(
                  child: Text(
                    '$score/$total',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreStat('Correct', score.toString(), Colors.green),
                _buildScoreStat('Wrong', wrong.toString(), Colors.red),
              ],
            ),
            const SizedBox(height: 40),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Review Answers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(total, (index) {
              final q = _questions[index];
              final selected = _selectedAnswers[index];
              final isCorrect = selected == q.correctIndex;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(q.questionText),
                      const SizedBox(height: 8),
                      Text(
                        'Your Answer: ${selected != null ? q.options[selected] : 'Not answered'}',
                        style: TextStyle(
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                      if (!isCorrect)
                        Text(
                          'Correct Answer: ${q.options[q.correctIndex]}',
                          style: const TextStyle(color: Colors.green),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back to Home'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }
}
