import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/paper_section_model.dart';
import '../../services/paper_generator_service.dart';
import 'paper_preview_screen.dart'; // To be created next

class ExamPaperGeneratorScreen extends StatefulWidget {
  const ExamPaperGeneratorScreen({super.key});

  @override
  State<ExamPaperGeneratorScreen> createState() =>
      _ExamPaperGeneratorScreenState();
}

class _ExamPaperGeneratorScreenState extends State<ExamPaperGeneratorScreen> {
  Uint8List? _pdfBytes;
  String? _pdfFileName;
  String _pdfContent = '';
  String _pdfType = 'unknown';
  bool _isSyllabus = false;
  bool _isExtractingPdf = false;
  bool _isGenerating = false;
  String _generationStatus = '';
  int _generationCurrent = 0;
  int _generationTotal = 0;
  String _paperTitle = '';
  String _template = 'college_internal';
  String _overallDifficulty = 'balanced';
  int _totalMarks = 50;
  List<PaperSection> _sections = [];
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default sections
    _sections = [
      PaperSection(
        sectionName: 'Section A - MCQ',
        questionType: 'mcq',
        questionCount: 10,
        marksPerQuestion: 1,
        difficulty: 'easy',
      ),
      PaperSection(
        sectionName: 'Section B - Short Answers',
        questionType: 'short',
        questionCount: 5,
        marksPerQuestion: 2,
        difficulty: 'medium',
      ),
    ];
    _updateTotalMarks();
  }

  void _updateTotalMarks() {
    setState(() {
      _totalMarks = _sections.fold(0, (sum, s) => sum + s.totalMarks);
    });
    print('PAPER_SCREEN: Total marks updated: $_totalMarks');
  }

  Future<void> _pickPDF() async {
    try {
      print('PAPER_SCREEN: Opening file picker');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Necessary for bytes on mobile
      );

      if (result != null) {
        final platformFile = result.files.single;
        Uint8List? fileBytes = platformFile.bytes;

        // On some Android versions, even with withData: true, bytes might be null.
        // In that case, we read from path.
        if (fileBytes == null && platformFile.path != null) {
          print(
            'PAPER_SCREEN: Bytes null, reading from path: ${platformFile.path}',
          );
          final file = File(platformFile.path!);
          fileBytes = await file.readAsBytes();
        }

        if (fileBytes != null) {
          setState(() {
            _pdfBytes = fileBytes;
            _pdfFileName = platformFile.name;
            _pdfContent = ''; // Reset content
          });
          print(
            'PAPER_SCREEN: PDF selected: $_pdfFileName (${_pdfBytes!.length} bytes)',
          );
          _extractPDF();
        } else {
          print('PAPER_SCREEN: Error - Could not get bytes from file');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not read PDF file. Please try another.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('PAPER_SCREEN: Error picking PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking PDF: $e')));
      }
    }
  }

  Future<void> _extractPDF() async {
    if (_pdfBytes == null) return;

    setState(() {
      _isExtractingPdf = true;
    });

    try {
      final text =
          await PaperGeneratorService.extractTextFromPDF(_pdfBytes!);
      
      // Basic syllabus detection since we moved away from the old service structure
      final bool detectedSyllabus = text.toLowerCase().contains('syllabus') || 
                                   text.toLowerCase().contains('course outline') ||
                                   text.toLowerCase().contains('unit 1');

      setState(() {
        _pdfContent = text;
        _pdfType = detectedSyllabus ? 'syllabus' : 'chapter';
        _isSyllabus = detectedSyllabus;
        _isExtractingPdf = false;
      });

      print('PAPER_SCREEN: PDF type: $_pdfType, isSyllabus: $_isSyllabus');

      // Show warning if syllabus detected
      if (_isSyllabus) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Syllabus detected! Questions will be based on topics listed, not course structure.',
              )),
            ]),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'PDF content extracted! Type: ${_pdfType.toUpperCase()}')),
        );
      }

      print(
          'PAPER_SCREEN: PDF extracted, length: ${_pdfContent.length}, type: $_pdfType');
    } catch (e) {
      setState(() {
        _isExtractingPdf = false;
      });
      print('PAPER_SCREEN: Error extracting PDF: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error extracting PDF: $e')));
    }
  }

  void _addSection() {
    String sectionName = '';
    String questionType = 'mcq';
    int questionCount = 5;
    int marksPerQuestion = 2;
    String difficulty = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Section',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Section Name (e.g. Section C)',
                ),
                onChanged: (val) => sectionName = val,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: questionType,
                decoration: const InputDecoration(labelText: 'Question Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'mcq',
                    child: Text('MCQ (Multiple Choice)'),
                  ),
                  DropdownMenuItem(value: 'short', child: Text('Short Answer')),
                  DropdownMenuItem(value: 'long', child: Text('Long Answer')),
                  DropdownMenuItem(
                    value: 'true_false',
                    child: Text('True / False'),
                  ),
                  DropdownMenuItem(
                    value: 'fill_blank',
                    child: Text('Fill in the Blank'),
                  ),
                ],
                onChanged: (val) => setSheetState(() => questionType = val!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Question Count'),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => setSheetState(
                                () =>
                                    questionCount > 1 ? questionCount-- : null,
                              ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$questionCount',
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              onPressed: () => setSheetState(
                                () =>
                                    questionCount < 20 ? questionCount++ : null,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Marks Per Q'),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => setSheetState(
                                () => marksPerQuestion > 1
                                    ? marksPerQuestion--
                                    : null,
                              ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$marksPerQuestion',
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              onPressed: () => setSheetState(
                                () => marksPerQuestion < 10
                                    ? marksPerQuestion++
                                    : null,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                ],
                onChanged: (val) => setSheetState(() => difficulty = val!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  if (sectionName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter section name'),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _sections.add(
                      PaperSection(
                        sectionName: sectionName,
                        questionType: questionType,
                        questionCount: questionCount,
                        marksPerQuestion: marksPerQuestion,
                        difficulty: difficulty,
                      ),
                    );
                  });
                  _updateTotalMarks();
                  Navigator.pop(context);
                },
                child: const Text('Add Section'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _removeSection(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Section'),
        content: Text(
          'Are you sure you want to remove "${_sections[index].sectionName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _sections.removeAt(index);
              });
              _updateTotalMarks();
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePaper() async {
    if (_pdfBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a PDF first')),
      );
      return;
    }
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter paper title')));
      return;
    }
    if (_sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one section')),
      );
      return;
    }
    if (_pdfContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF content not extracted yet')),
      );
      return;
    }

    print('PAPER_SCREEN: Generate button tapped');
    setState(() {
      _isGenerating = true;
    });

    try {
      final questions = await PaperGeneratorService.generateFullPaper(
        pdfContent: _pdfContent,
        sections: _sections,
        paperTitle: _titleController.text,
        overallDifficulty: _overallDifficulty,
        pdfType: _pdfType,
        onProgress: (status, current, total) {
          setState(() {
            _generationStatus = status;
            _generationCurrent = current;
            _generationTotal = total;
          });
        },
      );

      setState(() {
        _generationStatus = 'Saving paper to cloud...';
      });

      await PaperGeneratorService.savePaper(
        title: _titleController.text.trim(),
        totalMarks: _totalMarks,
        sections: _sections,
        questions: questions,
        difficulty: _overallDifficulty,
        template: _template,
        pdfBytes: null, // PDF will be saved after export
      );

      print('PAPER_SCREEN: Paper auto-saved to DB');

      setState(() {
        _isGenerating = false;
      });

      print('PAPER_SCREEN: Generation complete, navigating to preview');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaperPreviewScreen(
            questions: questions,
            sections: _sections,
            paperTitle: _titleController.text,
            totalMarks: _totalMarks,
            difficulty: _overallDifficulty,
            template: _template,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      print('PAPER_SCREEN: Error generating paper: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating paper: $e')));
    }
  }

  Color _getSectionColor(String type) {
    switch (type) {
      case 'mcq':
        return Colors.blue;
      case 'short':
        return Colors.green;
      case 'long':
        return Colors.orange;
      case 'true_false':
        return Colors.purple;
      case 'fill_blank':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getSectionIcon(String type) {
    switch (type) {
      case 'mcq':
        return Icons.list;
      case 'short':
        return Icons.short_text;
      case 'long':
        return Icons.article;
      case 'true_false':
        return Icons.check_circle_outline;
      case 'fill_blank':
        return Icons.edit;
      default:
        return Icons.question_mark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Paper Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STEP INDICATOR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStep(1, 'Upload PDF', _pdfBytes != null),
                _buildStep(2, 'Configure', _sections.isNotEmpty),
                _buildStep(3, 'Generate', _isGenerating),
              ],
            ),
            const SizedBox(height: 24),

            // SECTION 1 — Upload PDF Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    if (_pdfBytes == null) ...[
                      const Text(
                        'Upload Syllabus PDF',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'AI will generate questions strictly from this PDF',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _pickPDF,
                        child: const Text('Choose PDF'),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pdfFileName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isExtractingPdf) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text(
                          'Extracting content...',
                          style: TextStyle(fontSize: 12),
                        ),
                      ] else if (_pdfContent.isNotEmpty) ...[
                        Text(
                          'Content extracted (${_pdfContent.length} chars)',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      TextButton(
                        onPressed: _pickPDF,
                        child: const Text('Change PDF'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 2 — Paper Settings Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Paper Title',
                        hintText: 'e.g. Mid-Term Exam - Unit 3',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Template',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String>(
                      value: _template,
                      items: const [
                        DropdownMenuItem(
                          value: 'school_exam',
                          child: Text('School Exam'),
                        ),
                        DropdownMenuItem(
                          value: 'college_internal',
                          child: Text('College Internal'),
                        ),
                        DropdownMenuItem(
                          value: 'mcq_test',
                          child: Text('MCQ Only Test'),
                        ),
                        DropdownMenuItem(
                          value: 'unit_test',
                          child: Text('Unit Test'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _template = val!),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Overall Difficulty',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDifficultyChip(
                          'easy',
                          'Easy Paper',
                          Colors.green,
                        ),
                        _buildDifficultyChip(
                          'balanced',
                          'Balanced',
                          Colors.blue,
                        ),
                        _buildDifficultyChip(
                          'tough',
                          'Tough Paper',
                          Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECTION 3 — Paper Structure Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Paper Structure',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _addSection,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            "Total Marks:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            "$_totalMarks marks",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._sections.asMap().entries.map((entry) {
                      int idx = entry.key;
                      PaperSection section = entry.value;
                      return _buildSectionItem(section, idx);
                    }).toList(),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Section'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(color: Colors.blue.shade300),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // SECTION 4 — Generate Button
            if (_isGenerating)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _generationTotal > 0
                        ? _generationCurrent / _generationTotal
                        : null,
                    backgroundColor: Colors.purple.shade50,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _generationStatus,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  Text(
                    'Section $_generationCurrent of $_generationTotal',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _generatePaper,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Exam Paper with AI'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step, String label, bool isDone) {
    bool isActive = false;
    if (step == 1 && _pdfBytes == null) isActive = true;
    if (step == 2 && _pdfBytes != null && _sections.isNotEmpty) isActive = true;
    if (step == 3 && _isGenerating) isActive = true;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green
                : (isActive ? Colors.blue : Colors.grey.shade300),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDone || isActive ? Colors.black : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyChip(String value, String label, Color color) {
    bool isSelected = _overallDifficulty == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      onSelected: (selected) {
        if (selected) setState(() => _overallDifficulty = value);
      },
    );
  }

  Widget _buildSectionItem(PaperSection section, int index) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getSectionColor(
                      section.questionType,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getSectionIcon(section.questionType),
                    color: _getSectionColor(section.questionType),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.sectionName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${section.questionCount} questions × ${section.marksPerQuestion} marks = ${section.totalMarks} marks',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _removeSection(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildBadge(
                    section.questionType.toUpperCase(),
                    _getSectionColor(section.questionType),
                  ),
                  _buildBadge(section.difficulty.toUpperCase(), Colors.grey),
                ],
              ),
            ),
          ],
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
        border: Border.all(color: color.withOpacity(0.2)),
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
}
