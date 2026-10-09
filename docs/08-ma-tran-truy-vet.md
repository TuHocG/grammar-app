# Ma trận truy vết: hành vi app gốc → mã nguồn → dữ liệu → quyết định port

Bản 1, 2026-10-05. Mỗi dòng là một hành vi quan sát được của Grammar 3.1, lấy từ `docs/02` (bảng tính năng và checklist), `docs/06` (28 bài hướng dẫn của tác giả) và `docs/source/A..E` (phân tích mã VB6). Cột **Quyết định** có ba giá trị: **Giữ** (tái tạo đúng hành vi), **Tương đương** (hành vi hiện đại thay thế, ghi rõ khác gì), **Bỏ** (ghi lý do). Cột **Mốc** theo `docs/07` §5. Cột **Kiểm thử** là cách xác nhận khi implement; "song song" = chạy app gốc trên máy này và so sánh.

Cột **Mã nguồn** ghi `file:thủ tục` trong `legacy/source-vb6-utf8/`; số dòng xem trong báo cáo `docs/source` tương ứng (A = Main2.frm, B = M1.bas và khởi động, C = READING.bas và từ điển, D = bài tập và từ vựng, E = âm thanh, video, đàm thoại, tranh).

Trạng thái thực hiện ghi ở cột cuối khi implement: ☐ chưa, ◐ đã viết mã (M1, 2026-10-05) nhưng chưa so song song với app gốc, ☑ xong và đã so song song.

