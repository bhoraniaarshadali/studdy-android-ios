import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractionService {
  
  static Future<String> extractText(Uint8List pdfBytes) async {
    try {
      print('PDF_EXTRACT: Starting local extraction using Syncfusion');
      print('PDF_SERVICE: Syncfusion extraction started'); // Added as requested
      
      // Load PDF document
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      
      final StringBuffer extractedText = StringBuffer();
      
      // Extract text page by page
      for (int i = 0; i < document.pages.count; i++) {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        
        if (pageText.isNotEmpty) {
          extractedText.write('[Page ${i + 1}]\n');
          extractedText.write(pageText);
          extractedText.write('\n\n');
        }
        
        print('PDF_EXTRACT: Page ${i + 1}/${document.pages.count} extracted - ${pageText.length} chars');
        print('PDF_SERVICE: Page ${i + 1} extracted successfully'); // Added as requested
      }
      
      final int pageCount = document.pages.count;
      // Dispose document
      document.dispose();
      
      final String result = extractedText.toString();
      print('PDF_EXTRACT: Total extracted: ${result.length} characters from $pageCount pages');
      print('PDF_SERVICE: All pages done, total: ${result.length} chars'); // Added as requested
      return result;
      
    } catch (e) {
      print('PDF_EXTRACT: Syncfusion ERROR - $e');
      throw Exception('Failed to extract PDF text: $e');
    }
  }
  
  static Future<Map<String, dynamic>> extractTextWithMetadata(Uint8List pdfBytes) async {
    try {
      print('PDF_EXTRACT: Starting extraction with metadata');
      print('PDF_SERVICE: Syncfusion extraction started'); // Requested log
      
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final StringBuffer extractedText = StringBuffer();
      final List<Map<String, dynamic>> pages = [];
      
      for (int i = 0; i < document.pages.count; i++) {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        
        pages.add({
          'page': i + 1,
          'text': pageText,
          'char_count': pageText.length,
        });
        
        if (pageText.isNotEmpty) {
          extractedText.write('[Page ${i + 1}]\n');
          extractedText.write(pageText);
          extractedText.write('\n\n');
        }
        print('PDF_SERVICE: Page ${i + 1} extracted successfully'); // Requested log
      }
      
      final int totalPages = document.pages.count;
      document.dispose();
      
      final result = {
        'text': extractedText.toString(),
        'total_pages': totalPages,
        'pages': pages,
        'total_chars': extractedText.length,
      };
      
      print('PDF_EXTRACT: Done - $totalPages pages, ${extractedText.length} total chars');
      print('PDF_SERVICE: All pages done, total: ${extractedText.length} chars'); // Requested log
      return result;
      
    } catch (e) {
      print('PDF_EXTRACT: ERROR with metadata - $e');
      throw Exception('Failed to extract PDF: $e');
    }
  }
}
