import '../../../../core/widgets/neo_tag.dart';

class ExamModel {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMin;
  final int? feeIdr;
  final double? venueLat;
  final double? venueLng;
  final int? venueRadiusM;
  final bool requireBiometric;
  final bool requireGeofence;
  final int maxCritical;
  final bool aiAutoFinalize;
  final String status;
  final String? courseName;
  final String? courseCode;
  final String? lecturerName;
  final bool isEnrolled;

  ExamModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.startAt,
    required this.endAt,
    required this.durationMin,
    this.feeIdr,
    this.venueLat,
    this.venueLng,
    this.venueRadiusM,
    this.requireBiometric = false,
    this.requireGeofence = false,
    this.maxCritical = 3,
    this.aiAutoFinalize = false,
    this.status = 'published',
    this.courseName,
    this.courseCode,
    this.lecturerName,
    this.isEnrolled = false,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['id'] as String,
      courseId: json['course_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Ujian Tanpa Judul',
      description: json['description'] as String?,
      startAt: DateTime.tryParse(json['start_at']?.toString() ?? '') ?? DateTime.now(),
      endAt: DateTime.tryParse(json['end_at']?.toString() ?? '') ?? DateTime.now(),
      durationMin: int.tryParse(json['duration_min']?.toString() ?? '') ?? 60,
      feeIdr: int.tryParse(json['fee_idr']?.toString() ?? ''),
      venueLat: double.tryParse(json['venue_lat']?.toString() ?? ''),
      venueLng: double.tryParse(json['venue_lng']?.toString() ?? ''),
      venueRadiusM: int.tryParse(json['venue_radius_m']?.toString() ?? ''),
      requireBiometric: json['require_biometric'] == true || json['require_biometric'] == 1,
      requireGeofence: json['require_geofence'] == true || json['require_geofence'] == 1,
      maxCritical: int.tryParse(json['max_critical']?.toString() ?? '') ?? 3,
      aiAutoFinalize: json['ai_auto_finalize'] == true || json['ai_auto_finalize'] == 1,
      status: json['status'] as String? ?? 'draft',
      courseName: json['course_name'] as String?,
      courseCode: json['course_code'] as String?,
      lecturerName: json['lecturer_name'] as String?,
      isEnrolled: json['is_enrolled'] == true || json['is_enrolled'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'duration_min': durationMin,
      'fee_idr': feeIdr,
      'venue_lat': venueLat,
      'venue_lng': venueLng,
      'venue_radius_m': venueRadiusM,
      'require_biometric': requireBiometric,
      'require_geofence': requireGeofence,
      'max_critical': maxCritical,
      'ai_auto_finalize': aiAutoFinalize,
      'status': status,
      'course_name': courseName,
      'course_code': courseCode,
      'lecturer_name': lecturerName,
      'is_enrolled': isEnrolled,
    };
  }

  String get computedStatus {
    if (status == 'draft') return 'DRAFT';
    final now = DateTime.now();
    if (now.isBefore(startAt)) return 'AKAN DATANG';
    if (now.isAfter(endAt)) return 'SELESAI';
    return 'BERLANGSUNG';
  }

  NeoTagVariant get statusVariant {
    switch (computedStatus) {
      case 'BERLANGSUNG':
        return NeoTagVariant.success;
      case 'AKAN DATANG':
        return NeoTagVariant.info;
      case 'SELESAI':
        return NeoTagVariant.muted;
      default:
        return NeoTagVariant.warning;
    }
  }

  ExamModel copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    int? durationMin,
    int? feeIdr,
    double? venueLat,
    double? venueLng,
    int? venueRadiusM,
    bool? requireBiometric,
    bool? requireGeofence,
    int? maxCritical,
    bool? aiAutoFinalize,
    String? status,
    String? courseName,
    String? courseCode,
    String? lecturerName,
    bool? isEnrolled,
  }) {
    return ExamModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      durationMin: durationMin ?? this.durationMin,
      feeIdr: feeIdr ?? this.feeIdr,
      venueLat: venueLat ?? this.venueLat,
      venueLng: venueLng ?? this.venueLng,
      venueRadiusM: venueRadiusM ?? this.venueRadiusM,
      requireBiometric: requireBiometric ?? this.requireBiometric,
      requireGeofence: requireGeofence ?? this.requireGeofence,
      maxCritical: maxCritical ?? this.maxCritical,
      aiAutoFinalize: aiAutoFinalize ?? this.aiAutoFinalize,
      status: status ?? this.status,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      lecturerName: lecturerName ?? this.lecturerName,
      isEnrolled: isEnrolled ?? this.isEnrolled,
    );
  }
}
