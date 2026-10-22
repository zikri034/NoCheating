# Log Keputusan Teknis — SafeExam

## 2026-10-22: F03 — Perbaikan Overflow Baris Selesai & Penataan Tombol Monitor dan Review AI pada Kelola Ujian

### Masalah yang Ditemukan
1. **RenderFlex Overflow pada Baris Waktu Selesai (`_buildInfoRow`)**:
   - Pada `ExamDetailDialog`, baris 'Selesai' menggunakan `Row` dengan `Spacer()` dan `Text(value)` berformat panjang (`dd MMMM yyyy, HH:mm WIB` dengan font `Space Mono`). Pada resolusi layar ponsel (360-390px lebar), panjang teks monospaced melebihi sisa ruang kontainer sehingga memicu overflow kanan (RenderFlex overflowed).
2. **Tombol "MONITOR" dan "REVIEW AI" Terlalu Sempit & Teks Bertumpuk**:
   - Di baris aksi bawah `ExamDetailDialog`, terdapat 4 elemen: `NeoButton` MONITOR (Expanded), `NeoButton` REVIEW AI (Expanded), `IconButton` Hapus Ujian (48px), dan `IconButton` Tutup (48px).
   - `NeoButton` secara default memiliki horizontal padding 24px kiri-kanan dan font size 16px.
   - Ruang tersisa untuk teks di dalam tombol hanya sekitar 26-35px, menyebabkan teks "MONITOR" dan "REVIEW AI" terpaksa wrap menjadi beberapa baris, menabrak border, dan bertumpukan (*tumpang tindih*).

### Keputusan & Solusi
1. **Perbaikan Baris Informasi (`_buildInfoRow`)**:
   - Mengganti `Spacer() + Text` dengan `Expanded(child: Text(value, textAlign: TextAlign.end, ...))` dan `crossAxisAlignment: CrossAxisAlignment.start`.
   - Menyingkat format tanggal menjadi `dd MMM yyyy, HH:mm` (contoh: "22 Okt 2026, 23:59 WIB") agar ringkas, rapi, dan adaptif.
2. **Penambahan Fleksibilitas pada `NeoButton`**:
   - Menambahkan parameter opsional `padding`, `fontSize`, dan `icon` pada `NeoButton`.
   - Membatasi teks tombol dengan `maxLines: 1` dan `overflow: TextOverflow.ellipsis` agar tidak pernah keluar dari kontainer atau tumpang tindih.
3. **Redesain Baris Aksi Kelola Ujian (`ExamDetailDialog`)**:
   - Menjadikan tombol `MONITOR` dan `REVIEW AI` mengambil lebar penuh secara seimbang (masing-masing 50% lebar dialog).
   - Menambahkan ikon visual `Icons.visibility_outlined` untuk MONITOR dan `Icons.auto_awesome` untuk REVIEW AI dengan font size 13px dan padding proporsional (10px horizontal, 12px vertikal).
   - Memindahkan aksi hapus ujian ke tombol lingkaran di header dialog (berdampingan dengan tombol X tutup), serta menjaga dialog tetap bersih, lapang, dan bergaya Neo-Brutalism.
4. **Pencegahan Overflow pada Komponen Terkait**:
   - Menjadikan `exam.lecturerName` pada `ExamCard` fleksibel dengan `Flexible` dan ellipsis.
   - Menjadikan label `Waktu Mulai:` dan `Waktu Selesai:` pada `CreateExamDialog` aman dengan `Flexible`.
5. **Validasi**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 45/45 test passed.

## 2026-10-22: F07 — Perbaikan Red Screen of Death pada Halaman Review Essay / UTS Dosen

### Masalah yang Ditemukan
1. **Type Cast Error pada Kolom Desimal PostgreSQL**:
   - Kolom `questions.max_score`, `essay_grades.ai_score`, `essay_grades.teacher_score`, dan `essay_grades.final_score` di database PostgreSQL bertipe `numeric`/`decimal`.
   - Driver Node-Postgres (`pg`) secara default mengembalikan nilai `numeric` sebagai `String` (misal `"10.00"`, `"1.50"`) untuk menjaga presisi matematis tanpa rounding error floating point.
   - Pada `lib/features/exams/presentation/screens/essay_review_screen.dart:288`, kode memanggil:
     `final maxScore = (r['max_score'] as num?)?.toDouble() ?? 50.0;`
   - Karena `r['max_score']` bertipe `String`, evaluasi cast `("10.00" as num?)` melempar uncaught `TypeError: type 'String' is not a subtype of type 'num?' in type cast` saat Flutter merender widget tree, yang memicu **Red Screen of Death** di aplikasi.
2. **Potensi Kesalahan Parsing JSON pada Flags & AI Breakdown**:
   - Kolom `flags` dan `ai_json` dapat berupa JSON string atau List/Map dinamis tergantung serialisasi Knex. Pemanggilan `.cast<String>()` atau `as Map<String, dynamic>?` langsung rentan terhadap type mismatch jika format berubah.
3. **Siklus Hidup Controller**:
   - Controller skor dan komentar belum dibersihkan saat refresh daftar review, dan berisiko membuat instance baru setiap frame jika key tidak ditemukan.

### Keputusan & Solusi
1. **Konversi Tipe Data pada Endpoint Backend (`server/src/routes/reviews.ts`)**:
   - Mengonversi `max_score`, `ai_score`, `teacher_score`, dan `final_score` secara eksplisit menjadi `Number` sebelum dikembalikan ke klien, serta memastikan `flags` dan `ai_json` selalu diparse menjadi object/array JSON valid.
