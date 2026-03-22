import 'package:flutter/material.dart';
import '../../models/question_model.dart';
import '../../services/supabase_service.dart';
import '../auth/login_screen.dart';

class StudentExamScreen extends StatefulWidget {
  final List<QuestionModel> questions;
  final String examCode;
  final String studentName;

  const StudentExamScreen({
    super.key,
    required this.questions,
    required this.examCode,
    required this.studentName,
  });

  @override
  State<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends State<StudentExamScreen> {
  int _currentQuestion = 0;
  late List<int?> _selectedAnswers;
  bool _isSubmitting = false;
  bool _examSubmitted = false;
  int _score = 0;
  bool _resultsPublished = false;
  bool _isCheckingResults = false;

  @override
  void initState() {
    super.initState();
    _selectedAnswers = List.filled(widget.questions.length, null);
    debugPrint('EXAM: Started for ${widget.studentName}, questions: ${widget.questions.length}');
    debugPrint('EXAM: Question ${_currentQuestion + 1} viewed');
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_selectedAnswers[i] == widget.questions[i].correctIndex) {
        score++;
      }
    }
    return score;
  }

  Future<void> _submitExam() async {
    setState(() => _isSubmitting = true);
    final score = _calculateScore();
    final percentage = (score / widget.questions.length * 100).toInt();
    
    try {
      await SupabaseService.saveResult(
        examCode: widget.examCode,
        studentName: widget.studentName,
        score: score,
        total: widget.questions.length,
        answers: _selectedAnswers,
        instantMode: true,
      );
      
      debugPrint('EXAM: Submitted, score: $score / ${widget.questions.length}');
      debugPrint('RESULT: Score: $score/${widget.questions.length} = $percentage%');
      
      final isPublished = await SupabaseService.checkResultsPublished(widget.examCode);
      
      setState(() {
        _score = score;
        _examSubmitted = true;
        _resultsPublished = isPublished;
      });
    } catch (e) {
      debugPrint('EXAM: Submit ERROR - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting exam: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _checkResults() async {
    setState(() => _isCheckingResults = true);
    try {
      final isPublished = await SupabaseService.checkResultsPublished(widget.examCode);
      debugPrint('CHECK: Results published: $isPublished');
      if (isPublished) {
        setState(() => _resultsPublished = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Results not published yet. Check back later.')),
          );
        }
      }
    } catch (e) {
      debugPrint('CHECK: ERROR - $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingResults = false);
      }
    }
  }

  void _showSubmitDialog() {
    final answeredCount = _selectedAnswers.where((a) => a != null).length;
    debugPrint('EXAM: Submit dialog shown, answered: $answeredCount/${widget.questions.length}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: Text('You have answered $answeredCount out of ${widget.questions.length} questions. Are you sure you want to submit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Exam'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isSubmitting 
          ? _buildSubmittingState()
          : (!_examSubmitted ? _buildExamInProgress() : _buildPostSubmissionView()),
    );
  }

  Widget _buildSubmittingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Submitting...', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExamInProgress() {
    final q = widget.questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / widget.questions.length;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, ${widget.studentName}',
            style: const TextStyle(fontSize: 14, color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestion + 1} of ${widget.questions.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Q${_currentQuestion + 1}',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 32),
          Text(
            q.questionText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: q.options.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedAnswers[_currentQuestion] == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAnswers[_currentQuestion] = index);
                    debugPrint('EXAM: Q${_currentQuestion + 1} answered: $index');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blueAccent.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.blueAccent : Colors.grey.shade100,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            q.options[index],
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected ? Colors.blueAccent : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildStepNavigation(),
        ],
      ),
    );
  }

  Widget _buildStepNavigation() {
    final isLast = _currentQuestion == widget.questions.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentQuestion > 0 ? () {
              setState(() => _currentQuestion--);
              debugPrint('EXAM: Previous tapped, now on Q$_currentQuestion');
            } : null,
            icon: const Icon(Icons.arrow_back_ios),
            color: Colors.blueAccent,
          ),
          Text(
            '${_currentQuestion + 1} / ${widget.questions.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          isLast 
          ? ElevatedButton(
              onPressed: _showSubmitDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : IconButton(
              onPressed: () {
                setState(() => _currentQuestion++);
                debugPrint('EXAM: Next tapped, now on Q$_currentQuestion');
              },
              icon: const Icon(Icons.arrow_forward_ios),
              color: Colors.blueAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildPostSubmissionView() {
    if (!_resultsPublished) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 100, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Exam Submitted!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your teacher will publish results soon',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Text(
                'Come back later to see your score',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCheckingResults ? null : _checkResults,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCheckingResults 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Check Results', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Back to Home', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }

    // Results ARE published
    final percentage = (_score / widget.questions.length * 100).round();
    Color scoreColor = Colors.green;
    if (percentage < 40) scoreColor = Colors.red;
    else if (percentage < 60) scoreColor = Colors.orange;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scoreColor, width: 8),
            ),
            child: Column(
              children: [
                Text(
                  '$percentage%',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: scoreColor),
                ),
                Text(
                  '$_score / ${widget.questions.length}',
                  style: TextStyle(fontSize: 18, color: scoreColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSimpleStat('Correct', _score.toString(), Colors.green),
              _buildSimpleStat('Wrong', (widget.questions.length - _score).toString(), Colors.red),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Answer Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          ...List.generate(widget.questions.length, (index) {
            final q = widget.questions[index];
            final selected = _selectedAnswers[index];
            final isCorrect = selected == q.correctIndex;
            return _buildReviewCard(q, selected, isCorrect, index);
          }),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildReviewCard(QuestionModel q, int? selected, bool isCorrect, int index) {
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
              children: [
                Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? Colors.green : Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(q.questionText, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            _buildReviewOption('Your: ${selected != null ? q.options[selected] : 'Not answered'}', isCorrect ? Colors.green : Colors.red),
            if (!isCorrect) 
              _buildReviewOption('Correct: ${q.options[q.correctIndex]}', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewOption(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13)),
    );
  }
}
