import 'dart:convert';

class QuestionModel {
  final String id;
  final String courseId;
  final String type; // 'mcq' | 'essay'
  final String body;
  final List<String>? options;
  final double maxScore;
  final int? position;
  final String? courseName;
  final String? courseCode;
  final String? correctOption;
  final String? rubric;
  final String? modelAnswer;

  QuestionModel({
    required this.id,
    required this.courseId,
    required this.type,
    required this.body,
    this.options,
    this.maxScore = 10.0,
    this.position,
    this.courseName,
    this.courseCode,
    this.correctOption,
    this.rubric,
    this.modelAnswer,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    List<String>? parsedOptions;
    if (json['options'] != null) {
      if (json['options'] is List) {
        parsedOptions = (json['options'] as List).map((e) => e.toString()).toList();
      } else if (json['options'] is String) {
        try {
          final decoded = jsonDecode(json['options'] as String);
          if (decoded is List) {
            parsedOptions = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    }

    return QuestionModel(
      id: json['id'] as String,
      courseId: json['course_id'] as String? ?? '',
      type: json['type'] as String? ?? 'mcq',
      body: json['body'] as String? ?? '',
      options: parsedOptions,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 10.0,
      position: (json['position'] as num?)?.toInt(),
      courseName: json['course_name'] as String?,
      courseCode: json['course_code'] as String?,
      correctOption: json['correct_option'] as String?,
      rubric: json['rubric'] as String?,
      modelAnswer: json['model_answer'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'type': type,
      'body': body,
      'options': options,
      'max_score': maxScore,
      'position': position,
      'course_name': courseName,
      'course_code': courseCode,
      'correct_option': correctOption,
      'rubric': rubric,
      'model_answer': modelAnswer,
    };
  }
}