2. **Defensive Parsing pada Flutter (`EssayReviewScreen`)**:
   - Menggunakan `double.tryParse(r['max_score']?.toString() ?? '') ?? 50.0` yang aman baik menerima `int`, `double`, `String`, maupun `null`.
   - Memasukkan fallback parsing untuk `flags` (aman untuk `List` dan string JSON) dan `ai_json` (aman untuk `Map` dan string JSON).
   - Memperbaiki pemetaan rincian rubrik dengan `.whereType<Map>()` dan `.toString()` untuk atribut poin dan kriteria.
   - Menggunakan `_scoreControllers.putIfAbsent(...)` dan `_commentControllers.putIfAbsent(...)` agar controller selalu terikat secara konsisten.
   - Menjamin pelepasan memori dengan mendispose controller lama sebelum memuat daftar review baru.
3. **Penyempurnaan Modul Serupa**:
   - Mengamankan parsing `criticalCount` dan `violations` pada `exam_monitor_screen.dart`.
   - Mengamankan parsing koordinat geofence (`venue_lat`, `venue_lng`, `venue_radius_m`) pada `exam_runner_provider.dart`.
   - Mengamankan parsing response `fetchExamDetail`, `finalizeEssayGrade`, dan `createQuestionsBatch` pada `exam_repository.dart`.
4. **Validasi**:
   - Menambahkan unit test di `test/unit/essay_review_test.dart` (45/45 test Flutter lulus, 0 error pada `flutter analyze`).
   - Seluruh 76 test backend di Vitest tetap lulus 100%.

## 2026-10-19: F03 & Ekstraksi AI — Tampilan Bank Soal Dosen, Perbaikan Pembuatan Ujian & Penanganan Overflow UI

### Masalah yang Ditemukan
1. **Overflow UI pada Ekstraksi Dokumen AI**: Pada dialog hasil ekstraksi Gemini (`ExtractQuestionsDialog`), tag tipe soal dan baris aksi memicu layout overflow pada resolusi layar mobile kecil.
2. **Ambiguitas Bank Soal bagi Dosen**: Dosen sebelumnya tidak memiliki antarmuka untuk melihat, mencari, atau mengelola butir-butir soal di Bank Soal (`questions`). Halaman utama hanya menampilkan daftar ujian.
3. **Kegagalan Pembuatan Ujian ("Ujian Tak Kunjung Muncul")**:
   - Skema Zod `createExamSchema` di backend menggunakan `.optional()` untuk `description`, `fee_idr`, `venue_lat`, `venue_lng`, dan `venue_radius_m`. Saat Flutter mengirimkan nilai `null` untuk kolom yang tidak diisi, server merespons dengan HTTP 400 (`Expected number, received null`).
   - Query `GET /api/exams` mengurutkan hasil berdasarkan `exams.start_at desc`. Ujian yang baru dibuat dengan jadwal hari ini ditempatkan jauh di bawah ujian seed minggu depan.
   - Dialog pembuatan ujian di Flutter tidak menampilkan pesan error visual saat submit gagal, sehingga pengguna mengira sistem macet.

### Keputusan & Solusi
1. **Perbaikan Layout & Overflow Dialog**:
   - Mengganti teks panjang tag menjadi `PG` dan `ESSAY` yang ringkas, mengecilkan tap target checkbox, serta membungkus elemen dengan `Flexible`/`Expanded` pada `ExtractQuestionsDialog`.
2. **Antarmuka Tab Bank Soal Khusus Dosen**:
   - Menambahkan segmented tab toggle neo-brutalis di bagian atas `exams_screen.dart` untuk dosen: `[ 📝 DAFTAR UJIAN ]` dan `[ 📚 BANK SOAL ]`.
   - Mengembangkan tampilan Bank Soal yang memuat:
     - Search bar pencarian teks soal (`NeoTextField`) dengan debounce.
     - Filter chip interaktif (`SEMUA`, `PILIHAN GANDA`, `ESSAY`).
     - Kartu butir soal lengkap dengan penanda jawaban benar pada pilihan ganda dan rubrik/kunci jawaban pada essay.
     - Tombol cepat `+ BUAT SOAL` (manual via `CreateQuestionDialog`) dan `✨ AI EKSTRAK` (via `ExtractQuestionsDialog`).
3. **Perbaikan API & Form Pembuatan Ujian**:
   - Mengubah skema validasi backend menjadi `.nullish()` pada `server/src/routes/exams.ts` agar menerima nilai `null` dan `undefined`.
   - Mengubah pengurutan `GET /api/exams` menjadi `.orderBy('exams.created_at', 'desc')` sehingga ujian yang baru dibuat segera tampil di posisi paling atas.
   - Menambahkan banner pesan kesalahan visual di dalam `CreateExamDialog` dan penanganan error responsif.
   - Menyertakan unit test komprehensif di `exam_provider_test.dart` (44/44 test Flutter lulus, 0 issues analyzer).

## 2026-10-11: F02 — Perbaikan Autentikasi Biometrik (Face ID & Sidik Jari)

