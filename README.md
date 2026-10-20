# Grammar 4.0

Ứng dụng học tiếng Anh cross-platform (Flutter), kế thừa và tiếp tục phát triển **Grammar 3.1** của TuHocTiengAnh.net theo uỷ thác của tác giả. Giữ toàn bộ chức năng học của bản gốc (từ điển 544 nghìn mục, 4.565 bài đọc song ngữ, 356 bài văn phạm, 49 nghìn bài tập, luyện nói, luyện nghe, video phụ đề, phân tích câu, từ vựng tranh…) với giao diện mới.

*English: a Flutter successor of the Vietnamese English-learning app Grammar 3.1, continued with the original author's blessing. Content data is distributed separately.*

Repo này chứa **mã nguồn app và nội dung bài học** (`content/`). Audio giọng thật và video tải riêng. Việc giải mã dữ liệu của app cũ, tài liệu tính năng gốc và phân tích mã VB6 nằm ở repo riêng (`grammar-legacy`, xem phần Tài liệu).

## Chạy khi phát triển

1. Cài Flutter stable (3.47+) và Python 3.11+ (có sẵn trên macOS). Desktop cần thêm: Windows → Visual Studio 2022 Build Tools (workload C++) và `nuget.exe` trên PATH; macOS → Xcode Command Line Tools; Linux → clang, cmake, ninja, GTK, libmpv. Android → Android SDK + JDK 17. `flutter doctor` phải sạch cho nền tảng muốn chạy.
2. Dựng cơ sở dữ liệu nội dung từ `content/` (khoảng 30 giây):

   ```sh
   python3 tool/content/pack.py      # content/dataset (JSON) -> content/grammar.db (gitignore)
   ```

3. Tuỳ chọn, tải phần nặng từ Google Drive (link ở mục Releases hoặc hỏi người quản lý repo):

   | Gói | Nội dung | Giải nén vào |
   |---|---|---|
   | `grammar4-audio.zip` (≈ 620 MB) | 119 bài đọc giọng thật (MP3/WAV) | `content/` (tạo ra `content/dataset/audio/`) |
   | Thư mục video (≈ 8,6 GB) | 210 tập MP4 có phụ đề (`A 01.mp4` …) | thư mục bất kỳ, chọn trong trang Video của app |

   Không có audio thì các bài đó đọc bằng giọng máy; không có video thì trang Video báo thiếu file. Thư mục audio và thư mục video có thể đặt ở bất kỳ đâu rồi chọn trong **Cài Đặt → Dữ liệu**.
4. Chạy:

   ```sh
   flutter pub get
   flutter run -d windows   # hoặc -d macos, -d linux, -d <android device>
   flutter analyze && flutter test   # test tra từ và chấm bài dùng content/grammar.db
   ```

   App tìm dữ liệu theo thứ tự: thư mục đã lưu trong Cài Đặt → `--dart-define=GRAMMAR_DATA_DIR=...` → `content/` trong thư mục làm việc → hỏi người dùng. Dữ liệu người dùng (từ đã lưu, tiến độ, bài tự nhập) nằm trong `user.db` ở thư mục hỗ trợ của app; Cài Đặt có xuất/khôi phục JSON.

   **Cài Đặt → Dữ liệu** có ba mục, mỗi mục hiện tóm tắt những gì tìm thấy: *Dữ liệu bài học* (chọn file `grammar.db`; ảnh đọc từ `dataset/img` cạnh file; hiện phiên bản, ngày phát hành, số bài), *Âm thanh thực* (chọn thư mục chứa `1.mp3`, `2.wav`…; mặc định `dataset/audio` cạnh `grammar.db`; hiện số bài có file), *Video* (chọn thư mục chứa `A 01.mp4`…; hiện số tập có file).

## Sửa nội dung bài học

Nguồn nội dung là các file trong `content/dataset/` (JSON có cấu trúc, bài văn phạm là Markdown nhẹ, ảnh WebP), mô tả từng trường ở `docs/09` và tài liệu dữ liệu của repo `grammar-legacy`. Quy trình:

