import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../widgets/loading_widget.dart';
import '../../services/supabase_service.dart';

class LiveExamMonitorScreen extends StatefulWidget {
  final Map<String, dynamic> exam;

  const LiveExamMonitorScreen({super.key, required this.exam});

  @override
  State<LiveExamMonitorScreen> createState() => _LiveExamMonitorScreenState();
}

class _LiveExamMonitorScreenState extends State<LiveExamMonitorScreen> {
  List<Map<String, dynamic>> _liveResults = [];
  List<Map<String, dynamic>> _sessions = [];
  int _totalJoined = 0;
  int _totalSubmitted = 0;
  int _activeStudents = 0;
  int _suspiciousCount = 0;
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeToRealtime();
    print('MONITOR: Screen opened for exam: ${widget.exam['code']}');
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
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

      final sessions = await SupabaseService.getExamSessions(widget.exam['code']);

      setState(() {
        _liveResults = List<Map<String, dynamic>>.from(results);
        _sessions = List<Map<String, dynamic>>.from(sessions);
        _totalJoined = _sessions.length;
        _activeStudents = _sessions.where((s) => s['status'] == 'active').length;
        _totalSubmitted = _sessions.where((s) => s['status'] == 'submitted').length;
        _suspiciousCount = _liveResults.where((r) =>
            ((r['warnings'] ?? 0) as int) + ((r['app_switches'] ?? 0) as int) >= 3).length;
        _isLoading = false;
      });
      print('MONITOR: Loaded ${_liveResults.length} results, ${_sessions.length} sessions');
    } catch (e) {
      print('MONITOR: Load error - $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('exam_monitor_${widget.exam['code']}')
        // Listen to Results
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
            print('MONITOR: New result received: ${payload.newRecord['enrollment_number']}');
            final newResult = payload.newRecord;
            setState(() {
              _liveResults.insert(0, newResult);
              _suspiciousCount = _liveResults.where((r) =>
                  ((r['warnings'] ?? 0) as int) + ((r['app_switches'] ?? 0) as int) >= 3).length;
            });

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
        // Listen to Sessions - Insert
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'exam_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'exam_code',
            value: widget.exam['code'],
          ),
          callback: (payload) {
            print('MONITOR: New student joined: ${payload.newRecord['enrollment_number']}');
            final newSession = payload.newRecord;
            setState(() {
              _sessions.insert(0, newSession);
              _totalJoined = _sessions.length;
              _activeStudents = _sessions.where((s) => s['status'] == 'active').length;
              _totalSubmitted = _sessions.where((s) => s['status'] == 'submitted').length;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.person_add, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('${newSession['student_name'] ?? newSession['enrollment_number']} joined the exam!'),
                ]),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
              ),
            );
          },
        )
        // Listen to Sessions - Update
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'exam_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'exam_code',
            value: widget.exam['code'],
          ),
          callback: (payload) {
            print('MONITOR: Session updated: ${payload.newRecord['enrollment_number']} -> ${payload.newRecord['status']}');
            final updated = payload.newRecord;
            setState(() {
              final index = _sessions.indexWhere((s) => s['enrollment_number'] == updated['enrollment_number']);
              if (index != -1) {
                _sessions[index] = updated;
              }
              _activeStudents = _sessions.where((s) => s['status'] == 'active').length;
              _totalSubmitted = _sessions.where((s) => s['status'] == 'submitted').length;
            });

            if (updated['status'] == 'submitted') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.task_alt, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('${updated['student_name'] ?? updated['enrollment_number']} submitted!'),
                  ]),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        )
        .subscribe();

    print('MONITOR: All realtime hooks subscribed for exam: ${widget.exam['code']}');
  }

  String _formatJoinTime(String? joinedAt) {
    if (joinedAt == null) return '';
    try {
      final dt = DateTime.parse(joinedAt).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      return '';
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
      body: _isLoading ? const Center(child: AppLoadingWidget(message: 'Loading live data...')) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 24),
            Text(
              'CURRENTLY TAKING EXAM',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActiveStudentsSection(),
            const SizedBox(height: 32),
            Text(
              'SUBMITTED',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSubmittedSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _buildMetricCard(icon: Icons.people, color: Colors.blue, value: '$_totalJoined', label: 'Joined'),
        const SizedBox(width: 8),
        _buildMetricCard(icon: Icons.pending_actions, color: Colors.orange, value: '$_activeStudents', label: 'In Progress'),
        const SizedBox(width: 8),
        _buildMetricCard(icon: Icons.task_alt, color: Colors.green, value: '$_totalSubmitted', label: 'Submitted'),
      ],
    );
  }

  Widget _buildMetricCard({required IconData icon, required Color color, required String value, required String label}) {
    return Expanded(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveStudentsSection() {
    final activeSessions = _sessions.where((s) => s['status'] == 'active').toList();
    if (activeSessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: const Center(child: Text('No students currently taking exam', style: TextStyle(color: Colors.grey, fontSize: 13))),
      );
    }

    return Column(
      children: activeSessions.map((session) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              _PulsingDot(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session['student_name'] ?? session['enrollment_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Text('Joined ${(_formatJoinTime(session['joined_at']))}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        if (session['last_warning_type'] != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${session['last_warning_type'].toString().replaceAll('_', ' ')}',
                            style: TextStyle(color: Colors.red.shade400, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if ((session['warnings'] ?? 0) > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red, size: 12),
                      const SizedBox(width: 2),
                      Text('${session['warnings']}', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                child: const Text('In Progress', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmittedSection() {
    if (_liveResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: const Center(child: Text('No submissions yet', style: TextStyle(color: Colors.grey, fontSize: 13))),
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
            border: Border.all(color: totalViolations >= 3 ? Colors.red.shade300 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result['student_name'] ?? result['enrollment_number'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(result['enrollment_number'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$score/$total', style: TextStyle(fontWeight: FontWeight.bold, color: percentage >= 60 ? Colors.green : Colors.red)),
                  Text('$percentage%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              if (totalViolations > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: totalViolations >= 3 ? Colors.red : Colors.orange, borderRadius: BorderRadius.circular(8)),
                  child: Text('${totalViolations}⚠', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
