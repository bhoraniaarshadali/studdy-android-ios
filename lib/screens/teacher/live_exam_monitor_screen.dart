import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../widgets/loading_widget.dart';

class LiveExamMonitorScreen extends StatefulWidget {
  final Map<String, dynamic> exam;

  const LiveExamMonitorScreen({super.key, required this.exam});

  @override
  State<LiveExamMonitorScreen> createState() => _LiveExamMonitorScreenState();
}

class _LiveExamMonitorScreenState extends State<LiveExamMonitorScreen> {
  List<Map<String, dynamic>> _liveResults = [];
  int _totalJoined = 0;
  int _totalSubmitted = 0;
  int _suspiciousCount = 0;
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
  final DateTime _monitorStartTime = DateTime.now();
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeToRealtime();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
    print('MONITOR: Screen opened for exam: ${widget.exam['code']}');
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _elapsedTimer?.cancel();
    print('MONITOR: Unsubscribed from realtime');
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Supabase.instance.client
          .from('results')
          .select('*')
          .eq('exam_code', widget.exam['code'])
          .order('created_at', ascending: false);

      setState(() {
        _liveResults = List<Map<String, dynamic>>.from(results);
        _totalSubmitted = _liveResults.length;
        _totalJoined = _liveResults.length;
        _suspiciousCount = _liveResults.where((r) =>
            ((r['warnings'] ?? 0) as int) + ((r['app_switches'] ?? 0) as int) >= 3).length;
        _isLoading = false;
      });
      print('MONITOR: Initial data loaded - ${_liveResults.length} results');
    } catch (e) {
      print('MONITOR: Load error - $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('exam_monitor_${widget.exam['code']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'results',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'exam_code',
            value: widget.exam['code'],
          ),
          callback: (payload) {
            print('MONITOR: New result received: ${payload.newRecord}');
            final newResult = payload.newRecord;
            setState(() {
              _liveResults.insert(0, newResult);
              _totalSubmitted = _liveResults.length;
              _totalJoined = _liveResults.length;
              _suspiciousCount = _liveResults.where((r) =>
                  ((r['warnings'] ?? 0) as int) + ((r['app_switches'] ?? 0) as int) >= 3).length;
            });

            // Show notification for suspicious student
            final warnings = (newResult['warnings'] ?? 0) as int;
            final switches = (newResult['app_switches'] ?? 0) as int;
            if (warnings + switches >= 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'High Risk: ${newResult['enrollment_number']} submitted with ${warnings + switches} violations!'),
                    ),
                  ]),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'results',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'exam_code',
            value: widget.exam['code'],
          ),
          callback: (payload) {
            print('MONITOR: Result updated: ${payload.newRecord}');
            final updatedResult = payload.newRecord;
            setState(() {
              final index = _liveResults.indexWhere((r) => r['id'] == updatedResult['id']);
              if (index != -1) {
                _liveResults[index] = updatedResult;
              }
            });
          },
        )
        .subscribe();

    print('MONITOR: Subscribed to realtime for exam: ${widget.exam['code']}');
  }

  String _formatElapsed() {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Monitor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Code: ${widget.exam['code']}', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                _PulsingDot(),
                const SizedBox(width: 8),
                const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildExamInfoCard(),
            const SizedBox(height: 24),
            _buildLiveFeedHeader(),
            const SizedBox(height: 12),
            _buildLiveResultsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          icon: Icons.people,
          color: Colors.blue,
          value: '$_totalJoined',
          label: 'Joined',
        ),
        _buildMetricCard(
          icon: Icons.task_alt,
          color: Colors.green,
          value: '$_totalSubmitted',
          label: 'Submitted',
        ),
        _buildMetricCard(
          icon: Icons.gpp_bad,
          color: Colors.red,
          value: '$_suspiciousCount',
          label: 'High Risk',
        ),
        _buildMetricCard(
          icon: Icons.timer,
          color: Colors.purple,
          value: _formatElapsed(),
          label: 'Monitoring',
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildExamInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exam['title'] ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildBadge(widget.exam['code'], Colors.blue),
                const SizedBox(width: 8),
                _buildBadge(widget.exam['timer_mode']?.toString().toUpperCase() ?? 'NONE', Colors.purple),
                const SizedBox(width: 8),
                _buildBadge(widget.exam['result_mode']?.toString().toUpperCase() ?? 'INSTANT', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLiveFeedHeader() {
    return Row(
      children: [
        _PulsingDot(),
        const SizedBox(width: 8),
        const Text(
          'Live Submissions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Text('${_liveResults.length} total', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildLiveResultsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: AppLoadingWidget(message: 'Initializing monitor...'),
      );
    }

    if (_liveResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Waiting for students...',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Results will appear here in real-time',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _liveResults.map((result) {
        final warnings = (result['warnings'] ?? 0) as int;
        final switches = (result['app_switches'] ?? 0) as int;
        final totalViolations = warnings + switches;
        final score = result['score'] as int? ?? 0;
        final total = result['total'] as int? ?? 1;
        final percentage = (score / total * 100).round();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: totalViolations >= 3
                  ? Colors.red.shade300
                  : totalViolations > 0
                      ? Colors.orange.shade300
                      : Colors.grey.shade200,
              width: totalViolations >= 3 ? 1.5 : 1,
            ),
            boxShadow: [
              if (totalViolations >= 3)
                BoxShadow(
                  color: Colors.red.withOpacity(0.05),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: totalViolations >= 3
                      ? Colors.red.shade50
                      : percentage >= 60
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${_liveResults.indexOf(result) + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: totalViolations >= 3
                          ? Colors.red
                          : percentage >= 60
                              ? Colors.green
                              : Colors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score/$total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: percentage >= 60 ? Colors.green : Colors.red,
                    ),
                  ),
                  Text('$percentage%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              if (totalViolations > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: totalViolations >= 3 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${totalViolations}⚠',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(_animation.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(_animation.value * 0.5),
              blurRadius: 4,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
