# Kế hoạch port Grammar 3.1 sang ứng dụng cross-platform (Grammar 4.0)

> Từ 2026-10-07 mã app nằm ở gốc repo `grammar4` (trước đó là thư mục `app/` của repo `grammar`, nay là `grammar-legacy`); `tools/etl`, `docs/02 03 05 06`, `docs/source` và `legacy/`, `dist/` nhắc trong tài liệu này thuộc repo `grammar-legacy`. Từ 2026-10-07 nội dung bài học nằm trong `content/dataset` của repo này và là nguồn chính thức (ETL của `grammar-legacy` chỉ dùng cho lần nhập đầu); `content/grammar.db` dựng bằng `tool/content/pack.py`, có phiên bản nội dung trong bảng `meta`. Audio và video tải riêng. Vì nội dung nằm trong repo, lớp "không đóng gói dữ liệu thô" và DB mã hoá ở §11 không còn chống sao chép được nếu repo công khai (mã hoá đã bỏ 2026-10-20, §11).

Bản 1, 2026-10-05. Tài liệu điều phối: quyết định, phạm vi, kiến trúc, lộ trình và cách bảo đảm không bỏ sót chức năng. Chi tiết từng chức năng nằm ở `docs/02` (bảng tính năng), `docs/06` (hướng dẫn gốc), `docs/source/*` (phân tích mã nguồn VB6), `docs/08` (ma trận truy vết, sinh sau khi phân tích mã nguồn xong).

## 1. Bối cảnh mới

- Đã có **quyền tác giả** và **mã nguồn VB6** (`D:\english\grammar 3.1\Data G\Code`, 42 nghìn dòng, 90 file; bản UTF-8 ở `legacy/source-vb6-utf8/`). Mọi suy luận trước đây về định dạng và hành vi giờ được đối chiếu trực tiếp với mã; mã nguồn là nguồn sự thật.
- Có thêm thư mục `Doc` của tác giả: tài liệu Word gốc của từ điển, bài đọc, văn phạm, bài tập, sách giáo khoa 6–12 (4,4 GB), bộ ảnh Học Hình. Dùng để đối chiếu khi dữ liệu nhị phân có chỗ khó hiểu; **không** dùng làm nguồn chính vì app chạy bằng dữ liệu nhị phân và dữ liệu đó đã giải mã 100 %.
- Có 210 video AVI (14 GB) cho mục Luyện Nghe → Video.
- Phát triển và kiểm thử ngay trên máy Windows này, có app gốc để so sánh hành vi.

## 2. Mục tiêu và nguyên tắc

1. **Port đầy đủ nhất có thể** mọi chức năng phục vụ việc học: từ điển, bài đọc, luyện nói, văn phạm, mọi dạng bài tập, luyện nghe (bài tập và video), phân tích câu, từ vựng tranh, từ vựng của bạn, bài tự nhập. Thước đo là ma trận truy vết ở `docs/08`: mỗi hành vi của app gốc phải có một trong ba trạng thái *giữ nguyên*, *thay bằng tương đương hiện đại*, *bỏ có lý do*.
2. **Giữ sự tiện lợi cốt lõi**: tra từ từ mọi nơi bằng một chạm hoặc gõ, nghĩa nhanh rồi nghĩa đầy đủ, dịch từng câu, lưu từ một phím, liên kết chéo từ bài tập về bài văn phạm.
3. **Giao diện hiện đại, tối giản**: bỏ khung đỏ, hoạt hình linh vật, ảnh nền, font bitmap VPS; dùng typography rõ, chủ đề sáng/tối, bố cục đáp ứng cho điện thoại, máy tính bảng, máy tính. Trang trí là thứ duy nhất được phép bỏ mà không cần lý do.
4. **Một code base** chạy trên Windows, macOS, Android, iOS (và web nếu không tốn thêm), dữ liệu nằm cục bộ, không cần server.
5. **Dữ liệu là sản phẩm riêng**: bộ công cụ `tools/etl` tiếp tục sinh dữ liệu từ `legacy/Grammar`; app chỉ đọc định dạng mới. Khi mã nguồn VB6 cho thấy ETL sai ở đâu, sửa ETL trước, không vá trong app.

## 3. Quyết định nền tảng

**Đề xuất: Flutter (Dart) + SQLite (drift).** Lý do:

- Một code base cho desktop (Windows, macOS, Linux), mobile (Android, iOS) và web; render văn bản tự vẽ nên hiển thị tiếng Việt, IPA, tô sáng từng từ nhất quán trên mọi nền tảng.
- Có sẵn plugin ổn định cho những thứ app cần: `flutter_tts` (TTS hệ thống trên mọi nền tảng), `just_audio`/`audioplayers` (MP3/WAV với mốc thời gian), `media_kit` hoặc `video_player` (AVI cần `media_kit` vì dựa trên libmpv), `drift`/`sqlite3` (từ điển 544 nghìn mục, FTS5), `shared_preferences`/`drift` (tiến độ người dùng).
- Android bao gồm máy đọc sách e-ink (Boox), nên hướng EBWA cũ vẫn khả thi dưới dạng một bản build nếu muốn.

Phương án thay thế nếu chủ dự án muốn ở lại hệ sinh thái web: **Tauri 2 + TypeScript (React hoặc Svelte)** cho desktop và mobile, cùng SQLite qua plugin; video AVI phải nhờ libmpv hoặc chuyển mã sang MP4. Tầng dữ liệu (SQLite do ETL sinh) giống hệt nhau ở cả hai phương án, nên quyết định này có thể đổi trước Giai đoạn 3 mà không mất công đoạn dữ liệu.

Những thứ không port vì thuộc về Windows/VB6: hook chuột-bàn phím toàn hệ thống, tra từ clipboard khi Alt+Tab (bỏ, docs/08 G23: tra bằng ô Tra từ nhanh, gõ-để-tra trên desktop và chạm từ trong bài), bộ gõ tiếng Việt tự viết (hệ điều hành đã có), font VPS và chuyển mã, Tạo File WAV bằng SAPI (thay bằng xuất audio qua TTS của nền tảng nếu cần), đăng ký khởi động cùng Windows, kiểm tra license.

## 4. Kiến trúc

```
legacy/Grammar (nhị phân VB6)  ──tools/etl──▶  dist/dataset (JSON + WebP + audio)  ──tools/etl pack-sqlite──▶  grammar.db (+ media/)
                                                                                                    │
                                                                   app/ (Flutter) ──── đọc ──────────┘
                                                                     ├─ data/      repository trên drift: dictionary, readings, dialogs, grammar, exercises, wordforms, listening, analysis, pictures, subtitles, help
                                                                     ├─ domain/    use-case: lookup, highlight, practice sessions, grading, SRS
                                                                     ├─ ui/        màn hình theo tính năng, thành phần dùng chung (WordTapText, QuickDef, SentenceList, ExerciseRunner)
                                                                     └─ platform/  tts, audio, video, share, file picker
```

- **Dữ liệu nội dung**: một file SQLite khoảng 250 MB (từ điển chiếm phần lớn) + thư mục media (ảnh 65 MB, audio 650 MB tuỳ chọn, video 14 GB tuỳ chọn, người dùng tự đặt). ETL thêm lệnh `pack-sqlite` chuyển `dist/dataset` thành DB; app lần đầu mở sẽ sao chép DB từ assets hoặc tải về.
- **Dữ liệu người dùng**: bảng riêng trong SQLite (từ đã lưu, câu ngữ cảnh, đánh dấu Quay Từ, tiến độ bài tập, câu đàm thoại đã chọn, tiêu điểm tranh đã chọn, bài tự nhập, cài đặt). Có xuất/nhập JSON để sao lưu và chuyển máy.
- **Thành phần dùng chung quan trọng nhất**: `WordTapText` (văn bản mà mọi từ chạm được, tô đỏ/gạch chân từ đã lưu, chọn cụm), `QuickDefSheet` (nghĩa nhanh → nghĩa đầy đủ → Lưu), `SentencePlayer` (TTS hoặc audio theo mốc, tô sáng câu, mũi tên), `ExerciseRunner` (điền từ, trắc nghiệm, chọn câu sai, chấm, giải thích, liên kết văn phạm, đếm điểm). Bốn thành phần này phủ gần hết hành vi của app gốc.

## 5. Phạm vi theo phiên bản