### Masalah yang Ditemukan
1. **Android Activity Type**: `MainActivity.kt` mewarisi `FlutterActivity`. Library `local_auth` membutuhkan `FlutterFragmentActivity` untuk memunculkan dialog `BiometricPrompt`. Hal ini menyebabkan runtime exception/crash saat memicu biometrik di Android.
2. **iOS Permission**: `Info.plist` belum memiliki entri `NSFaceIDUsageDescription`, yang wajib ada agar izin Face ID tidak menyebabkan crash di iOS.
3. **Payload Validasi Server**: Endpoint `POST /api/auth/biometric/enroll` memiliki schema Zod `device_id: z.string().uuid()` dan `device_secret: z.string().min(32)`. Client sebelumnya mengirimkan string statis non-UUID (`'device_id_123'`) dan secret pendek (`'device_secret_abc'`), menyebabkan HTTP 400 Validation Error.
4. **Penyimpanan Kredensial**: Client tidak menyimpan `device_id` dan `device_secret` ke `FlutterSecureStorage` setelah pendaftaran, sehingga saat login biometrik (Mode B), kredensial tidak ditemukan.
5. **Penghapusan Session saat Logout**: Pemanggilan `_storage.deleteAll()` saat logout menghapus kredensial perangkat yang sudah di-bind. Diubah agar hanya menghapus `access_token` dan `refresh_token`.
6. **Shadowing Route di Backend**: File `auth.ts` memuat route simulasi mock `/biometric/enroll` dan `/biometric/login` yang menimpa route database PostgreSQL di `biometric.ts`.
7. **Komponen BiometricButton**: Belum ada komponen `BiometricButton` neo-brutalis yang mendeteksi Face ID vs Sidik Jari secara dinamis sesuai PRD Bagian 5 & F02.

### Keputusan & Solusi
1. Mengubah `MainActivity.kt` menjadi turunan `FlutterFragmentActivity`.
2. Menambahkan `NSFaceIDUsageDescription` pada `ios/Runner/Info.plist`.
3. Membuat utilitas `DeviceUtils` untuk menghasilkan UUID v4 standar RFC 4122 dan secret acak 256-bit (64 hex) yang aman secara kriptografi, serta deteksi platform.
4. Memperbarui `BiometricService` dengan parameter `biometricOnly: true`, `stickyAuth: true`, dan helper label biometrik.
5. Mengimplementasikan `BiometricButton` sesuai token Neo-Brutalism (border 3 px, offset shadow 6x6 / 2x2 saat ditekan, warna tertiary `#B28DFF`, Space Grotesk 800 kapital).
6. Menyesuaikan `AuthProvider` dan `AuthRepository` untuk alur enroll, login (Mode B), unlock gate (Mode A), dan revoke perangkat, serta inisialisasi status biometrik dari secure storage.
7. Menghapus route mock di `auth.ts` dan menambahkan dukungan upsert pada `biometric.ts` di backend.

## 2026-10-17: F03 & F10 — Manajemen Ujian, Bank Soal, Pencarian & Enrollment (Sprint 3)

### Masalah & Kebutuhan
1. **Routing Server**: `exams.ts` belum dimount di `app.ts`, dan endpoint bank soal (`questions.ts`) serta endpoint mata kuliah (`courses.ts`) belum tersedia.
2. **Proteksi Informasi Mahasiswa (PRD Rule 6)**: Mahasiswa tidak boleh melihat `correct_option`, `rubric`, atau `model_answer` pada endpoint detail ujian.
3. **Indikator Pendaftaran Ujian**: Mahasiswa memerlukan informasi status apakah mereka sudah terdaftar (`is_enrolled`) pada daftar ujian dan detail ujian.
4. **UI Neo-Brutalism**: Halaman `exams_screen.dart` sebelumnya berupa placeholder statis tanpa fungsionalitas pencarian, filter status, pendaftaran ujian, atau pembuatan ujian bagi dosen.

