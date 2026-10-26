import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';
import '../models/course_model.dart';

class ExamRepository {
  final Dio _dio;

  ExamRepository({Dio? dio}) : _dio = dio ?? DioClient.create();

  Future<List<ExamModel>> fetchExams({
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty && status != 'ALL') {
      queryParams['status'] = status.toLowerCase();
    }

    try {
      final response = await _dio.get('/exams', queryParameters: queryParams);
      final List examsList = response.data['exams'] as List? ?? [];
      return examsList.map((e) => ExamModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat daftar ujian';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> fetchExamDetail(String id) async {
    try {
      final response = await _dio.get('/exams/$id');
      final exam = ExamModel.fromJson(Map<String, dynamic>.from(response.data['exam'] as Map));
      final List qList = response.data['questions'] as List? ?? [];
      final questions = qList.map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map))).toList();
      final count = int.tryParse(response.data['enrollment_count']?.toString() ?? '') ?? 0;

      return {
        'exam': exam,
        'questions': questions,
        'enrollment_count': count,
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat detail ujian';
      throw Exception(msg);
    }
  }

  Future<void> enrollExam(String id) async {
    try {
      await _dio.post('/exams/$id/enroll');
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal mendaftar ujian';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> fetchMyExamResult(String examId) async {
    try {
      final response = await _dio.get('/exams/$examId/my-result');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat hasil ujian';
      throw Exception(msg);
    }
  }

  Future<ExamModel> createExam(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/exams', data: data);
      return ExamModel.fromJson(response.data['exam'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal membuat ujian';
      throw Exception(msg);
    }
  }

  Future<void> deleteExam(String examId) async {
    try {
      await _dio.delete('/exams/$examId');
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal menghapus ujian';
      throw Exception(msg);
    }
  }

  Future<List<CourseModel>> fetchCourses() async {
    try {
      final response = await _dio.get('/courses');
      final List list = response.data['courses'] as List? ?? [];
      return list.map((c) => CourseModel.fromJson(c as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat mata kuliah';
      throw Exception(msg);
    }
  }

  Future<CourseModel> createCourse(String code, String name) async {
    try {
      final response = await _dio.post('/courses', data: {
        'code': code.trim(),
        'name': name.trim(),
      });
      return CourseModel.fromJson(response.data['course'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal membuat mata kuliah / materi';
      throw Exception(msg);
    }
  }

  Future<List<QuestionModel>> fetchQuestions({
    String? courseId,
    String? search,
    String? type,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': 1000,
    };
    if (courseId != null && courseId.isNotEmpty) queryParams['course_id'] = courseId;
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (type != null && type.isNotEmpty) queryParams['type'] = type;

    try {
      final response = await _dio.get('/questions', queryParameters: queryParams);
      final List list = response.data['questions'] as List? ?? [];
      return list.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat bank soal';
      throw Exception(msg);
    }
  }

  Future<QuestionModel> createQuestion(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/questions', data: data);
      return QuestionModel.fromJson(response.data['question'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal membuat soal';
      throw Exception(msg);
    }
  }

  Future<void> assignQuestions(String examId, List<String> questionIds) async {
    try {
      await _dio.post('/exams/$examId/questions', data: {
        'question_ids': questionIds,
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal menetapkan soal';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> fetchExamMonitor(String examId) async {
    try {
      final response = await _dio.get('/exams/$examId/monitor');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat data monitor ujian';
      throw Exception(msg);
    }
  }

  /// Ambil antrean review essay untuk dosen (PRD F07)
  Future<List<Map<String, dynamic>>> fetchEssayReviews({
    String? status,
    String? examId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (examId != null && examId.isNotEmpty) queryParams['exam_id'] = examId;

      final response = await _dio.get('/reviews', queryParameters: queryParams);
      final List list = response.data['reviews'] as List? ?? [];
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat review essay';
      throw Exception(msg);
    }
  }

  /// Ambil daftar review essay dikelompokkan per mahasiswa
  Future<List<Map<String, dynamic>>> fetchStudentEssayReviews({
    String? status,
    String? examId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (examId != null && examId.isNotEmpty) queryParams['exam_id'] = examId;

      final response = await _dio.get('/reviews/by-student', queryParameters: queryParams);
      final List list = response.data['students'] as List? ?? [];
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memuat antrean review siswa';
      throw Exception(msg);
    }
  }

  /// Finalisasi nilai seluruh essay dalam 1 siswa sekaligus oleh dosen
  Future<Map<String, dynamic>> finalizeStudentEssays(
    String attemptId, {
    required double totalEssayScore,
    String? teacherComment,
  }) async {
    try {
      final response = await _dio.post('/reviews/attempts/$attemptId/finalize', data: {
        'total_essay_score': totalEssayScore,
        'teacher_comment': teacherComment,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memfinalisasi penilaian essay siswa';
      throw Exception(msg);
    }
  }

  /// Finalisasi atau ubah nilai essay oleh dosen (PRD F07)
  Future<Map<String, dynamic>> finalizeEssayGrade(
    String gradeId, {
    required double teacherScore,
    String? teacherComment,
    bool finalize = true,
  }) async {
    try {
      final response = await _dio.patch('/essay-grades/$gradeId', data: {
        'teacher_score': teacherScore,
        'teacher_comment': teacherComment,
        'finalize': finalize,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal memfinalisasi nilai essay';
      throw Exception(msg);
    }
  }

  /// Ekstraksi naskah soal dari dokumen Word/PDF menggunakan Gemini 2.0 Flash
  Future<Map<String, dynamic>> extractQuestionsFromDocument(
    String filePath,
    String fileName,
  ) async {
    try {
      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/questions/extract-document',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal mengekstrak soal dari dokumen';
      throw Exception(msg);
    }
  }

  /// Simpan batch banyak soal sekaligus ke bank soal
  Future<List<QuestionModel>> createQuestionsBatch({
    required String courseId,
    required List<Map<String, dynamic>> questions,
  }) async {
    try {
      final response = await _dio.post(
        '/questions/batch',
        data: {
          'course_id': courseId,
          'questions': questions,
        },
      );
      final List list = response.data['questions'] as List? ?? [];
      return list.map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map))).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal menyimpan batch soal';
      throw Exception(msg);
    }
  }

  /// Hapus satu butir soal dari bank soal (dosen)
  Future<void> deleteQuestion(String questionId) async {
    try {
      await _dio.delete('/questions/$questionId');
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal menghapus butir soal';
      throw Exception(msg);
    }
  }

  /// Hapus banyak butir soal sekaligus dari bank soal (dosen)
  Future<void> deleteQuestionsBatch(List<String> questionIds) async {
    try {
      await _dio.post('/questions/batch-delete', data: {
        'question_ids': questionIds,
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message ?? 'Gagal menghapus butir soal';
      throw Exception(msg);
    }
  }
}

