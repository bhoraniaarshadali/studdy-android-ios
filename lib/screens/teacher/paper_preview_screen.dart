import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../models/generated_question_model.dart';
import '../../models/paper_section_model.dart';
import '../../services/paper_generator_service.dart';

class PaperPreviewScreen extends StatefulWidget {
  final List<GeneratedQuestion> questions;
  final List<PaperSection> sections;
  final String paperTitle;
  final int totalMarks;
  final String difficulty;
  final String template;

  const PaperPreviewScreen({
    super.key,
    required this.questions,
    required this.sections,
    required this.paperTitle,
    required this.totalMarks,
    required this.difficulty,
    required this.template,
  });

  @override
  State<PaperPreviewScreen> createState() => _PaperPreviewScreenState();
}

class _PaperPreviewScreenState extends State<PaperPreviewScreen> {
  late List<GeneratedQuestion> _questions;
  bool _isSaving = false;
  bool _isExporting = false;
  bool _showAnswerKey = false;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.questions);
    print(
      'PREVIEW: Loaded ${_questions.length} questions, ${widget.totalMarks} total marks',
    );
  }

  void _editQuestion(GeneratedQuestion question, int index) {
    print('PREVIEW: Editing question ${index + 1}');
    final textController = TextEditingController(text: question.questionText);
    final answerController = TextEditingController(text: question.answer);
    List<TextEditingController> optionControllers = [];

    if (question.questionType == 'mcq' && question.options != null) {
      optionControllers = question.options!
          .map((opt) => TextEditingController(text: opt))
          .toList();
    }

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
                'Edit Question',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Question Text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (question.questionType == 'mcq') ...[
                const Text(
                  'Options',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(4, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: optionControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Option ${['A', 'B', 'C', 'D'][i]}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }),
              ],
              TextField(
                controller: answerController,
                decoration: InputDecoration(
                  labelText: question.questionType == 'mcq'
                      ? 'Correct Answer Text (Must match an option exactly)'
                      : 'Correct Answer',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  setState(() {
                    _questions[index] = GeneratedQuestion(
                      questionText: textController.text,
                      questionType: question.questionType,
                      answer: answerController.text,
                      marks: question.marks,
                      difficulty: question.difficulty,
                      sectionName: question.sectionName,
                      options: question.questionType == 'mcq'
                          ? optionControllers.map((c) => c.text).toList()
                          : null,
                      sourceReference: question.sourceReference,
                      confidenceScore: question.confidenceScore,
                      isEditing: false,
                    );
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteQuestion(int index) {
    print('PREVIEW: Deleting question ${index + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text(
          'Are you sure you want to delete this question? This will affect the paper structure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _questions.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _savePaper() async {
    setState(() => _isSaving = true);
    try {
      print('SAVE: Generating PDF for Supabase upload...');

      // Generate PDF doc
      final pdfDoc = pw.Document();

      // Group questions by section
      final Map<String, List<GeneratedQuestion>> sectionQuestions = {};
      for (final section in widget.sections) {
        sectionQuestions[section.sectionName] = _questions
            .where((q) => q.sectionName == section.sectionName)
            .toList();
      }

      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  widget.paperTitle,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Total Marks: ${widget.totalMarks} | Questions: ${_questions.length} | Difficulty: ${widget.difficulty}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 4),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by Studdy',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          build: (context) {
            final List<pw.Widget> pageWidgets = [];
            int questionNumber = 1;

            for (final section in widget.sections) {
              final questions = sectionQuestions[section.sectionName] ?? [];
              if (questions.isEmpty) continue;

              // Section header
              pageWidgets.add(pw.SizedBox(height: 12));
              pageWidgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        section.sectionName,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 13),
                      ),
                      pw.Text(
                        '${section.totalMarks} Marks',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
              pageWidgets.add(pw.SizedBox(height: 8));

              // Questions
              for (final question in questions) {
                pageWidgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Question text with number and marks
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Q$questionNumber. ',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 12),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                question.questionText,
                                style: const pw.TextStyle(fontSize: 12),
                              ),
                            ),
                            pw.Text(
                              '[${question.marks}M]',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        // MCQ options
                        if (question.questionType == 'mcq' &&
                            question.options != null)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children:
                                  question.options!.asMap().entries.map((e) {
                                final label = ['A', 'B', 'C', 'D'][e.key];
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.only(bottom: 2),
                                  child: pw.Text(
                                    '($label) ${e.value}',
                                    style: const pw.TextStyle(fontSize: 11),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // True/False options
                        if (question.questionType == 'true_false')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Text(
                              '(A) True    (B) False',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),

                        // Fill blank
                        if (question.questionType == 'fill_blank')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Text(
                              'Answer: ______________________________',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),

                        // Short/Long answer lines
                        if (question.questionType == 'short')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Column(
                              children: List.generate(
                                  3,
                                  (_) => pw.Container(
                                        margin:
                                            const pw.EdgeInsets.only(top: 6),
                                        decoration: const pw.BoxDecoration(
                                          border: pw.Border(
                                              bottom: pw.BorderSide(
                                                  color: PdfColors.grey400)),
                                        ),
                                        height: 14,
                                      )),
                            ),
                          ),

                        if (question.questionType == 'long')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Column(
                              children: List.generate(
                                  6,
                                  (_) => pw.Container(
                                        margin:
                                            const pw.EdgeInsets.only(top: 6),
                                        decoration: const pw.BoxDecoration(
                                          border: pw.Border(
                                              bottom: pw.BorderSide(
                                                  color: PdfColors.grey400)),
                                        ),
                                        height: 14,
                                      )),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
                questionNumber++;
              }
            }

            return pageWidgets;
          },
        ),
      );

      // Add Answer Key page
      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  'ANSWER KEY - ${widget.paperTitle}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Divider(thickness: 1.5),
            ],
          ),
          build: (context) {
            final List<pw.Widget> answerWidgets = [];
            int qNum = 1;

            for (final section in widget.sections) {
              final questions = sectionQuestions[section.sectionName] ?? [];
              if (questions.isEmpty) continue;

              answerWidgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
                  child: pw.Text(
                    section.sectionName,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12),
                  ),
                ),
              );

              for (final question in questions) {
                answerWidgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Q$qNum. ',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            question.answer,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                qNum++;
              }
            }

            return answerWidgets;
          },
        ),
      );

      final Uint8List pdfBytes = await pdfDoc.save();

      await PaperGeneratorService.savePaper(
        title: widget.paperTitle,
        totalMarks: widget.totalMarks,
        sections: widget.sections,
        questions: _questions,
        difficulty: widget.difficulty,
        template: widget.template,
        pdfBytes: pdfBytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paper saved to cloud successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('SAVE: ERROR - $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _exportPDF() async {
    setState(() => _isExporting = true);
    print('EXPORT: Starting PDF generation');

    try {
      final pdf = pw.Document();

      // Group questions by section
      final Map<String, List<GeneratedQuestion>> sectionQuestions = {};
      for (final section in widget.sections) {
        sectionQuestions[section.sectionName] = _questions
            .where((q) => q.sectionName == section.sectionName)
            .toList();
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  widget.paperTitle,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Total Marks: ${widget.totalMarks} | Questions: ${_questions.length} | Difficulty: ${widget.difficulty}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 4),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by Studdy',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          build: (context) {
            final List<pw.Widget> pageWidgets = [];
            int questionNumber = 1;

            for (final section in widget.sections) {
              final questions = sectionQuestions[section.sectionName] ?? [];
              if (questions.isEmpty) continue;

              // Section header
              pageWidgets.add(pw.SizedBox(height: 12));
              pageWidgets.add(
                pw.Container(
                  width: double.infinity,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        section.sectionName,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 13),
                      ),
                      pw.Text(
                        '${section.totalMarks} Marks',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
              pageWidgets.add(pw.SizedBox(height: 8));

              // Questions
              for (final question in questions) {
                pageWidgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Question text with number and marks
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Q$questionNumber. ',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 12),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                question.questionText,
                                style: const pw.TextStyle(fontSize: 12),
                              ),
                            ),
                            pw.Text(
                              '[${question.marks}M]',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        // MCQ options
                        if (question.questionType == 'mcq' &&
                            question.options != null)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children:
                                  question.options!.asMap().entries.map((e) {
                                final label = ['A', 'B', 'C', 'D'][e.key];
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.only(bottom: 2),
                                  child: pw.Text(
                                    '($label) ${e.value}',
                                    style: const pw.TextStyle(fontSize: 11),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // True/False options
                        if (question.questionType == 'true_false')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Text(
                              '(A) True    (B) False',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),

                        // Fill blank
                        if (question.questionType == 'fill_blank')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Text(
                              'Answer: ______________________________',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),

                        // Short/Long answer lines
                        if (question.questionType == 'short')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Column(
                              children: List.generate(
                                  3,
                                  (_) => pw.Container(
                                        margin:
                                            const pw.EdgeInsets.only(top: 6),
                                        decoration: const pw.BoxDecoration(
                                          border: pw.Border(
                                              bottom: pw.BorderSide(
                                                  color: PdfColors.grey400)),
                                        ),
                                        height: 14,
                                      )),
                            ),
                          ),

                        if (question.questionType == 'long')
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Column(
                              children: List.generate(
                                  6,
                                  (_) => pw.Container(
                                        margin:
                                            const pw.EdgeInsets.only(top: 6),
                                        decoration: const pw.BoxDecoration(
                                          border: pw.Border(
                                              bottom: pw.BorderSide(
                                                  color: PdfColors.grey400)),
                                        ),
                                        height: 14,
                                      )),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
                questionNumber++;
              }
            }

            return pageWidgets;
          },
        ),
      );

      // Add Answer Key page if _showAnswerKey
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  'ANSWER KEY - ${widget.paperTitle}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Divider(thickness: 1.5),
            ],
          ),
          build: (context) {
            final List<pw.Widget> answerWidgets = [];
            int qNum = 1;

            for (final section in widget.sections) {
              final questions = sectionQuestions[section.sectionName] ?? [];
              if (questions.isEmpty) continue;

              answerWidgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
                  child: pw.Text(
                    section.sectionName,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12),
                  ),
                ),
              );

              for (final question in questions) {
                answerWidgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Q$qNum. ',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            question.answer,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                qNum++;
              }
            }

            return answerWidgets;
          },
        ),
      );

      print('EXPORT: PDF generated, saving to device storage');

      // Generate PDF bytes
      final Uint8List pdfBytes = await pdf.save();

      // Save to Downloads directory
      String savePath = '';

      if (Platform.isAndroid) {
        // Save to Downloads folder
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        final fileName =
            '${widget.paperTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        savePath = '${directory.path}/$fileName';
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            '${widget.paperTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        savePath = '${directory.path}/$fileName';
      } else {
        final directory = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final fileName =
            '${widget.paperTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        savePath = '${directory.path}/$fileName';
      }

      // Write file
      final file = File(savePath);
      await file.writeAsBytes(pdfBytes);
      print('EXPORT: PDF saved at: $savePath');

      // Open the file
      final result = await OpenFile.open(savePath);
      print('EXPORT: Open file result: ${result.message}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PDF saved successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(savePath,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => OpenFile.open(savePath),
          ),
        ),
      );
      print('EXPORT: PDF export completed');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF saved locally and uploaded to cloud!'),
          backgroundColor: Colors.green,
        ),
      );

      // Then save to Supabase
      print('EXPORT: Saving paper to Supabase...');
      await PaperGeneratorService.savePaper(
        title: widget.paperTitle,
        totalMarks: widget.totalMarks,
        sections: widget.sections,
        questions: _questions,
        difficulty: widget.difficulty,
        template: widget.template,
        pdfBytes: pdfBytes,
      );
      print('EXPORT: Paper saved to Supabase successfully');
    } catch (e) {
      print('EXPORT: ERROR - $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.paperTitle),
        actions: [
          IconButton(
            icon: Icon(_showAnswerKey ? Icons.key_off : Icons.key),
            tooltip: 'Toggle Answer Key',
            onPressed: () => setState(() => _showAnswerKey = !_showAnswerKey),
          ),
          _isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _exportPDF,
                  tooltip: 'Export PDF',
                ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _savePaper,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // HEADER CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'EXAM PAPER',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.paperTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _headerChip(
                        Icons.star,
                        'Total: ${widget.totalMarks} Marks',
                      ),
                      _headerChip(Icons.quiz, '${_questions.length} Questions'),
                      _headerChip(Icons.speed, widget.difficulty),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // STATS ROW
            Row(
              children: [
                _buildMetricCard('Sections', widget.sections.length.toString()),
                const SizedBox(width: 12),
                _buildMetricCard('Questions', _questions.length.toString()),
                const SizedBox(width: 12),
                _buildMetricCard('Total marks', widget.totalMarks.toString()),
              ],
            ),
            const SizedBox(height: 24),

            // SECTIONS AND QUESTIONS
            ...widget.sections.map((section) {
              final sectionQuestions = _questions
                  .where((q) => q.sectionName == section.sectionName)
                  .toList();
              if (sectionQuestions.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          section.sectionName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${section.totalMarks} marks',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sectionQuestions.asMap().entries.map((entry) {
                    final qIdx = entry.key;
                    final question = entry.value;
                    final overallIdx = _questions.indexOf(question);

                    return _buildQuestionCard(question, overallIdx, qIdx);
                  }).toList(),
                  const SizedBox(height: 20),
                ],
              );
            }).toList(),
            const SizedBox(height: 60),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _showAnswerKey = !_showAnswerKey),
                  icon: const Icon(Icons.key),
                  label: Text(_showAnswerKey ? 'Hide Answers' : 'Show Answers'),
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportPDF,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePaper,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save Paper'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    GeneratedQuestion question,
    int overallIdx,
    int qIdx,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question number badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${qIdx + 1}',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                        question.questionText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // MCQ options
                      if (question.questionType == 'mcq' &&
                          question.options != null)
                        Column(
                          children: question.options!.asMap().entries.map((e) {
                            final label = ['A', 'B', 'C', 'D'][e.key];
                            final isCorrect =
                                _showAnswerKey && question.answer == e.value;
                            return Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? Colors.green.shade50
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCorrect
                                      ? Colors.green.shade300
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '$label. ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(child: Text(e.value)),
                                  if (isCorrect)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                      // True/False options
                      if (question.questionType == 'true_false')
                        Row(
                          children: [
                            _trueFalseOption(
                              'True',
                              question.answer == 'True' && _showAnswerKey,
                            ),
                            const SizedBox(width: 12),
                            _trueFalseOption(
                              'False',
                              question.answer == 'False' && _showAnswerKey,
                            ),
                          ],
                        ),

                      // Fill blank
                      if (question.questionType == 'fill_blank')
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: _showAnswerKey
                              ? Text(
                                  'Answer: ${question.answer}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const Text('________________________'),
                        ),

                      // Short
                      if (question.questionType == 'short')
                        _showAnswerKey
                            ? Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade100,
                                  ),
                                ),
                                child: Text(
                                  'Answer: ${question.answer}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Column(
                                children: List.generate(
                                  3,
                                  (index) => Divider(
                                    color: Colors.grey.shade300,
                                    height: 24,
                                    thickness: 1,
                                  ),
                                ),
                              ),

                      // Long
                      if (question.questionType == 'long')
                        _showAnswerKey
                            ? Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade100,
                                  ),
                                ),
                                child: Text(
                                  'Answer: ${question.answer}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Column(
                                children: List.generate(
                                  6,
                                  (index) => Divider(
                                    color: Colors.grey.shade300,
                                    height: 24,
                                    thickness: 1,
                                  ),
                                ),
                              ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Marks badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '[${question.marks}M]',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // Source reference
            if (question.sourceReference != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 40),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        question.sourceReference!,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editQuestion(question, overallIdx),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteQuestion(overallIdx),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trueFalseOption(String label, bool isCorrect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCorrect ? Colors.green.shade400 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCorrect) const Icon(Icons.check, color: Colors.green, size: 14),
          if (isCorrect) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isCorrect ? Colors.green.shade700 : Colors.black87,
              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
