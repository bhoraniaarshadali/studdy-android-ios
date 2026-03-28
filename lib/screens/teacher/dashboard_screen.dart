import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'create_exam_screen.dart';
import 'exam_detail_screen.dart';
import 'exam_paper_generator_screen.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import 'generated_papers_screen.dart';
import 'teacher_exams_screen.dart';
import '../../services/teacher_auth_service.dart';
import '../auth/teacher_login_screen.dart';
import '../auth/login_screen.dart';
import '../../services/auth_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _generatedPapers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadExams();
  }

  void _checkAuth() {
    if (!TeacherAuthService.isLoggedIn) {
      print('TEACHER_AUTH: Not logged in, redirecting to login');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
          (route) => false,
        );
      });
      return;
    }
    print('TEACHER_AUTH: Logged in as: ${TeacherAuthService.teacherEmail}');
  }

  Future<void> _loadExams() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.getTeacherExams();

      // Fetch generated papers
      final papers = await Supabase.instance.client
          .from('generated_papers')
          .select('id, title, total_marks, difficulty, template, created_at')
          .order('created_at', ascending: false)
          .limit(5);

      if (!mounted) return;
      setState(() {
        _exams = result;
        _generatedPapers = List<Map<String, dynamic>>.from(papers);
        _isLoading = false;
        _errorMessage = null;
      });
      debugPrint(
        'DASHBOARD: Loaded ${_exams.length} exams and ${_generatedPapers.length} generated papers',
      );
    } catch (e) {
      debugPrint('DASHBOARD: ERROR - $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return isoString;
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
            const Text('My Exams', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              TeacherAuthService.teacherEmail,
              style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExams,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign Out?'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(context);
                        await TeacherAuthService.signOut();
                        await AuthService.logout();
                        print('TEACHER_AUTH: Logged out');
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingWidget(message: 'Loading exams...')
          : _errorMessage != null
          ? AppErrorWidget(message: _errorMessage!, onRetry: _loadExams)
          : _exams.isEmpty
          ? _buildEmptyState()
          : _buildMainContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOptions,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No exams yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first exam',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateExamScreen(),
                ),
              );
              _loadExams();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Create Exam'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionCards(),
          _buildStatsRow(),
          if (_exams.isNotEmpty) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text(
                    'Recent Exams',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherExamsScreen(),
                        ),
                      ).then((_) => _loadExams());
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
            ..._exams
                .take(2)
                .map(
                  (exam) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildExamCard(exam),
                  ),
                )
                .toList(),
          ],
          if (_generatedPapers.isNotEmpty) _buildGeneratedPapersSection(),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildActionCards() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildActionCard(
            'Create Exam',
            'AI MCQ Exam',
            Icons.quiz,
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateExamScreen()),
            ).then((_) => _loadExams()),
          ),
          const SizedBox(width: 12),
          _buildActionCard(
            'Generate Paper',
            'AI paper from PDF',
            Icons.description,
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ExamPaperGeneratorScreen(),
              ),
            ).then((_) => _loadExams()),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create New',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              title: 'Create MCQ Exam',
              subtitle: 'AI generates MCQ questions',
              icon: Icons.quiz,
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateExamScreen()),
                ).then((_) => _loadExams());
              },
            ),
            const Divider(height: 32),
            _buildOptionTile(
              title: 'Generate Exam Paper',
              subtitle: 'Full paper with sections from PDF',
              icon: Icons.description,
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExamPaperGeneratorScreen(),
                  ),
                ).then((_) => _loadExams());
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildGeneratedPapersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.description, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Generated Papers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GeneratedPapersScreen(),
                    ),
                  ).then((_) => _loadExams());
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _generatedPapers.length > 2 ? 2 : _generatedPapers.length,
          itemBuilder: (context, index) {
            final paper = _generatedPapers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GeneratedPapersScreen(),
                    ),
                  ).then((_) => _loadExams());
                },
                title: Text(
                  paper['title'] ?? 'Untitled Paper',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildSmallBadge(
                        paper['difficulty']?.toUpperCase() ?? 'N/A',
                        Colors.grey,
                      ),
                      _buildSmallBadge('AUTO-SAVED', Colors.green),
                      _buildSmallBadge(
                        paper['template']?.replaceAll('_', ' ').toUpperCase() ??
                            'N/A',
                        Colors.blue,
                      ),
                      Text(
                        _formatDate(paper['created_at']),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${paper['total_marks']}M',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    int totalStudents = 0;
    for (var exam in _exams) {
      totalStudents += (exam['student_count'] as int? ?? 0);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildStatCard('Total Exams', _exams.length.toString()),
          const SizedBox(width: 12),
          _buildStatCard('Total Students', totalStudents.toString()),
          const SizedBox(width: 12),
          _buildStatCard('Avg Score', 'N/A'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final mode = exam['result_mode'] ?? 'instant';
    final published = exam['results_published'] ?? false;
    final code = exam['code'] ?? '------';
    final title = exam['title'] ?? 'No Title';
    final date = exam['created_at'] != null
        ? _formatDate(exam['created_at'])
        : 'No Date';
    final studentCount = exam['student_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamDetailScreen(exam: exam),
            ),
          );
        },
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildCodeBadge(code),
              ],
            ),
            const SizedBox(height: 8),
            _buildTimerBadge(exam),
            const SizedBox(height: 12),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge(
                  mode.toUpperCase(),
                  mode == 'instant' ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(mode, published),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$studentCount students',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBadge(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String mode, bool published) {
    if (mode == 'instant' || published) {
      return _buildBadge(published ? 'PUBLISHED' : 'INSTANT', Colors.green);
    }
    return _buildBadge('PENDING', Colors.orange);
  }

  Widget _buildTimerBadge(Map<String, dynamic> exam) {
    final mode = exam['timer_mode'] ?? 'none';
    print('DASHBOARD: Timer mode for ${exam['code']}: $mode');

    if (mode == 'none') return const SizedBox.shrink();

    if (mode == 'duration') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_bottom, size: 12, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              '${exam['duration_minutes']} min limit',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (mode == 'window') {
      try {
        final start = DateTime.parse(exam['window_start']).toLocal();
        final end = DateTime.parse(exam['window_end']).toLocal();
        final now = DateTime.now();

        Color bgColor;
        Color textColor;
        String text;
        IconData icon;

        if (now.isBefore(start)) {
          bgColor = Colors.orange.shade50;
          textColor = Colors.orange.shade700;
          text =
              'Starts ${start.day}/${start.month} ${start.hour}:${start.minute.toString().padLeft(2, '0')}';
          icon = Icons.schedule;
        } else if (now.isAfter(end)) {
          bgColor = Colors.grey.shade100;
          textColor = Colors.grey.shade600;
          text = 'Expired';
          icon = Icons.timer_off;
        } else {
          bgColor = Colors.green.shade50;
          textColor = Colors.green.shade700;
          text =
              'Live until ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
          icon = Icons.sensors;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        return const SizedBox.shrink();
      }
    }

    return const SizedBox.shrink();
  }
}
