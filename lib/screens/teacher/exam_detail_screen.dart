import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class ExamDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exam;

  const ExamDetailScreen({super.key, required this.exam});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  bool _isPublishing = false;
  late bool _resultsPublished;

  @override
  void initState() {
    super.initState();
    _resultsPublished = widget.exam['results_published'] ?? false;
    _loadResults();
    debugPrint('DETAIL: Screen opened for exam: ${widget.exam['code']}');
    debugPrint('DETAIL: Result mode: ${widget.exam['result_mode']}');
    debugPrint('DETAIL: Results published: $_resultsPublished');
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.getExamResults(widget.exam['code']);
      setState(() {
        _results = result;
        _isLoading = false;
      });
      debugPrint('DETAIL: Loaded ${_results.length} results');
    } catch (e) {
      debugPrint('DETAIL: ERROR - $e');
      setState(() => _isLoading = false);
    }
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
                      ...List.generate(_results.length, (index) {
                        return _buildResultCard(_results[index], index);
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
    return const Row(
      children: [
        Icon(Icons.emoji_events_outlined, color: Colors.amber, size: 24),
        const SizedBox(width: 8),
        Text(
          'Leaderboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
    );
  }

  Widget _buildEmptyState() {
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
}
