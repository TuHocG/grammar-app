# Lược đồ SQLite cho app (`dist/grammar.db`)

Sinh bằng `python -m etl pack-sqlite --dataset dist/dataset --out dist/grammar.db` (20 giây, 230 MB). Chỉ chứa **nội dung**; app tự tạo các bảng người dùng (mục 3). Ảnh và âm thanh là file trong `img/`, `audio/` cạnh DB; cột đường dẫn là tương đối. Cột JSON giữ nguyên cấu trúc như trong `dist/dataset` (xem `docs/05` phần B).

## 1. Bảng nội dung

| Bảng | Khoá | Cột chính | Ghi chú |
|---|---|---|---|
| `meta` | key | value | `counts`, `built`, `dialog_images` (JSON 16 ảnh), `media_note` |
| `dict_entry` | id | headword, key, ipa, segs (JSON), quick (JSON) | 544.266 dòng; `key` = chữ thường bỏ dấu, có index; `dict_fts` (FTS5 trên headword) |
| `quick_def` | key | word, ipa, respell, pos, vi | 12.787 nghĩa nhanh, tra theo `key` |
| `reading_section` | sid | parent_sid, title, depth, position | cây mục lục 139 nút lá + nhóm |
| `reading` | id | sid, position, title, img, audio, times (JSON), title_audio, page, en (JSON), vi (JSON) | 4.565 bài; `en`/`vi` là mảng đoạn → câu |
| `reading_sentence` | (reading_id, idx) | para, en, vi | 181.366 câu, `reading_sentence_fts` (FTS5 trên `en`) để tìm câu chứa từ |
| `dialog_topic` | sid | title, position | 19 chủ đề |
| `dialog` | id | sid, position, title, pairs (JSON) | 2.641 bài, 4 cặp `{a,b,avi,bvi}` |
| `grammar_lesson` | ref (1-based) | title, chapter, drills, body (Markdown nhẹ) | 356; `ref` là số mà mọi tham chiếu `?n` dùng |
| `exercise_menu` | idx 0–8 | name, start, end | 9 bộ đề cột phải |
| `exercise` | id | menu, lesson_ref, g, kind, text, blanks, given, choices, answer, vi, expl, refs | 49.557; `menu` NULL = bài tập theo bài văn phạm (`lesson_ref`) |
| `wordform_family` | id | members (JSON) | 17.878 họ từ; `wordform_member(word → family_id)` để tra ngược |
| `wordform_root` | position | root, start, n, common | 3.901 từ gốc; `start` 1-based trong menu WORD FORMS; `common` = có trong danh sách thông dụng |
| `listening_item` | id | unit, n, en, correct, options (JSON) | 1.142 |
| `analysis_lesson` | id | words (JSON) | 12 |
| `picture_topic` | id | title, first, words (JSON có `xy`, `img`), page | 155 |
| `subtitle_film` | id | code, grp, title, first_line, video, duration, lines | 210 |
| `subtitle_line` | (film_id, idx) | s, e, en, vi | 34.671 |
| `help_topic` | id | title, text | 30 |

Truy vấn mẫu (đo trên máy phát triển): tra tiền tố `WHERE key >= ? AND key < ?` 1,7 ms; `dict_fts MATCH` 2,5 ms.

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
| `user_reading` | id, package, title, en (JSON), vi (JSON), img, grammar_refs (JSON), created_at | `BaiNhap/` |
| `user_setting` | key, value | tốc độ, giọng, cỡ chữ, chủ đề |

Xuất/nhập: toàn bộ các bảng `user_*` ra một file JSON để sao lưu và chuyển máy.
