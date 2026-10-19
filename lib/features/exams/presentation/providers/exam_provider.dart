import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/question_model.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/exam_repository.dart';
import '../../../../core/services/notification_service.dart';

enum ExamFilterTab { all, upcoming, active, finished }

class ExamProvider extends ChangeNotifier {
  final ExamRepository _repository;

  ExamProvider({ExamRepository? repository}) : _repository = repository ?? ExamRepository();

  List<ExamModel> _allExams = [];
  List<ExamModel> _filteredExams = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  ExamFilterTab _selectedTab = ExamFilterTab.all;
  Timer? _debounceTimer;

  // Question bank & courses for lecturer
  List<CourseModel> _courses = [];
  List<QuestionModel> _questions = [];
  bool _isLoadingCourses = false;
  bool _isLoadingQuestions = false;

  // Getters
  List<ExamModel> get exams => _filteredExams;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  ExamFilterTab get selectedTab => _selectedTab;
  List<CourseModel> get courses => _courses;
  List<QuestionModel> get questions => _questions;
  bool get isLoadingCourses => _isLoadingCourses;
  bool get isLoadingQuestions => _isLoadingQuestions;

  Future<void> loadExams() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allExams = await _repository.fetchExams(search: _searchQuery);
      _applyLocalFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  void onSearchChanged(String query) {
    _searchQuery = query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      loadExams();
    });
  }

  void selectTab(ExamFilterTab tab) {
    if (_selectedTab != tab) {
      _selectedTab = tab;
      _applyLocalFilters();
      notifyListeners();
    }
  }

  void _applyLocalFilters() {
    if (_selectedTab == ExamFilterTab.all) {
      _filteredExams = List.from(_allExams);
      return;
    }

    _filteredExams = _allExams.where((exam) {
      switch (_selectedTab) {
        case ExamFilterTab.upcoming:
          return exam.computedStatus == 'AKAN DATANG';
        case ExamFilterTab.active:
          return exam.computedStatus == 'BERLANGSUNG';
        case ExamFilterTab.finished:
          return exam.computedStatus == 'SELESAI';
        case ExamFilterTab.all:
          return true;
      }
    }).toList();
  }

  Future<bool> enrollExam(String examId) async {
    try {
      await _repository.enrollExam(examId);
      // Update local state
      _allExams = _allExams.map((e) {
        if (e.id == examId) {
          return e.copyWith(isEnrolled: true);
        }
        return e;
      }).toList();
      _applyLocalFilters();
      notifyListeners();

      // Schedule reminders (PRD F15)
      try {
        final enrolled = _allExams.firstWhere((e) => e.id == examId);
        NotificationService.instance.scheduleExamReminders(
          examId: enrolled.id,
          title: enrolled.title,
          startAt: enrolled.startAt,
        );
      } catch (_) {}

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getExamDetail(String examId) async {
    try {
      return await _repository.fetchExamDetail(examId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> createExam(Map<String, dynamic> data) async {
    try {
      final newExam = await _repository.createExam(data);
      _allExams.insert(0, newExam);
      _applyLocalFilters();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCourses() async {
    _isLoadingCourses = true;
    notifyListeners();
    try {
      _courses = await _repository.fetchCourses();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingCourses = false;
      notifyListeners();
    }
  }

  Future<void> loadQuestions({String? courseId, String? search, String? type}) async {
    _isLoadingQuestions = true;
    notifyListeners();
    try {
      _questions = await _repository.fetchQuestions(
        courseId: courseId,
        search: search,
        type: type,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingQuestions = false;
      notifyListeners();
    }
  }

  Future<bool> createQuestion(Map<String, dynamic> data) async {
    try {
      final q = await _repository.createQuestion(data);
      _questions.insert(0, q);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignQuestions(String examId, List<String> questionIds) async {
    try {
      await _repository.assignQuestions(examId, questionIds);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> extractQuestionsFromDocument(String filePath, String fileName) async {
    return await _repository.extractQuestionsFromDocument(filePath, fileName);
  }

  Future<List<QuestionModel>> createQuestionsBatch({
    required String courseId,
    required List<Map<String, dynamic>> questions,
  }) async {
    final created = await _repository.createQuestionsBatch(
      courseId: courseId,
      questions: questions,
    );
    _questions.insertAll(0, created);
    notifyListeners();
    return created;
  }


  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
