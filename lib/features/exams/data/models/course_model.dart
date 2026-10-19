class CourseModel {
  final String id;
  final String code;
  final String name;
  final String? lecturerId;
  final String? lecturerName;

  CourseModel({
    required this.id,
    required this.code,
    required this.name,
    this.lecturerId,
    this.lecturerName,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lecturerId: json['lecturer_id'] as String?,
      lecturerName: json['lecturer_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'lecturer_id': lecturerId,
      'lecturer_name': lecturerName,
    };
  }
}
