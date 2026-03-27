class PaperSection {
  final String sectionName;
  final String
  questionType; // 'mcq', 'short', 'long', 'true_false', 'fill_blank'
  final int questionCount;
  final int marksPerQuestion;
  final String difficulty; // 'easy', 'medium', 'hard'

  PaperSection({
    required this.sectionName,
    required this.questionType,
    required this.questionCount,
    required this.marksPerQuestion,
    required this.difficulty,
  });

  int get totalMarks => questionCount * marksPerQuestion;

  Map<String, dynamic> toJson() => {
    'section_name': sectionName,
    'question_type': questionType,
    'question_count': questionCount,
    'marks_per_question': marksPerQuestion,
    'difficulty': difficulty,
    'total_marks': totalMarks,
  };

  factory PaperSection.fromJson(Map<String, dynamic> json) => PaperSection(
    sectionName: json['section_name'],
    questionType: json['question_type'],
    questionCount: json['question_count'],
    marksPerQuestion: json['marks_per_question'],
    difficulty: json['difficulty'],
  );
}