### Keputusan & Solusi
1. Menambahkan helper `requireRole` pada `auth.middleware.ts` dan mengimplementasikan router `questions.ts` (CRUD bank soal & filter) serta `courses.ts` (daftar mata kuliah).
2. Menghubungkan seluruh router ujian (`/api/exams`), bank soal (`/api/questions`), dan mata kuliah (`/api/courses`) ke Express `app.ts`.
3. Memfilter kolom sensitif pada `GET /api/exams/:id` berdasarkan role `lecturer` vs `student` dan menambahkan left join/subquery `enrollments` untuk menghasilkan atribut `is_enrolled`.
4. Mengembangkan komponen Neo-Brutalism:
   - `NeoTag`: Badge status (`AKAN DATANG`, `BERLANGSUNG`, `SELESAI`, `DRAFT`) dengan warna token PRD (#5CA8FF, #5CE08A, #D9D2C3, #FFDE59).
   - `NeoChip`: Filter tab interaktif dengan offset shadow dan animasi tekan.
   - `NeoEmptyState`: State kosong neo-brutalis jika hasil pencarian tidak ditemukan.
   - `ExamCard`: Kartu ujian dengan informasi durasi, jadwal, pengampu, badge biometrik & geofence, serta tombol pendaftaran.
   - `ExamDetailDialog`, `CreateExamDialog`, dan `AssignQuestionsDialog`: Dialog interaktif untuk detail ujian, pembuatan ujian baru oleh dosen, serta pemilihan banyak soal dari bank soal.
5. Mengimplementasikan `ExamRepository` dan `ExamProvider` dengan mekanisme debounce pencarian 300 ms dan filter lokal responsif.
6. Membuat automated tests:
   - Server: 11 tests baru di `tests/exams.test.ts` (total 20/20 test passing).
   - Flutter: 8 tests baru di `exam_model_test.dart` dan `exam_provider_test.dart` (total 16/16 test passing).

## 2026-10-17: F04 — Pelaksanaan Ujian, Autosave Terenkripsi, Timer Otoritatif & Auto-grading (Sprint 4)

### Masalah & Kebutuhan
1. **Model & Siklus Hidup Attempt**: Ujian memerlukan tabel `exam_attempts`, `attempt_answers`, dan `essay_grades` untuk melacak pengerjaan mahasiswa, deadline waktu, serta riwayat jawaban.
2. **Timer Otoritatif & Grace Period**: Klien tidak boleh mengandalkan jam lokal perangkat untuk deadline ujian. Server menyediakan `GET /api/time`, menghitung `server_deadline = min(now + duration, end_at)`, dan menolak sync setelah `server_deadline + GRACE_SECONDS` (60 detik). Klien wajib auto-submit saat waktu habis.
3. **Pengacakan Soal Deterministik**: PRD F04 mewajibkan urutan soal dan opsi diacak per mahasiswa dengan seed attempt agar unik namun konsisten ketika sesi di-resume.
4. **Keamanan & Autosave Offline**: Draft jawaban harus disimpan secara lokal di SQLite terenkripsi AES-GCM 256-bit tiap 5 detik dan disinkronkan ke server secara berkala (15 detik) atau saat berpindah soal.
5. **Auto-grading Pilihan Ganda**: Jawaban MCQ dinilai secara otomatis saat submit, dan attempt dikunci dari pengubahan lebih lanjut.
6. **UI Neo-Brutalism Runner**: Layar pengerjaan ujian (`ExamRunnerScreen`) dengan timer Space Mono (berwarna merah jika < 5 menit), kisi navigasi nomor soal (belum/terjawab/ragu-ragu), kartu pilihan ganda, textarea essay (maks 3000 karakter), dan dialog konfirmasi kumpul.

### Keputusan & Solusi
1. Membuat migrasi knex `20261017200000_create_attempts_and_answers.js` untuk tabel `exam_attempts`, `attempt_answers`, dan `essay_grades`.
2. Mengimplementasikan `attempt.service.ts` berisi logika murni:
   - `calculateServerDeadline`: Membatasi deadline berdasarkan sisa waktu ujian.
   - `isDeadlineExceeded`: Memeriksa toleransi grace period 60 detik.
   - `randomizeQuestionsForAttempt`: Pengacakan deterministik berbasis seed LCG untuk soal dan opsi MCQ.
   - `gradeMultipleChoice`: Penilaian otomatis pilihan ganda.
3. Membangun router `attempts.ts` dengan endpoint:
   - `POST /api/exams/:id/attempts`: Mulai atau resume attempt mahasiswa (sanitasi kunci jawaban/rubrik).
   - `PUT /api/attempts/:id/answers`: Batch update draft jawaban dengan validasi deadline.
   - `POST /api/attempts/:id/submit`: Kumpulkan ujian dan kalkulasi skor pilihan ganda.
   - `GET /api/attempts/:id/result`: Tampilkan hasil ujian dan rincian jawaban.
   - `GET /api/time`: Endpoint sinkronisasi waktu server.
4. Di sisi Flutter:
   - Menambahkan dependensi `sqflite`, `path`, dan `cryptography`.
   - Mengimplementasikan `LocalEncryptionService` menggunakan AES-GCM (kunci disimpan di `FlutterSecureStorage`).
   - Mengimplementasikan `LocalExamDatabase` untuk penyimpanan terenkripsi offline draft jawaban.
   - Mengimplementasikan `ExamRunnerProvider` dengan timer 1 detik, autosave 5 detik, server sync 15 detik, dan auto-submit.
   - Mengembangkan `ExamRunnerScreen` (PopScope pemblokir back button, grid modal nomor soal, kartu opsi neo-brutalis) dan `ExamResultScreen`.
## 2026-10-18: F05 & F06 — Sensor, Geofence + Peta, Anti-Curang & Monitor Dosen (Sprint 5)

### Masalah & Kebutuhan
1. **Pemantauan Integritas Ujian (PRD F05 & Ketentuan T8)**: Ujian memerlukan pemantauan sensor accelerometer dan gyroscope untuk mendeteksi guncangan (`device_shake`) dan rotasi mendadak (`sudden_rotation`).
2. **Deteksi Kecurangan Berbobot Kritis**: Kejadian aplikasi beralih ke background/paused > 5 detik, lokasi palsu (`Position.isMocked`), atau keluar dari radius geofence > 30 detik harus diklasifikasikan sebagai `critical` yang mengarah pada terminasi ujian jika mencapai batas `max_critical`.
3. **Pencegahan Screenshot & Privasi Tampilan**: Klien harus memblokir tangkapan layar selama ujian berlangsung menggunakan `FLAG_SECURE` (`screen_protector`).
4. **Verifikasi Lokasi & LBS (PRD F06 & Ketentuan T5)**: Dosen menentukan titik koordinat dan radius ujian. Mahasiswa wajib berada di dalam radius untuk dapat memulai ujian ber-geofence, serta dapat memantau posisi dan lingkaran radius di peta interaktif OpenStreetMap (`flutter_map`).
5. **Dashboard Pemantauan Dosen (Monitor Integritas)**: Dosen membutuhkan antarmuka monitor real-time untuk memantau status pengerjaan seluruh peserta dan linimasa rekaman kejadian pelanggaran.

### Keputusan & Solusi
1. Di sisi Backend (Node.js & Knex):
   - Menambahkan migrasi Knex `20261018180000_create_violation_events.js` untuk tabel `violation_events`.
   - Mengimplementasikan `violation.service.ts` berisi fungsi logika murni:
     - `evaluateViolation`: Memastikan sinyal `warn` tidak pernah menaikkan hitungan kritis atau memicu terminasi; sedangkan sinyal `critical` menaikkan hitungan dan memicu terminasi (`isTerminated = true`) saat mencapai `max_critical`.
     - `calculateDistanceMeters` & `isInsideGeofence`: Perhitungan jarak Haversine geodesik.
   - Endpoint baru:
     - `POST /api/attempts/:id/violations`: Mahasiswa mencatat kejadian pelanggaran.
     - `GET /api/exams/:id/monitor`: Dosen memantau daftar peserta ujian, ringkasan metrik, dan linimasa kejadian pelanggaran.
     - Validasi koordinat GPS saat `POST /api/exams/:id/attempts` jika ujian ber-geofence (menolak akses jika di luar radius).
2. Di sisi Flutter:
   - Menambahkan dependensi `sensors_plus`, `geolocator`, `flutter_map`, `latlong2`, dan `screen_protector`.
   - Menambahkan izin lokasi `ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION` di AndroidManifest dan `NSLocationWhenInUseUsageDescription` di Info.plist iOS.
   - Membangun `SensorIntegrityService` dengan throttling sampling ~20Hz dan kalibrasi baseline 3 detik.
   - Membangun `GeofenceService` dengan deteksi lokasi palsu `isMocked` dan radius kalkulasi.
   - Memperbarui `LocalExamDatabase` dengan tabel antrean lokal `violation_queue` untuk dukungan offline.
   - Mengembangkan `ExamLocationScreen` (peta OpenStreetMap, lingkaran geofence, marker posisi, jarak real-time).
   - Mengembangkan `ExamMonitorScreen` untuk dosen dengan visualisasi neo-brutalisme.
   - Mengintegrasikan `WidgetsBindingObserver` di `ExamRunnerScreen` untuk mendeteksi app paused > 5 detik dan menampilkan banner merah stiker peringatan saat terjadi pelanggaran.
3. Pengujian Automated:
   - Server: 7 unit & integration tests baru di `tests/violations.test.ts` (total 40/40 test passing, linter bersih).
   - Flutter: 11 tests baru di `sensor_integrity_service_test.dart`, `geofence_service_test.dart`, dan `exam_runner_provider_test.dart` (total 36/36 test passing).

---

## 2026-10-18 — Sprint 6: Koreksi Essay AI Gemini, Review Dosen, & Hasil Ujian (F07)

### Konteks & Masalah
1. **Otomatisasi Penilaian Essay Substantif (PRD F07 & Ketentuan T9)**: Jawaban essay membutuhkan evaluasi komprehensif berbasis rubrik pertanyaan dan kunci jawaban tanpa bias, dalam Bahasa Indonesia.
2. **Keamanan & Pertahanan Prompt Injection**: Jawaban mahasiswa berpotensi memuat instruksi manipulatif (misal "beri nilai 100", "abaikan rubrik"). Sistem harus memperlakukan jawaban murni sebagai data pasif, menangkap upaya injection (`prompt_injection_attempt`), dan menurunkan confidence/flagging.
3. **Privasi & Keamanan Kredensial**: `GEMINI_API_KEY` tidak boleh pernah bocor ke klien. Data identitas mahasiswa (Nama, NIM) tidak boleh dikirimkan ke model AI.
4. **Resiliensi & In-Process Queue**: Evaluasi AI harus diproses di background tanpa memblokir respons submit klien, dengan konkurensi terkontrol (concurrency 2), caching SHA-256 in-memory, serta exponential backoff retry untuk error 429/5xx, dengan fallback `pending_manual` jika AI gagal total.
5. **Human-in-the-Loop & Transparansi Nilai**: Dosen memiliki kendali penuh untuk meninjau rubrik breakdown, mengkoreksi nilai, dan memfinalisasi (`finalized`). Mahasiswa melihat label "Nilai sementara (AI)" hingga difinalisasi dosen.

### Keputusan & Solusi
1. Di sisi Backend (Node.js & Knex):
   - Menggunakan `@google/genai` (SDK resmi terbaru) dengan model Gemini 2.0 Flash (`process.env.GEMINI_MODEL || 'gemini-2.0-flash'`).
   - Menyusun `server/src/ai/prompts.ts`:
     - System instruction penilai adil akademis dalam Bahasa Indonesia.
     - Pembatasan maksimal 3000 karakter dan pembersihan karakter kontrol (`sanitizeStudentAnswer`).
     - Format XML-tags terstruktur: `<soal>`, `<rubrik>`, `<kunci_jawaban>`, `<nilai_maksimum>`, `<jawaban_mahasiswa>`.
     - Structured Output JSON schema Gemini yang memvalidasi score, rubric breakdown, strengths, improvements, feedback, confidence, dan flags.
   - Mengimplementasikan `server/src/ai/gemini.service.ts`:
     - Caching in-memory berbasis SHA-256 hash `(jawaban + rubrik + model)`.
     - Validasi Zod dan clamping nilai ke `0..max_score`.
     - Exponential backoff retry handler untuk rate limit atau server error.
     - Mock handler injection untuk pengujian unit/CI tanpa memanggil API publik.
   - Mengimplementasikan `server/src/jobs/essay_queue.ts`:
     - Antrean in-process konkurensi 2.
     - Pembaruan status: jika confidence low atau memiliki flag -> `needs_review`, selain itu `ai_graded`.
     - Auto-finalisasi jika ujian memiliki flag `ai_auto_finalize === true`.
     - Fallback ke `pending_manual` jika AI gagal setelah retry.
     - Perhitungan dan pembaruan `total_score` attempt saat seluruh essay selesai difinalisasi.
   - Endpoint Baru:
     - `GET /api/reviews?status=&exam_id=`: Antrean review essay untuk dosen.
     - `PATCH /api/essay-grades/:id`: Dosen mengubah nilai, memberikan catatan, dan memfinalisasi nilai.
     - `GET /api/attempts/:id/result`: Dilengkapi dengan rincian rubric breakdown AI, catatan dosen, dan flag `is_provisional`.
2. Di sisi Flutter:
   - `ExamRepository`: Menambahkan metode `fetchEssayReviews` dan `finalizeEssayGrade`.
   - `EssayReviewScreen`: Antarmuka review dosen berestetika Neo-brutalism dengan filter tab (Semua, Perlu Review, Dinilai AI, Final), kartu detail submission, panel evaluasi Gemini AI (skor, confidence, flags, rincian kriteria rubrik, kekuatan/perbaikan, feedback), dan formulir koreksi/finalisasi nilai.
   - `ExamResultScreen`: Diperkaya untuk menampilkan rincian hasil essay, badge status "NILAI SEMENTARA (AI)" vs "NILAI FINAL", uraian rubrik penilaian, umpan balik AI, dan catatan dosen.
   - Integrasi tombol "REVIEW AI" di `ExamCard` dan `ExamDetailDialog` khusus untuk role dosen.
3. Pengujian:
   - Backend: 8 unit & integration test baru di `server/tests/ai_grading.test.ts` (Total backend test: 48/48 passing, lint bersih).
   - Flutter: Unit test baru di `test/unit/essay_review_test.dart` (Total Flutter test: 39/39 passing, analyze bersih).

---

## 2026-10-18 — Sprint 7: Blockchain Audit Trail, Konversi Waktu & Kurs, Notifikasi, Pair Rush, & Saran Kesan (F16, F08, F09, F15, F11, F14)

### Konteks & Masalah
1. **Audit Trail Blockchain Anti-Manipulasi (PRD F16 & Ketentuan T13)**: Hasil dan bukti pengerjaan ujian harus disimpan dalam rantai hash tahan-ubah (single-node hash-chain). Modifikasi ilegal pada baris database harus dapat dideteksi secara deterministik lewat rekalkulasi hash SHA-256.
2. **Standardisasi Data Canonical**: Mengingat PostgreSQL tipe `jsonb` mengubah urutan kunci objek JSON, hash kriptografis blockchain wajib dihitung dari kolom teks `data_canonical` dengan urutan kunci terurut (`deterministicStringify`).
3. **Konversi Waktu Multi-Zona (PRD F08 & Ketentuan T7)**: Jadwal ujian UTC/lokal harus dapat dikonversi ke 4 zona waktu: WIB (`Asia/Jakarta`), WITA (`Asia/Makassar`), WIT (`Asia/Jayapura`), dan London (`Europe/London`, GMT/BST otomatis) menggunakan data IANA paket `timezone` tanpa hardcoded offset.
4. **Konversi Mata Uang & Cache Offline (PRD F09 & Ketentuan T7)**: Ujian berbayar memerlukan konversi nominal IDR ke USD, EUR, MYR, dan JPY dengan cache database `fx_rates` dan fallback offline SQLite/demo.
5. **Mini-Game Edukasi Pair Rush (PRD F11 & Ketentuan T10)**: Mahasiswa dapat mengasah pemahaman istilah ↔ definisi mata kuliah lewat permainan mencocokkan kartu 4×3, timer, kombo, dan papan peringkat 10 teratas, dengan perlindungan larangan bermain saat ujian aktif.
6. **Saran dan Kesan Kuliah (PRD F14 & Ketentuan T6)**: Mahasiswa memberikan evaluasi rating 1–5, kesan, dan saran dengan dukungan antrean offline SQLite `feedback_queue`.
7. **Notifikasi Pengingat Ujian (PRD F15 & Ketentuan T12)**: Pengingat terjadwal H−1 pukul 09:00 dan 15 menit sebelum ujian menggunakan `flutter_local_notifications` dan zona waktu perangkat.

### Keputusan & Solusi
1. Di sisi Backend (Node.js & Knex):
   - Migrasi Knex `20261018200000_create_sprint7_tables.js` untuk tabel `blocks`, `fx_rates`, `study_pairs`, `game_scores`, dan `course_feedback`.
   - `blockchain.service.ts`:
     - Serialization deterministik `deterministicStringify(obj)`.
     - Mining PoW ringan dengan `CHAIN_DIFFICULTY` (default 3 nol).
     - Rantai hash: `hash = SHA-256(idx | prev_hash | SHA-256(data_canonical) | nonce)`.
     - Penambahan blok `SUBMISSION` saat ujian dikumpulkan dan `RESULT` saat nilai difinalisasi menggunakan PostgreSQL advisory transaction lock (`pg_advisory_xact_lock(16)`).
     - Endpoint verifikasi `GET /api/chain/verify` mendeteksi blok yang rusak atau dimanipulasi.
     - Endpoint receipt `GET /api/chain/receipt/:attemptId` menghasilkan payload QR string.
   - Skrip demo manipulasi database: `server/scripts/tamper-demo.ts`.
   - `fx.service.ts` & `routes/fx.ts`: Integrasi API kurs publik dengan fallback cache DB dan demo.
   - `game.service.ts` & `routes/game.ts`: Validasi blokir pengerjaan saat ujian aktif (`EXAM_IN_PROGRESS`), pencatatan skor, dan leaderboard.
   - `feedback.service.ts` & `routes/feedback.ts`: Validasi zod rating 1–5 dan kesan, otorisasi dosen untuk melihat rekapitulasi.
2. Di sisi Flutter:
   - Dependensi baru: `qr_flutter: ^4.1.0`, `timezone: ^0.11.2`, `flutter_local_notifications: ^22.3.2`.
   - `TimezoneService` & `TimezoneConverterDialog`: Menghitung waktu di 4 zona waktu IANA, selisih hari (+1 hari), dan countdown aktif.
   - `CurrencyConverterDialog`: Konverter nominal IDR ke USD, EUR, MYR, JPY dengan status live/cache/demo.
   - `BlockchainReceiptDialog`: Menampilkan bukti blok, nomor indeks, QR code, dan tombol "Verifikasi Rantai Hash".
   - `PairRushScreen`: Permainan kartu istilah ↔ definisi grid neo-brutalis, timer milidetik, kombo bertingkat, dan modal bottom sheet Top 10 Leaderboard.
   - `FeedbackScreen`: Form neo-brutalis rating bintang 1–5, textarea kesan dan saran, antrean offline SQLite `feedback_queue`, dan sinkronisasi otomatis.
   - `NotificationService`: Penjadwalan notifikasi H−1 dan 15 menit sebelum ujian, notifikasi publikasi nilai, serta perizinan Android 13+.
   - Pembaruan `LocalExamDatabase` untuk tabel lokal `feedback_queue`, `fx_cache`, `pairs_cache`, dan `notif_schedule`.
3. Pengujian Automated:
   - Backend: 20 unit & integration test baru di `server/tests/sprint7.test.ts` (Total backend test: 68/68 passing, linter bersih 0 issue).
   - Flutter: 4 unit test baru di `test/unit/sprint7_client_test.dart` (Total Flutter test: 43/43 passing, analyzer bersih 0 issue).
   - Skrip `tamper-demo.ts` sukses mendeteksi manipulasi database secara otomatis.

---

## 2026-10-18 — Sprint 8: Finalisasi, Perapian, Pengujian End-to-End, Bug Fixes, & Laporan Akhir (docs/LAPORAN.md)

### Konteks & Masalah
1. **Penyelarasan Seluruh Ketentuan Tugas Akhir (T1–T14)**: Memastikan seluruh fungsionalitas PRD dari Sprint 1 sampai 7 telah terintegrasi tanpa cacat, aman dari potensi regresi, serta seluruh pengujian unit/integrasi otomatis berada pada status 100% lulus.
2. **Dokumentasi REST API & Spesifikasi Resmi**: Melengkapi spesifikasi OpenAPI 3.0.3 (`server/openapi.yaml`) dan koleksi berkas HTTP Client (`docs/api-examples.http`) untuk memfasilitasi pengujian independen seluruh endpoint.
3. **Diagram Desain Perangkat Lunak (Mermaid)**: Menyediakan berkas diagram Mermaid standar di folder `docs/diagrams/` yang mencakup arsitektur, ERD, usecase, activity diagram, sequence diagram, dan class diagram.
4. **Penyusunan Laporan Lengkap (docs/LAPORAN.md)**: Menyusun draf laporan tugas akhir akademik yang mencakup Cover, Halaman Pengesahan (dengan placeholder `ISI_...`), Bab 1–6, Tabel Pengujian Black-Box komprehensif, serta Lampiran.

### Keputusan & Solusi
1. **Dokumentasi API & Koleksi HTTP**:
   - `server/openapi.yaml`: Mendokumentasikan 35+ endpoint backend REST dengan skema validasi request, respons error, dan otorisasi Bearer JWT.
   - `docs/api-examples.http`: Berkas request siap pakai untuk VSCode REST Client / IntelliJ yang memuat skenario login, biometrik, attempt ujian, review dosen, blockchain audit, hingga fitur pelengkap.
2. **Diagram Sistem Terpadu**:
   - Dibuat dan disimpan di `docs/diagrams/`: `architecture.mmd`, `erd.mmd`, `usecase.mmd`, `activity_exam.mmd`, `activity_ai_grading.mmd`, `activity_biometric.mmd`, `sequence_login.mmd`, `sequence_biometric_enroll.mmd`, `sequence_submit_grading.mmd`, dan `class_diagram.mmd`.
3. **Penyusunan Laporan Tugas Akhir (`docs/LAPORAN.md`)**:
   - Format laporan akademik lengkap sesuai Bab 13 PRD (Ketentuan T14).
   - Dilengkapi tabel evaluasi pengujian black-box mencakup 16 skenario pengujian kunci (brute-force lockout, biometrik Mode A & B, geofence LBS, sensor accelerometer, background app switch, auto-submit timeout, anti-prompt injection Gemini, dosen review, tamper detection blockchain, offline-online sync, timezone, currency, pair rush, dan saran/kesan).
4. **Verifikasi Definition of Done (DoD)**:
   - [x] T2: Register/login, bcrypt salt 12, dual JWT token aman, lockout 5x, auto-login, logout pencabutan token.
   - [x] T3: Login biometrik (Mode B), gerbang buka aplikasi (Mode A), gerbang ujian, fallback password, pencabutan perangkat.
   - [x] T4: SQLite lokal dan PostgreSQL online (draft terenkripsi AES-GCM, cache kurs/pairs/feedback, sinkronisasi offline).
   - [x] T5: REST API + OpenAPI 3.0.3; berjalan di Android & iOS; geofence Haversine + peta OpenStreetMap.
   - [x] T6: Bottom nav memuat Ujian, Pair Rush, Saran & Kesan, Profil (foto avatar), dan Logout.
   - [x] T7: Jadwal ujian dalam 4 zona waktu (WIB, WITA, WIT, London GMT/BST); konversi biaya ujian ke USD, EUR, MYR, JPY.
   - [x] T8: Accelerometer dan gyroscope terhubung ke pencatatan pelanggaran integritas.
   - [x] T9: Essay dikoreksi Gemini 2.5 Flash dengan structured output JSON, penanganan injeksi prompt, dan dasbor review dosen.
   - [x] T10: Pair Rush 4x3 neo-brutalis dapat dimainkan, kombo, timer, dan leaderboard tersimpan.
   - [x] T11: Pencarian dan filter ujian; bank soal dan pemilihan banyak soal oleh dosen.
   - [x] T12: Notifikasi pengingat terjadwal (H-1 & 15m) dan notifikasi nilai siap.
   - [x] T13: Blok SUBMISSION dan RESULT tercatat; verifikasi rantai mendeteksi manipulasi database (`tamper-demo.ts`).
   - [x] T14: `docs/LAPORAN.md` lengkap + diagram Mermaid di `docs/diagrams/`.
   - [x] UI konsisten Neo-Brutalism (border 3 px, hard shadow 4 px, warna kontras); seluruh test hijau (Backend 68/68, Flutter 43/43); zero lint/analyzer issue.

---

## 2026-10-19: Improvement — Ekstraksi Naskah Soal Berkas (PDF / Word DOCX) Berbantuan Google Gemini 2.0 Flash

### Konteks & Masalah
Pembuatan butir soal secara manual satu per satu di perangkat mobile merupakan friksi besar bagi dosen. Dosen pada umumnya sudah memiliki naskah soal ujian dalam format dokumen Word (`.docx`) atau PDF yang rapi dengan nomor urut, pilihan ganda A/B/C/D, kunci jawaban, dan rubrik essay.

### Keputusan & Solusi
1. **Dukungan Multimodal & Parsing Dokumen di Backend**:
   - Memanfaatkan kemampuan native multimodal PDF dari Google Gemini 2.0 Flash (`inlineData` `application/pdf`).
   - Mengintegrasikan library `mammoth` untuk mengekstrak teks murni secara andal dari berkas Microsoft Word (`.docx`).
   - Merancang prompt terstruktur (`QUESTION_EXTRACTION_SYSTEM_INSTRUCTION`) dan JSON Schema Zod (`extractedQuestionsResultSchema`) agar Gemini mengekstrak nomor urut soal, mendeteksi tipe (`mcq` vs `essay`), memecah opsi pilihan, mendeteksi kunci jawaban, dan merumuskan estimasi rubrik/model answer.
2. **Endpoint REST API**:
   - `POST /api/questions/extract-document` (role `lecturer`): upload file berkas naskah soal via `multer` (maks 15 MB) dan mengembalikan array soal terstruktur yang sudah terurut rapi.
   - `POST /api/questions/batch` (role `lecturer`): menyimpan banyak soal sekaligus ke tabel `questions` dalam satu transaksi database PostgreSQL (Supabase).
3. **Komponen UI Neo-Brutalism di Flutter**:
   - Menambahkan dependency `file_picker: ^13.0.0` untuk memilih berkas `.pdf`, `.docx`, `.doc`, atau `.txt` dari perangkat mobile.
   - Komponen `ExtractQuestionsDialog`:
     - Pemilihan mata kuliah & pemilih berkas naskah.
     - Indikator pemrosesan Gemini AI.
     - Kartu review interaktif berurutan (`#1`, `#2`, dst.) dengan badge tipe `PILIHAN GANDA` / `ESSAY`, penandaan opsi kunci hijau, pratinjau rubrik, checkbox seleksi, dan tombol `Simpan ke Bank Soal`.
   - Diintegrasikan ke tombol `UNGGAH SOAL` pada AppBar daftar ujian serta di dalam dialog `AssignQuestionsDialog`.
4. **Verifikasi Pengujian**:
   - Backend: Unit & integration test di `tests/question_extraction.test.ts` (6 tests passing, total 74/74 passing).
   - Flutter: `flutter analyze` 0 issues, `flutter test` 43/43 tests passing.

