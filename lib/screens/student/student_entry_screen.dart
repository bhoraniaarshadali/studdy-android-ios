import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_dashboard_screen.dart';
import 'qr_scan_screen.dart';

class StudentEntryScreen extends StatefulWidget {
  final String? prefilledCode;

  const StudentEntryScreen({super.key, this.prefilledCode});

  @override
  State<StudentEntryScreen> createState() => _StudentEntryScreenState();
}

class _StudentEntryScreenState extends State<StudentEntryScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _enrollmentController = TextEditingController();
  bool _isLoading = false;
  int _step = 1; // 1 = code entry, 2 = enrollment entry
  Map<String, dynamic>? _examData;
  Map<String, dynamic>? _timerValidation;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCode != null) {
      _codeController.text = widget.prefilledCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyCode();
      });
    }
    print('ENTRY: Step 1 - Code entry');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _enrollmentController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    print('ENTRY: Verifying code: $code');

    try {
      final examData = await SupabaseService.getExamDetails(code);
      _examData = examData;

      // Timer window validation
      final timerValidation = SupabaseService.validateExamWindow(_examData!);
      
      if (timerValidation['valid'] == false) {
        final reason = timerValidation['reason'];
        
        if (reason == 'not_started' && mounted) {
          final startsAt = timerValidation['startsAt'] as DateTime;
          final local = startsAt.toLocal();
          final formatted = '${local.day}/${local.month}/${local.year} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
          
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(children: [Icon(Icons.schedule, color: Colors.orange), SizedBox(width: 8), Text('Not Started Yet')]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This exam has not started yet.'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text('Starts at: $formatted', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  ),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
          setState(() => _isLoading = false);
          print('TIMER: Exam not started yet, starts at: $startsAt');
          return;
        }
        
        if (reason == 'expired' && mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(children: [Icon(Icons.timer_off, color: Colors.red), SizedBox(width: 8), Text('Exam Expired')]),
              content: const Text('This exam window has expired. You can no longer take this exam.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
          setState(() => _isLoading = false);
          print('TIMER: Exam window expired');
          return;
        }
      }

      print('TIMER: Exam valid - proceeding to step 2');
      setState(() {
        _examData = examData;
        _timerValidation = timerValidation;
        _step = 2;
        _isLoading = false;
      });
      print('VERIFY: Exam found: ${_examData!['title']}');
      print('ENTRY: Step 2 - Enrollment entry for exam: ${_examData!['code']}');
    } catch (e) {
      debugPrint('ENTRY: Invalid code: $code - $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid exam code. Please check and try again.')),
        );
      }
    }
  }

  Future<void> _checkEnrollment() async {
    final enrollment = _enrollmentController.text.trim();
    if (enrollment.isEmpty || enrollment.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid enrollment number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    print('ENTRY: Checking enrollment: $enrollment');

    try {
      final result = await SupabaseService.checkOrCreateStudent(enrollment);
      final bool isNew = result['isNew'];
      
      if (isNew) {
        print('ENTRY: New student, going to dashboard');
        await _navigateToDashboard(enrollment, true);
      } else {
        print('ENTRY: Existing student');
        // Check if student already gave this exam
        final results = await SupabaseService.getStudentResults(enrollment);
        final bool alreadyGaveExam = results.any((r) => r['exam_code'] == _codeController.text.trim().toUpperCase());
        
        if (alreadyGaveExam) {
          print('ENTRY: Exam already submitted, going to dashboard directly');
          if (mounted) {
            // Persist enrollment number
            final SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('student_enrollment', enrollment.trim());
            
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(
                builder: (_) => StudentDashboardScreen(
                  enrollmentNumber: enrollment.trim(),
                  isNew: false,
                  pendingExamCode: null,
                ),
              ),
            );
          }
          return;
        } else {
          await _navigateToDashboard(enrollment, false);
        }
      }
    } catch (e) {
      debugPrint('ENTRY: Enrollment ERROR - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToDashboard(String enrollment, bool isNew) async {
    if (mounted) {
      // Persist enrollment number
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_enrollment', enrollment.trim());

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => StudentDashboardScreen(
            enrollmentNumber: enrollment.trim(),
            pendingExamCode: null,
            pendingTimerData: null,
            isNew: isNew,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_step == 1 ? "Join Exam" : "Enter Enrollment"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: _step == 2 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 1),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: SingleChildScrollView(
          key: ValueKey<int>(_step),
          padding: const EdgeInsets.all(24.0),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.qr_code_scanner_rounded, size: 80, color: Colors.blueAccent),
        const SizedBox(height: 24),
        const Text(
          'Enter Exam Code',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Get the code from your teacher',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 40),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exam Code', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  onChanged: (val) {
                    final upper = val.toUpperCase();
                    if (val != upper) {
                      _codeController.value = _codeController.value.copyWith(
                        text: upper,
                        selection: TextSelection.collapsed(offset: upper.length),
                      );
                    }
                  },
                  style: const TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 8,
                    color: Colors.blueAccent,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'ABC123',
                    hintStyle: TextStyle(letterSpacing: 8, color: Colors.grey.shade300),
                    prefixIcon: const Icon(Icons.key_rounded, color: Colors.blueAccent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Verify Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("OR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QRScanScreen()),
              );
              if (result != null && result is String) {
                _codeController.text = result;
                _verifyCode();
              }
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.blueAccent),
              foregroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.green, width: 1),
          ),
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _examData?['title'] ?? 'Untitled Exam',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Code: ${_examData?['code']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'Who are you?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your details to identify yourself',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 40),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enrollment Number', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: _enrollmentController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 2405112070013',
                    prefixIcon: const Icon(Icons.badge_outlined, color: Colors.blueAccent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _checkEnrollment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
