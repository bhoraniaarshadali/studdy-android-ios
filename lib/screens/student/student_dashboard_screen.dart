import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/supabase_service.dart';
import 'exam_screen.dart';
import '../auth/login_screen.dart';
import 'student_result_detail_screen.dart';

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
      });
      print('STUDENT_DASH: Loaded - results: ${_myResults.length}, total_exams: ${_upcomingExams.length}');
      _myResults.forEach((r) => print('DASH_RESULT: exam_code="${r['exam_code']}"'));
    } catch (e) {
      print('STUDENT_DASH: ERROR - $e');
      if (mounted) {
        setState(() => _isLoading = false);
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
              timerData: timerData,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (_studentData != null)
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your dashboard...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isNew) _buildWelcomeBanner() else _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Upcoming Exams', Icons.calendar_today_outlined),
                  const SizedBox(height: 12),
                  _buildUpcomingSection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('My Results', Icons.emoji_events_outlined),
                  const SizedBox(height: 12),
                  _buildResultsSection(),
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
          const Text(
            'Welcome to Studdy!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    final nonSubmitted = _upcomingExams.where((e) => e['is_submitted'] != true).toList();
    
    if (nonSubmitted.isEmpty) {
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
      itemCount: nonSubmitted.length,
      itemBuilder: (context, index) {
        final exam = nonSubmitted[index];
        // At this point isSubmitted is always false because we filtered
        
        return Card(
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
                          Text(exam['created_at'].toString().substring(0, 10), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    print('STUDENT_DASH: Starting exam ${exam['code']}');
                    
                    // Validate window again before joining
                    final validation = SupabaseService.validateExamWindow(exam);
                    if (validation['valid'] == false) {
                      final reason = validation['reason'];
                      if (reason == 'not_started') {
                        final startsAt = validation['startsAt'] as DateTime;
                        final local = startsAt.toLocal();
                        final formatted = '${local.day}/${local.month}/${local.year} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
                        
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Row(children: [Icon(Icons.schedule, color: Colors.orange), SizedBox(width: 8), Text('Not Started')]),
                            content: Text('This exam has not started yet. Starts at: $formatted'),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                          ),
                        );
                        return;
                      } else if (reason == 'expired') {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Row(children: [Icon(Icons.timer_off, color: Colors.red), SizedBox(width: 8), Text('Expired')]),
                            content: const Text('This exam window has expired and is no longer available.'),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                          ),
                        );
                        return;
                      }
                    }
                    
                    _joinExam(exam['code'], timerData: validation);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Start Exam'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmittedBadge(String code) {
    print('STUDENT_DASH: Exam $code already submitted');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.grey, size: 16),
          SizedBox(width: 4),
          Text('Submitted', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_myResults.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('You haven\'t taken any exams yet', style: TextStyle(color: Colors.grey))),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myResults.length,
      itemBuilder: (context, index) {
        final result = _myResults[index];
        final bool isPublished = result['results_published'] == true || result['result_mode'] == 'instant';
        final int score = result['score'] ?? 0;
        final int total = result['total'] ?? 0;
        final int percentage = total > 0 ? (score / total * 100).toInt() : 0;

        Color scoreColor = Colors.red;
        if (percentage >= 60) scoreColor = Colors.green;
        else if (percentage >= 40) scoreColor = Colors.orange;

        return Card(
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
                      Text(result['exam_title'] ?? 'Unknown Exam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text(result['exam_code'] ?? '----', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
                          ),
                          const SizedBox(width: 8),
                          Text(result['created_at'].toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPublished)
                  _buildPublishedScore(result, score, total, percentage, scoreColor)
                else
                  _buildPendingBadge(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPublishedScore(Map<String, dynamic> result, int score, int total, int percentage, Color scoreColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$score / $total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: scoreColor)),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentResultDetailScreen(
                    result: result,
                    examTitle: result['exam_title'] ?? 'Exam Detail',
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('View Details', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingBadge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
          child: const Text('Pending', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(height: 4),
        const Text('Manual Review', style: TextStyle(fontSize: 10, color: Colors.grey)),
        SizedBox(
          height: 28,
          child: TextButton(
            onPressed: _loadData,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Check Again', style: TextStyle(fontSize: 11, color: Colors.blueAccent)),
          ),
        ),
      ],
    );
  }
}
