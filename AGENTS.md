# AGENTS.md — SafeExam

Aplikasi ujian online (Flutter + Node.js/Express + PostgreSQL) untuk Tugas Akhir Pemrograman Aplikasi Mobile.
**Sumber kebenaran produk: `docs/PRD.md`** (salin dari `PRD_SafeExam_TugasAkhir.md`). Baca bagian 0 (panduan agen) dan bagian 12 (rencana sprint) sebelum mulai.

## Struktur
- `app/` — Flutter (Dart 3). Fitur di `lib/features/<fitur>/{data,domain,presentation}`.
- `server/` — Node.js 20+, TypeScript, Express, Knex + `pg`, zod, vitest.
- `docker-compose.yml` — layanan `api` dan `db` (PostgreSQL 16+).
- `docs/` — PRD, DECISIONS, LAPORAN, diagram Mermaid, screenshots.

## Perintah
```
# infrastruktur
docker compose up -d db
# backend
cd server && npm install && npm run migrate && npm run seed && npm run dev
cd server && npm run lint && npm test
# flutter
cd app && flutter pub get && flutter analyze && flutter test
cd app && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

## Aturan
1. Kerjakan satu sprint sekali (PRD bagian 12); jangan menambah fitur di luar PRD.
2. Logika dulu (service murni + unit test), baru UI.
3. Jalankan analyze/lint/test sebelum menyatakan selesai. Commit kecil dengan ID fitur (`F02: ...`).
4. Rahasia hanya dari `.env` (jangan commit). `GEMINI_API_KEY` hanya di server, tidak pernah di Flutter.
5. SQL hanya lewat knex terparameter. Hash blockchain dihitung dari `data_canonical` (teks), bukan `jsonb`.
6. Respons API untuk mahasiswa tidak boleh memuat `correct_option`, `rubric`, `model_answer`.
7. Jangan mengarang data pribadi; pakai placeholder `ISI_...`.
8. Verifikasi versi paket dan nama model Gemini di dokumentasi resmi (model dari env `GEMINI_MODEL`).
9. UI: neo-brutalism (border 3 px, bayangan keras tanpa blur, warna solid). Token di PRD bagian 5.
10. Ambigu → pakai default PRD bagian 15, catat di `docs/DECISIONS.md`. Bertanya hanya jika terblokir.

## Selesai berarti
Kode berjalan, test baru lulus, analyzer bersih, acceptance fitur di PRD terpenuhi, dokumen `docs/` diperbarui.
