import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../models/question_model.dart';
import '../../services/kie_ai_service.dart';

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

  Future<void> _pickPDF() async {
    print('PDF_PICK: Button tapped');
    try {
      print('PDF_PICK: FilePicker opened');
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
        print('PDF_PICK: File selected - name: $_pdfFileName, bytes: ${_pdfBytes?.length}');
      } else {
        print('PDF_PICK: No file selected, user cancelled');
      }
    } catch (e) {
      print('PDF_PICK: ERROR - $e');
    }
  }

  Future<String> _extractTextFromPDF() async {
    if (_pdfBytes == null) return '';

    print('PDF_EXTRACT: Starting extraction');
    print('PDF_EXTRACT: PDF bytes size: ${_pdfBytes?.length}');
    setState(() => _statusText = 'Extracting PDF content...');
    final base64String = base64Encode(_pdfBytes!);
    print('PDF_EXTRACT: Base64 string length: ${base64String.length}');

    try {
      print('PDF_EXTRACT: Sending request to KIE API');
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

      print('PDF_EXTRACT: Response status: ${response.statusCode}');
      print('PDF_EXTRACT: Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String text = data['candidates'][0]['content']['parts'][0]['text'];
        print('PDF_EXTRACT: Extracted text preview: ${text.substring(0, text.length > 200 ? 200 : text.length)}');
        print('PDF_EXTRACT: Total text length: ${text.length}');
        return text;
      } else {
        throw Exception('Failed to extract PDF text: ${response.statusCode}');
      }
    } catch (e) {
      print('PDF_EXTRACT: ERROR - $e');
      rethrow;
    }
  }

  Future<void> _generateQuestions() async {
    print('GENERATE: Button tapped');
    print('GENERATE: PDF selected: ${_pdfBytes != null}');
    print('GENERATE: Manual text length: ${_contentController.text.length}');
    
    String content = '';
    
    if (_pdfBytes != null) {
      print('GENERATE: Using PDF content');
      try {
        content = await _extractTextFromPDF();
      } catch (e) {
        print('GENERATE: ERROR - $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting PDF: $e')),
        );
        setState(() => _statusText = '');
        return;
      }
    } else if (_contentController.text.trim().isNotEmpty) {
      print('GENERATE: Using manual text');
      content = _contentController.text.trim();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a PDF or enter content')),
      );
      return;
    }

    print('CreateExam: content length: ${content.length}, questions: $_questionCount, options: $_optionCount, difficulty: $_difficulty');
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
      print('GENERATE: Total questions: ${questions.length}');
      setState(() {
        _questions = questions;
        _isLoading = false;
        _statusText = '';
      });
    } catch (e) {
      print('GENERATE: ERROR - $e');
      setState(() {
        _isLoading = false;
        _statusText = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
              ],
            ],
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
            items: [3, 5, 10, 15],
            onChanged: (val) => setState(() => _questionCount = val!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown<int>(
            label: 'Options',
            value: _optionCount,
            items: [3, 4],
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
