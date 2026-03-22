import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../../models/question_model.dart';
import '../../services/kie_ai_service.dart';
import '../../services/supabase_service.dart';
import 'review_questions_screen.dart';
import 'exam_published_screen.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final TextEditingController _contentController = TextEditingController();
  List<QuestionModel> _questions = [];
  bool _isLoading = false;
  int _questionCount = 5;
  int _optionCount = 4;
  String _difficulty = 'medium';

  // New state variables
  String? _pdfFileName;
  Uint8List? _pdfBytes;
  String _statusText = '';
  bool _isPublishing = false;
  String _resultMode = 'instant'; // 'instant' or 'manual'
  String _timerMode = 'none'; // 'none', 'duration', 'window'
  int _durationMinutes = 30;
  DateTime? _windowStart;
  DateTime? _windowEnd;

  Future<void> _pickPDF() async {
    debugPrint('PDF_PICK: Button tapped');
    try {
      debugPrint('PDF_PICK: FilePicker opened');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _pdfFileName = result.files.single.name;
          _pdfBytes = result.files.single.bytes;
        });
        debugPrint('PDF_PICK: File selected - name: $_pdfFileName, bytes: ${_pdfBytes?.length}');
      } else {
        debugPrint('PDF_PICK: No file selected, user cancelled');
      }
    } catch (e) {
      debugPrint('PDF_PICK: ERROR - $e');
    }
  }

  Future<String> _extractTextFromPDF() async {
    if (_pdfBytes == null) return '';

    debugPrint('PDF_EXTRACT: Starting extraction');
    debugPrint('PDF_EXTRACT: PDF bytes size: ${_pdfBytes?.length}');
    setState(() => _statusText = 'Extracting PDF content...');
    final base64String = base64Encode(_pdfBytes!);
    debugPrint('PDF_EXTRACT: Base64 string length: ${base64String.length}');

    try {
      debugPrint('PDF_EXTRACT: Sending request to KIE API');
      final response = await http.post(
        Uri.parse('https://api.kie.ai/gemini/v1/models/gemini-3-flash-v1betamodels:streamGenerateContent'),
        headers: {
          'Authorization': 'Bearer 2d4fb913866d594231cf9ad1f3625a32',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "stream": false,
          "contents": [
            {
              "role": "user",
              "parts": [
                {
                  "inline_data": {
                    "mime_type": "application/pdf",
                    "data": base64String
                  }
                },
                {
                  "text": "Extract all text content from this PDF. Return only plain text, no formatting, no markdown."
                }
              ]
            }
          ]
        }),
      );

      debugPrint('PDF_EXTRACT: Response status: ${response.statusCode}');
      debugPrint('PDF_EXTRACT: Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String text = data['candidates'][0]['content']['parts'][0]['text'];
        debugPrint('PDF_EXTRACT: Extracted text preview: ${text.substring(0, text.length > 200 ? 200 : text.length)}');
        debugPrint('PDF_EXTRACT: Total text length: ${text.length}');
        return text;
      } else {
        throw Exception('Failed to extract PDF text: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('PDF_EXTRACT: ERROR - $e');
      rethrow;
    }
  }

  Future<void> _generateQuestions() async {
    debugPrint('GENERATE: Button tapped');
    debugPrint('GENERATE: PDF selected: ${_pdfBytes != null}');
    debugPrint('GENERATE: Manual text length: ${_contentController.text.length}');
    
    String content = '';
    
    if (_pdfBytes != null) {
      debugPrint('GENERATE: Using PDF content');
      try {
        content = await _extractTextFromPDF();
      } catch (e) {
        debugPrint('GENERATE: ERROR - $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting PDF: $e')),
        );
        setState(() => _statusText = '');
        return;
      }
    } else if (_contentController.text.trim().isNotEmpty) {
      debugPrint('GENERATE: Using manual text');
      content = _contentController.text.trim();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a PDF or enter content')),
      );
      return;
    }

    debugPrint('CreateExam: content length: ${content.length}, questions: $_questionCount, options: $_optionCount, difficulty: $_difficulty');
    setState(() {
      _isLoading = true;
      _statusText = 'Generating questions...';
    });

    try {
      final questions = await KieAiService.generateQuestions(
        content: content,
        questionCount: _questionCount,
        optionCount: _optionCount,
        difficulty: _difficulty,
      );
      debugPrint('GENERATE: Total questions: ${questions.length}');
      setState(() {
        _isLoading = false;
        _statusText = '';
      });

      // Navigate to Review screen
      final List<QuestionModel>? reviewedQuestions = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewQuestionsScreen(questions: questions),
        ),
      );

      if (reviewedQuestions != null) {
        setState(() {
          _questions = reviewedQuestions;
        });
        debugPrint('REVIEW: Returned with ${_questions.length} questions');
      }
    } catch (e) {
      debugPrint('GENERATE: ERROR - $e');
      setState(() {
        _isLoading = false;
        _statusText = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _publishExam() async {
    debugPrint('PUBLISH_BTN: Publish button tapped');
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate questions first')),
      );
      return;
    }

    // Timer validation
    if (_timerMode == 'window') {
      if (_windowStart == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select exam start time')));
        return;
      }
      if (_windowEnd == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select exam end time')));
        return;
      }
      if (_windowEnd!.isBefore(_windowStart!)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time')));
        return;
      }
    }

    debugPrint('PUBLISH_BTN: Questions ready: ${_questions.length}');
    setState(() => _isPublishing = true);

    try {
      debugPrint('PUBLISH_BTN: Calling SupabaseService...');
      final code = await SupabaseService.publishExam(
        title: 'Exam ${DateTime.now().toLocal().toString().substring(0, 16)}',
        questions: _questions,
        resultMode: _resultMode,
        timerMode: _timerMode,
        durationMinutes: _timerMode == 'duration' ? _durationMinutes : null,
        windowStart: _timerMode == 'window' ? _windowStart : null,
        windowEnd: _timerMode == 'window' ? _windowEnd : null,
      );
      debugPrint('PUBLISH_BTN: Got code: $code');
      debugPrint('PUBLISH: Result mode: $_resultMode');
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExamPublishedScreen(
              examCode: code,
              resultMode: _resultMode,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('PUBLISH_BTN: ERROR - $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Exam'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPdfUploadSection(),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              _buildContentInputCard(),
              const SizedBox(height: 16),
              _buildSettingsRow(),
              const SizedBox(height: 24),
              _buildResultModeUI(),
              const SizedBox(height: 24),
              _buildTimerSettingsUI(),
              const SizedBox(height: 24),
              _buildGenerateButton(),
              if (_statusText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ],
              if (_questions.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildQuestionsHeader(),
                const SizedBox(height: 16),
                _buildQuestionsList(),
                const SizedBox(height: 32),
                _buildPublishSection(),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultModeUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Result Mode',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildResultCard(
                mode: 'instant',
                icon: Icons.flash_on,
                title: 'Instant',
                subtitle: 'Student ko turant result mile',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildResultCard(
                mode: 'manual',
                icon: Icons.timer,
                title: 'Manual Publish',
                subtitle: 'Teacher publish kare tab result mile',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _resultMode == mode;
    return InkWell(
      onTap: () => setState(() => _resultMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.blueAccent : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerSettingsUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timer Settings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTimerCard(
                mode: 'none',
                icon: Icons.timer_off_outlined,
                title: 'No Timer',
                subtitle: 'No limit',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTimerCard(
                mode: 'duration',
                icon: Icons.hourglass_empty_rounded,
                title: 'Duration',
                subtitle: 'Fixed mins',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTimerCard(
                mode: 'window',
                icon: Icons.schedule_rounded,
                title: 'Window',
                subtitle: 'Start/End',
              ),
            ),
          ],
        ),
        if (_timerMode == 'duration') _buildDurationPicker(),
        if (_timerMode == 'window') _buildWindowPicker(),
      ],
    );
  }

  Widget _buildTimerCard({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _timerMode == mode;
    return InkWell(
      onTap: () => setState(() => _timerMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.blueAccent : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationPicker() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Duration (minutes)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (_durationMinutes > 5) setState(() => _durationMinutes -= 5);
                },
                icon: const Icon(Icons.remove_circle_outline, color: Colors.blueAccent),
              ),
              const SizedBox(width: 20),
              Text(
                '$_durationMinutes',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed: () {
                  if (_durationMinutes < 180) setState(() => _durationMinutes += 5);
                },
                icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [15, 30, 45, 60, 90].map((m) {
              return ChoiceChip(
                label: Text('$m min', style: TextStyle(fontSize: 12, color: _durationMinutes == m ? Colors.white : Colors.black87)),
                selected: _durationMinutes == m,
                onSelected: (selected) => setState(() => _durationMinutes = m),
                selectedColor: Colors.blueAccent,
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowPicker() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exam Start Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          _buildDateTimePicker(
            value: _windowStart,
            hint: 'Select start date & time',
            onPicked: (dt) => setState(() => _windowStart = dt),
          ),
          const SizedBox(height: 16),
          const Text('Exam End Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          _buildDateTimePicker(
            value: _windowEnd,
            hint: 'Select end date & time',
            onPicked: (dt) {
              if (_windowStart != null && dt.isBefore(_windowStart!)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time')));
                return;
              }
              setState(() => _windowEnd = dt);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker({
    required DateTime? value,
    required String hint,
    required ValueChanged<DateTime> onPicked,
  }) {
    return OutlinedButton(
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date == null) return;
        
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
        );
        if (time == null) return;
        
        final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        onPicked(dt);
        print('TIMER: Window set: $dt');
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value != null ? value.toString().substring(0, 16) : hint,
            style: TextStyle(color: value != null ? Colors.black87 : Colors.grey, fontSize: 14),
          ),
          const Icon(Icons.calendar_today, size: 18, color: Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _buildPublishSection() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isPublishing ? null : _publishExam,
        icon: const Icon(Icons.cloud_upload),
        label: _isPublishing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Publish Exam',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfUploadSection() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _pickPDF,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload PDF'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_pdfFileName != null) ...[
          const SizedBox(height: 8),
          Text(
            _pdfFileName!,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  Widget _buildContentInputCard() {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste syllabus or topic content',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter text here...',
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown<int>(
            label: 'Questions',
            value: _questionCount,
            items: [1, 2, 3, 4, 5, 10, 15, 20],
            onChanged: (val) => setState(() => _questionCount = val!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown<int>(
            label: 'Options',
            value: _optionCount,
            items: [2, 3, 4],
            onChanged: (val) => setState(() => _optionCount = val!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown<String>(
            label: 'Difficulty',
            value: _difficulty,
            items: ['easy', 'medium', 'hard'],
            onChanged: (val) => setState(() => _difficulty = val!),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(item.toString()),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generateQuestions,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Generate MCQs with AI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildQuestionsHeader() {
    return Text(
      'Generated Questions (${_questions.length})',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildQuestionsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Q${index + 1}: ${q.questionText}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit coming soon')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _questions.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(q.options.length, (optIndex) {
                  final isCorrect = optIndex == q.correctIndex;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCorrect ? Colors.green : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      '${String.fromCharCode(65 + optIndex)}. ${q.options[optIndex]}',
                      style: TextStyle(
                        color: isCorrect ? Colors.green.shade800 : Colors.black87,
                        fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