## 0. Quy ước chung của app (áp dụng mọi màn hình)

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| G1 | Một cửa sổ, 18 nút menu cột trái/phải; mọi màn hình là các khung (RichTextBox) hiện/ẩn trong cùng form | A §1.1, `Main2.frm:butN_MouseUp`, B §5 | `data.Muc[0..8]` kích thước 9 menu | Tương đương: điều hướng theo trang (Flutter Navigator), menu chính dạng lưới; không giữ cơ chế khung chồng | M1 | 18 mục đều mở được | ☑ |
| G2 | Gõ chữ ở bất kỳ màn hình nào → mở danh sách headword cuộn tới chuỗi đã gõ | A §1.5, B `M1.bas:LoadListTudien1`, `RPhim_KeyPress` | `dict_entry.key` (tiền tố) | Tương đương: ô tìm kiếm toàn cục (phím tắt desktop: gõ bất kỳ ở màn hình đọc = mở tìm; Esc = đóng sheet/hộp thoại hoặc quay về trang trước); mọi trang có nút 🔍 mở bảng tra nhanh ngay trên trang (`lookup_sheet.dart`) | M1 | gõ "aban" → danh sách bắt đầu từ abandon | ☑ |
| G3 | Click trái vào một từ trong văn bản → nghĩa nhanh (IPA, phiên âm Việt hoá, nghĩa ngắn) + máy đọc từ | A §1.5, C §3.3 `TraTuDOS`, `TimtudienDOS` | `quick_def`, `dict_entry` | Giữ (WordTapText + QuickDefSheet) | M1 | chạm "ball" trong bài đọc → "bɔ:l / bôl / quả bóng" | ☑ |
| G4 | Rê chuột vào khung nghĩa nhanh → nghĩa đầy đủ (từ loại, nghĩa, ví dụ song ngữ, tham chiếu); click phải khung → tắt | A §1.5 `RDOS_MouseUp`, C §3.2 `Timtudien`, B §4.4 `VietS_Rhd` | `dict_entry.segs` | Tương đương: chạm "Xem đầy đủ" hoặc kéo sheet lên; vuốt xuống để tắt | M1 | mục "abandon" hiện đủ `pos/m/ex/dom/ref` | ☑ |
| G5 | Mục `Xem#x#` tự chuyển sang mục `x` | C §3.2 `LaytuGoc` | `dict_entry.redirect` (6.206 mục) | Giữ (hiện "→ x" rồi mở x; 65 đích thiếu thì báo không có). Chỉ mục đầy đủ (`Timtudien`) đi theo `Xem#`; nghĩa nhanh (`TimtudienDOS`) luôn là của đúng từ được chọn: "heard" hiện "đã nghe (quá khứ của Hear)", mục đầy đủ mượn của "hear" (232 mục như vậy) | M1 | tra "abaci" → mở "abacus"; chạm "heard" → tiêu đề "heard", không phải "hear" | ☑ |
| G6 | Không trúng → thử một lần dạng gốc của -ed/-ing/-s | C §3.2 `TimBienThe`, D §4.4 `Doi_ed_ing_TuDien.bas:DoiBienThe` | — | Giữ: quy tắc gốc + bảng 221 động từ bất quy tắc của app gốc (`Mang1..3` → `app/lib/data/irregular_verbs.dart`, 318 dạng) | M1 | "kicked" → "kick"; "went" → "go" | ☑ |
| G7 | Bôi đen cụm ≤ 4 từ để tra cụm; trong khung nghĩa nhanh ≤ 2 từ | A §7.5 `SoBlankQuet = 3` | `dict_entry` (có mục nhiều từ) | Giữ: bài đọc nằm trong `SelectionArea` (kéo chuột hoặc nhấn giữ để bôi đen); nút nổi "Tra cụm …" và mục "Tra từ điển" trong menu chọn; không giới hạn số từ; thử đổi một từ về dạng gốc như `DoiBienThe` rồi bỏ dần từ cuối (`LookupService.lookup`) | M1 | chọn "came through" → "come through"; "came through them" → "come through" | ☑ |
| G8 | Related forms: khi tra từ thuộc họ từ → danh sách dạng từ | D §4.3 `WorForm.bas:TuWordForm` | `wordform_family`, `wordform_member` | Giữ (một phần của QuickDefSheet) | M1 | "unit" → unit (n), interunit (adj)… | ☑ |
| G9 | Enter khi đang xem nghĩa → lưu từ + câu ngữ cảnh vào Từ Vựng Của Bạn; lưu lại lần nữa = bỏ đánh dấu trong bài | D §10 `TuVungChon.bas:SaveSTuChon`, A `cmbMouseWheel_KeyPress` | `user_word` (bản mới) | Giữ (nút "Lưu từ" trong sheet; bỏ phím Enter theo yêu cầu 2026-10-06) | M1 | lưu "abandon" → có trong danh sách và tô đỏ ở mọi bài | ☑ |
| G10 | Từ đã lưu tô đỏ trong mọi bài; từ cùng dạng (họ từ) gạch chân | D §10.3 `BatDOTuChonTrongR2` | `user_word` + `wordform_member` | Đổi có chủ ý (người dùng chọn 2026-10-06): mọi lần xuất hiện của từ/cụm đã lưu tô đỏ (khớp nguyên từ, cả cụm nhiều từ); gạch chân các từ cùng họ Word Forms và dạng biến đổi (`baseFormCandidates`: kicked → kick); từ đã lưu ở dạng biến đổi lấy họ của dạng gốc. Mã gốc thật ra tô đỏ lần đầu và gạch chân các lần lặp lại, không theo họ từ (docs/05 A). Áp dụng cho bài đọc, Phân Tích Câu, bài Văn Phạm | M2 | lưu "kick" → "kicked", "outkick" gạch chân; lưu "dog" → mọi "dog" đỏ, "dogs" gạch chân | ☑ |
| G11 | F2 → tạo/sửa từ của người dùng theo mẫu `Từ Anh: nghĩa Việt`; Enter máy tự thêm phiên âm, Enter nữa lưu; `_` = xuống dòng; rê vào từ rồi F2 = điền sẵn | D §10.1 `TaoTuVung.bas`, A `F2` | `user_word` (có trường nghĩa riêng) | Tương đương: form "Từ của bạn" với ô từ, nghĩa (`_` = xuống dòng), IPA tự điền từ từ điển. Mở được ngay trong bài: **F2** ở bất kỳ trang nào → điền sẵn cụm đang bôi đen, hoặc từ đang tra trong sheet, hoặc từ dưới chuột (từ đã lưu → "Sửa từ" với nghĩa riêng của nó; từ mới → phiên âm + nghĩa lấy sẵn từ từ điển, lưu kèm câu ngữ cảnh); nút "Sửa từ (F2)" / "Thêm với nghĩa riêng (F2)" trong sheet tra từ; nút "+" ở Từ Vựng Của Bạn | M1 | rê vào "abandon", F2, sửa nghĩa, Lưu → F2 lần nữa mở "Sửa từ" với nghĩa đó | ☑ |
| G12 | Bộ gõ tiếng Việt riêng (Telex/VNI, F1 đổi kiểu, ESC xoá) trong ô nhập | B §4.7 `Chung.bas`, `CheDoi_.bas` | `data.Kcu` slot 32 | Bỏ: hệ điều hành đã có bộ gõ | — | — | ☐ |
| G13 | ESC hoặc click phải ra ngoài khung → thoát màn hình hiện tại; lăn chuột cuộn | A §1.3–1.4 `NhanChuotPhaiIM1` | — | Tương đương: nút Back / cử chỉ vuốt; desktop giữ ESC | M1 | — | ☑ |
| G14 | Click phải lên nút menu chính → thoát app; nút đóng cửa sổ Windows vô hiệu | A §7.3 | — | Bỏ (dùng nút đóng chuẩn) | — | — | ☐ |
| G15 | Nút **Giọng** / Cài Đặt: chọn giọng SAPI, tốc độ 1–7 (Rate −10/−6/−3/0/2/4/8), bật/tắt âm thanh | E §1 `Amthanh.bas`, `PopUpWav.bas:TocDoDoc2` | `user_setting` | Tương đương: Windows dùng SAPI qua kênh riêng trong runner (`flutter_tts` sập trên Windows), nền tảng khác dùng `flutter_tts`; chọn giọng, 7 nấc tốc độ đúng bảng Rate | M1 | đọc "abandon" ở tốc độ 1 và 7 | ☑ |
| G16 | **Tạo File** xuất WAV: từ clipboard; click phải một bài → Creat; click phải chủ đề → Creat tất cả | E §1.7 `PopUpWav.bas:LamTaoWav`, A §2.19 | — | Tương đương: "Xuất âm thanh" bằng TTS nền tảng ra file (nếu nền tảng hỗ trợ synthesizeToFile) hoặc Bỏ trên web | M6 | xuất một bài ra file, phát được | ☐ |
| G17 | Đổi ảnh nền, trang trí hoạt hình (`Pic1/3/4/6`, `Sao.bas`, `RollNew*`) | C §7, E §2 `Amthanh.bas:GoiM` | `Pic1/3/4/6/7` | Bỏ (giao diện mới tối giản; giữ chủ đề sáng/tối) | — | — | ☐ |
| G18 | Cỡ chữ bài đọc | `F1.frm`, `data.Kcu` slot 34 | `user_setting` | Giữ (cài đặt cỡ chữ toàn app) | M1 | — | ☑ |
| G19 | Nhiều hồ sơ `user2..5` chọn bằng thư mục làm việc | B §6.3 | thư mục `user*` | Bỏ (một hồ sơ; có xuất/nhập JSON để chuyển máy, chọn nơi lưu / file khôi phục bằng hộp thoại file của hệ điều hành – `file_picker`) | M6 | xuất rồi nhập lại giữ nguyên từ đã lưu | ☑ |
| G20 | Kiểm tra phiên bản 30 ngày, tự thoát; khoá menu 10 s khi khởi động; chống chạy 2 bản; chống sửa ReadMe | C §8.2–8.3 `MoWeb.bas`, `Delete_WEB.bas`, B §1.3 | — | Bỏ | — | — | ☐ |
| G21 | Hướng dẫn trong app: nút Hướng Dẫn Cách Học (ReadMe) và 28 chủ đề help gắn với màn hình đang mở | C §8.1 `Help_.bas:TimSoHelp` | `help_topic` (không còn hiển thị) | Tương đương: nút "?" ở mỗi màn hình mở đúng chủ đề; nội dung hướng dẫn viết lại cho Grammar 4.0 (chuột/phím và chạm), đóng gói trong app (`lib/ui/help/help_content.dart`), không đọc `help_topic` của dữ liệu | M1 | ở màn hình Bài tập bấm ? → `/help/bai-tap` | ☑ |
| G22 | Lưu vị trí mục đã mở của từng màn hình, bài đọc đang đọc dở, cài đặt | B §6.1 `data.Kcu` 34 slot, `SaveSelStartReading` | `user_progress`, `user_setting` | Giữ (mở lại đúng chỗ) | M1 | đóng mở app vẫn ở bài đang đọc | ☑ |
| G23 | Tra từ từ clipboard khi chuột vào danh sách headword | B §7, B §9.13 | — | Tương đương: "Chia sẻ văn bản vào app" (mobile) và dán vào ô tìm (desktop) | M6 | — | ☐ |

