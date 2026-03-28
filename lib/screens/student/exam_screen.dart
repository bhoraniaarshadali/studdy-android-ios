import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:camera/camera.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'dart:async';
import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../models/question_model.dart';
import '../../services/supabase_service.dart';
import '../auth/login_screen.dart';

class StudentExamScreen extends StatefulWidget {
  final List<QuestionModel> questions;
  final String examCode;
  final String enrollmentNumber;
  final Map<String, dynamic>? timerData;

  const StudentExamScreen({
    super.key,
    required this.questions,
    required this.examCode,
    required this.enrollmentNumber,
    this.timerData,
  });

  @override
  State<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends State<StudentExamScreen> with WidgetsBindingObserver {
  int _currentQuestion = 0;
  late List<int?> _selectedAnswers;
  bool _isSubmitting = false;
  bool _examSubmitted = false;
  int _score = 0;
  bool _resultsPublished = false;
  bool _isCheckingResults = false;

  // Timer state
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _timerExpired = false;
  String _timerMode = 'none';

  // Anti-cheat state variables
  int _warningCount = 0;
  bool _examPaused = false;
  bool _cameraInitialized = false;
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _faceDetected = true;
  int _noFaceCount = 0;
  static const int _maxNoFaceCount = 3;
  Timer? _faceCheckTimer;
  int _appSwitchCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedAnswers = List.filled(widget.questions.length, null);
    debugPrint('EXAM: Started for ${widget.enrollmentNumber}, questions: ${widget.questions.length}');
    
    // Anti-cheat setup
    WidgetsBinding.instance.addObserver(this);
    
    // Fullscreen lock
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Screen on raho
    WakelockPlus.enable();
    
    // Screenshot block (Android/iOS)
    NoScreenshot.instance.screenshotOff();
    
    // Initialize camera for proctoring
    _initCamera();
    
    print('ANTICHEAT: Fullscreen enabled');
    print('ANTICHEAT: Screenshot blocked');
    print('ANTICHEAT: Wakelock enabled');

    // Initialize Timer
    if (widget.timerData != null && widget.timerData!['valid'] == true) {
      if (widget.timerData!.containsKey('durationMinutes')) {
        _timerMode = 'duration';
        _remainingSeconds = widget.timerData!['durationMinutes'] * 60;
        _startCountdown();
        print('TIMER: Duration mode - ${widget.timerData!['durationMinutes']} minutes');
      } else if (widget.timerData!.containsKey('remainingMinutes')) {
        _timerMode = 'window';
        _remainingSeconds = widget.timerData!['remainingMinutes'] * 60;
        _startCountdown();
        print('TIMER: Window mode - ${widget.timerData!['remainingMinutes']} minutes remaining');
      }
    }
    
    print('TIMER: Started - mode: $_timerMode, seconds: $_remainingSeconds');

    // Create exam session when student starts exam
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SupabaseService.createExamSession(
        widget.examCode,
        widget.enrollmentNumber,
        widget.enrollmentNumber, // name fallback
      );
      print('EXAM: Session created for ${widget.enrollmentNumber}');
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // restore UI
    NoScreenshot.instance.screenshotOn(); // restore screenshot
    WakelockPlus.disable();
    _countdownTimer?.cancel();
    _faceCheckTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    WidgetsBinding.instance.removeObserver(this);
    print('ANTICHEAT: All proctoring disposed');
    print('FACE: FaceDetector closed');
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() => _timerExpired = true);
          print('TIMER: Time up! Submitting exam...');
          _autoSubmit();
        }
      } else {
        if (mounted) {
          setState(() => _remainingSeconds--);
          
          if (_remainingSeconds % 30 == 0) {
            print('TIMER: Remaining: ${_formatTime(_remainingSeconds)}');
          }

          if (_remainingSeconds == 300) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('5 minutes remaining!'),
                 backgroundColor: Colors.orange,
                 duration: Duration(seconds: 3),
               )
             );
             print('TIMER: 5 minutes warning shown');
          }
          if (_remainingSeconds == 60) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('1 minute remaining! Submit soon.'),
                 backgroundColor: Colors.red,
                 duration: Duration(seconds: 3),
               )
             );
             print('TIMER: 1 minute warning shown');
          }
        }
      }
    });
  }


  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_selectedAnswers[i] == widget.questions[i].correctIndex) {
        score++;
      }
    }
    return score;
  }

  Future<void> _initCamera() async {
    try {
      if (kIsWeb) return; // skip on web
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('ANTICHEAT: No cameras available');
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _cameraInitialized = true);
      }
      print('ANTICHEAT: Front camera initialized for proctoring');
      
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          minFaceSize: 0.1,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      print('FACE: FaceDetector initialized');
      
      // Start face check every 5 seconds
      _faceCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkFaceWithMLKit());
    } catch (e) {
      print('ANTICHEAT: Camera init failed: $e');
    }
  }

  Future<void> _checkFaceWithMLKit() async {
    if (_examSubmitted || _cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_faceDetector == null) return;
    
    try {
      // Capture image from camera
      final XFile imageFile = await _cameraController!.takePicture();
      print('FACE: Analyzing image for faces (In Isolate)...');
      
      // Moving to background isolate to prevent UI stuttering
      final faces = await compute(_detectFacesIsolate, imageFile.path);
      
      print('FACE: Detected ${faces.length} face(s)');
      
      if (faces.isEmpty) {
        _noFaceCount++;
        print('FACE: No face detected! Count: $_noFaceCount / $_maxNoFaceCount');
        
        setState(() => _faceDetected = false);
        
        // Update session with face warning
        await SupabaseService.updateExamSessionWarning(
          widget.examCode,
          widget.enrollmentNumber,
          warningType: 'face_not_detected',
        );
        
        if (_noFaceCount >= _maxNoFaceCount) {
          _noFaceCount = 0;
          setState(() => _warningCount++);
          
          if (_warningCount >= 3) {
            _showTerminationDialog();
          } else {
            _showWarningDialog(
              title: 'Warning $_warningCount of 3',
              message: 'Your face is not visible!\n\nPlease keep your face in front of the camera during the exam.',
              icon: Icons.face_retouching_off,
              iconColor: Colors.orange,
              buttonText: 'I understand',
              buttonColor: Colors.orange,
              onContinue: () {},
            );
          }
        } else {
          // Show subtle warning
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.face_retouching_off, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Face not visible! Please face the camera. ($_noFaceCount/$_maxNoFaceCount)'),
                ]),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // Face detected
        if (!_faceDetected) {
          print('FACE: Face detected again');
        }
        setState(() => _faceDetected = true);
        _noFaceCount = 0;
        
        // Check if multiple faces detected (possible cheating)
        if (faces.length > 1) {
          print('FACE: Multiple faces detected! Count: ${faces.length}');
          setState(() => _warningCount++);
          
          await SupabaseService.updateExamSessionWarning(
            widget.examCode,
            widget.enrollmentNumber,
            warningType: 'multiple_faces',
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.warning, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Multiple faces detected! Only you should be visible.'),
                ]),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
        
        // Check eye open probability (looking away)
        final face = faces.first;
        if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
          final leftEye = face.leftEyeOpenProbability!;
          final rightEye = face.rightEyeOpenProbability!;
          
          if (leftEye < 0.3 && rightEye < 0.3) {
            print('FACE: Eyes closed detected');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please keep your eyes open and face the screen!'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      }
      
      // Clean up temp image
      try { File(imageFile.path).deleteSync(); } catch(_) {}
      
    } catch (e) {
      print('FACE: Detection error - $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_examSubmitted) return;
    
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive) {
      print('ANTICHEAT: App went to background');
      // Just track, dont do anything yet
    }
    
    if (state == AppLifecycleState.resumed) {
      // App came back from background
      setState(() => _appSwitchCount++);
      print('ANTICHEAT: App resumed from background. Switch count: $_appSwitchCount');
      
      // Re-enable fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      
      // Now show warning based on count
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_examSubmitted) _handleAppSwitch();
      });
    }
  }

  void _handleAppSwitch() {
    if (_examSubmitted) return;
    
    setState(() => _warningCount++);
    print('ANTICHEAT: Handling switch - warning $_warningCount of 3');
    
    if (_warningCount == 1) {
      _showWarningDialog(
        title: 'Warning 1 of 3',
        message: 'You left the exam screen!\n\nPlease stay on this screen during the exam.',
        icon: Icons.warning_amber,
        iconColor: Colors.orange,
        buttonText: 'Continue Exam',
        buttonColor: Colors.orange,
        onContinue: () {},
      );
    } else if (_warningCount == 2) {
      _showWarningDialog(
        title: 'Warning 2 of 3 — Last Warning!',
        message: 'You left the exam screen again!\n\nOne more violation will terminate your exam.',
        icon: Icons.warning_amber,
        iconColor: Colors.deepOrange,
        buttonText: 'I Understand',
        buttonColor: Colors.deepOrange,
        onContinue: () {},
      );
    } else if (_warningCount >= 3) {
      _showTerminationDialog();
    }
  }

  void _showWarningDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onContinue,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            // Warning progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Container(
                width: 60,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i < _warningCount ? Colors.red : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
            const SizedBox(height: 6),
            Text(
              '$_warningCount / 3 warnings',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              Navigator.pop(context);
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              onContinue();
              print('ANTICHEAT: Warning dialog dismissed');
            },
            child: Text(buttonText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTerminationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.gpp_bad, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text('Exam Terminated!'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // All 3 warning bars filled red
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Container(
                width: 60,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
            const SizedBox(height: 12),
            const Text(
              '3 / 3 warnings',
              style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'You have left the exam screen 3 times.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your exam is being automatically submitted with current answers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              Navigator.pop(context);
              print('ANTICHEAT: Termination confirmed - auto submitting');
              _autoSubmit();
            },
            child: const Text('Submit Exam Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _autoSubmit() async {
    print('ANTICHEAT: _autoSubmit() called - submitting exam now');
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_examSubmitted && mounted) {
      _submitExam();
    }
  }

  Future<void> _submitExam() async {
    setState(() => _isSubmitting = true);
    final score = _calculateScore();
    final percentage = (score / widget.questions.length * 100).toInt();
    
    try {
      await SupabaseService.saveResult(
        examCode: widget.examCode,
        enrollmentNumber: widget.enrollmentNumber,
        score: score,
        total: widget.questions.length,
        answers: _selectedAnswers,
        instantMode: true,
        warnings: _warningCount,
        appSwitches: _appSwitchCount,
      );
      
      print('ANTICHEAT: Exam submitted with $_warningCount warnings, $_appSwitchCount app switches');
      
      debugPrint('EXAM: Submitted, score: $score / ${widget.questions.length}');
      debugPrint('RESULT: Score: $score/${widget.questions.length} = $percentage%');
      
      final isPublished = await SupabaseService.checkResultsPublished(widget.examCode);
      
      setState(() {
        _score = score;
        _examSubmitted = true;
        _resultsPublished = isPublished;
      });

      // Update session to submitted
      await SupabaseService.updateExamSessionSubmitted(
        widget.examCode,
        widget.enrollmentNumber,
      );
      print('EXAM: Session marked as submitted');
    } catch (e) {
      debugPrint('EXAM: Submit ERROR - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting exam: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _checkResults() async {
    setState(() => _isCheckingResults = true);
    try {
      final isPublished = await SupabaseService.checkResultsPublished(widget.examCode);
      debugPrint('CHECK: Results published: $isPublished');
      if (isPublished) {
        setState(() => _resultsPublished = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Results not published yet. Check back later.')),
          );
        }
      }
    } catch (e) {
      debugPrint('CHECK: ERROR - $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingResults = false);
      }
    }
  }

  void _showSubmitDialog() {
    final answeredCount = _selectedAnswers.where((a) => a != null).length;
    debugPrint('EXAM: Submit dialog shown, answered: $answeredCount/${widget.questions.length}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: Text('You have answered $answeredCount out of ${widget.questions.length} questions. Are you sure you want to submit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_examSubmitted) {
          print('ANTICHEAT: Back button blocked');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Back button disabled during exam'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            )
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Exam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            if (_timerMode != 'none' && !_examSubmitted)
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _remainingSeconds <= 60 ? Colors.red : 
                           _remainingSeconds <= 300 ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (!_examSubmitted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.red.shade50,
                      child: Row(
                        children: [
                          // Camera status
                          Icon(
                            _cameraInitialized ? Icons.videocam : Icons.videocam_off,
                            size: 14,
                            color: _cameraInitialized ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _cameraInitialized ? 'Camera ON' : 'Camera OFF',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Face detection status
                          if (_cameraInitialized)
                            Row(children: [
                              Icon(
                                _faceDetected ? Icons.face : Icons.face_retouching_off,
                                size: 14,
                                color: _faceDetected ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _faceDetected ? 'Face OK' : 'No Face!',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _faceDetected ? Colors.green : Colors.red,
                                  fontWeight: _faceDetected ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ]),
                          const Spacer(),
                          // Warning dots
                          Row(
                            children: List.generate(3, (i) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _warningCount ? Colors.red : Colors.grey.shade300,
                              ),
                            )),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_warningCount/3',
                            style: TextStyle(
                              fontSize: 10,
                              color: _warningCount > 0 ? Colors.red : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                Expanded(
                  child: _isSubmitting 
                      ? _buildSubmittingState()
                      : (!_examSubmitted ? _buildExamInProgress() : _buildPostSubmissionView()),
                ),
              ],
            ),
            
            // Floating camera preview (top left corner)
            if (_cameraInitialized && !_examSubmitted && !kIsWeb)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _warningCount > 0 ? Colors.orange : Colors.green,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      // Camera preview
                      CameraPreview(_cameraController!),
                      
                      // Live indicator top left
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Warning indicator if warnings > 0
                      if (_warningCount > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_warningCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Submitting...', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExamInProgress() {
    final q = widget.questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / widget.questions.length;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, ${widget.enrollmentNumber}',
            style: const TextStyle(fontSize: 14, color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestion + 1} of ${widget.questions.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Q${_currentQuestion + 1}',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 32),
          SelectionContainer.disabled(
            child: Text(
              q.questionText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: q.options.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedAnswers[_currentQuestion] == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAnswers[_currentQuestion] = index);
                    debugPrint('EXAM: Q${_currentQuestion + 1} answered: $index');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blueAccent.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.blueAccent : Colors.grey.shade100,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SelectionContainer.disabled(
                            child: Text(
                              q.options[index],
                              style: TextStyle(
                                fontSize: 16,
                                color: isSelected ? Colors.blueAccent : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildStepNavigation(),
        ],
      ),
    );
  }

  Widget _buildStepNavigation() {
    final isLast = _currentQuestion == widget.questions.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentQuestion > 0 ? () {
              setState(() => _currentQuestion--);
              debugPrint('EXAM: Previous tapped, now on Q$_currentQuestion');
            } : null,
            icon: const Icon(Icons.arrow_back_ios),
            color: Colors.blueAccent,
          ),
          Text(
            '${_currentQuestion + 1} / ${widget.questions.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          isLast 
          ? ElevatedButton(
              onPressed: _showSubmitDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : IconButton(
              onPressed: () {
                setState(() => _currentQuestion++);
                debugPrint('EXAM: Next tapped, now on Q$_currentQuestion');
              },
              icon: const Icon(Icons.arrow_forward_ios),
              color: Colors.blueAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildPostSubmissionView() {
    if (!_resultsPublished) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 100, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Exam Submitted!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your teacher will publish results soon',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Text(
                'Come back later to see your score',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCheckingResults ? null : _checkResults,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCheckingResults 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Check Results', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Back to Home', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }

    // Results ARE published
    final percentage = (_score / widget.questions.length * 100).round();
    Color scoreColor = Colors.green;
    if (percentage < 40) scoreColor = Colors.red;
    else if (percentage < 60) scoreColor = Colors.orange;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scoreColor, width: 8),
            ),
            child: Column(
              children: [
                Text(
                  '$percentage%',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: scoreColor),
                ),
                Text(
                  '$_score / ${widget.questions.length}',
                  style: TextStyle(fontSize: 18, color: scoreColor),
                ),
              ],
            ),
          ),
          if (_warningCount > 0 || _appSwitchCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade800),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Note: $_warningCount warnings and $_appSwitchCount app switches were recorded during this exam.',
                        style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSimpleStat('Correct', _score.toString(), Colors.green),
              _buildSimpleStat('Wrong', (widget.questions.length - _score).toString(), Colors.red),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Answer Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          ...List.generate(widget.questions.length, (index) {
            final q = widget.questions[index];
            final selected = _selectedAnswers[index];
            final isCorrect = selected == q.correctIndex;
            return _buildReviewCard(q, selected, isCorrect, index);
          }),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildReviewCard(QuestionModel q, int? selected, bool isCorrect, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
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
              children: [
                Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? Colors.green : Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SelectionContainer.disabled(child: Text(q.questionText, style: const TextStyle(fontSize: 15))),
            const SizedBox(height: 12),
            _buildReviewOption('Your: ${selected != null ? q.options[selected] : 'Not answered'}', isCorrect ? Colors.green : Colors.red),
            if (!isCorrect) 
              _buildReviewOption('Correct: ${q.options[q.correctIndex]}', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewOption(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: SelectionContainer.disabled(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13))),
    );
  }

  // Static method to run detection in the background isolate via compute()
  static Future<List<Face>> _detectFacesIsolate(String path) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    try {
      final inputImage = InputImage.fromFilePath(path);
      return await detector.processImage(inputImage);
    } finally {
      await detector.close();
    }
  }
}
