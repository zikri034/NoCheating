class AttemptModel {
  final String id;
  final String examId;
  final String studentId;
  final DateTime startedAt;
  final DateTime serverDeadline;
  final DateTime? submittedAt;
  final String status;
  final double? totalScore;
  final int seed;
  final int criticalCount;

  AttemptModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.startedAt,
    required this.serverDeadline,
    this.submittedAt,
    this.status = 'in_progress',
    this.totalScore,
    this.seed = 0,
    this.criticalCount = 0,
  });

  factory AttemptModel.fromJson(Map<String, dynamic> json) {
    return AttemptModel(
      id: json['id'] as String,
      examId: json['exam_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '') ?? DateTime.now(),
      serverDeadline: DateTime.tryParse(json['server_deadline']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at'].toString()) : null,
      status: json['status'] as String? ?? 'in_progress',
      totalScore: (json['total_score'] as num?)?.toDouble(),
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      criticalCount: (json['critical_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_id': examId,
      'student_id': studentId,
      'started_at': startedAt.toIso8601String(),
      'server_deadline': serverDeadline.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'status': status,
      'total_score': totalScore,
      'seed': seed,
      'critical_count': criticalCount,
    };
  }

  bool get isFinished => status == 'submitted' || status == 'graded' || status == 'terminated';
}
