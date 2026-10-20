# Lược đồ SQLite cho app (`dist/grammar.db`)

Sinh bằng `python3 tool/content/pack.py` (từ `content/dataset` ra `content/grammar.db`; trước 2026-10-07 là `python -m etl pack-sqlite` của repo `grammar-legacy`) (20 giây, 210 MB bản `full`, 176 MB bản `web`). Chỉ chứa **nội dung**; app tự tạo các bảng người dùng (mục 3). Ảnh và âm thanh là file trong `img/`, `audio/` cạnh DB; cột đường dẫn là tương đối. Cột JSON giữ nguyên cấu trúc như trong `dist/dataset` (xem `docs/05` phần B). Không có mốc giờ dựng: cùng nội dung và cùng phiên bản SQLite dựng ra cùng byte.

**Hai biến thể** (từ 1.2.0, `pack.py --variant`, ghi ở `meta.variant`), cùng lược đồ: `full` (bản cài offline) có hai phần tuỳ chọn là bảng `media` và `subtitle_film`/`subtitle_line`; `web` (bản web) không có cả hai — trang Từ Vựng Tranh là file ảnh như ảnh minh hoạ, và bản web không có video. App kiểm tra bảng có tồn tại hay không (`ContentDb.hasVideo`, `embeddedMedia`) chứ không hỏi nền tảng.

## 1. Bảng nội dung

| Bảng | Khoá | Cột chính | Ghi chú |
|---|---|---|---|
| `meta` | key | value | `content_version`, `content_date`, `schema_version` (từ `content/content.json`), `variant`, `counts`, `dialog_images`, `dialog_page_images`, `exercise_group_size` |
| `dict_entry` | id | headword, key, ipa, segs (JSON), quick (JSON), redirect | 544.266 dòng; `key` = chữ thường bỏ dấu, có index |
| `quick_def` | key | word, ipa, respell, pos, vi | 12.787 nghĩa nhanh, tra theo `key` |
| `reading_section` | sid | parent_sid, title, depth, position | cây mục lục 139 nút lá + nhóm |
| `reading` | id | sid, position, title, img, audio, times (JSON), title_audio, page | 4.660 bài; thân bài nằm ở `reading_sentence` |
| `reading_sentence` | (reading_id, idx) | para, en, vi | 199.333 câu theo thứ tự, `para` đánh dấu đoạn |
| `dialog_topic` | sid | title, position | 19 chủ đề |
| `dialog` | id | sid, position, title, pairs (JSON) | 2.641 bài, 4 cặp `{a,b,avi,bvi}` |
| `grammar_lesson` | ref (1-based) | title, chapter, drills, body (Markdown nhẹ) | 356; `ref` là số mà mọi tham chiếu `?n` dùng |
| `exercise_menu` | idx 0–8 | name, start, end | 9 bộ đề cột phải |
| `exercise` | id | menu, lesson_ref, g, kind, text, blanks, given, choices, answer, vi, expl, refs | 49.557; `menu` NULL = bài tập theo bài văn phạm (`lesson_ref`) |
| `wordform_family` | id | members (JSON) | 17.878 họ từ; `wordform_member(word → family_id)` để tra ngược |
| `wordform_root` | position | root, start, n, common | 3.901 từ gốc; `start` 1-based trong menu WORD FORMS; `common` = có trong danh sách thông dụng |
| `listening_item` | id | unit, n, en, correct, options (JSON) | 1.142 |
| `analysis_lesson` | id | words (JSON) | 12 |
| `picture_topic` | id | title, first, words (JSON có `xy`, `img`), page | 155; `page` (`img/pages/<n>.webp`) nằm trong bảng `media` (`full`) hoặc là file (`web`) |
| `media` (chỉ `full`) | path | mime, data (BLOB) | Ảnh bắt buộc nhúng trong DB, tra theo đúng đường dẫn tương đối nội dung dùng. Hiện là 155 trang Từ Vựng Tranh (28 MB): tiêu điểm vẽ trên các trang này nên không thể thiếu. |
| `subtitle_film` (chỉ `full`) | id | code, grp, title, first_line, video, duration, lines | 210 |
| `subtitle_line` (chỉ `full`) | (film_id, idx) | s, e, en, vi | 34.671 |

