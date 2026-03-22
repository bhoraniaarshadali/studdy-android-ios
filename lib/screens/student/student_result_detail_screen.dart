import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/question_model.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

class StudentResultDetailScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final String examTitle;

  const StudentResultDetailScreen({
    super.key,
    required this.result,
    required this.examTitle,
  });

  @override
  State<StudentResultDetailScreen> createState() => _StudentResultDetailScreenState();
}

class _StudentResultDetailScreenState extends State<StudentResultDetailScreen> {
  List<QuestionModel> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExamQuestions();
  }

  Future<void> _loadExamQuestions() async {
    try {
      final exam = await Supabase.instance.client
          .from('exams')
          .select()
          .eq('code', widget.result['exam_code'])
          .single();

      final questionsRaw = exam['questions'] as List;
      setState(() {
        _questions = questionsRaw.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList();
        _isLoading = false;
        _errorMessage = null;
      });
      print('RESULT_DETAIL: Loaded ${_questions.length} questions');
    } catch (e) {
      print('RESULT_DETAIL: Error loading questions - $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int score = widget.result['score'] ?? 0;
    final int total = widget.result['total'] ?? 0;
    final int percentage = total > 0 ? (score / total * 100).round() : 0;
    
    Color statusColor = Colors.red;
    if (percentage >= 60) statusColor = Colors.green;
    else if (percentage >= 40) statusColor = Colors.orange;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.examTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const AppLoadingWidget(message: 'Loading details...')
          : _errorMessage != null
              ? AppErrorWidget(message: _errorMessage!, onRetry: _loadExamQuestions)
              : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(score, total, percentage, statusColor),
                  const SizedBox(height: 24),
                  const Text(
                    'Your Answers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  _buildAnswersList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(int score, int total, int percentage, Color statusColor) {
    final String status = percentage >= 60 ? 'Passed' : 'Failed';
    final String date = widget.result['created_at'].toString().substring(0, 10);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withOpacity(0.1),
                border: Border.all(color: statusColor.withOpacity(0.2), width: 8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$score / $total',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildStatItem('Score', '$score/$total', Colors.blue)),
                Expanded(child: _buildStatItem('Percentage', '$percentage%', statusColor)),
                Expanded(child: _buildStatItem('Status', status, statusColor)),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Submitted on: $date', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildAnswersList() {
    final answers = List<dynamic>.from(widget.result['answers'] ?? []);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        final int? studentAnswer = answers.length > index ? (answers[index] as int?) : null;
        final bool isCorrect = studentAnswer == q.correctIndex;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
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
                    Text(
                      'Q${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        q.questionText,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(q.options.length, (j) {
                  final bool isStudentChoice = studentAnswer == j;
                  final bool isCorrectChoice = q.correctIndex == j;

                  Color bgColor = Colors.transparent;
                  Color borderColor = Colors.grey.shade200;
                  Widget? trainee;

                  if (isStudentChoice && isCorrectChoice) {
                    bgColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    trainee = const Icon(Icons.check_circle, color: Colors.green, size: 18);
                  } else if (isStudentChoice && !isCorrectChoice) {
                    bgColor = Colors.red.shade50;
                    borderColor = Colors.red;
                    trainee = const Icon(Icons.cancel, color: Colors.red, size: 18);
                  } else if (isCorrectChoice) {
                    borderColor = Colors.green;
                    trainee = const Icon(Icons.check_circle_outline, color: Colors.green, size: 18);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            q.options[j],
                            style: TextStyle(
                              color: isStudentChoice || isCorrectChoice ? Colors.black87 : Colors.grey.shade700,
                              fontWeight: isStudentChoice || isCorrectChoice ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (trainee != null) trainee,
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                if (studentAnswer == null)
                  const Text('Not answered', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))
                else if (isCorrect)
                  const Text('Correct!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))
                else
                  Text(
                    'Wrong. Correct was: ${q.options[q.correctIndex]}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
