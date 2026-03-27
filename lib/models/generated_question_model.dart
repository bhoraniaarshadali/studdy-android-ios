class GeneratedQuestion {
  final String questionText;
  final String questionType;
  final List<String>? options; // for MCQ
  final String answer;
  final int marks;
  final String difficulty;
  final String? sourceReference; // page/paragraph reference
  final double? confidenceScore;
  final String sectionName;
  bool isEditing;

  GeneratedQuestion({
    required this.questionText,
    required this.questionType,
    required this.answer,
    required this.marks,
    required this.difficulty,
    required this.sectionName,
    this.options,
    this.sourceReference,
    this.confidenceScore,
    this.isEditing = false,
  });

  Map<String, dynamic> toJson() => {
    'question_text': questionText,
    'question_type': questionType,
    'options': options,
    'answer': answer,
    'marks': marks,
    'difficulty': difficulty,
    'source_reference': sourceReference,
    'confidence_score': confidenceScore,
    'section_name': sectionName,
  };

  factory GeneratedQuestion.fromJson(Map<String, dynamic> json) =>
      GeneratedQuestion(
        questionText: json['question_text'],
        questionType: json['question_type'],
        answer: json['answer'],
        marks: json['marks'],
        difficulty: json['difficulty'],
        sectionName: json['section_name'],
        options: json['options'] != null
            ? List<String>.from(json['options'])
            : null,
        sourceReference: json['source_reference'],
        confidenceScore: json['confidence_score']?.toDouble(),
      );
}
