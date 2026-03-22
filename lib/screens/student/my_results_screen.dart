import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import 'student_result_detail_screen.dart';

class MyResultsScreen extends StatefulWidget {
  final String enrollmentNumber;

  const MyResultsScreen({
    super.key,
    required this.enrollmentNumber,
  });

  @override
  State<MyResultsScreen> createState() => _MyResultsScreenState();
}

class _MyResultsScreenState extends State<MyResultsScreen> {
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatus = 'all'; // all, published, pending

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await SupabaseService.getStudentResults(widget.enrollmentNumber);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
        print('MY_RESULTS: Loaded ${results.length} results');
      }
    } catch (e) {
      print('MY_RESULTS: ERROR - $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getScoreColor(Map<String, dynamic> result) {
    final score = result['score'] ?? 0;
    final total = result['total'] ?? 1;
    final pct = (score / total * 100).round();
    if (pct >= 60) return Colors.green;
    if (pct >= 40) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return isoString;
    }
  }

  List<Map<String, dynamic>> _getFilteredResults() {
    if (_filterStatus == 'all') return _results;
    
    return _results.where((r) {
      final bool isPublished = r['result_mode'] == 'instant' || r['results_published'] == true;
      if (_filterStatus == 'published') return isPublished;
      if (_filterStatus == 'pending') return !isPublished;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _getFilteredResults();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Results', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadResults,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingWidget(message: 'Loading results...')
          : _errorMessage != null
              ? AppErrorWidget(message: _errorMessage!, onRetry: _loadResults)
              : _results.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsRow(),
                          const SizedBox(height: 24),
                          _buildFilterChips(),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredResults.length,
                            itemBuilder: (context, index) {
                              return _buildResultCard(filteredResults[index]);
                            },
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No results yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Give an exam to see your results here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    int passedCount = 0;
    double totalPct = 0;
    
    for (var r in _results) {
      final score = r['score'] ?? 0;
      final total = r['total'] ?? 1;
      final pct = score / total;
      if (pct >= 0.6) passedCount++;
      totalPct += pct;
    }
    
    final avgPct = _results.isNotEmpty ? (totalPct / _results.length * 100).toInt() : 0;

    return Row(
      children: [
        Expanded(child: _buildStatCard('Total', _results.length.toString(), Colors.blueAccent)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Passed', passedCount.toString(), Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Avg Score', '$avgPct%', Colors.orange)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _buildChip('All', 'all'),
        const SizedBox(width: 8),
        _buildChip('Published', 'published'),
        const SizedBox(width: 8),
        _buildChip('Pending', 'pending'),
      ],
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = value);
        }
      },
      selectedColor: Colors.blueAccent.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blueAccent : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.grey.shade300),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final bool isPublished = result['result_mode'] == 'instant' || result['results_published'] == true;
    final scoreColor = _getScoreColor(result);
    final score = result['score'] ?? 0;
    final total = result['total'] ?? 1;
    final percentage = (score / total * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result['exam_title'] ?? 'Exam',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (isPublished)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    percentage >= 60 ? 'Passed' : 'Failed',
                    style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.tag, size: 12, color: Colors.grey),
              const SizedBox(width: 2),
              Text(result['exam_code'] ?? '----', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
              const SizedBox(width: 2),
              Text(_formatDate(result['created_at'].toString()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (isPublished) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Score', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        '$score / $total',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: scoreColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      '$percentage%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: scoreColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / total,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(scoreColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentResultDetailScreen(
                      result: result,
                      examTitle: result['exam_title'] ?? 'Exam',
                    ),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View Details'),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Results not published yet. Check back later.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
