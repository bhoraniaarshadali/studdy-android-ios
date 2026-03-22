import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'student_entry_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> with SingleTickerProviderStateMixin {
  bool _isScanned = false;
  String _scannedCode = '';
  late AnimationController _animationController;
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isFlashOn = false;
  bool _isProcessingGallery = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onCodeScanned(String code) {
    if (_isScanned) return;
    
    setState(() {
      _isScanned = true;
      _scannedCode = code;
    });

    print('QR: Scanned code: $code');
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(
            builder: (_) => StudentEntryScreen(prefilledCode: code),
          ),
        );
      }
    });
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessingGallery = true);
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) {
        setState(() => _isProcessingGallery = false);
        return;
      }

      print('QR_GALLERY: Analyzing image: ${image.path}');
      
      // Analyze image for QR codes
      final BarcodeCapture? result = await _scannerController.analyzeImage(image.path);
      
      if (result != null && result.barcodes.isNotEmpty) {
        final code = result.barcodes.first.rawValue;
        if (code != null && code.length == 6) {
          print('QR_GALLERY: QR found in image: $code');
          _onCodeScanned(code);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid code detected. Must be a 6-character exam code.'),
                backgroundColor: Colors.orange,
              )
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No QR code found in this image. Try another image.'),
              backgroundColor: Colors.red,
            )
          );
        }
        print('QR_GALLERY: No QR found in image');
      }
    } catch (e) {
      print('QR_GALLERY: ERROR - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read image. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingGallery = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Scan QR Code", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isFlashOn = !_isFlashOn);
              _scannerController.toggleTorch();
            },
            icon: Icon(
              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isFlashOn ? Colors.yellow : Colors.white,
            ),
          ),
        ],
      ),
      body: kIsWeb
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'QR scanning is not available on web.',
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please enter the exam code manually.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Scanner
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    if (_isScanned) return;
                    final barcode = capture.barcodes.first;
                    final code = barcode.rawValue;
                    
                    if (code != null && code.length == 6) {
                      _onCodeScanned(code);
                    }
                  },
                ),
                
                // Enhanced Overlay
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ScannerOverlayPainter(
                        scanLinePosition: _animationController.value,
                        isScanned: _isScanned,
                      ),
                      child: Container(),
                    );
                  },
                ),
                
                // UI Elements
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 80),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Text(
                              "Point at the Exam QR Code",
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isScanned) 
                        Expanded(
                          child: Center(
                            child: _buildScanSuccessUI(),
                          ),
                        )
                      else 
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isProcessingGallery ? null : _pickFromGallery,
                                icon: _isProcessingGallery 
                                  ? const SizedBox(
                                      width: 18, 
                                      height: 18, 
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                    )
                                  : const Icon(Icons.photo_library_outlined, color: Colors.white),
                                label: Text(
                                  _isProcessingGallery ? 'Reading QR...' : 'Select from Gallery',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white38),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildGuidanceText(),
                            ],
                          ),
                        ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGuidanceText() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: const Text(
        "Make sure the QR code is centered and well-lit",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  Widget _buildScanSuccessUI() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 30, spreadRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            "Success!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            "Registration auto-joining...",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double scanLinePosition;
  final bool isScanned;

  ScannerOverlayPainter({required this.scanLinePosition, required this.isScanned});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double scanAreaSize = 260.0;
    final double left = (width - scanAreaSize) / 2;
    final double top = (height - scanAreaSize) / 2;
    final double right = left + scanAreaSize;
    final double bottom = top + scanAreaSize;
    final Radius cornerRadius = const Radius.circular(20);

    final Paint backgroundPaint = Paint()..color = Colors.black.withOpacity(0.7);
    final Paint borderPaint = Paint()
      ..color = isScanned ? Colors.green : Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint accentPaint = Paint()
      ..color = isScanned ? Colors.green : Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // 1. Draw Hole (Darken strictly outside the box)
    final Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, width, height));
    final Path holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(left, top, right, bottom), cornerRadius));
    
    final Path finalPath = Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(finalPath, backgroundPaint);

    // 2. Draw Rounded Border
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(left, top, right, bottom), cornerRadius), borderPaint);

    // 3. Draw Corner Accents
    const double length = 40.0;
    const double arcRadius = 20.0;
    
    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + length)
        ..lineTo(left, top + arcRadius)
        ..arcToPoint(Offset(left + arcRadius, top), radius: cornerRadius)
        ..lineTo(left + length, top),
      accentPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(right - length, top)
        ..lineTo(right - arcRadius, top)
        ..arcToPoint(Offset(right, top + arcRadius), radius: cornerRadius, clockwise: true)
        ..lineTo(right, top + length),
      accentPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - length)
        ..lineTo(left, bottom - arcRadius)
        ..arcToPoint(Offset(left + arcRadius, bottom), radius: cornerRadius, clockwise: false)
        ..lineTo(left + length, bottom),
      accentPaint,
    );

    // Bottom Right
    final Path brPath = Path()
      ..moveTo(right, bottom - length)
      ..lineTo(right, bottom - arcRadius)
      ..arcToPoint(Offset(right - arcRadius, bottom), radius: cornerRadius, clockwise: true)
      ..lineTo(right - length, bottom);
    canvas.drawPath(brPath, accentPaint);

    // 4. Draw Scanning Line (only if not scanned)
    if (!isScanned) {
      final double linePadding = 15.0;
      final double y = top + (scanAreaSize * scanLinePosition);
      
      // Glow effect for line
      final Paint glowPaint = Paint()
        ..color = isScanned ? Colors.green.withOpacity(0.3) : Colors.blueAccent.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRect(Rect.fromLTWH(left + linePadding, y - 1, scanAreaSize - (linePadding * 2), 2), glowPaint);

      // Main Line
      canvas.drawLine(
        Offset(left + linePadding, y), 
        Offset(right - linePadding, y), 
        accentPaint..strokeWidth = 2.5
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) => true;
}