## 1. Bài Đọc (`Butcu = 1`) – help [0], [3], [4], [19]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| R1 | Cây mục lục 139 nhóm / 4.565 bài, nhóm lồng nhau; click nhóm mở bản ghi `pos` | C §6 `TaoThuMucTreeview_.bas`, `ReLoadVtMucReading` | `reading_section`, `reading` | Giữ (danh sách phân cấp có tìm kiếm tiêu đề) | M2 | đếm 4.565 bài; nhóm "Lớp 6-12" có cây con | ☑ |
| R2 | Trang bài: ảnh minh hoạ, tiêu đề, thân bài (đoạn, câu) | C §2 `GoiR2`, `Write_X1_X2` | `reading.img`, `en`, `vi` | Giữ (ảnh WebP ≤ 800 px). Nhóm "Phiên Âm Quốc Tế" (sid 0, một bài) là bài học, không phải bài đọc → mục menu riêng ở trang chủ (`/ipa`, `IpaLessonPage`), ẩn khỏi cây Bài Đọc: văn bản hướng dẫn tiếng Việt hiện thường (không số câu, không đọc câu); 50 ký hiệu là ô bấm → hiện "đọc là …"; 28 từ ví dụ là hàng bấm → hiện phiên âm Việt (pill) + nút đọc từ, công tắc "Hiện tất cả". ETL giải mã nhóm này với `ipa_letters=True` (ʃ, ʒ, ɔ đúng font gốc) | M2 | "1. Red Rubber Ball." có ảnh; bài "Cách Ðọc Phiên Âm Quốc Tế": chạm ʃ → "sờ (uốn cong lưỡi)", chạm "fruticulum" → "frù thí kìu lờm" | ☑ |
| R3 | Ảnh theo nhóm: Lớp 6-12 dùng `[mã]` → `Pic8`; nhóm "Các bệnh cần biết" ảnh ngẫu nhiên `Cacbenhcanbiet1..10`; hai nhóm đối thoại/Văn Hoá Mỹ dùng chung một ảnh | C §2.4 `HinhSo612`, `TinhTenHinh` | `reading.img` đã gán sẵn trong ETL | Giữ (ETL gán theo `BaiCungHinh`: hai nhóm → `VAN HOA MY..jpg`; "Các bệnh cần biết" → `Cacbenhcanbiet{(vị trí trong nhóm mod 10)+1}` thay cho ngẫu nhiên, để ảnh ổn định giữa các lần mở) | M2 | "Bai 4.(15)" hiện ảnh 1.6.15a; 100 bài đối thoại, 61 bài Văn Hóa Mỹ, 855 bài bệnh đều có ảnh | ☑ |
| R4 | Click phải vào câu → nghe câu (TTS) và hiện bản dịch câu đó | A §2.2, C §2 | `reading_sentence` (en, vi theo chỉ số) | Tương đương: mỗi câu có số thứ tự nhỏ phía trước, ô bấm 24 px (`_SentenceNumber`); chạm số → mở bản dịch dưới đoạn và đọc câu (TTS/giọng thật); chạm lại → đóng bản dịch và dừng đọc nếu đang đọc câu đó; nút loa trong bảng = đọc lại/dừng; nút "Bản dịch" hiện tất cả (cờ `continuous` theo từng lần `play`, không dùng chung) | M2 | câu 2 → "Nó đá quả bóng." | ☑ |
| R5 | **Nghe toàn bài**: TTS đọc từng câu, tô sáng câu đang đọc; mũi tên trái = nghe lại nhiều lần, lên = câu trước, phải/xuống = câu kế, Esc thoát | A §2.7 `R2_KeyDown`, B `M1.bas:NhanF9R2Thuc`, E §1.5 | `reading_sentence` | Giữ (SentencePlayer: nút ⏮ ⏯ ⏭ lặp; desktop giữ phím) | M2 | đọc 3 câu, dừng, lùi | ☑ |
| R6 | Nhóm "Các Bài Âm Thanh Thực": phát MP3/WAV thật theo mốc câu; 90 bài đọc cả tựa trước câu 1 | E §2 `AmthanhThuc.bas`, `TinhPhatAmThucDeBai`, `WindowsMedia_R2.bas` | `reading.audio`, `times`, `title_audio` | Giữ (seek theo `times[k]`; nếu `title_audio` phát từ 0 trước câu 0; file nền tảng không phát được thì đọc bằng TTS) | M2 | bài 26 tô sáng tựa rồi câu 1 đúng lúc | ☑ |
| R7 | Bài **Phiên Âm Quốc Tế**: bảng ký hiệu IPA, click ký hiệu → đọc mẫu; phần sau luyện đọc từng từ (xử lý theo vị trí ký tự cứng) | A §7.7 | `reading` id 0 | Tương đương: bài này dựng riêng thành bảng IPA có nút đọc từng ký hiệu/từ mẫu | M2 | chạm /æ/ → đọc "cat" | ☑ |
| R8 | Thẻ Gói: chọn gói bài nhập | A §2.3 | — | Giữ (xem N1–N6) | M5 | — | ☑ |
| R9 | Thẻ Đổi hình nền, Cỡ chữ | A §2.2 | — | Bỏ ảnh nền (G17); cỡ chữ giữ (G18) | M1 | — | ☑ |

### 1a. Xếp từ (`Rxep`) – help [16]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| X1 | Xáo từ của một câu Anh (bỏ dấu câu, bỏ câu < 4 từ), hiện câu Việt làm gợi ý | D §6 `XepTu.bas:LoadCauAnhViet` | `reading_sentence` / `dialog` | Giữ | M2 | câu 4 từ trở lên mới xuất hiện | ☑ |
| X2 | Click phải vào từ → từ đi vào đúng vị trí (chỉ khi đúng từ kế tiếp); Enter → xem đáp án hoặc câu mới; không tính điểm | D §6 | — | Tương đương: chạm từ (thay click phải), sai thì rung; nút "Đáp án" / "Câu kế" | M2 | sai không di chuyển | ☑ |
| X3 | Dùng chung cho Bài Đọc, Luyện Nói, Phân Tích Câu | A §2.4 | — | Giữ (một widget) | M2 | mở từ 3 nơi | ☑ |

