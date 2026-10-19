import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/features/exams/data/models/exam_model.dart';
import 'package:thereisnocheating/features/exams/data/models/question_model.dart';
import 'package:thereisnocheating/features/exams/data/repositories/exam_repository.dart';
import 'package:thereisnocheating/features/exams/presentation/providers/exam_provider.dart';

class MockExamRepository extends ExamRepository {
  List<ExamModel> mockExams = [];
  List<QuestionModel> mockQuestions = [];

  MockExamRepository(this.mockExams, [List<QuestionModel>? questions]) {
    if (questions != null) mockQuestions = questions;
  }

  @override
  Future<List<ExamModel>> fetchExams({String? search, String? status, int page = 1, int limit = 20}) async {
    if (search != null && search.isNotEmpty) {
      return mockExams.where((e) => e.title.toLowerCase().contains(search.toLowerCase())).toList();
    }
    return mockExams;
  }

  @override
  Future<void> enrollExam(String id) async {
    final idx = mockExams.indexWhere((e) => e.id == id);
    if (idx != -1) {
      mockExams[idx] = mockExams[idx].copyWith(isEnrolled: true);
    }
  }

  @override
  Future<List<QuestionModel>> fetchQuestions({String? courseId, String? search, String? type}) async {
    return List.from(mockQuestions);
  }

  @override
  Future<QuestionModel> createQuestion(Map<String, dynamic> data) async {
    return QuestionModel(
      id: 'q-${mockQuestions.length + 1}',
      courseId: data['course_id'] ?? 'c1',
      type: data['type'] ?? 'mcq',
      body: data['body'] ?? '',
      maxScore: (data['max_score'] as num?)?.toDouble() ?? 10.0,
    );
  }
}

void main() {
  group('ExamProvider Filtering & Search Tests (F10)', () {
    late ExamProvider provider;
    late List<ExamModel> sampleExams;

    setUp(() {
      final now = DateTime.now();
      sampleExams = [
        ExamModel(
          id: '1',
          courseId: 'c1',
          title: 'Kuis Flutter',
          startAt: now.add(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 1, hours: 1)),
          durationMin: 60,
        ),
        ExamModel(
          id: '2',
          courseId: 'c1',
          title: 'UTS Pemrograman Mobile',
          startAt: now.subtract(const Duration(minutes: 10)),
          endAt: now.add(const Duration(minutes: 50)),
          durationMin: 60,
        ),
        ExamModel(
          id: '3',
          courseId: 'c1',
          title: 'Tugas Akhir Lama',
          startAt: now.subtract(const Duration(days: 5)),
          endAt: now.subtract(const Duration(days: 4)),
          durationMin: 120,
        ),
      ];
      final mockRepo = MockExamRepository(sampleExams);
      provider = ExamProvider(repository: mockRepo);
    });

    test('loadExams populates all exams', () async {
      await provider.loadExams();
      expect(provider.exams.length, 3);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
    });

    test('selectTab filters exams by status correctly', () async {
      await provider.loadExams();

      provider.selectTab(ExamFilterTab.upcoming);
      expect(provider.exams.length, 1);
      expect(provider.exams.first.title, 'Kuis Flutter');

      provider.selectTab(ExamFilterTab.active);
      expect(provider.exams.length, 1);
      expect(provider.exams.first.title, 'UTS Pemrograman Mobile');

      provider.selectTab(ExamFilterTab.finished);
      expect(provider.exams.length, 1);
      expect(provider.exams.first.title, 'Tugas Akhir Lama');

      provider.selectTab(ExamFilterTab.all);
      expect(provider.exams.length, 3);
    });

    test('enrollExam mutates exam enrollment status', () async {
      await provider.loadExams();
      expect(provider.exams.first.isEnrolled, false);

      final success = await provider.enrollExam('1');
      expect(success, true);
      expect(provider.exams.firstWhere((e) => e.id == '1').isEnrolled, true);
    });

    test('loadQuestions and createQuestion manages question bank list correctly', () async {
      expect(provider.questions.isEmpty, true);
      await provider.loadQuestions();
      expect(provider.isLoadingQuestions, false);

      final success = await provider.createQuestion({
        'course_id': 'c1',
        'type': 'mcq',
        'body': 'Pertanyaan baru',
        'max_score': 10.0,
      });

      expect(success, true);
      expect(provider.questions.length, 1);
      expect(provider.questions.first.body, 'Pertanyaan baru');
    });
  });
}
