import db from '../src/db/knex';

async function main() {
  const testExamTitles = [
    'Ujian Sprint 4 Test',
    'Ujian Pengawasan S5 & Geofence',
    'Kuis 1 Pemrograman Mobile',
  ];

  const testExams = await db('exams')
    .whereIn('title', testExamTitles)
    .orWhere('title', 'like', 'Ujian Percobaan%')
    .select('id', 'title');

  console.log(`Found ${testExams.length} test exams to clean.`);

  const ids = testExams.map((e) => e.id);
  if (ids.length > 0) {
    await db('exam_attempts').whereIn('exam_id', ids).del();
    await db('exam_questions').whereIn('exam_id', ids).del();
    await db('enrollments').whereIn('exam_id', ids).del();
    await db('exams').whereIn('id', ids).del();
  }

  const remaining = await db('exams')
    .join('courses', 'exams.course_id', 'courses.id')
    .select('exams.id', 'exams.title', 'courses.name as course_name', 'exams.start_at')
    .orderBy('exams.start_at', 'desc');

  console.log('Cleaned database. Remaining exams count:', remaining.length);
  console.log(remaining);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
