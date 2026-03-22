import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_scan_screen.dart';
import '../../services/supabase_service.dart';
import 'exam_screen.dart';
import '../auth/login_screen.dart';
import 'my_results_screen.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String enrollmentNumber;
  final bool isNew;
  final String? pendingExamCode;
  final Map<String, dynamic>? pendingTimerData;

  const StudentDashboardScreen({
    super.key,
    required this.enrollmentNumber,
    this.isNew = false,
    this.pendingExamCode,
    this.pendingTimerData,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  List<Map<String, dynamic>> _myResults = [];
  List<Map<String, dynamic>> _upcomingExams = [];
  bool _isLoading = true;
  Map<String, dynamic>? _studentData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        SupabaseService.getStudentByEnrollment(widget.enrollmentNumber),
        SupabaseService.getStudentResults(widget.enrollmentNumber),
        SupabaseService.getAllActiveExams(),
      ]);

      final studentData = responses[0] as Map<String, dynamic>?;
      final results = (responses[1] as List).cast<Map<String, dynamic>>();
      final allExams = (responses[2] as List).cast<Map<String, dynamic>>();

      // Mark which exams are already submitted
      final submittedExamCodes = results.map((r) => r['exam_code'] as String).toSet();
      
      final upcoming = allExams.map((exam) {
        final bool isSubmitted = submittedExamCodes.contains(exam['code']);
        return {
          ...exam,
          'is_submitted': isSubmitted,
        };
      }).toList();

      setState(() {
        _studentData = studentData;
        _myResults = results;
        _upcomingExams = upcoming;
        _isLoading = false;
        _errorMessage = null;
      });
      print('STUDENT_DASH: Loaded - results: ${_myResults.length}, total_exams: ${_upcomingExams.length}');
      _myResults.forEach((r) => print('DASH_RESULT: exam_code="${r['exam_code']}"'));
    } catch (e) {
      print('STUDENT_DASH: ERROR - $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinExam(String examCode, {Map<String, dynamic>? timerData}) async {
    // Check submitted FIRST before anything else
    final alreadySubmitted = _myResults.any(
      (r) => r['exam_code'].toString().trim().toUpperCase() == examCode.trim().toUpperCase()
    );
    
    print('STUDENT_DASH: Checking submitted for $examCode: $alreadySubmitted');
    print('STUDENT_DASH: My result codes: ${_myResults.map((r) => r['exam_code']).toList()}');
    print('JOIN_CHECK: comparing "$examCode" with result codes');
    _myResults.forEach((r) => print('JOIN_CHECK: result code="${r['exam_code']}" match=${r['exam_code'].toString().trim() == examCode.trim()}'));
    
    if (alreadySubmitted) {
      print('STUDENT_DASH: BLOCKED - exam already submitted: $examCode');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already submitted this exam.'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }

    final examData = _upcomingExams.firstWhere((e) => e['code'] == examCode);
    final validation = timerData ?? SupabaseService.validateExamWindow(examData);

    if (validation['valid'] == false) {
      final reason = validation['reason'];
      if (reason == 'not_started') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This exam hasn\'t started yet.')));
        return;
      } else if (reason == 'expired') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This exam has expired.')));
        return;
      }
    }

    debugPrint('STUDENT_DASH: Joining exam: $examCode');
    setState(() => _isLoading = true);
    try {
      final questions = await SupabaseService.getExamByCode(examCode);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentExamScreen(
              questions: questions,
              examCode: examCode,
              enrollmentNumber: widget.enrollmentNumber,
              timerData: validation,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('STUDENT_DASH: ERROR joining exam - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining exam: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getExamStatus(Map<String, dynamic> exam) {
    if (exam['is_submitted'] == true) return 'submitted';
    
    if (exam['timer_mode'] == 'window') {
      final now = DateTime.now().toUtc();
      final start = DateTime.parse(exam['window_start']).toUtc();
      final end = DateTime.parse(exam['window_end']).toUtc();
      
      if (now.isBefore(start)) return 'not_started';
      if (now.isAfter(end)) return 'expired';
    }
    
    return 'available';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _studentData?['name'] != null ? 'Welcome, ${_studentData!['name']}' : 'My Dashboard',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              widget.enrollmentNumber,
              style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('student_enrollment');
              print('LOGOUT: Enrollment removed, exiting dashboard');
              
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _isLoading 
          ? const AppLoadingWidget(message: 'Loading your dashboard...')
          : _errorMessage != null
              ? AppErrorWidget(message: _errorMessage!, onRetry: _loadData)
              : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isNew) _buildWelcomeBanner() else _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildResultsCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'Upcoming Exams', 
                    Icons.calendar_today_outlined,
                    onScan: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QRScanScreen()),
                      );
                      if (result != null && result is String) {
                        _joinExam(result);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildUpcomingSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildResultsCard() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyResultsScreen(enrollmentNumber: widget.enrollmentNumber),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Results',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_myResults.length} exams completed',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _studentData?['name'] != null ? 'Welcome, ${_studentData!['name']}!' : 'Welcome to Studdy!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 8),
          Text(
            'Your enrollment number is: ${widget.enrollmentNumber}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            'Keep this safe — you\'ll need it to access your results',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final nonSubmittedCount = _upcomingExams.where((e) => e['is_submitted'] != true).length;
    return Row(
      children: [
        Expanded(child: _buildStatCard('Exams Given', _myResults.length.toString(), Colors.blueAccent)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Upcoming', nonSubmittedCount.toString(), Colors.orange)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {VoidCallback? onScan}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Spacer(),
        if (onScan != null && !kIsWeb)
          IconButton(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
            tooltip: 'Scan QR Code',
          ),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    if (_upcomingExams.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No upcoming exams right now', style: TextStyle(color: Colors.grey))),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _upcomingExams.length,
      itemBuilder: (context, index) {
        final exam = _upcomingExams[index];
        final status = _getExamStatus(exam);
        
        print('DASH: Exam ${exam['code']} status: $status');

        double opacity = 1.0;
        if (status == 'submitted') opacity = 0.7;
        if (status == 'expired') opacity = 0.6;

        return Opacity(
          opacity: opacity,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exam['title'] ?? 'Untitled Exam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(exam['code'], style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            if (status == 'not_started') ...[
                              const Icon(Icons.schedule, size: 14, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                'Starts: ${DateTime.parse(exam['window_start']).toLocal().toString().substring(0, 16)}',
                                style: const TextStyle(fontSize: 11, color: Colors.orange),
                              ),
                            ] else if (status == 'expired') ...[
                              const Icon(Icons.timer_off, size: 14, color: Colors.red),
                              const SizedBox(width: 4),
                              const Text('Exam Expired', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                            ] else ...[
                              Text(exam['created_at'].toString().substring(0, 10), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ],
                        ),
                        if (status == 'expired') ...[
                          const SizedBox(height: 4),
                          const Text('This exam can no longer be attempted', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusButton(exam, status),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusButton(Map<String, dynamic> exam, String status) {
    if (status == 'submitted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.grey, size: 16),
            SizedBox(width: 4),
            Text('Submitted', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }
    
    if (status == 'expired') {
      return const SizedBox();
    }
    
    if (status == 'not_started') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text('Not Started', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
      );
    }

    return ElevatedButton(
      onPressed: () {
        print('STUDENT_DASH: Starting exam ${exam['code']}');
        final validation = SupabaseService.validateExamWindow(exam);
        _joinExam(exam['code'], timerData: validation);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: const Text('Start Exam'),
    );
  }


}