| Phiên bản | Nội dung |
|---|---|
| **M1 Nền** | ETL → SQLite; app khung với điều hướng, cài đặt, TTS, từ điển (tìm, nghĩa nhanh, nghĩa đầy đủ, họ từ), từ vựng của bạn (lưu, xem, xoá, sửa, tạo từ). |
| **M2 Bài đọc** | Mục lục, trang bài, chạm từ, chạm câu dịch, Nghe toàn bài (TTS và audio thật theo mốc), Xếp từ, Đàm thoại 10 mức, Nghe viết, bài âm thanh thực. |
| **M3 Văn phạm và bài tập** | 356 bài, bài tập theo bài và trộn nhiều bài, 9 bộ đề cột phải, 4 dạng bài tập, giải thích từng phương án, Word Forms với bảng từ gốc và hai mức đánh dấu. |
| **M4 Luyện nói và nghe** | Luyện Nói (chủ đề, bài, Chọn Câu, ôn tập, Đàm thoại), Luyện Nghe bài tập, Luyện Nghe Video với phụ đề đồng bộ, tô màu theo thời gian, lặp câu. |
| **M5 Phần còn lại** | Phân tích câu, Từ vựng tranh (trang điểm nóng và lưới ảnh, Luyện tập 0/1/2), Quay Từ (dạng flashcard chuyển động), Bài nhập của bạn (soạn, phân câu, dịch, ảnh, Ngu Phap), trợ giúp. |
| **M6 Hoàn thiện** | Chủ đề tối, phím tắt desktop, chia sẻ văn bản vào app, sao lưu, đóng gói cài đặt cho từng nền tảng. |

Mỗi mốc kết thúc bằng việc **so sánh song song với app gốc** trên máy này theo checklist trong `docs/08`.

Trạng thái 2026-10-05: M1–M5 đã viết xong và chạy trên Windows (mọi màn hình chụp kiểm tra, test tự động cho tra từ và chấm bài); M6 đang làm: sao lưu/khôi phục JSON, gõ-để-tra trên desktop, DB mã hoá (SQLite3MultipleCiphers qua `hooks` của `package:sqlite3`, công cụ `app/tool/encrypt_db.dart`), build Android. Việc so song song với Grammar.exe từng dòng docs/08 do chủ dự án làm tay (sandbox không điều khiển được chuột/bàn phím của app gốc), xong 2026-10-14: 94 dòng ☑, 12 dòng Bỏ; xuất WAV (G16, V4) và tra từ clipboard (G23) chuyển sang Bỏ.

## 6. Cách bảo đảm không sót chức năng

1. **Phân tích mã nguồn** (xong, kết quả ở `docs/source/A..E`): năm báo cáo theo module, mỗi báo cáo có chỉ mục mọi thủ tục và danh sách sai khác so với tài liệu suy luận.
2. **Ma trận truy vết** `docs/08-ma-tran-truy-vet.md`: một dòng cho mỗi hành vi (lấy từ docs/02 checklist + docs/06 hướng dẫn + docs/source), cột: mã nguồn (module, thủ tục), dữ liệu, quyết định port, mốc, cách kiểm thử. Trạng thái cập nhật khi implement.
3. **Sửa ETL theo mã nguồn**: bảng token lấy nguyên văn từ `GiaiMa` trong READING.bas; mọi cấu trúc file lấy theo đoạn `Open/Get` thật; chạy lại `verify` và test.
4. **Kiểm thử đối chiếu**: với mỗi màn hình, chạy app gốc và app mới cạnh nhau trên cùng dữ liệu (ví dụ bài "1. Red Rubber Ball", bài tập ARTICLES câu 1, Đàm thoại mức 4) và ghi kết quả vào ma trận.
5. **Không xoá kiến thức cũ cho đến khi được thay thế**: đã gộp docs/01 và docs/04 vào docs/05 phần C, xoá docs/archive và tools/analysis (2026-10-05).

## 7. Lộ trình công việc ngay trước khi code

