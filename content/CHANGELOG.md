# Lịch sử nội dung

Phiên bản nội dung `MAJOR.MINOR.PATCH` nằm trong `content/content.json`, được ghi vào `grammar.db` (bảng `meta`, khoá `content_version`) và hiện trong Cài Đặt của app.

- **PATCH**: sửa chính tả, bản dịch, đáp án, lời giảng; không thêm bớt mục nào.
- **MINOR**: thêm bài, câu, bài tập, mục từ điển; ID cũ giữ nguyên, ID mới cấp tiếp.
- **MAJOR**: thay đổi phá vỡ tương thích. Nếu lược đồ DB đổi thì tăng cả `schema`, và app phải được cập nhật cùng lúc (app từ chối DB có `schema` lớn hơn bản nó hỗ trợ).

Trước khi tăng phiên bản: `python3 tool/content/check.py` phải qua (không mất ID cũ).

## 1.1.0 — 2026-10-13

Bản dữ liệu 2019 của tác giả (thư mục `Data G/Code`, mới hơn bản cài 2018), nhập bằng `tools/content_import.py` của `grammar-legacy`, giữ nguyên mọi ID cũ:

- **Luyện nói**: thêm chủ đề **"Nha Khoa."** với 99 bài (2.641 → 2.740 bài, 19 → 20 chủ đề); bài 2659 được tác giả bổ sung. Bài 100 của chủ đề (3 cặp câu) bị bỏ vì bản 2019 chưa có phần tiếng Việt.
- **Bài đọc**: 4.565 → 4.661 bài. Thêm 96 bài và 7 nhóm trong "Books. › Stories." (Những cuộc phiêu lưu của Pinocchio, Phù Thủy Xứ OZ, Gulliver Du Ký, Ông già và biển cả, Ba Câu Hỏi của nhà vua, Nhóm Lửa, Thảm kịch ở Styles); 61 bài trong "Books." được tác giả viết lại (Jane Eyre, How Men Think, Four Seconds…) giữ ID cũ; 143 bài đổi tiêu đề (ví dụ "Confidence 1." → "Chapter 1.") giữ ảnh cũ; 1 bài sửa bản dịch. Hai nhóm đổi tên nhẹ ("Raising a Self Reliant Child.", "You can.").
- Bản 2019 bị hỏng phần tiếng Việt của 7 bài "Truyện Ngắn" (ID 4687–4693: Promotion, River, King Of The Pumpkins, Tommaso Argento In London, The Skier, Scarlett, The Robe Of Peace): giữ bản dịch 2018, phần tiếng Anh giống hệt. Chỉ bài 538 có sửa dịch thật (một câu).
- Ảnh minh hoạ cho cả 96 bài truyện mới, lấy từ các ấn bản đã hết bản quyền trên Project Gutenberg: Phù Thủy Xứ OZ (W. W. Denslow, 1900, 19 bài), Pinocchio (Carlo Chiostri, 1901, 34/36 bài — chương 5 và 30 của ấn bản không có tranh), Gulliver (ấn bản D.C. Heath 1900, 16 bài). Thêm 27 ảnh chọn riêng từ Wikimedia Commons và Gutenberg cho các bài mà các ấn bản trên không có tranh: Pinocchio chương 5 và 30 (Enrico Mazzanti, 1883), cả 10 chương Ông già và biển cả (tranh Winslow Homer, Rosa Bonheur và hình cá của cơ quan nghề cá Hoa Kỳ), Ba Câu Hỏi của nhà vua (Michel Sevier, 1916), Nhóm Lửa (ảnh Eric A. Hegg trên đèo Chilkoot, 1898), Thảm kịch ở Styles (hai sơ đồ in trong ấn bản 1920 cho chương 3–4; các chương khác là tranh, ảnh cùng thời về bối cảnh của chương: dinh thự Essex, phiên điều tra tử vong, Scotland Yard, người Bỉ tị nạn, nhà bằng quân bài của Chardin…). Nguồn từng ảnh trong `content/IMAGE_CREDITS.md`.
- Ảnh cho bài cũ "origins of Life" của Grammar 3.1, vốn không có ảnh: ảnh NASA chụp Stanley Miller bên bộ thí nghiệm. Các bài Lớp 6-12 và bài Phiên Âm Quốc Tế không có ảnh giữ nguyên như app gốc.

## 1.0.0 — 2026-10-07

- Bản đầu tiên, chuyển nguyên vẹn từ Grammar 3.1 bằng ETL của repo `grammar-legacy` (giải mã 100 %, đối chiếu mã nguồn VB6).
- 544.266 mục từ điển, 4.565 bài đọc, 2.641 bài luyện nói, 356 bài văn phạm, 49.557 bài tập, 3.901 từ gốc Word Forms, 1.142 câu luyện nghe, 12 bài phân tích câu, 155 chủ đề từ vựng tranh, 210 tập phụ đề, 30 bài hướng dẫn, 3.315 ảnh. Audio (119 bài) và video (210 tập) phân phối riêng.
- `grammar.db` chứa luôn 155 trang Từ Vựng Tranh (bảng `media`) vì tiêu điểm vẽ trên các trang này; ảnh minh hoạ và ghi âm vẫn là file, được `tool/content/bundle.py` đặt trong `img/` và `audio/` cạnh `grammar.db`.
- Audio phát hành toàn bộ dạng MP3: 8 file WAV gốc (bài 2–5 MS ADPCM, 6–9 PCM 8 bit) được chuyển sang MP3 CBR bằng `tools/audio/transcode.py` của repo `grammar-legacy`, vì Windows và Android không phát được MS ADPCM; `reading.audio` của bài 2–9 là `audio/<n>.mp3`. Mốc câu (`times`) của bài 2–5 nhân với 11179 / 11155,73 = 1,0020858: header của bốn file ADPCM gốc ghi tốc độ dữ liệu 11179 B/s trong khi thực tế là 11155,73 B/s (block 512 byte = 1012 mẫu ở 22 050 Hz), Windows Media Player tính vị trí theo header nên mốc gốc chậm dần so với thời gian thật (lệch ≈ 0,8 s ở cuối bài 2). Bài 6–9 (PCM) giữ nguyên mốc.
- Phụ đề video: câu đầu của 68 tập có mốc bắt đầu `s` (trước đây 0, tức tính cả đoạn mở đầu, vì app gốc chỉ lưu mốc kết thúc). Mốc tìm bằng script `tools/video/first_line_start.py` của repo grammar-legacy: 55 tập nhận dạng giọng nói (faster-whisper) tìm đúng các từ của câu 1, lùi 0,5 s; 3 tập theo Silero VAD và 7 tập ước lượng theo số từ khi lời bị nhạc lấn hoặc không được đọc; 3 tập (A 47, B 24, B 46) chỉnh tay sau khi nghe kiểm tra. Câu không có chữ ("...") và đoạn mở đầu dưới 3 s giữ `s = 0`. Các câu khác không đổi (câu i vẫn bắt đầu ở mốc kết thúc câu i−1).
