import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'exam_screen.dart';

class StudentJoinScreen extends StatefulWidget {
  final String? prefilledCode;
  final String? enrollmentNumber;

  const StudentJoinScreen({
    super.key,
    this.prefilledCode,
    this.enrollmentNumber,
  });

  @override
  State<StudentJoinScreen> createState() => _StudentJoinScreenState();
}

class _StudentJoinScreenState extends State<StudentJoinScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _enrollmentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCode != null) {
      _codeController.text = widget.prefilledCode!;
    }
    if (widget.enrollmentNumber != null) {
      _enrollmentController.text = widget.enrollmentNumber!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _enrollmentController.dispose();
    super.dispose();
  }

  Future<void> _joinExam() async {
    final enrollment = _enrollmentController.text.trim();
    final code = _codeController.text.trim().toUpperCase();

    if (enrollment.isEmpty || enrollment.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid enrollment number')),
      );
      return;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam code must be 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('JOIN: Enrollment: $enrollment, Code: $code');
      final questions = await SupabaseService.getExamByCode(code);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentExamScreen(
              questions: questions,
              examCode: code,
              enrollmentNumber: enrollment,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('JOIN: ERROR - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Join Exam'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school_outlined,
                size: 100,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Enter Exam Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask your teacher for the exam code',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enrollment Number',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _enrollmentController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. 2405112070013',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Exam Code',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: 'e.g. AB12CD',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _joinExam,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Join Exam',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
