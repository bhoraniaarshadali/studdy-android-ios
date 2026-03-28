import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../models/question_model.dart';
import 'student_response_screen.dart';
import 'dashboard_screen.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

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
  String? _errorMessage;
  
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _showQR = false;
  bool _isSharingQR = false;

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
        _errorMessage = null;
      });
      debugPrint('DETAIL: Loaded ${_results.length} results');
      print('DETAIL: Filtered results reset to ${_results.length}');
    } catch (e) {
      debugPrint('DETAIL: ERROR - $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
        final name = (r['student_name'] ?? '').toString().toLowerCase();
        return enrollment.contains(q) || name.contains(q);
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
            ? const AppLoadingWidget(message: 'Loading exam results...')
            : _errorMessage != null
                ? AppErrorWidget(message: _errorMessage!, onRetry: _loadResults)
                : DefaultTabController(
                    length: 2,
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildInfoCard(),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverAppBarDelegate(
                            const TabBar(
                              tabs: [
                                Tab(text: 'Leaderboard', icon: Icon(Icons.leaderboard_outlined)),
                                Tab(text: 'Proctoring Report', icon: Icon(Icons.security_outlined)),
                              ],
                              labelColor: Colors.blueAccent,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                      body: TabBarView(
                        children: [
                          _buildLeaderboardTab(),
                          _buildProctoringTab(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildLeaderboardHeader(),
          const SizedBox(height: 16),
          if (_results.isNotEmpty) ...[
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
    );
  }

  Widget _buildProctoringTab() {
    if (_results.isEmpty) return _buildEmptyState();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        return _buildProctoringCard(_results[index]);
      },
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
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _showQR = !_showQR);
                    print('QR_DETAIL: QR toggled: $_showQR for exam ${widget.exam['code']}');
                  },
                  icon: Icon(_showQR ? Icons.qr_code_2 : Icons.qr_code, size: 18),
                  label: Text(_showQR ? 'Hide QR' : 'Show QR Code'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showQR ? Container(
                key: const ValueKey('qr'),
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Exam QR Code',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Share this with students to join',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    
                    // QR Code wrapped in Screenshot widget
                    Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Studdy Exam',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.exam['title'] ?? 'Exam',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            QrImageView(
                              data: widget.exam['code'],
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.exam['code'],
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Scan QR or enter code in Studdy app',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Action buttons row
                    Row(
                      children: [
                        // Download button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSharingQR ? null : () {
                              print('QR_DETAIL: Download button tapped');
                              _downloadQR();
                            },
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Download'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Share button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSharingQR ? null : () {
                              print('QR_DETAIL: Share button tapped');
                              _shareQR();
                            },
                            icon: _isSharingQR
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.share, size: 16),
                            label: const Text('Share'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ) : const SizedBox.shrink(key: ValueKey('empty')),
            ),
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
                  hintText: 'Search by enrollment or name...',
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
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result['enrollment_number'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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

  Widget _buildProctoringCard(Map<String, dynamic> result) {
    print('PROCTOR_REPORT: ${result['enrollment_number']} - warnings: ${result['warnings']}, switches: ${result['app_switches']}, risk: ${_getRiskLabel(result)}');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getProctoringColor(result),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getProctoringBorderColor(result)),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getProctoringIcon(result),
              color: _getProctoringIconColor(result),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Student info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result['student_name'] ?? result['enrollment_number'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  result['enrollment_number'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Warnings
                    const Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                    const SizedBox(width: 2),
                    Text(
                      '${result['warnings'] ?? 0} warnings',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    // App switches
                    const Icon(Icons.swap_horiz, size: 12, color: Colors.blue),
                    const SizedBox(width: 2),
                    Text(
                      '${result['app_switches'] ?? 0} switches',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Risk badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRiskColor(result),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getRiskLabel(result),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProctoringColor(Map<String, dynamic> result) {
    final warnings = (result['warnings'] ?? 0) as int;
    final switches = (result['app_switches'] ?? 0) as int;
    final total = warnings + switches;
    if (total == 0) return Colors.green.shade50;
    if (total <= 2) return Colors.orange.shade50;
    return Colors.red.shade50;
  }

  Color _getProctoringBorderColor(Map<String, dynamic> result) {
    final total = ((result['warnings'] ?? 0) as int) + ((result['app_switches'] ?? 0) as int);
    if (total == 0) return Colors.green.shade200;
    if (total <= 2) return Colors.orange.shade200;
    return Colors.red.shade200;
  }

  IconData _getProctoringIcon(Map<String, dynamic> result) {
    final total = ((result['warnings'] ?? 0) as int) + ((result['app_switches'] ?? 0) as int);
    if (total == 0) return Icons.verified_user;
    if (total <= 2) return Icons.warning_amber;
    return Icons.gpp_bad;
  }

  Color _getProctoringIconColor(Map<String, dynamic> result) {
    final total = ((result['warnings'] ?? 0) as int) + ((result['app_switches'] ?? 0) as int);
    if (total == 0) return Colors.green;
    if (total <= 2) return Colors.orange;
    return Colors.red;
  }

  Color _getRiskColor(Map<String, dynamic> result) {
    final total = ((result['warnings'] ?? 0) as int) + ((result['app_switches'] ?? 0) as int);
    if (total == 0) return Colors.green;
    if (total <= 2) return Colors.orange;
    return Colors.red;
  }

  String _getRiskLabel(Map<String, dynamic> result) {
    final total = ((result['warnings'] ?? 0) as int) + ((result['app_switches'] ?? 0) as int);
    if (total == 0) return 'Clean';
    if (total <= 2) return 'Suspicious';
    return 'High Risk';
  }

  Future<void> _downloadQR() async {
    try {
      setState(() => _isSharingQR = true);
      print('QR_DETAIL: Capturing QR for download');
      
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes == null) throw Exception('Failed to capture QR');
      
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) await directory.create(recursive: true);
      
      final fileName = 'Studdy_QR_${widget.exam['code']}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(imageBytes);
      
      print('QR_DETAIL: QR saved to: ${file.path}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('QR saved to Downloads!', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(fileName, style: const TextStyle(fontSize: 11)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('QR_DETAIL: Download ERROR - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSharingQR = false);
    }
  }

  Future<void> _shareQR() async {
    try {
      setState(() => _isSharingQR = true);
      print('QR_DETAIL: Capturing QR for sharing');
      
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes == null) throw Exception('Failed to capture QR');
      
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Studdy_QR_${widget.exam['code']}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Join my exam on Studdy!\n\nExam: ${widget.exam['title'] ?? 'Exam'}\nCode: ${widget.exam['code']}\n\nScan the QR or enter code in Studdy app.',
        subject: 'Studdy Exam Code: ${widget.exam['code']}',
      );
      
      print('QR_DETAIL: QR shared successfully');
    } catch (e) {
      print('QR_DETAIL: Share ERROR - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSharingQR = false);
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white, // Ensure TabBar has a background when pinned
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
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
