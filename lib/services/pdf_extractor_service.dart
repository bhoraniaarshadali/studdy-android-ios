import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractorService {
  
  static Future<String> extractText(Uint8List pdfBytes) async {
    try {
      print('PDF_LOCAL: Starting local extraction...');
      final document = PdfDocument(inputBytes: pdfBytes);
      final extractor = PdfTextExtractor(document);
      
      final StringBuffer buffer = StringBuffer();
      final int pageCount = document.pages.count;
      
      print('PDF_LOCAL: Total pages: $pageCount');
      
      for (int i = 0; i < pageCount; i++) {
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.trim().isNotEmpty) {
          buffer.writeln('[Page ${i + 1}]');
          buffer.writeln(pageText.trim());
          buffer.writeln();
        }
        print('PDF_LOCAL: Page ${i+1} extracted - ${pageText.length} chars');
      }
      
      document.dispose();
      
      final result = buffer.toString();
      print('PDF_LOCAL: Total extracted: ${result.length} characters');
      return result;
    } catch (e) {
      print('PDF_LOCAL: ERROR - $e');
      throw Exception('Local PDF extraction failed: $e');
    }
  }
  
  static bool isLikelySyllabus(String text) {
    final syllabusKeywords = [
      'unit', 'chapter', 'module', 'topic', 'syllabus',
      'course outline', 'credit', 'hours', 'semester',
      'marks distribution', 'weight', 'reference book',
      'textbook', 'co ', 'peo', 'pso', 'bloom',
    ];
    
    final lowerText = text.toLowerCase();
    int matchCount = 0;
    for (final keyword in syllabusKeywords) {
      if (lowerText.contains(keyword)) matchCount++;
    }
    
    print('PDF_LOCAL: Syllabus keywords found: $matchCount');
    return matchCount >= 3;
  }
  
  static bool isLikelyChapterContent(String text) {
    final contentKeywords = [
      'definition', 'example', 'figure', 'table',
      'equation', 'formula', 'theorem', 'proof',
      'introduction', 'conclusion', 'summary',
      'therefore', 'however', 'moreover',
    ];
    
    final lowerText = text.toLowerCase();
    int matchCount = 0;
    for (final keyword in contentKeywords) {
      if (lowerText.contains(keyword)) matchCount++;
    }
    
    print('PDF_LOCAL: Chapter content keywords found: $matchCount');
    return matchCount >= 3;
  }
}