| # | Việc | Kết quả |
|---|---|---|
| P1 ☑ | Năm agent phân tích mã nguồn | `docs/source/A..E.md` |
| P2 ☑ | Đối chiếu bảng token và cấu trúc file với mã; sửa `tools/etl` | `verify` 100 %, test xanh, ghi chú sai khác trong `docs/05` |
| P3 ☑ | Viết `docs/08` ma trận truy vết từ docs/02 + docs/06 + docs/source | mỗi hành vi có quyết định port và mốc |
| P4 ☑ | Thêm `pack-sqlite` vào ETL, lược đồ DB (nội dung + người dùng) | `dist/grammar.db`, tài liệu lược đồ |
| P5 ☑ | Scaffold app Flutter, kiến trúc thư mục, thành phần dùng chung, chủ đề | `app/` chạy trên Windows; Android SDK 36 + JDK 17 đã cài, `flutter doctor` sạch |
| P6 ☑ | Dọn repo: gộp docs cũ, bỏ `tools/analysis`, `docs/archive` | cây tài liệu gọn, README mới |

## 8. Rủi ro

| Rủi ro | Giảm thiểu |
|---|---|
| Phát AVI trên mobile và web | `media_kit` (libmpv) phát AVI trên desktop/Android; iOS và web cần chuyển mã sang MP4/H.264 bằng script ffmpeg trong `tools/`. |
| TTS chất lượng khác nhau giữa nền tảng | Windows: `flutter_tts` sập (access violation trong WinRT MediaPlayer) nên app dùng kênh SAPI riêng (`app/windows/runner/sapi_tts.cpp`, đúng engine app gốc); nền tảng khác dùng `flutter_tts`; cho phép chọn giọng, tốc độ. |
| Từ điển 544 nghìn mục trên mobile | SQLite + FTS5, chỉ nạp mục đang xem; đã đo trên desktop, cần đo trên Android cấu hình thấp ở M1. |
| Hành vi ẩn trong 42 nghìn dòng VB6 | Ma trận truy vết + đối chiếu song song với app gốc. |
| Bản quyền nội dung | Đã có quyền tác giả; vẫn không đưa dữ liệu lên repo công khai nếu không được tác giả đồng ý rõ. |

## 9. Dọn dẹp (đã làm 2026-10-05)

- Giữ: `docs/02` (tính năng), `docs/03` (ảnh), `docs/05` (dữ liệu, cập nhật theo mã), `docs/06` (hướng dẫn gốc), `docs/source/*`, `docs/07` (kế hoạch này), `docs/08` (ma trận).
- Gộp `docs/01` và `docs/04` vào `docs/05` (phần lịch sử giải mã ngắn gọn), xoá `docs/archive/`, xoá `tools/analysis/` (đã được `tools/etl` thay thế), giữ `legacy/` (nhị phân + mã nguồn) và `dist/`.

## 10. Quyết định của chủ dự án (2026-10-05)

1. **Flutter.** SDK đặt ở `D:\sdklutter`; build Windows cần Visual Studio 2022 Build Tools (workload C++); Android cài sau khi M1 chạy được trên Windows.
2. ~~**Không làm bản web** bây giờ: tải 250 MB dữ liệu + media qua trình duyệt làm hệ thống phức tạp, chưa cần.~~ **Đổi 2026-10-20 (mục 12): web là kênh chính.**
3. **Chuyển 210 AVI sang MP4/H.264** bằng script ffmpeg trong `tools/video/` để dùng `video_player` chuẩn trên mọi nền tảng; tên file giữ mã tập (`A 01.mp4`…).
4. **Công bố miễn phí** theo tinh thần của tác giả, nhưng phải **gây khó cho việc trích xuất dữ liệu để trục lợi**. Xem mục 11.

## 11. Bảo vệ nội dung

Ứng dụng chạy offline nên không thể chống trích xuất tuyệt đối (mọi thứ máy khách đọc được thì người có kỹ năng cũng đọc được); mục tiêu là nâng chi phí trích xuất lên mức không đáng làm với nội dung miễn phí, và để lại dấu vết:

| Lớp | Cách làm | Mốc |
|---|---|---|
| Không đóng gói dữ liệu thô | `grammar.db` và media **không nằm trong bộ cài**; app tải về lần đầu từ máy chủ của chủ dự án qua HTTPS, từng gói (từ điển, bài đọc, audio…). | M1 (tải), M6 (máy chủ) |
| Mã hoá cơ sở dữ liệu | SQLite mở bằng **SQLCipher** (`sqlcipher_flutter_libs` + `drift`), khoá sinh tại runtime từ hằng bị xáo trộn trong mã + định danh cài đặt; file trên đĩa không đọc được bằng công cụ SQLite thường. | M1 |
| Mã hoá media | Ảnh/audio lưu trong gói tải về dạng mã hoá AES-CTR theo từng file, giải mã vào bộ nhớ khi hiển thị/phát (`just_audio` qua `StreamAudioSource`); video giữ nguyên vì quá lớn, chỉ đặt ngoài thư mục app. | M2, M4 |
| Làm rối mã | Build phát hành với `flutter build --obfuscate --split-debug-info`, tắt log. | M6 |
| Giấy phép và dấu vết | Màn hình giới thiệu ghi rõ tác giả nội dung, giấy phép "miễn phí, không được bán hay phân phối lại dữ liệu"; mỗi gói tải về gắn định danh cài đặt (watermark nhẹ trong metadata) để truy nguồn khi bị phát tán. | M6 |
| Không công khai dữ liệu | Repo mã nguồn có thể công khai, nhưng `legacy/`, `dist/`, khoá và máy chủ dữ liệu thì không. | luôn |

Hiện trạng (đến 2026-10-20, đã bỏ — xem đoạn dưới): `package:sqlite3` 3.x build biến thể SQLite3MultipleCiphers (`hooks.user_defines.sqlite3.source: sqlite3mc` trong `app/pubspec.yaml`); `dart run tool/encrypt_db.dart dist/grammar.db out.db <key>` mã hoá bằng `PRAGMA rekey`; app mở bằng `--dart-define=GRAMMAR_DB_KEY=<key>` (bản phát triển dùng DB thường, không cần khoá). Tải DB từ máy chủ và mã hoá media làm ở bước đóng gói phát hành.

Phát hành (2026-10-07): GitHub Actions (`.github/workflows/release.yml`) build Windows, Android, macOS với `--obfuscate --split-debug-info` và khoá DB lấy từ secret, rồi đưa lên GitHub Releases. Bản đầu chưa làm Linux, web, iOS và tải dữ liệu từ máy chủ: người dùng tải gói dữ liệu (`grammar.db` đã mã hoá và `grammar.images` chứa ảnh minh hoạ) vào một thư mục rồi chọn thư mục đó trong app. Windows và macOS chưa ký mã.

**Bỏ mã hoá (2026-10-20).** Nội dung đã nằm trong repo (sắp công khai) và bản web phải tải DB về trình duyệt, nên khoá trong mã không bảo vệ được gì. Gói dữ liệu từ 1.2.0 là SQLite thường; app bỏ sqlite3mc (`hooks` trong pubspec), `tool/encrypt_db.dart`, `GRAMMAR_DB_KEY`. App mới không đọc `grammar.db` mã hoá của 1.0.x (báo lỗi, gợi ý tải dữ liệu mới). Các lớp còn giữ: làm rối mã, giấy phép và dòng bản quyền nội dung trong README/giới thiệu.

## 12. Bản web và tải dữ liệu trực tiếp (quyết định 2026-10-20)

Nhiều người dùng iPhone/iPad; không có kinh phí App Store/VPS; bản Windows chưa ký vướng SmartScreen. Quyết định:

1. **Web là kênh chính**: web tĩnh (PWA, chạy offline) trên Cloudflare Pages miễn phí, không backend. Có mọi bài học, **không có video**; audio thực phát qua mạng hoặc tải về trình duyệt (bổ sung 2026-10-21, xem (7)); mời người dùng tải bản offline để đủ tính năng.
2. **Dữ liệu**: `grammar.db` hai biến thể cùng lược đồ (`full` cho bản cài, `web` không `media`/`subtitle_*`); bỏ phần app không đọc (docs/09). Web tải DB lần đầu (cắt khối nén, VFS chỉ đọc của `package:sqlite3` bản WASM, giữ API đồng bộ), ảnh tải dần khi mở; dữ liệu người dùng trong IndexedDB.
3. **Bản native** giữ (Windows, Android, macOS), thêm "Tải dữ liệu" từ GitHub Releases của repo (công khai) hoặc chọn thư mục đã tải như cũ.
4. **Phát hành**: tag → bản nháp + preview web (noindex); chủ dự án publish → workflow riêng đưa đúng bản đã thử lên production.

