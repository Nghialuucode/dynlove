# 🚀 DynLove MVP — Cặp Đôi (Couple App)

Ứng dụng kết nối cặp đôi với Backend Node.js chạy trên Windows VPS (PostgreSQL, Socket.io) và Mobile App viết bằng Flutter.

---

## 📁 Cấu trúc dự án

```text
DynLove/
├── backend/                 # Node.js + Express + Socket.io + PostgreSQL
│   ├── package.json
│   ├── .env.example
│   ├── schema.sql
│   └── src/
│       ├── index.js
│       ├── db.js
│       ├── auth.js
│       ├── routes.js
│       └── socket.js
├── mobile/                  # Flutter app
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── api.dart
│       ├── socket_service.dart
│       └── screens/
│           ├── login.dart
│           ├── home.dart
│           └── chat.dart
├── deploy/
│   ├── setup-windows.ps1
│   └── Caddyfile
└── README.md
```

---

## ⚡ 1. Hướng Dẫn Deploy Backend (Windows VPS)

### Yêu cầu
- Windows Server 2019/2022 hoặc Windows 10/11 VPS
- Đã mở port 80, 443, 3000 ở firewall nhà mạng (Security Groups / Provider Firewall)
- Trỏ bản ghi DNS `A` (ví dụ `api.dynlove.app`) về IP VPS của bạn

### Các bước cài đặt
1. Copy thư mục `backend/` và `deploy/` vào `C:\apps\dynlove-backend\` (sao cho `package.json` nằm tại `C:\apps\dynlove-backend\package.json`).
2. Mở **PowerShell as Administrator** trên VPS:
   ```powershell
   cd C:\apps\dynlove-backend\..\deploy
   # Sửa biến $DOMAIN trong setup-windows.ps1 thành domain của bạn trước khi chạy:
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\setup-windows.ps1
   ```
3. Kiểm tra trạng thái service:
   ```powershell
   nssm status DynLoveBackend
   nssm status Caddy
   curl http://localhost:3000/health
   ```

---

## 📱 2. Hướng Dẫn Chạy Flutter Mobile App

### Chạy Local / Máy thật
1. Di chuyển vào thư mục `mobile`:
   ```bash
   cd mobile
   flutter pub get
   ```
2. Cập nhật địa chỉ Backend trong `mobile/lib/api.dart`:
   ```dart
   static const base = 'https://api.dynlove.app'; // Hoặc http://<IP_VPS>:3000
   ```
3. Chạy trên thiết bị hoặc giả lập:
   ```bash
   flutter run
   ```
4. Build APK phát hành:
   ```bash
   flutter build apk --release
   ```

---

## 🔑 3. Luồng Test & Xác Thực (Demo Flow)

1. **Đăng nhập**: Nhập số điện thoại bất kỳ $\rightarrow$ Bấm Gửi OTP $\rightarrow$ Nhập mã mock `123456` $\rightarrow$ Xác nhận.
2. **Ghép đôi**: 
   - Thiết bị 1: Bấm "Tạo mã mời" $\rightarrow$ nhận mã 6 ký tự.
   - Thiết bị 2: Đăng nhập SĐT khác $\rightarrow$ nhập mã mời của thiết bị 1 $\rightarrow$ Kết nối thành công.
3. **Đếm ngày**: Màn hình Home tự động tính số ngày từ ngày yêu nhau.
4. **Nuôi Pet**: Bấm "Cho ăn", "Xoa đầu", "Tắm" $\rightarrow$ Level, EXP, Hunger, Happiness tự cập nhật real-time qua Socket.io sang cả 2 máy.
5. **Chat Real-time & Gửi yêu thương**: Vào màn hình Chat $\rightarrow$ nhắn tin hai chiều, nhận thông báo typing và chạm tim tức thì.

---

## 🛠️ 4. Kế Hoạch Mở Rộng Phase 2

- Thay thế mock OTP bằng Firebase Auth Phone / Twilio Verify.
- Đăng ký Task Scheduler chạy `pg_dump` backup cơ sở dữ liệu hàng ngày lên Cloudflare R2 / AWS S3.
- Native Widgets (Android `AppWidgetProvider` & iOS `WidgetKit`) qua plugin `home_widget`.
- Đồng bộ nhạc Spotify qua Spotify Web API / SDK.
- Rive Animation cho Pet với file `.riv` tương tác cao cấp.
- Push Notifications qua Firebase Cloud Messaging (FCM) & APNs.