### 1b. Đàm thoại (`DangDamThoai`, Timer5) – help [2], [23]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| T1 | "Nhìn câu Việt, nói câu Anh": hiện câu Việt (Bài Đọc) hoặc nghe câu A (Luyện Nói), người học nói; máy ghi dần từ gợi ý | E §4.1–4.3 `XepTu.bas:VietTuTimer5`, `XetSpeak`, `DamThoai_7.bas:DocCauA` | câu song ngữ / cặp A-B | Giữ | M2 (đọc), M4 (nói) | — | ☑ |
| T2 | Mức độ khó 1–10 (mặc định 4): nhịp T = 5/3/2/1/0,7/0,6/0,5/0,4/0,2/0,1 s; mức 1–5 có từ đầu, chờ 3T (1–3) hoặc 7T (4–5) rồi mỗi từ cách T có đọc; mức 6 chỉ câu đề, 6T; mức 7–10 chỉ dấu `.` mỗi T rồi đọc nguyên câu | E §4.2 `SetMucdoF6`, §4.4 bảng | — | Giữ nguyên bảng (hằng trong code) | M2 | mức 1: từ thứ 2 xuất hiện sau 15 s; mức 7: 3 s rồi dấu chấm | ☑ |
| T3 | Chọn câu tuần tự; sau 5 vòng nhảy ngẫu nhiên 1–20; bỏ câu < 2 từ, câu đã "Bỏ câu này" (chỉ trong phiên), Luyện Nói bỏ dòng tựa | E §4.1 `TangCauSpeak`, `RandomSpeak`, §4.5 | — | Giữ | M2 | — | ☑ |
| T4 | Next/Back; "Answer:" ở mọi mức trong Luyện Nói; mức ≥ 7 dòng câu A thay bằng "Listen: ..." | E §4.4–4.5 | — | Giữ | M4 | — | ☑ |
| T5 | Tốc độ TTS không đổi theo mức | E §7.9 | — | Giữ | M2 | — | ☑ |
| T6 | Ảnh minh hoạ ngẫu nhiên mỗi câu từ `k1..k16` (chỉ Luyện Nói) | E §7.10 `GanHinhDamThoai` | `dialog_topic` pool `img/dialogs` | Giữ | M4 | — | ☑ |

### 1c. Nghe viết (`Rviet`) – help [14]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| W1 | TTS (hoặc audio thật) đọc câu Anh, hiện câu Việt; gõ lại câu Anh (bỏ tựa, bỏ dấu câu); gõ sai → nền đỏ và đọc lại | D §7 `NGHE_VIET.bas`, A §2.6 | `reading_sentence` | Giữ (so từng ký tự, ô nhập đổi màu) | M2 | gõ sai 1 ký tự → đỏ | ☑ |
| W2 | Trái = nghe lại; mũi tên phải = gợi ý ký tự kế; click phải = hiện trọn từ; lên/xuống đổi câu; Backspace bị chặn | A §7.10 `ShowChuNhac` | — | Tương đương: nút Nghe lại / Gợi ý 1 ký tự / Hiện từ; Backspace cho phép (ghi nhận là nới lỏng) | M2 | — | ☑ |
| W3 | Không tra từ trong chế độ này | docs/06 [14] | — | Giữ | M2 | — | ☑ |

## 2. Từ Vựng Của Bạn (`Butcu = 2`) – help [10], [20]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| V1 | Xem Từ Chọn: danh sách từ đã lưu (số thứ tự, từ, câu ngữ cảnh, nghĩa); từ mới ở cuối | D §10.1–10.2 `TuVungChon.bas` (`dataChon.txt`, `DataTuDienUser.txt`) | `user_word` | Giữ (danh sách + tìm) | M1 | — | ☑ |
| V2 | Trái → nghĩa; quét từ số thứ tự (kéo > 7 px) → xoá các từ quét; quét không từ số → bật/tắt đánh dấu đỏ; Delete → xoá cả danh sách; phải → sửa mục | D §10.2, A §7.6 | `user_word.marked` | Tương đương: vuốt để xoá, chạm sao để đánh dấu, chọn nhiều, nút sửa | M1 | — | ☑ |
| V3 | Từ đánh dấu đỏ tô đỏ trong bài đọc; tra một từ tự bật đỏ nó | D §10.3 | — | Giữ | M2 | — | ☑ |
| V4 | Shift+mũi tên chọn nhiều rồi Enter → tạo WAV | A, E §1.7 | — | Tương đương (G16) | M6 | — | ☐ |
| V5 | **Quay Từ**: chỉ từ đánh dấu đỏ; từ chạy ngang màn hình (tốc độ ≥ 4 thì đứng giữa); Màu chữ; Tốc độ 1–10 (8–10 không đọc); trái vào nền → tra từ; phải vào nền → xoá từ đã thuộc (không lưu); Viết từ; Đổi kiểu | D §11 `QuayTuChon.bas`, A §2.9, §7.12 | `user_word.marked`, `user_setting` | Tương đương: chế độ flashcard tự chạy (hiện từ → đọc → nghĩa), tốc độ 10 nấc, nút "Đã thuộc" bỏ đánh dấu | M5 | — | ☑ |
| V6 | TTS đọc từ < 15 ký tự hai lần (và từ gốc hai lần) | E §7.20 `M1.bas:2774` | — | Tương đương: đọc một lần, có nút lặp (ghi nhận khác) | M5 | — | ☑ |

