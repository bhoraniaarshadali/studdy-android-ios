import 'package:flutter/material.dart';
import '../../models/question_model.dart';

class StudentResponseScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final List<QuestionModel> questions;

  const StudentResponseScreen({
    super.key,
    required this.result,
    required this.questions,
  });

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, ${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = result['score'] ?? 0;
    final total = result['total'] ?? 0;
    final percentage = total > 0 ? (score / total * 100).toInt() : 0;
    final enrollment = result['enrollment_number'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(enrollment, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Score: $score / $total', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProctoringCard(),
            _buildSummaryCard(enrollment, percentage, score, total),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.history_edu_outlined, color: Colors.blueAccent, size: 24),
                SizedBox(width: 8),
                Text(
                  'Response Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(questions.length, (i) => _buildQuestionReview(i)),
          ],
        ),
      ),
    );
  }

  Widget _buildProctoringCard() {
    final warnings = (result['warnings'] ?? 0) as int;
    final switches = (result['app_switches'] ?? 0) as int;
    final total = warnings + switches;

    print('PROCTOR_DETAIL: ${result['enrollment_number']} - warnings: $warnings, switches: $switches, risk: ${total == 0 ? 'Clean' : total <= 2 ? 'Suspicious' : 'High Risk'}');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: total == 0 ? Colors.green.shade50 : 
               total <= 2 ? Colors.orange.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: total == 0 ? Colors.green.shade200 :
                 total <= 2 ? Colors.orange.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                total == 0 ? Icons.verified_user :
                total <= 2 ? Icons.warning_amber : Icons.gpp_bad,
                color: total == 0 ? Colors.green :
                       total <= 2 ? Colors.orange : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Proctoring Report',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: total == 0 ? Colors.green :
                         total <= 2 ? Colors.orange : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  total == 0 ? 'Clean' :
                  total <= 2 ? 'Suspicious' : 'High Risk',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(height: 4),
                      Text('$warnings', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('Warnings', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.swap_horiz, color: Colors.blue, size: 20),
                      const SizedBox(height: 4),
                      Text('$switches', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('App Switches', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.assessment, color: Colors.purple, size: 20),
                      const SizedBox(height: 4),
                      Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('Total Events', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Warning progress bar
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Risk level:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (total / 6).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      total == 0 ? Colors.green :
                      total <= 2 ? Colors.orange : Colors.red,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String enrollment, int percentage, int score, int total) {
    final passed = percentage >= 60;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              enrollment,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Submitted on: ${_formatDateTime(result['created_at'])}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildStatBox('Score', '$score / $total', Colors.blueAccent),
                _buildStatDivider(),
                _buildStatBox('Percentage', '$percentage%', Colors.black87),
                _buildStatDivider(),
                _buildStatBox('Status', passed ? 'Passed' : 'Failed', passed ? Colors.green : Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.shade200);
  }

  Widget _buildQuestionReview(int i) {
    final q = questions[i];
    final answersList = List<dynamic>.from(result['answers'] ?? []);
    final int? studentAnswer = i < answersList.length ? answersList[i] : null;
    final isCorrect = studentAnswer == q.correctIndex;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${i + 1}',
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Spacer(),
                if (studentAnswer == null)
                  const Text('No Answer', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))
                else if (isCorrect)
                  const Text('Answered Correctly', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
                else
                  const Text('Answered Incorrectly', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              q.questionText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            ...List.generate(q.options.length, (j) => _buildOptionView(q, j, studentAnswer)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionView(QuestionModel q, int j, int? studentAnswer) {
    final isCorrectOption = j == q.correctIndex;
    final isStudentChoice = j == studentAnswer;
    
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    String? badgeText;
    Color badgeColor = Colors.grey;

    if (isCorrectOption && isStudentChoice) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green;
      badgeText = 'CORRECT';
      badgeColor = Colors.green;
    } else if (isStudentChoice && !isCorrectOption) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red;
      badgeText = 'WRONG';
      badgeColor = Colors.red;
    } else if (isCorrectOption) {
      borderColor = Colors.green;
      badgeText = 'CORRECT ANSWER';
      badgeColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isCorrectOption || isStudentChoice ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isStudentChoice ? (isCorrectOption ? Colors.green : Colors.red) : Colors.grey.shade100,
            ),
            child: Center(
              child: Text(
                String.fromCharCode(65 + j),
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: isStudentChoice ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              q.options[j],
              style: TextStyle(
                color: isStudentChoice ? Colors.black87 : Colors.black54,
                fontWeight: isStudentChoice ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (badgeText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }
}
