/**
 * Seed: 1 dosen, 3 mahasiswa, 1 mata kuliah, bank soal (mcq + essay),
 *        2 ujian contoh (satu berbiaya dan berlokasi), 12 pasang study_pairs.
 *
 * Password for all users: password123
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.seed = async function(knex) {
  // Clean in reverse dependency order
  await knex('course_feedback').del().catch(() => {});
  await knex('game_scores').del().catch(() => {});
  await knex('study_pairs').del().catch(() => {});
  await knex('fx_rates').del().catch(() => {});
  await knex('blocks').del().catch(() => {});
  await knex('violation_events').del().catch(() => {});
  await knex('essay_grades').del().catch(() => {});
  await knex('attempt_answers').del().catch(() => {});
  await knex('exam_attempts').del().catch(() => {});
  await knex('enrollments').del().catch(() => {});
  await knex('exam_questions').del().catch(() => {});
  await knex('questions').del().catch(() => {});
  await knex('exams').del().catch(() => {});
  await knex('courses').del().catch(() => {});
  await knex('biometric_devices').del().catch(() => {});
  await knex('refresh_tokens').del().catch(() => {});
  await knex('users').del();

  // bcrypt hash (cost 12) for 'password123'
  const bcrypt = require('bcryptjs');
  const passwordHash = await bcrypt.hash('password123', 12);

  // ---------- USERS ----------
  const [lecturer] = await knex('users').insert({
    role: 'lecturer',
    name: 'Dr. Budi Santoso',
    email: 'budi.lecturer@safeexam.ac.id',
    password_hash: passwordHash,
  }).returning('*');

  const students = await knex('users').insert([
    {
      role: 'student',
      nim: '2021001',
      name: 'Ani Wijaya',
      email: 'ani.student@safeexam.ac.id',
      password_hash: passwordHash,
    },
    {
      role: 'student',
      nim: '2021002',
      name: 'Budi Pratama',
      email: 'budi.student@safeexam.ac.id',
      password_hash: passwordHash,
    },
    {
      role: 'student',
      nim: '2021003',
      name: 'Citra Lestari',
      email: 'citra.student@safeexam.ac.id',
      password_hash: passwordHash,
    },
  ]).returning('*');

  // ---------- COURSE ----------
  const [course] = await knex('courses').insert({
    code: 'IF4501',
    name: 'Pemrograman Aplikasi Mobile',
    lecturer_id: lecturer.id,
  }).returning('*');

  // ---------- QUESTIONS (Bank Soal) ----------
  // 5 MCQ + 3 Essay = 8 questions total
  const questions = await knex('questions').insert([
    {
      course_id: course.id,
      type: 'mcq',
      body: 'Widget mana yang digunakan untuk menampilkan daftar item yang dapat di-scroll di Flutter?',
      options: JSON.stringify(['GridView', 'ListView', 'Column', 'Row']),
      correct_option: 'B',
      max_score: 10,
    },
    {
      course_id: course.id,
      type: 'mcq',
      body: 'Apa fungsi utama dari widget Scaffold di Flutter?',
      options: JSON.stringify(['Mengatur state', 'Menyediakan struktur layout dasar Material', 'Menangani routing', 'Mengelola database']),
      correct_option: 'B',
      max_score: 10,
    },
    {
      course_id: course.id,
      type: 'mcq',
      body: 'Method HTTP mana yang digunakan untuk memperbarui sebagian data resource di REST API?',
      options: JSON.stringify(['PUT', 'POST', 'PATCH', 'DELETE']),
      correct_option: 'C',
      max_score: 10,
    },
    {
      course_id: course.id,
      type: 'mcq',
      body: 'Di Flutter, package mana yang menyediakan autentikasi biometrik (sidik jari / Face ID)?',
      options: JSON.stringify(['flutter_secure_storage', 'local_auth', 'bio_auth', 'fingerprint_auth']),
      correct_option: 'B',
      max_score: 10,
    },
    {
      course_id: course.id,
      type: 'mcq',
      body: 'Apa tipe state management yang digunakan pada proyek SafeExam sesuai PRD?',
      options: JSON.stringify(['BLoC', 'Riverpod', 'Provider', 'GetX']),
      correct_option: 'C',
      max_score: 10,
    },
    {
      course_id: course.id,
      type: 'essay',
      body: 'Jelaskan perbedaan antara StatelessWidget dan StatefulWidget di Flutter. Berikan masing-masing satu contoh penggunaan yang tepat.',
      rubric: 'Definisi StatelessWidget (2), Definisi StatefulWidget (2), Contoh StatelessWidget (3), Contoh StatefulWidget (3)',
      model_answer: 'StatelessWidget adalah widget yang tidak memiliki state internal yang berubah. Contoh: menampilkan teks statis. StatefulWidget memiliki state yang dapat berubah dan memicu rebuild UI. Contoh: form input atau counter.',
      max_score: 10,
    },
    {
      course_id: course.id,
      type: 'essay',
      body: 'Bagaimana cara mengamankan API endpoint dengan JWT dan refresh token? Jelaskan alur autentikasi lengkap mulai dari login hingga refresh token.',
      rubric: 'Penjelasan JWT (3), Alur login (3), Mekanisme refresh token (2), Keamanan (penyimpanan hash, rotasi) (2)',
      model_answer: 'JWT digunakan sebagai access token berdurasi pendek. Saat login, server memvalidasi kredensial, lalu mengeluarkan access token (15 menit) dan refresh token (7 hari). Refresh token disimpan sebagai hash di database. Saat access token habis, client mengirim refresh token untuk mendapatkan pasangan token baru. Refresh token lama langsung dicabut (rotasi).',
      max_score: 10,
    },
    {
      course_id: course.id,
      type: 'essay',
      body: 'Apa keuntungan dan keterbatasan penggunaan autentikasi biometrik (Face ID/sidik jari) dalam konteks ujian online? Sertakan aspek keamanan dan privasi.',
      rubric: 'Keuntungan (3), Keterbatasan (3), Aspek keamanan (2), Aspek privasi (2)',
      model_answer: 'Keuntungan: kecepatan login, tidak perlu mengingat password. Keterbatasan: hanya membuktikan pengguna perangkat (bukan identitas pasti peserta ujian), perilaku berbeda antar OS. Keamanan: secret di-hash di server, device binding. Privasi: data biometrik tidak dikirim ke server, hanya verifikasi lokal via local_auth.',
      max_score: 10,
    },
  ]).returning('*');

  // ---------- EXAMS ----------
  const now = new Date();
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const nextWeek = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const nextWeekEnd = new Date(nextWeek.getTime() + 3 * 60 * 60 * 1000);

  // Exam 1: gratis, tanpa lokasi
  const [exam1] = await knex('exams').insert({
    course_id: course.id,
    title: 'UTS Pemrograman Mobile 2026',
    description: 'Ujian Tengah Semester mata kuliah Pemrograman Aplikasi Mobile. Materi: Flutter basics, Widget, State management, REST API.',
    start_at: tomorrow,
    end_at: new Date(tomorrow.getTime() + 3 * 60 * 60 * 1000),
    duration_min: 90,
    require_biometric: true,
    require_geofence: false,
    max_critical: 3,
    status: 'published',
    created_by: lecturer.id,
  }).returning('*');

  // Exam 2: berbiaya dan berlokasi (sertifikasi)
  const [exam2] = await knex('exams').insert({
    course_id: course.id,
    title: 'Sertifikasi Flutter Developer',
    description: 'Ujian sertifikasi kemampuan pengembangan aplikasi Flutter. Peserta wajib hadir di lokasi. Biaya ujian Rp 150.000.',
    start_at: nextWeek,
    end_at: nextWeekEnd,
    duration_min: 120,
    fee_idr: 150000,
    venue_lat: -6.973015,
    venue_lng: 107.630547,
    venue_radius_m: 200,
    require_biometric: true,
    require_geofence: true,
    max_critical: 3,
    ai_auto_finalize: false,
    status: 'published',
    created_by: lecturer.id,
  }).returning('*');

  // Assign questions to exams
  // Exam 1: first 5 MCQ + 1 essay
  const exam1Questions = [
    questions[0], questions[1], questions[2],
    questions[3], questions[4], questions[5],
  ];
  await knex('exam_questions').insert(
    exam1Questions.map((q, i) => ({
      exam_id: exam1.id,
      question_id: q.id,
      position: i + 1,
    }))
  );

  // Exam 2: all 8 questions
  await knex('exam_questions').insert(
    questions.map((q, i) => ({
      exam_id: exam2.id,
      question_id: q.id,
      position: i + 1,
    }))
  );

  // Enroll all students to exam 1
  await knex('enrollments').insert(
    students.map((s) => ({
      exam_id: exam1.id,
      student_id: s.id,
    }))
  );

  // 12 Study pairs for Course (F11 Mini Game Pair Rush)
  await knex('study_pairs').insert([
    { course_id: course.id, term: 'Widget', definition: 'Komponen dasar antarmuka pengguna di Flutter' },
    { course_id: course.id, term: 'StatelessWidget', definition: 'Widget yang tidak memiliki state internal yang dapat berubah' },
    { course_id: course.id, term: 'StatefulWidget', definition: 'Widget yang mempertahankan mutable state selama masa hidupnya' },
    { course_id: course.id, term: 'Provider', definition: 'Paket manajemen state berbasis InheritedWidget di Flutter' },
    { course_id: course.id, term: 'AES-GCM', definition: 'Algoritma enkripsi simetris terotentikasi berkinerja tinggi' },
    { course_id: course.id, term: 'JWT', definition: 'Format token terotentikasi berisi header, payload, dan signature' },
    { course_id: course.id, term: 'Bcrypt', definition: 'Fungsi hashing password adaptif berbasis algoritma Blowfish' },
    { course_id: course.id, term: 'Geofence', definition: 'Batas geografis virtual berbasis koordinat GPS dan radius' },
    { course_id: course.id, term: 'Accelerometer', definition: 'Sensor pendeteksi percepatan linier dan gaya gravitasi' },
    { course_id: course.id, term: 'Gyroscope', definition: 'Sensor pendeteksi kecepatan sudut rotasi perangkat' },
    { course_id: course.id, term: 'Hash-Chain', definition: 'Struktur data kriptografis di mana tiap blok memuat hash blok sebelumnya' },
    { course_id: course.id, term: 'PoW', definition: 'Mekanisme konsensus ringan untuk menemukan nonce hash berawalan nol' },
  ]);

  // Initial FX Rates (F09 Currency Conversion)
  await knex('fx_rates').insert([
    { base: 'IDR', quote: 'USD', rate: 0.00006154, fetched_at: now },
    { base: 'IDR', quote: 'EUR', rate: 0.00005714, fetched_at: now },
    { base: 'IDR', quote: 'MYR', rate: 0.00027397, fetched_at: now },
    { base: 'IDR', quote: 'JPY', rate: 0.00921659, fetched_at: now },
    { base: 'USD', quote: 'IDR', rate: 16250.00, fetched_at: now },
    { base: 'EUR', quote: 'IDR', rate: 17500.00, fetched_at: now },
    { base: 'MYR', quote: 'IDR', rate: 3650.00, fetched_at: now },
    { base: 'JPY', quote: 'IDR', rate: 108.50, fetched_at: now },
  ]);

  // Sample Game Scores (F11 Leaderboard)
  await knex('game_scores').insert([
    { user_id: students[0].id, score: 950, duration_ms: 18500 },
    { user_id: students[1].id, score: 820, duration_ms: 22100 },
    { user_id: students[2].id, score: 760, duration_ms: 26400 },
  ]);

  // Sample Feedback (F14 Saran dan Kesan)
  await knex('course_feedback').insert([
    {
      user_id: students[0].id,
      impression: 'Mata kuliah ini sangat aplikatif dan menantang! Arsitektur client-server dan keamanan aplikasinya benar-benar dipelajari secara mendalam.',
      suggestion: 'Bisa ditambahkan modul pengenalan arsitektur microservices untuk skala enterprise.',
      rating: 5,
    },
  ]);

  console.log('Seed completed: 1 lecturer, 3 students, 1 course, 8 questions, 2 exams, 12 study pairs, FX rates, game scores, and feedback.');
};
