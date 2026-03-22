import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dashboard_screen.dart';
import 'create_exam_screen.dart';

class ExamPublishedScreen extends StatefulWidget {
  final String examCode;
  final String resultMode;

  const ExamPublishedScreen({
    super.key,
    required this.examCode,
    required this.resultMode,
  });

  @override
  State<ExamPublishedScreen> createState() => _ExamPublishedScreenState();
}

class _ExamPublishedScreenState extends State<ExamPublishedScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareQRWithCode() async {
    setState(() => _isSharing = true);
    debugPrint('SHARE: Starting QR share');
    try {
      final imageBytes = await screenshotController.capture();
      
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/exam_${widget.examCode}.png').writeAsBytes(imageBytes);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Join my exam on Studdy!\nExam Code: ${widget.examCode}\nScan the QR or enter code manually.',
          subject: 'Studdy Exam Code: ${widget.examCode}',
        );
        debugPrint('SHARE: QR shared successfully');
      }
    } catch (e) {
      debugPrint('SHARE: ERROR - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Exam Published!'),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Exam Published Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share the code or QR with your students',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildCodeCard(context),
            const SizedBox(height: 24),
            _buildQRCard(context),
            const SizedBox(height: 24),
            _buildResultModeInfo(),
            const SizedBox(height: 40),
            _buildBottomButtons(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Exam Code', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.examCode,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.blueAccent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.examCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                    debugPrint('PUBLISHED: Code copied: ${widget.examCode}');
                  },
                  icon: const Icon(Icons.copy_rounded, color: Colors.blueAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCard(BuildContext context) {
    return Column(
      children: [
        Screenshot(
          controller: screenshotController,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Studdy Exam', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Code: ${widget.examCode}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: widget.examCode,
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan or enter code in Studdy app',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : _shareQRWithCode,
            icon: _isSharing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share_rounded),
            label: Text(_isSharing ? 'Generating...' : 'Share QR & Code'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultModeInfo() {
    if (widget.resultMode == 'instant') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Results will be shown instantly after submission',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: const Row(
          children: [
            Icon(Icons.timer, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'You will need to manually publish results from dashboard',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const TeacherDashboardScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Go to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const CreateExamScreen()),
                (route) => false,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              side: const BorderSide(color: Colors.blueAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Another Exam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