1. Sửa hoặc thêm bài trong `content/dataset/`. Các file JSON theo một bố cục dễ đọc (mỗi câu, cặp hội thoại, nghĩa từ điển một dòng) để diff xem được bằng mắt; script nào ghi file thì dùng `jsonfmt.dumps`, hoặc chạy `python3 tool/content/jsonfmt.py` sau khi sửa.
2. `python3 tool/content/check.py` — báo lỗi nếu file lệch bố cục, hoặc nếu bản sửa làm mất hay đổi nghĩa một ID cũ (tiến độ của người học trỏ vào các ID này). Khi **thêm** mục mới thì chạy `--update` để ghi ID mới vào `content/ids.json`.
3. Tăng `version` trong `content/content.json` (PATCH sửa lỗi, MINOR thêm bài, MAJOR phá tương thích) và ghi vào `content/CHANGELOG.md`.
4. `python3 tool/content/pack.py`, chạy app kiểm tra; commit cả nội dung và `ids.json`.

Phiên bản nội dung được ghi vào `grammar.db` (bảng `meta`: `content_version`, `content_date`, `schema_version`) và hiện ở Cài Đặt → Dữ liệu. Nếu đổi lược đồ DB thì tăng `schema` trong `content.json` và `ContentDb.supportedSchema` trong app cùng lúc; app từ chối DB có lược đồ mới hơn nó.

## Đóng gói dữ liệu cho người dùng

```sh
python3 tool/content/bundle.py                         # check + pack -> build/content/grammar.db + grammar.images
python3 tool/content/bundle.py --zip-data              # kèm grammar4-data-<phiên bản>.zip gộp hai file, để chia sẻ tay
python3 tool/content/bundle.py --zip-audio <thư mục 1.mp3…>  # kèm gói giọng đọc thật
```

Kết quả trong `build/content/`: `grammar.db` và `grammar.images` cho người tải tay, `grammar.db.gz` (cùng DB nén, bằng một phần ba) và `bundle.json` (phiên bản, kích thước, sha256 từng file) dành cho việc app tự tải dữ liệu sắp làm (docs/07 §12), kèm `SHA256SUMS.txt`. Pipeline phát hành đính từng file riêng; gói zip (`--zip-data`) tiện gửi tay, người nhận giải nén ra thư mục. `--web` dựng thêm `build/content/web/`: `grammar.db` biến thể cho bản web (không nhúng trang tranh, không phụ đề video; xem docs/09) và `img/pages/` là các trang tranh dạng file; `--host` chạy tiếp `tool/content/host.py --verify` ra `build/host/`, bố cục cho máy chủ web (docs/09 §4). Người dùng đặt cả hai file vào một thư mục bất kỳ rồi chọn thư mục đó trong Cài Đặt → Dữ liệu:

```
grammar.db       bài học + 155 trang Từ Vựng Tranh (nhúng trong DB, bảng media)
grammar.images   ảnh minh hoạ bài đọc và luyện nói (zip không nén, app đọc thẳng; tuỳ chọn)
audio/…          giọng đọc thật, từ gói audio giải nén vào cùng thư mục (tuỳ chọn)
video/…          video Luyện Nghe A 01.mp4 … (tuỳ chọn)
```

Cấu trúc `content/dataset/` chỉ là nguồn trong repo; app đọc được cả hai cấu trúc (không có `grammar.images` thì tìm ảnh trong `img/` hoặc `dataset/img/`). DB không mã hoá (từ 1.2.0; `grammar.db` mã hoá của bản 1.0.x không mở được nữa, tải gói mới).

## Cấu trúc