Đã bỏ (1.2.0, app chưa bao giờ đọc): cột `reading.en`/`vi` (bản sao của `reading_sentence`), chỉ mục FTS5 `dict_fts` và `reading_sentence_fts`, bảng `help_topic` (hướng dẫn của app nằm trong mã, `lib/ui/help/help_content.dart`), khoá `meta.built`, `media_note`. Truy vấn mẫu (đo trên máy phát triển): tra tiền tố `WHERE key >= ? AND key < ?` 1,7 ms.

**File ngoài DB.** Ảnh minh hoạ (`reading.img`, ảnh luyện nói trong `meta`) và ghi âm (`reading.audio`) không nằm trong DB; DB giữ đường dẫn tương đối `img/...`, `audio/...`. Bản phát hành (`tool/content/bundle.py`) gom ảnh minh hoạ vào `grammar.images` cạnh grammar.db: zip không nén, mỗi ảnh mang đúng đường dẫn `img/...` của nội dung, app đọc thẳng từ zip (`lib/data/image_pack.dart`). Không có file này thì app tìm `<thư mục chứa grammar.db>/img/...`, rồi `<thư mục>/dataset/img/...` (cấu trúc `content/` trong repo). Ghi âm vẫn là file trong `audio/`. Thiếu ảnh minh hoạ thì bài học vẫn dùng được; thiếu ghi âm thì đọc bằng giọng máy.

**Lược đồ.** 1: bản đầu. App đọc được lược đồ ≤ `ContentDb.supportedSchema` (= 1); DB không có bảng `media` vẫn mở được, khi đó ảnh trang tranh lấy từ file; không có `subtitle_film` thì các lối vào Video ẩn đi. Bỏ bảng/cột app không đọc (1.2.0) không tăng lược đồ: app 1.0.x vẫn mở được DB 1.2.0.

## 2. Quy ước tra từ

1. Chuẩn hoá chuỗi người dùng chạm bằng cùng hàm `search_key` (chữ thường, bỏ dấu, gộp khoảng trắng).
2. Thử `quick_def` theo key → nghĩa nhanh; nếu không có, thử `dict_entry` theo key; nếu không có, thử dạng gốc (bỏ `s`, `es`, `ed`, `ing`, `d`, nhân đôi phụ âm) như app gốc (`Doi_ed_ing_TuDien.bas`, sẽ chốt theo báo cáo `docs/source/D`).
3. Họ từ: `wordform_member` theo từ → `wordform_family.members`.

## 3. Bảng người dùng (app tạo, cùng DB hoặc DB riêng `user.db`)

| Bảng | Cột | Thay cho file cũ |
|---|---|---|
| `user_word` | id, headword, key, meaning (nghĩa người dùng tự tạo hoặc NULL), ipa, context_reading_id, context_idx, added_at, marked (0/1, cho Quay Từ), box, next_review | `DataTuDienUser.txt`, `dataChon.txt`, phần "từ chọn" trong `data.Kcu` |
| `user_progress` | kind, item_id, state (JSON), updated_at | `data.Kcu` (vị trí đang học, điểm) |
| `user_dialog_pick` | dialog_id, pair_idx, picked_at | `DataSpChon` (câu đàm thoại đã chọn) |
| `user_dialog_skip` | dialog_id, pair_idx | "Bỏ câu này" |
| `user_picture_pick` | topic_id, word_idx | tiêu điểm đã chọn (`dataHH.xy` byte cờ) |
| `user_wordform_mark` | root_position, level (1 đỏ sáng, 2 đỏ sẫm) | trạng thái bảng Word Forms |
| `user_reading` | id, package, title, en (JSON), vi (JSON), img, created_at | `BaiNhap/` |
| `user_grammar_mark` | ref (bài văn phạm), added_at | bài "Ngu Phap" trong `BaiNhap/` (Ngữ Pháp Của Bạn) |
| `user_setting` | key, value | tốc độ, giọng, cỡ chữ, chủ đề |

