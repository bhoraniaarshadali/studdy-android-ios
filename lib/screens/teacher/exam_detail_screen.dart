import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../models/question_model.dart';
import 'student_response_screen.dart';
import 'dashboard_screen.dart';

class ExamDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exam;

  const ExamDetailScreen({super.key, required this.exam});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _filteredResults = [];
  List<QuestionModel> _questions = [];
  bool _isLoading = true;
  bool _isPublishing = false;
  late bool _resultsPublished;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _resultsPublished = widget.exam['results_published'] ?? false;
    
    final questionsRaw = widget.exam['questions'];
    if (questionsRaw != null && questionsRaw is List) {
      _questions = (questionsRaw as List)
          .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
          .toList();
      print('DETAIL: Parsed ${_questions.length} questions');
    } else {
      _questions = [];
      print('DETAIL: No questions found in exam data');
    }

    _loadResults();
    debugPrint('DETAIL: Screen opened for exam: ${widget.exam['code']}');
    debugPrint('DETAIL: Result mode: ${widget.exam['result_mode']}');
    debugPrint('DETAIL: Results published: $_resultsPublished');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    try {
      // Re-fetch the exam to ensure questions are loaded
      final examWithQuestions = await Supabase.instance.client
        .from('exams')
        .select()
        .eq('code', widget.exam['code'])
        .single();
      
      print('DETAIL: Re-fetched exam with questions: ${examWithQuestions['questions'] != null}');
      
      final questionsRaw = examWithQuestions['questions'];
      if (questionsRaw != null && questionsRaw is List) {
        setState(() {
          _questions = (questionsRaw as List)
              .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
              .toList();
        });
        print('DETAIL: Questions loaded: ${_questions.length}');
      }

      final result = await SupabaseService.getExamResults(widget.exam['code']);
      setState(() {
        _results = result;
        _filteredResults = result;
        _isLoading = false;
      });
      debugPrint('DETAIL: Loaded ${_results.length} results');
      print('DETAIL: Filtered results reset to ${_results.length}');
    } catch (e) {
      debugPrint('DETAIL: ERROR - $e');
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    print('SEARCH: Searching for: $query');
    if (query.isEmpty) {
      setState(() => _filteredResults = _results);
      print('SEARCH: Query empty, showing all ${_results.length} results');
      return;
    }

    final q = query.toLowerCase().trim();
    setState(() {
      _filteredResults = _results.where((r) {
        final enrollment = r['enrollment_number'].toString().toLowerCase();
        return enrollment.contains(q);
      }).toList();
    });
    print('SEARCH: Query "$query" found ${_filteredResults.length} results');
  }

  Future<void> _publishResults() async {
    setState(() => _isPublishing = true);
    try {
      await SupabaseService.publishResults(widget.exam['code']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Results published successfully!')),
        );
      }
      setState(() {
        _isPublishing = false;
        _resultsPublished = true;
      });
      _loadResults();
      debugPrint('DETAIL: Results published');
    } catch (e) {
      debugPrint('DETAIL: Publish ERROR - $e');
      setState(() => _isPublishing = false);
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}, ${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      return isoString;
    }
  }

  void _confirmPublish() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Results?'),
        content: const Text('All students will be able to see their scores. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('DETAIL: Publish dialog confirmed');
              Navigator.pop(context);
              _publishResults();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.exam['title'] ?? 'Exam Detail';
    final code = widget.exam['code'] ?? '------';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(code, style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              print('DELETE: Confirmation shown for exam: $code');
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('Delete Exam?'),
                    ]
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Are you sure you want to delete this exam?'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Code: $code', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('Results: ${_results.length}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This will permanently delete the exam and all student results. This cannot be undone.',
                        style: TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        print('DELETE: User cancelled deletion');
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        print('DELETE: User confirmed deletion');
                        Navigator.pop(context);
                        try {
                          await SupabaseService.deleteExam(code);
                          print('DETAIL: Exam deleted, returning to dashboard');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"$title" deleted successfully'), backgroundColor: Colors.green),
                            );
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          print('DETAIL: Delete ERROR - $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Delete Exam',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadResults,
        child: _isLoading && _results.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    if (_results.isNotEmpty) ...[
                      _buildLeaderboardHeader(),
                      const SizedBox(height: 16),
                      if (_filteredResults.isEmpty && _searchController.text.isNotEmpty)
                        _buildEmptyState()
                      else
                        ...List.generate(_filteredResults.length, (index) {
                          return _buildResultCard(_filteredResults[index], index);
                        }),
                    ] else
                      _buildEmptyState(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final mode = widget.exam['result_mode'] ?? 'instant';
    final isManual = mode == 'manual';

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
            Row(
              children: [
                _buildStatBox('Code', widget.exam['code'], Colors.blueAccent),
                _buildStatVerticalDivider(),
                _buildStatBox('Students', _results.length.toString(), Colors.black87),
                _buildStatVerticalDivider(),
                _buildStatBox('Mode', mode.toUpperCase(), mode == 'instant' ? Colors.green : Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimerInfoRow(),
            if (isManual && !_resultsPublished) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Results not published yet',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPublishing ? null : _confirmPublish,
                  icon: _isPublishing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish_rounded),
                  label: const Text('Publish Results', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Results are visible to students',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildLeaderboardHeader() {
    return Row(
      children: [
        if (!_isSearching) ...[
          const Icon(Icons.emoji_events_outlined, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Leaderboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.grey),
            onPressed: () {
              print('SEARCH: Search bar opened');
              setState(() => _isSearching = true);
            },
            tooltip: 'Search',
          ),
        ] else ...[
          Expanded(
            child: Container(
              height: 44,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by enrollment...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () {
                      print('SEARCH: Search bar closed');
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        _filteredResults = _results;
                      });
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result, int index) {
    final rank = index + 1;
    final name = result['student_name'] ?? 'Unknown';
    final score = result['score'] ?? 0;
    final total = result['total'] ?? 0;
    final percentage = total > 0 ? (score / total * 100).toInt() : 0;
    final time = result['created_at'] != null ? _formatDateTime(result['created_at']) : 'N/A';

    Color rankColor;
    if (rank == 1) rankColor = Colors.amber;
    else if (rank == 2) rankColor = Colors.grey.shade400;
    else if (rank == 3) rankColor = Colors.brown.shade300;
    else rankColor = Colors.grey.shade200;

    return InkWell(
      onTap: () {
        debugPrint('DETAIL: Opening response for ${result['enrollment_number']}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentResponseScreen(
              result: result,
              questions: _questions,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    rank.toString(),
                    style: TextStyle(
                      color: rank <= 3 ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result['enrollment_number'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score / $total',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent),
                  ),
                  Text(
                    '($percentage%)',
                    style: TextStyle(fontSize: 12, color: percentage >= 50 ? Colors.green : Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    
    if (isSearching && _filteredResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No student found', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(
                'No results for "${_searchController.text}"',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60.0),
        child: Column(
          children: [
            Icon(Icons.person_off_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No students have taken this exam yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Share code: ${widget.exam['code']} with students',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerInfoRow() {
    final mode = widget.exam['timer_mode'] ?? 'none';
    print('DETAIL: Timer info - mode: $mode');

    if (mode == 'none') {
      return Row(
        children: [
          Icon(Icons.timer_off_outlined, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text('No time limit', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      );
    }

    if (mode == 'duration') {
      return Row(
        children: [
          const Icon(Icons.hourglass_bottom_rounded, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(
            '${widget.exam['duration_minutes']} minutes per attempt',
            style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    if (mode == 'window') {
      try {
        final start = DateTime.parse(widget.exam['window_start']).toLocal();
        final end = DateTime.parse(widget.exam['window_end']).toLocal();
        final now = DateTime.now();

        String format(DateTime dt) {
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return '${dt.day} ${months[dt.month - 1]} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
        }

        Widget statusBadge;
        if (now.isBefore(start)) {
          statusBadge = _buildTimerStatusBadge('Upcoming', Colors.orange);
        } else if (now.isAfter(end)) {
          statusBadge = _buildTimerStatusBadge('Expired', Colors.grey);
        } else {
          statusBadge = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PulsingDot(),
              const SizedBox(width: 6),
              _buildTimerStatusBadge('Live Now', Colors.green),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Window: ${format(start)} → ${format(end)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            statusBadge,
          ],
        );
      } catch (e) {
        return const SizedBox.shrink();
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildTimerStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