## 3. Văn Phạm (`Butcu = 3`) – help [7], [17]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| P1 | Hai cột chương (15) / bài (356); mục xanh đậm đầu chương = giới thiệu chương | D §5.1 `VanPham.bas`, `HocNguPhap.bas` | `grammar_lesson` (chapter, ref) | Giữ (danh sách hai cấp) | M3 | 15 chương, 356 bài | ☑ |
| P2 | Thân bài: in đậm, tô sáng, tiêu đề phụ, công thức, bảng chia động từ; `` `n`` = liên kết bài n | D §5.2 `WriteRVP2`, `LayChiThiVanpham` | `grammar_lesson.body` (Markdown nhẹ) | Giữ (render Markdown + liên kết nội bộ `?n`) | M3 | bài 3 "To Be" có bảng | ☑ |
| P3 | Bài có dấu chấm đỏ = có bài tập; thẻ "Làm bài tập" | D §5.3 | `grammar_lesson.drills`, `exercise.lesson_ref` | Giữ. ETL gán bài tập cho bài theo vị trí trong `data.Muc` (bài i = `Muc[9+i−1]` bản ghi liên tiếp sau 9 menu, mục 0 vẫn chiếm 1 bản ghi rỗng) như `NhanENTERBaiTapVanPham`, thay cho cách cũ lấy `?n` đầu tiên trong lời giảng (sai bài, 520 bản ghi không có bài). Bài có `Muc = 0` vẫn sở hữu 1 bản ghi: 33 bài trong số đó là bài xếp từ loại 3 (bài 37 "Câu Ðơn"). Cờ "có BT" = bài thật sự có bản ghi (132 bài; `@.` đánh dấu 131). Loại 3 = **Xếp từ** (`ScrambleBoard` trong runner), không phải danh sách câu để đọc | M3 | bài 48 "Passive Voice" 54 câu; bài 3 "To Be" 46 câu điền; bài 37 = 1 bài xếp từ; không bản ghi nào thiếu bài | ☑ |
| P4 | Click phải đánh dấu nhiều bài rồi Enter → bài tập trộn của các bài đã đánh dấu | D §1.8 `NhanENTERBaiTapVanPham` | `exercise` theo `lesson_ref` | Tương đương: chọn nhiều (checkbox) → "Làm trộn" | M3 | chọn 3 bài → tổng số bài = tổng ba bài | ☑ |
| P5 | Trong bài tập/lời giảng, liên kết `?n` mở bài văn phạm n trong khung phụ, click phải đóng | D §1.7 `GoiRVP2TuBaiTap` | `exercise.refs` | Giữ (sheet/bottom panel) | M3 | — | ☑ |

## 4. Bài tập (9 menu cột phải, `Butcu = 10..18`) – help [8], [12], [15], [26]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| E1 | Mỗi menu chia "Bài Tập n" 25 bài (nhóm cuối phần dư); nhớ nhóm đang làm | D §1.5 `CHON_BT`, B §6.1 slot 11–19 | `exercise_menu`, `exercise` (thứ tự) | Giữ (nhóm 25; lưu tiến độ `user_progress`) | M3 | ARTICLES 203 → 9 nhóm (8×25 + 3) | ☑ |
| E2 | Thứ tự bài trong nhóm xáo khi nhóm > 6 bài; hết nhóm → báo % đúng rồi quay vòng | D §1.5 `DAOBAITAP`, `ChamDiemBT` | — | Tương đương: xáo như cũ; hết nhóm hiện màn kết quả với nút "Làm lại / Nhóm kế" | M3 | — | ☑ |
| E3 | Tiêu đề đề bài theo mã nhóm (`@<k><tt>`): hai bộ (menu / bài văn phạm) | D §1.3 `PhanLoaiCau`, `GanCauViettren` | `exercise.kind`, `tt`, `exercise_title` | Giữ | M3 | TENSE tt 5 → "THE SIMPLE PRESENT \ THE PRESENT CONTINUOUS?" | ☑ |
| E4 | **Điền từ**: ô trống trong đề, thanh từ cho trước; Enter chấm: so chữ thường, bỏ khoảng trắng, 2 phương án đầu của `\`, đáp án rỗng chấp nhận ô trống; sai → đỏ | D §1.4, §1.6 `LamEnterDienTu`, `BaoVerb` | `exercise.text` `{n}`, `blanks[a, alt, n]`, `given` | Giữ (ExerciseRunner.fill); chấp nhận mọi phương án `alt` (nới lỏng có chủ ý) | M3 | "*a___" đúng với "a"; "an" sai | ☑ |
| E5 | Sau khi chấm: phải vào ô trống → lời giảng + liên kết; trái → đáp án; phải vào đề → bản dịch | D §1.7 `LamNhanChuotPhaiDienTu`, `VietRHDBT` | `exercise.expl`, `vi`, `refs` | Tương đương: sau chấm, chạm ô → popover "Đáp án / Vì sao"; nút "Dịch" | M3 | — | ☑ |
| E6 | CONDITIONAL, TENSE: không có lời giảng riêng, chèn liên kết bài 2–69 | D §1.2 `ThemSviet2_3` | `exercise.refs` | Giữ (hiện danh sách bài liên quan) | M3 | — | ☑ |
| E7 | **Trắc nghiệm a–d**: chọn phương án; sai → mờ, đúng → đậm; chọn sai rồi đúng không được điểm; phương án không xáo; phải vào phương án → lời giảng ("Câu A sai vì…"); phải vào đề → dịch | D §2 `ChonABCD_.bas:HienCauABCD`, `LamNhanChuotPhaiABCD` | `exercise.choices`, `answer`, `expl` | Giữ (ExerciseRunner.choice; "vì sao" của từng phương án qua nút ⓘ) | M3 | PRELIMINARY A bài 1 | ☑ |
| E8 | B+C VOCABULARY: rê vào phương án hiện nghĩa; click từ → Related forms + mục từ điển | docs/02 mục 17, D §2 | `expl`, `wordform_*`, `dict_entry` | Giữ (chạm giữ phương án) | M3 | — | ☑ |
| E9 | **Chọn câu sai** (TOEFL): 4 phần gạch chân, chọn phần sai; phải vào phần → lời giảng | D §3 `BT_Chonsai.bas` | `exercise.kind = error`, `blanks` 4 phần, `answer` | Giữ (ExerciseRunner.error) | M3 | TOEFL 355 bài error | ☑ |
| E10 | Dạng "danh sách câu" (34 bài `kind = sentences`) chỉ hiển thị | D §1.3 loại 3 | `exercise.kind = sentences` | Giữ (hiện câu, có chạm từ) | M3 | — | ◐ |
| E11 | **Word Forms**: bảng từ gốc (3.901); trái chọn 1–2 từ (mức 4 đỏ sáng); học xong trái lần nữa → mức 3 (đỏ sẫm, dự trữ); đổi hết đỏ sáng thành đỏ rồi Enter → ôn dự trữ; không chọn gì → tự chọn từ thông dụng (mức 3 mặc định); Delete xoá hết; mức ghi vào `Datawf.vt` | D §4.1–4.2 `WorForm.bas`, A §7.1 | `wordform_root` (start, count, common), `user_wordform_mark` | Giữ (hai mức đánh dấu lưu riêng; không ghi vào dữ liệu). Màu: mức 4 "học" = xanh, mức 3 "dự trữ" = đỏ (thay đỏ sáng/đỏ sẫm khó phân biệt) | M3 | chọn "abuse" → 11 bài; ô điền rộng theo đáp án dài nhất | ☑ |
| E12 | Trong bài Word Forms: thanh trên hiện từ gốc, trái vào → tra và xem các dạng; Enter chấm; phải vào đề → dịch; bộ đếm "đúng x/N" cộng dồn một lượt | D §4.3 | `exercise` (wordforms), `expl` | Giữ | M3 | — | ☑ |
| E13 | Tắt bộ gõ tiếng Việt khi làm bài | D §12 | — | Bỏ (G12) | — | — | ☐ |

## 5. Luyện Nghe (`Butcu = 4`) – help [9], [13], [21]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| L1 | Bài tập: Unit 1–20; nghe câu Anh (TTS), chọn 1 trong 4 câu Việt (xáo); chỉ tính điểm khi đúng ngay lần đầu; phải → nghe lại; sau khi trả lời mới tra từ; hết câu tự thoát kèm tỉ lệ | D §9 `Listening.bas`, A §2.11, §7.11 | `listening_item` (options[0] = đúng) | Giữ (xáo khi hiển thị); thêm: danh sách unit và trang unit hiện tên bài đọc có bản thu tương ứng (L2), bấm để mở bài | M4 | unit 1 có 55 câu? đếm theo dữ liệu | ☑ |
| L2 | Âm thanh thật của unit (`LoadFileWav(unit)`): `TinhTenBaiSoundThuc` với `Butcu = 4` lấy `sound/<unit>.*`, tức chính bản thu của bài "Các Bài Âm Thanh Thực" thứ unit; câu n = đoạn n của bản thu (`SoundThuc1Cau`) | D §9, §13.7, `READING.bas:1849` | `reading.audio = audio/<unit>.*`, `reading.times` | Giữ: `SentencePlayer` của bài đó, `speakOnce(n−1)`; TTS chỉ khi thiếu file | M4 | Unit 1 câu 1 = "Steve and Yaser first met…" phát từ `1.mp3`; nhãn "Giọng thật" | ☑ |
| L3 | Video: người dùng chỉ thư mục chứa AVI (cây thư mục; tên có dấu bị từ chối) | E §3.1 `PhimVB6.bas`, `DataPath.txt` | `subtitle_film.video` | Tương đương: chọn thư mục/file bằng file picker; nhớ đường dẫn | M4 | chọn `D:\english\grammar 3.1\videos` → 210 tập nhận | ☑ |
| L4 | Danh sách tập theo mã (A 1…F 5); tên phim F từ exe; A/B/C không tên | E §3.1, `DataF2` | `subtitle_film` (code, title, first_line) | Giữ, thêm `first_line` làm tên gợi ý | M4 | — | ☑ |
| L5 | Phát video đồng bộ phụ đề: dòng i hiện trong [e(i−1), e(i)] | E §3.3 `LoadFileCauPhim_Mang` | `subtitle_line.s`, `e` | Giữ (`media_kit`; AVI trên desktop/Android; iOS/web cần MP4 – xem docs/07 §8). Khác: dòng 1 có s = 0 trong dữ liệu gốc (gồm cả đoạn mở đầu); Grammar 4.0 thêm mốc bắt đầu nói của câu 1 (tìm bằng nhận dạng giọng nói, xem content/CHANGELOG.md). Trước mốc đó chưa hiện câu nào; câu kế từ đoạn mở đầu, câu trước/nghe lại câu 1 nhảy tới mốc đó thay vì giây 0 | M4 | A 1 dòng 1 hiện từ 34,75 s tới 37,09 s | ☑ |
| L6 | Rê ngang khung → phát liên tục; rê vào khung → tạm dừng; trái/phải ngoài khung → nghe lại **câu trước**, rồi lùi/tới một câu; trái trong khung → stretch; đúp → đổi cỡ | E §3.4 `VTReplay`, A §7.8 | — | Tương đương: nút ⏮ ⏯ ⏭ và "Nghe lại câu" (nghe lại câu hiện tại, ghi nhận khác với i−1); thêm "Phát lại từ đầu" (phím Home) về 0:00, phòng khi mốc câu 1 sai; thanh tua kèm thời gian như thanh của Windows Media Player nhúng trong app gốc (tua thì phụ đề và đoạn lặp theo câu tại chỗ mới) | M4 | — | ☑ |
| L7 | Rê vào **A** → phụ đề Anh; rê vào **V** → thêm dòng Việt; từ đổi màu khi rê (trắng) và sau khi lưu (đỏ); không có karaoke theo thời gian | E §3.5 `BatMauLaBel`, `BatDoLaBel` | `subtitle_line` | Tương đương: nút bật/tắt Anh và Việt; phụ đề là WordTapText (chạm từ tra, lưu từ tô đỏ) | M4 | — | ☑ |
| L8 | **Số câu lặp** (phải tăng, trái giảm): lặp một đoạn n câu, tắt tiếng và seek lùi 0,5 s | E §3.4 Timer2, A §7.8 | — | Giữ (chọn n, lặp từ câu hiện tại) | M4 | lặp 2 câu | ☑ |
| L9 | Trái vào từ phụ đề → nghĩa nhanh; rê → đầy đủ; Enter/phải → lưu | E §3.5 | — | Giữ (G3, G9) | M4 | — | ☑ |
| L10 | Nhận diện file qua `DataF3` (800 byte đầu AVI); chấp nhận `F  1 Beauty….avi` | E §3.2, §7.19 | `subtitle_film.video` | Tương đương: khớp theo tên `<chữ> <số>` ở đầu tên file, không đọc header | M4 | — | ☑ |

## 6. Phân Tích Câu (`Butcu = 5`) – help [1], [5]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| A1 | 12 bài đọc Unit 1–11 ("Những Mẩu Chuyện Tiếng Anh Tập") với mọi tính năng Bài Đọc | D §8 `PTCau.bas`, A §2.13 | `analysis_lesson` + `reading` tương ứng | Giữ: `/analysis/<id>` mở chính `ReadingPage` của bài 361–372 ở chế độ phân tích (ảnh, số câu, bản dịch, Nghe toàn bài, Xếp từ, Đàm thoại, Nghe viết); danh sách unit có thumbnail; `Sentence.tokens` giữ nhóm từ `|` | M5 | Unit 5: ảnh + 4 nút công cụ; danh sách 12 unit có ảnh | ☑ |
| A2 | Click phải vào từng từ → bảng: Từ, Từ loại, Vị trí, Chức năng, Ý cần viết, Ghi chú (+ "Phải có từ … vì:"), dòng xanh nghiêng = liên kết bài văn phạm; phải để đóng | D §8, §13.8 | `analysis_lesson.words[n, word, pos, position, function, meaning, note, refs]` | Tương đương: chạm từ → thẻ phân tích kèm nghĩa nhanh (IPA, phiên âm Việt, nghĩa, Lưu từ, Tra từ điển) như app gốc hiện cả hai; liên kết văn phạm hiện **tên bài** ("Câu Ðơn (Simple Sentence)") kèm số, chạm mở sheet, nút mở trang | M5 | Unit 5 "doctor": danh từ, đứng sau tính từ (his), 5 bài liên kết có tên | ☑ |

## 7. Từ Vựng (TRANH) (`Butcu = 6`) – help [22]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| H1 | 155 chủ đề; mỗi chủ đề một trang `Pic5/<t+1>.jpg` phóng theo màn hình (×2, ×1,5, ×1, ×0,8, ×0,5), vòng tròn tiêu điểm tại `xy` | E §5.1 `Hinh.bas:LoadFilePic`, `ShowAllDiemChon` | `picture_topic.page`, `words[].xy` (pixel trên ảnh gốc, cao 700; là góc trên-trái của vòng tròn `Shape D` 255 twip = 17 px, tâm chấm trắng ở `xy + 8,5`) | Giữ (InteractiveViewer, hotspot scale theo ảnh, nút số đặt tâm tại `xy + 8,5`; khung chung với Bài Đọc/Luyện Nói: breadcrumb Từ Vựng (Tranh) › tranh, menu trái 155 tranh (🔖 = có tiêu điểm đã chọn), Tranh trước / Tranh kế) | M5 | "Thời gian" (id 12) 8 hình đồng hồ; nút số trùng chấm trắng trên tranh | ☑ |
| H2 | Rê/chạm tiêu điểm → dòng dưới "english = nghĩa"; chuột đứng yên → tự đọc từ (Timer8) | E §5.2, A §7.9 | `words[].en`, `vi` | Giữ (chạm = hiện + đọc) | M5 | — | ☑ |
| H3 | Chế độ chuyển 0→1→2→1→2; *0*: chọn tiêu điểm (trái chọn/bỏ, phải nghe, Enter lưu cụm); *1*: tiêu điểm sáng → gõ từ Anh, trái/Enter → so chữ và nghe; *2*: nghe từ → chạm đúng tiêu điểm, Enter xem đáp án; không chấm điểm | E §5.3 `ChonCachHocHinh` | — | Giữ (ba chế độ chọn trực tiếp, thêm đếm đúng/sai) | M5 | — | ☑ |
| H4 | Mũi tên trái/phải lùi/tới trang; trái/lên, phải/xuống trong khung nghĩa = lùi/tới tiêu điểm | A §7.9 | — | Tương đương: vuốt trang, nút tiêu điểm trước/sau | M5 | — | ☑ |
| H5 | Không chọn tiêu điểm nào → luyện toàn bộ; tiêu điểm đã chọn lưu khi rời chủ đề (`dataHH.xy` byte `Chon`); chủ đề có tiêu điểm đã chọn hiện sách đỏ | E §5.4 | `user_picture_pick` | Giữ (lưu riêng) | M5 | — | ☑ |
| H6 | Lưới 8 ảnh nhỏ riêng (`Pic3`) | — | — | Bỏ: không tồn tại trong mã (Pic3 là hoạt hình trang trí); trang lưới là chính `Pic5` | — | — | ☐ |

## 8. Luyện Nói (`Butcu = 7`) – help [6], [24]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| S1 | 19 chủ đề, 2.641 bài; mỗi bài 4 cặp A/B kèm dịch; trái vào từ → nghĩa; phải vào dòng → dịch + đọc | A §2.15, C §2 (dùng `R2`) | `dialog_topic`, `dialog` (pairs a, b, avi, bvi; `datasp.av` lưu "<B>~<A>", ETL đã đổi đúng chiều 2026-10-06) | Giữ: chạm từ → nghĩa; chạm vào dòng (ngoài chữ) → đọc câu + hiện dịch (giữ lại). Trang bài cùng khung với Bài Đọc: breadcrumb Luyện Nói › chủ đề › bài, thanh công cụ Nghe toàn bài / Xếp từ / Đàm thoại / Nghe viết / Đổi ảnh (nút "Đổi ảnh nền" của app cũ) / Ôn tập, menu trái là các bài của chủ đề, Bài trước / Bài kế; Nghe toàn bài, Xếp từ, Nghe viết nhận bài đối thoại như một bài đọc (A1, B1, A2, B2 …; id `2000000 + dialog.id`) | M4 | Bài 1: A "What do you buy?" / B "A bar of Chocolate." | ☑ |
| S2 | Ảnh ngẫu nhiên `CANBAN1..24` trên trang | C §2.4 | pool `img/dialogs`? (CANBAN chưa đưa vào dataset) | Giữ: `CANBAN1..24` vào `img/dialogs` (`meta.dialog_page_images`); ảnh cố định theo số chủ đề/bài (`n mod 24`) thay vì ngẫu nhiên; thumbnail ở danh sách chủ đề và danh sách bài, ảnh đầu trang bài; pool k1..k16 vẫn cho Đàm thoại (T6) | M4 | chủ đề "Cụm từ" và Bài 1 có ảnh | ☑ |
| S3 | **Chọn Câu** (phải vào chủ đề hoặc nút): phải chọn, trái bỏ, kéo chọn nhiều, đúp = luyện ngay; câu đã chọn xếp lên đầu chủ đề, lưu thứ tự (`DataSpChon` 17 byte) | E §4.7 `TinhTongCauChon`, A §2.15 | `user_dialog_pick` (dialog_id, pair_idx, order) | Tương đương: nút 🔖 cạnh mỗi cặp A/B (chọn/bỏ); dòng hướng dẫn dưới thanh công cụ nói số cặp đã chọn trong chủ đề và Ôn tập sẽ làm gì; không sắp lại chủ đề | M4 | chọn 1 cặp → "Đã chọn 1 cặp…" | ☑ |
| S4 | **ôn tập**: luyện các câu đã chọn trong chủ đề; dưới 4 câu → luyện toàn bộ | E §7.11 | — | Giữ: nút "Ôn tập n cặp đã chọn" / "Ôn tập cả chủ đề" trên trang bài và trang chủ đề → Đàm thoại (máy đọc A, người học đáp B) | M4 | — | ☑ |
| S5 | Đàm thoại trong Luyện Nói: máy đọc câu A (giọng Anh), người học nói B; Answer + gợi ý theo mức (T2); Back/Next | E §1.6, §4.6 | — | Giữ (không có giọng Việt) | M4 | — | ☑ |
| S6 | Nút "Giọng Việt"/tốc độ Việt riêng (mô tả trong help) | E §7.12 | — | Bỏ: không tồn tại trong mã | — | — | ☐ |

## 9. Bài Nhập Của Bạn – help [25]

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| N1 | Gói = thư mục trong `BaiNhap` (0 mẫu, 1 cá nhân); F4 thư mục cùng cấp, F3 thư mục con, Delete, giữ 2 s đổi tên | A §2.3, `TrinhNhapViet_.bas`, `TreeviewDir.bas` | `BaiNhap/<n>/TV.txt`, `TV.tpf` | Tương đương: "Bài của bạn" lưu trong SQLite (`user_reading`), nhóm = thư mục ảo | M5 | tạo nhóm, bài | ◐ |
| N2 | Tạo bài: tựa, thân Anh phân câu bằng `_`, thân Việt tương ứng; ảnh đầu bài `[tên]` sau tựa (≤ 758 px) | A §2.3, docs/06 [25] | `user_reading` (en[], vi[], image) | Tương đương: trình soạn hai cột, tự tách câu, chọn ảnh từ máy | M5 | — | ◐ |
| N3 | Sửa bài, Chèn/Xoá câu Việt; Shift+lên/xuống đánh dấu nhiều, Delete xoá bài đỏ | A §7.13 | — | Tương đương | M5 | — | ◐ |
| N4 | Bài tên "Ngu Phap": phần Việt lưu `1,5,12` → mở hiện danh sách bài văn phạm | D §5.4, §13.12 | `user_reading` kiểu "grammar list" | Tương đương: "Bộ sưu tập bài văn phạm" do người dùng chọn | M5 | — | ◐ |
| N5 | Bài nhập kế thừa mọi tính năng Bài Đọc (chạm từ, dịch, nghe, xếp từ, đàm thoại, nghe viết) | A §2.3 | — | Giữ (cùng widget) | M5 | — | ◐ |
| N6 | Gửi bài lên web chia sẻ; công cụ nội bộ F1–F7 của tác giả | A §7.14 | — | Bỏ | — | — | ☐ |
| N7 | Nhập hai gói mẫu có sẵn trong `legacy/Grammar/BaiNhap` | — | hai gói không chứa bài | Bỏ (không có nội dung) | — | — | ☐ |

## 10. Dữ liệu người dùng và sao lưu

| Mã | Hành vi | Mã nguồn | Dữ liệu | Quyết định | Mốc | Kiểm thử | TT |
|---|---|---|---|---|---|---|---|
| U1 | Lưu từ (từ, câu ngữ cảnh, nghĩa riêng, đánh dấu đỏ) | `dataChon.txt`, `DataTuDienUser.txt` | `user_word` | Giữ | M1 | — | ☑ |
| U2 | Vị trí mục đã mở của 18 màn hình, nhóm "Bài Tập n" đang làm, bài đọc đang dở | `data.Kcu` | `user_progress` | Giữ | M1–M5 | — | ◐ |
| U3 | Cài đặt: giọng, tốc độ, âm thanh, cỡ chữ, kiểu Quay Từ, màu | `data.Kcu` | `user_setting` | Giữ | M1 | — | ☑ |
| U4 | Câu Luyện Nói đã chọn, tiêu điểm tranh đã chọn, mức Word Forms | `DataSpChon`, `dataHH.xy`, `Datawf.vt` | `user_dialog_pick`, `user_picture_pick`, `user_wordform_mark` | Giữ | M3–M5 | — | ☑ |
| U5 | Điểm bài tập (chỉ báo % cuối nhóm, không lưu) | `ChamDiemBT` | `user_progress` (mới: lưu lần làm gần nhất) | Tương đương: lưu kết quả để xem lại | M3 | — | ◐ |
| U6 | Chuyển máy: chép thư mục `user*` | — | xuất/nhập JSON | Tương đương | M6 | — | ☑ |

## 11. Tóm tắt quyết định

| Quyết định | Số dòng | Ghi chú |
|---|---|---|
| Giữ | 60 | hành vi học tập cốt lõi, chấm điểm, mốc thời gian, bảng mức độ khó |
| Tương đương | 33 | thao tác chuột phải/rê/phím → chạm, nút, cử chỉ; lưu trữ người dùng chuyển sang SQLite |
| Bỏ | 12 | trang trí, bộ gõ, kiểm tra phiên bản, hồ sơ theo thư mục, tính năng không có trong mã (karaoke, lưới Pic3, giọng Việt), file âm thanh không có trên đĩa |

Những chỗ bản port **cố ý khác** app gốc (phải nêu trong ghi chú phát hành): L1 Luyện Nghe hiện tên bài đọc của unit; W2 cho phép Backspace; E4 chấp nhận mọi phương án thay thế; L5 câu 1 bắt đầu ở mốc nói (dữ liệu mới) thay vì giây 0; L6 "nghe lại" là câu hiện tại; V6 đọc từ một lần; S3 danh sách câu đã chọn tách riêng thay vì sắp lại chủ đề; H3 có đếm đúng/sai. G21 hướng dẫn trong app viết lại (18 chủ đề theo app mới) thay cho 28 chủ đề help và ReadMe của app gốc; lời khuyên phương pháp học của tác giả giữ trong chủ đề "Cách học hiệu quả".
