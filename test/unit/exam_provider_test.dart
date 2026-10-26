import 'package:flutter_test/flutter_test.dart';
import 'package:thereisnocheating/features/exams/data/models/exam_model.dart';
import 'package:thereisnocheating/features/exams/data/models/question_model.dart';
import 'package:thereisnocheating/features/exams/data/models/course_model.dart';
import 'package:thereisnocheating/features/exams/data/repositories/exam_repository.dart';
import 'package:thereisnocheating/features/exams/presentation/providers/exam_provider.dart';

class MockExamRepository extends ExamRepository {
  List<ExamModel> mockExams = [];
  List<QuestionModel> mockQuestions = [];
  List<CourseModel> mockCourses = [];

  MockExamRepository(this.mockExams, [List<QuestionModel>? questions]) {
    if (questions != null) mockQuestions = questions;
  }

  @override
  Future<List<CourseModel>> fetchCourses() async {
    return List.from(mockCourses);
  }

  @override
  Future<CourseModel> createCourse(String code, String name) async {
    final c = CourseModel(
      id: 'c-${mockCourses.length + 1}',
      code: code,
      name: name,
    );
    mockCourses.insert(0, c);
    return c;
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

  @override
  Future<void> deleteQuestion(String questionId) async {
    mockQuestions.removeWhere((q) => q.id == questionId);
  }

  @override
  Future<void> deleteQuestionsBatch(List<String> questionIds) async {
    final idSet = questionIds.toSet();
    mockQuestions.removeWhere((q) => idSet.contains(q.id));
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

    test('deleteQuestion removes question from provider and repository', () async {
      await provider.createQuestion({
        'course_id': 'c1',
        'type': 'mcq',
        'body': 'Soal akan dihapus',
        'max_score': 10.0,
      });

      expect(provider.questions.length, 1);
      final qId = provider.questions.first.id;

      final success = await provider.deleteQuestion(qId);
      expect(success, true);
      expect(provider.questions.isEmpty, true);
    });

    test('deleteQuestionsBatch removes multiple questions from provider and repository', () async {
      await provider.createQuestion({
        'course_id': 'c1',
        'type': 'essay',
        'body': 'Soal batch 1',
        'max_score': 10.0,
      });
      await provider.createQuestion({
        'course_id': 'c1',
        'type': 'essay',
        'body': 'Soal batch 2',
        'max_score': 15.0,
      });

      expect(provider.questions.length, 2);
      final ids = provider.questions.map((q) => q.id).toList();

      final success = await provider.deleteQuestionsBatch(ids);
      expect(success, true);
      expect(provider.questions.isEmpty, true);
    });

    test('createCourse adds new course and updates courses list in provider', () async {
      expect(provider.courses.isEmpty, true);
      final newCourse = await provider.createCourse('IF4501', 'Pemrograman Aplikasi Mobile');
      expect(newCourse, isNotNull);
      expect(newCourse!.code, 'IF4501');
      expect(newCourse.name, 'Pemrograman Aplikasi Mobile');
      expect(provider.courses.length, 1);
      expect(provider.courses.first.id, newCourse.id);
    });
  });
}
