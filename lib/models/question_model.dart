class QuestionModel {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctIndex': correctIndex,
    };
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as String,
      questionText: json['questionText'] as String,
      options: List<String>.from(json['options'] as List),
      correctIndex: json['correctIndex'] as int,
    );
  }
}