Khoá `user_progress` (kind / item_id → state) app đang dùng:

| kind | item_id | state |
|---|---|---|
| `reading` | `last_reading` | id bài đọc mở gần nhất (cả bài nhập của bạn) |
| `reading` | `last_section`, `last_in_<sid>` | nhóm mở gần nhất; bài mở gần nhất trong nhóm |
| `grammar` | `last_lesson`; `chapter`, `saved_chapter` | bài văn phạm mở gần nhất; chương đang mở (cây đầy đủ / Ngữ Pháp Của Bạn) |
| `exercise` | `menu<m>-g<n>`, `lessons-<refs>`, `wordforms` | `{"pos","score","done"}` của nhóm bài tập |
| `listening` | `last`; `unit<u>` | unit mở gần nhất; điểm lần làm gần nhất ("đúng x/y") |
| `dialog` | `last`; `last_topic` | bài Luyện Nói mở gần nhất; chủ đề mở gần nhất |
| `analysis` | `last` | bài Phân Tích Câu mở gần nhất |
| `pictures` | `last` | chủ đề Từ Vựng (Tranh) mở gần nhất |
| `video` | `last` | video mở gần nhất |

`updated_at` tăng ngặt theo mỗi lần ghi; thẻ **Đang học** ở trang chính lấy mục có `updated_at` lớn nhất trong các khoá `last…` ở trên.

Xuất/nhập: toàn bộ các bảng `user_*` ra một file JSON để sao lưu và chuyển máy.

## 4. Bố cục cho máy chủ web (`tool/content/host.py`, `build/host/`)

Bản web (docs/07 §12) không mở file: nó tải DB biến thể `web` về trình duyệt một lần rồi đọc qua VFS chỉ đọc của `package:sqlite3` bản WASM (`lib/data/block_vfs.dart`). Để tải được từng phần và không phải giải nén cả DB vào bộ nhớ, `host.py` cắt DB thành **khối** (mặc định 64 KiB = 16 trang SQLite), nén raw-deflate từng khối, nối các khối thành **pack** khoảng 8 MiB (giới hạn 25 MiB/file của Cloudflare Pages) đặt tên theo sha256 của nội dung nên bất biến trên máy chủ. App giữ pack dạng nén trong bộ nhớ và chỉ giải nén khối SQLite đang đọc, giữ ~16 MB khối gần nhất.

```
data/latest.json              {"version","schema","manifest"} — bản hiện hành (no-cache)
data/<version>/manifest.json  format, content_version, schema, date, variant,
                              db: {size, sha256, page_size, block_size, packs: [{name, size, sha256, blocks: [độ dài nén từng khối]}]},
                              images: {"img/…": [bytes, sha8]}
data/db/<sha16>.bin           pack (immutable)
img/…                         mọi ảnh theo đường dẫn nội dung (ảnh minh hoạ và trang tranh)
```

Khối `i` chiếm byte `[i·block_size, (i+1)·block_size)` của file (khối cuối ngắn hơn); vị trí của nó trong pack tính dồn từ `blocks`. `host.py --verify` ghép lại và so sha256; `test/host_layout_test.dart` kiểm tra bố cục đã dựng, `test/block_vfs_test.dart` so mọi truy vấn qua VFS với DB mở thẳng. Số liệu 1.2.0: 176 MB → 8 pack, 56,5 MB. Manifest `format` tăng khi đổi bố cục; app đọc tới `HostManifest.supportedFormat`.
Tên pack phụ thuộc bản zlib dựng ra nó (cùng nội dung, máy khác có thể cho pack khác), nên trên máy chủ chỉ pack là `immutable`; `latest.json` và `manifest.json` phải `no-cache`.