Lộ trình: (1) dữ liệu hai biến thể, bỏ mã hoá — xong 2026-10-20; (2) tách lớp nền tảng khỏi `dart:io` (`ContentDb`/`UserDb` trên `package:sqlite3/common.dart`, `MediaStore`, các cặp `*_io`/`*_web` trong `lib/platform`, `flutter build web` trong CI biên dịch cả app cho web; `test/platform_imports_test.dart` giữ `dart:io` trong các file `*_io.dart`) — xong 2026-10-20, bản web mới chỉ là trang chờ; (3) định dạng dữ liệu host + VFS khối (`tool/content/host.py`, `lib/data/manifest.dart`, `lib/data/block_vfs.dart`, docs/09 §4; DB web 176 MB → 8 pack 56,5 MB, khối 64 KiB; test đọc toàn bộ DB qua VFS trên thư viện native) — xong 2026-10-20; (4) app web (`bootstrap_web`: SQLite WASM, user.db trên IndexedDB, pack trong Cache Storage, `WebMediaStore` + `CachedUrlImage`, trang tải lần đầu với hướng dẫn MH chính trên iOS, mục Dữ liệu web, `sw.js` giữ vỏ app; con trỏ "đã cài" tách khỏi bản mới nhất trên máy chủ, Web Lock một thẻ, font dự phòng IPA, `404.html`; thử bằng Playwright trên Chromium: tải 57 MB, mở lại từ cache, tra từ, Cài Đặt) — xong 2026-10-20, chưa thử trên thiết bị iOS thật; (5) tải dữ liệu trong bản native (`lib/platform/downloader_io.dart`: `bundle.json` → `grammar.db.gz` + `grammar.images` vào `<app support>/content/<ver>/`, `.part` + Range, sha256; màn hình lần đầu `SetupPage`, "Kiểm tra cập nhật" trong Cài Đặt; test với máy chủ giả kể cả đứt kết nối) — xong 2026-10-20, chưa thử với release thật vì repo còn private; (6) CI deploy (`tool/web/build_site.py`; job `web` của release.yml → artifact `site` + preview noindex; `deploy-web.yml` khi publish release → production; cần secret Cloudflare và project Pages `grammar4`) — xong 2026-10-20, chưa chạy thật; (7) audio thực trên máy chủ riêng (`grammarAudioUrl` trong `lib/app/config.dart`, mặc định `https://alfrededison.heliohost.us/grammar4/audio/`, 119 file `<n>.mp3`): bài chưa tải thì phát thẳng qua mạng (`audioFor` → `AudioUrl`; không có mạng → giọng máy), nút "Tải bài này" ở trang bài đọc, "Tải tất cả" trong Cài Đặt → Dữ liệu (`lib/platform/recordings*.dart`: bản cài ghi `<n>.mp3` vào thư mục âm thanh thực với `.part` + Range; bản web giữ trong Cache Storage `grammar-audio`, phát bằng blob URL), danh sách bài có biểu tượng đám mây cho bài chưa tải. Máy chủ đó là Plesk chỉ cho `.htaccess`, nginx phục vụ thẳng `*.mp3` nên bỏ qua `.htaccess`; vì vậy bản web gọi `<n>` không đuôi: Apache đổi thành `<n>.mp3` và gửi CORS cho `grammar4.pages.dev` và các preview `*.grammar4.pages.dev` (`audioplayers_web` đặt `crossOrigin=anonymous`) — xong 2026-10-21, chưa thử trên thiết bị. Sau thử nghiệm: `audioplayers_web` quên lệnh tua khi đang phát (bấm câu kế phát lại đoạn trước), nên `lib/platform/clip_player.dart` luôn tạm dừng rồi mới tua; trình duyệt từ chối phát (autoplay không có cú chạm mới) thì chỉ dừng lượt đó, không chuyển cả trang sang giọng máy; mở trang mới đè lên trang đang đọc thì dừng đọc (`StopReadingObserver`, `lib/app/router.dart`). Luyện Nghe trên iPhone nghe một đoạn khác chừng 1 giây trước mỗi câu: đoán là Safari iOS phát lại bộ đệm cũ của Web Audio sau khi tua, nên bản web phát bằng `<audio>` tự điều khiển, không qua Web Audio, chờ `seeked` rồi mới phát (`lib/platform/clip_player_web.dart`) — chưa thử trên iPhone. Số liệu thử nghiệm trên thiết bị ghi ở đây khi có.