```
lib/
  main.dart            gọi app/bootstrap: user.db → thư mục dữ liệu → grammar.db → TTS → ProviderScope
  app/                 bootstrap_{io,web} (khởi động theo nền tảng), grammar_app, providers (Riverpod), router (go_router), theme
  data/                content_db*.dart (grammar.db, chỉ đọc; content_db_io: thư mục dữ liệu), media_store (ảnh/ghi âm ngoài DB), folder_media (thư mục cạnh grammar.db), manifest + block_vfs (DB web: khối nén, VFS chỉ đọc), user_db*.dart, user_readings, models, search_key, backup
  domain/              lookup (tra từ như app gốc), sentence_player (TTS hoặc ghi âm theo mốc câu)
  platform/            tts.dart (Windows: SAPI qua kênh riêng; nền tảng khác: flutter_tts); các cặp *_io/*_web sau `import … if (dart.library.js_interop)`: native (SQLite, thư mục), env, app_dirs, user_images — cùng kiểu: app/bootstrap, ui/video/video_routes, ui/settings/data_section
  ui/                  home, dictionary, readings, grammar, exercises, dialogs, listening, video, analysis, pictures, vocab, user_readings, settings, help
  ui/widgets/          WordTapText (chạm từ, từ đã lưu đỏ), MarkText (Markdown nhẹ của bài văn phạm), shell
windows/runner/sapi_tts.cpp   TTS SAPI cho Windows
web/                          vỏ web (index.html, manifest, icon); bản web đang làm theo docs/07 §12
content/dataset/              nguồn nội dung (JSON, Markdown nhẹ, ảnh); content.json phiên bản; ids.json ID ổn định; CHANGELOG.md
tool/content/pack.py          dựng content/grammar.db từ content/dataset
tool/content/check.py         kiểm tra ID ổn định trước khi phát hành nội dung
tool/content/jsonfmt.py       bố cục JSON dễ đọc, dễ diff của content/dataset (`--check` chỉ báo)
tool/content/bundle.py        đóng gói bản phát hành: grammar.db, grammar.db.gz, grammar.images, bundle.json (`--web`: thêm bản web; `--host`: thêm build/host; `--zip-data`: kèm grammar4-data-<phiên bản>.zip; `--zip-audio`: grammar4-audio-<phiên bản>.zip)
tool/content/host.py          bố cục cho máy chủ web (docs/09 §4): DB web cắt khối nén thành pack, ảnh rời, manifest.json; `--verify` ghép lại kiểm tra
docs/                         kế hoạch port (07), ma trận truy vết hành vi app gốc (08), lược đồ SQLite (09)
DESIGN.md                     tham chiếu phong cách giao diện
```

## Ghi chú nền tảng

- **Windows**: `flutter_tts` sập trên một số máy nên TTS dùng SAPI qua kênh `grammar/tts` (`windows/runner/sapi_tts.cpp`), đúng engine Grammar 3.1 dùng (tốc độ 1–7 → Rate −10…8). Nếu `flutter build windows` báo `nuget.exe not found`, tải nuget.exe và thêm vào PATH. Nếu CMake đòi ghi vào `C:\Program Files\grammar`, xoá `build/windows` rồi build lại.
- **macOS**: App Sandbox đã tắt trong `macos/Runner/*.entitlements` để đọc thư mục dữ liệu và video do người dùng chọn. TTS dùng giọng hệ thống (System Settings → Accessibility → Spoken Content).
- **Android**: `android/gradle.properties` tắt Kotlin incremental và Gradle daemon vì lỗi cache kẹt trên Windows; bật lại nếu máy bạn không gặp.
- **Video** phát bằng `media_kit` (libmpv); phụ đề đồng bộ theo mốc kết thúc dòng như app gốc. Lối vào Video chỉ hiện khi DB có phụ đề (biến thể `full`).
- **Chụp màn hình tự động**: biến môi trường `GRAMMAR_INITIAL_ROUTE=/dict/word/ball` mở thẳng một màn hình.

## Phát hành

Bản phát hành gồm Windows, Android, macOS; chưa làm Linux, web và iOS. GitHub Actions (`.github/workflows/release.yml`) chạy khi đẩy tag `vX.Y.Z`. Workflow kiểm tra tag khớp `version:` trong `pubspec.yaml`, chạy check/analyze/test, build có `--obfuscate`, rồi tạo **bản nháp** GitHub Release kèm `Grammar-windows-x64.zip`, `Grammar-android.apk`/`.aab`, `Grammar-macos-universal.zip` (tên không mang số phiên bản để link `releases/latest/download/<file>` luôn trỏ bản mới nhất; chỉ release đã publish mới là "latest"). Symbol để giải mã stack trace nằm trong artifact `symbols-*` của lần chạy (giữ 90 ngày). Muốn build mà không tạo release thì chạy tay: Actions → Release → Run workflow, chọn nhánh, chọn `platform` (`all` hoặc một nền tảng, `data` để chỉ đóng gói dữ liệu), tuỳ chọn `skip_check` để bỏ job `check` (kiểm tra nội dung, analyze/test) khi chỉ cần build thử. Gói dữ liệu do job `data` đóng, chạy sau `check`. Mỗi file build (zip, apk, aab, gói dữ liệu) là một artifact riêng, không bọc thêm zip, ở mục Artifacts của lần chạy.

Thiết lập một lần, trong GitHub → Settings → Environments → **`Release`** → Environment secrets. Các job của workflow khai báo `environment: Release` nên mới đọc được các secret này. Nếu environment có giới hạn nhánh/tag (Deployment branches and tags), phải cho phép `main` và tag `v*`; nếu bật Required reviewers thì mỗi lần chạy phải duyệt.

| Secret | Giá trị |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | keystore ký Android dạng base64 (`base64 -w0 release.jks`) |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | mật khẩu và alias của keystore |

Tạo keystore: `keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias grammar`. Cất keystore ở chỗ an toàn ngoài repo: mất nó thì không phát hành được bản cập nhật cho người đã cài. Muốn build có ký trên máy, tạo `android/key.properties` (đã gitignore) với `storeFile=`, `storePassword=`, `keyAlias=`, `keyPassword=`. Không có file này thì bản release ký bằng khoá debug.

Các bước phát hành:

1. Tăng `version:` trong `pubspec.yaml` (ví dụ `0.2.0+2`; số sau `+` là versionCode Android và phải tăng mỗi lần).
2. Commit, rồi `git tag v0.2.0 && git push origin v0.2.0`.
3. Dữ liệu bài học: workflow tự chạy `tool/content/bundle.py` và đính `grammar.db` (ảnh trang tranh nằm trong DB), `grammar.images` (ảnh minh hoạ), `grammar.db.gz` và `bundle.json` (cho việc app tự tải dữ liệu, docs/07 §12) vào bản nháp. Bộ cài không chứa dữ liệu: người dùng tải `grammar.db` và `grammar.images` vào một thư mục rồi chọn thư mục đó trong Cài Đặt → Dữ liệu. Muốn tự đóng gói trên máy: `python3 tool/content/bundle.py`. Audio và video không đóng gói: đưa thư mục lên Google Drive; người dùng đặt `audio/`, `video/` cạnh grammar.db (app tự tìm) hoặc chọn thư mục khác trong Cài Đặt.
4. Mở bản nháp release, ghi chú gồm: link Drive tới audio và video; danh sách "cố ý khác" ở cuối docs/08; cách mở lần đầu (dưới đây). Sau đó Publish.

Mở lần đầu: **Windows** giải nén rồi chạy `grammar.exe`; SmartScreen cảnh báo vì exe chưa ký, chọn More info → Run anyway. **macOS**: app chưa notarize, nên nhấp phải → Open, hoặc chạy `xattr -cr "Grammar 4.0.app"`. **Android**: cho phép cài từ nguồn không rõ.

## Tài liệu

- [docs/07-ke-hoach-port.md](docs/07-ke-hoach-port.md) — kế hoạch, kiến trúc, mốc M1–M6, quyết định và cách bảo vệ nội dung.
- [docs/08-ma-tran-truy-vet.md](docs/08-ma-tran-truy-vet.md) — 106 hành vi của app gốc → thủ tục VB6 → dữ liệu → quyết định port → trạng thái. Cập nhật cột cuối khi làm xong một hành vi.
- [docs/09-luoc-do-sqlite.md](docs/09-luoc-do-sqlite.md) — lược đồ `grammar.db` và các bảng người dùng.
- Repo `grammar-legacy`: bộ công cụ ETL đã chuyển dữ liệu Grammar 3.1 thành `content/dataset` (chỉ dùng cho lần nhập đầu; từ nay sửa nội dung ở repo này), mô tả định dạng gốc, 72 ảnh chụp app gốc, 28 bài hướng dẫn nguyên văn và năm báo cáo phân tích mã VB6. Các tham chiếu `docs/02`, `docs/05`, `docs/06`, `docs/source/*` trong docs/08 trỏ sang repo đó.

## Bản quyền

Mã nguồn: giấy phép sẽ ghi trong `LICENSE`. Nội dung học trong `content/` cùng âm thanh và video thuộc tác giả Grammar 3.1 và các bên liên quan, được phân phối miễn phí cho việc học theo uỷ thác của tác giả; không được bán hay đóng gói lại để thu lợi.
