# Arsitektur Proyek: Feature-first (Modular)

Secara garis besar, proyek ini membagi tugas menjadi dua struktur utama: **`core/`** (pusat / inti yang dipakai bersama) dan **`features/`** (fitur-fitur spesifik aplikasi).

---

## 1. Folder `core/` (Komponen Inti / Global)

Folder ini berisi file-file yang sifatnya **umum (universal)**. Artinya, file di sini bisa dipanggil dan digunakan oleh *semua fitur* tanpa terkecuali.

* **`constants/`**
  * `style.dart`: Berisi daftar warna standar (seperti `AppStyle.primaryBlue`), ukuran teks, dan gaya *font* yang dipakai secara seragam di seluruh aplikasi.
* **`models/`**
  * Berisi *blueprint* data yang dipakai lintas fitur. Contoh: `discount_model.dart` (format data diskon) dan `rekap_model.dart` (data rekapitulasi umum).
* **`network/`**
  * `api_client.dart`: Jantung komunikasi aplikasi dengan internet. Menangani konfigurasi *HTTP Headers*, injeksi *Token Authorization*, dan alamat *Base URL* server.
  * `master_api_service.dart`: API umum yang tidak terikat pada satu fitur spesifik (misal: mengambil data meja / pajak).
* **`services/`**
  * `storage_service.dart`: Menangani penyimpanan lokal di perangkat (menggunakan *SharedPreferences*), seperti menyimpan Token Login, Outlet ID, dan Status Shift.
  * `reverb_service.dart`: Menangani koneksi *WebSocket / Pusher* untuk menerima notifikasi *real-time* (seperti pesanan baru dari pelanggan).
* **`utils/`**
  * File-file pembantu (*helper*). Contoh: `currency_formatter.dart` (mengubah angka jadi format "Rp") dan `tax_calculator.dart` (rumus hitung pajak/servis).
* **`widgets/`**
  * Komponen UI yang sering dipakai berulang-ulang di berbagai layar. Contoh: `table_panel.dart`.

---

## 2. Folder `features/` (Fitur Spesifik)

Di sinilah letak perbedaan terbesarnya. Aplikasi dibagi menjadi **modul-modul fitur**. Setiap fitur adalah "aplikasi kecil" yang mandiri dan memiliki foldernya masing-masing:

### A. `auth/` (Otentikasi & Login)

Semua hal terkait masuk dan keluarnya karyawan dari aplikasi.

* **`screens/`**: `login_screen.dart` (tampilan halaman login dengan PIN), `outlet_selection_screen.dart` (layar pilih cabang), `splash_screen.dart` (layar *loading* awal).
* **`providers/`**: `auth_provider.dart` (menyimpan logika *state* login/logout).
* **`services/`**: `auth_api_service.dart` (API khusus untuk mengecek PIN dan data *User* ke server).

### B. `home/` (Beranda & Etalase Produk)

Mengatur halaman utama tempat kasir memilih produk pesanan.

* **`screens/`**: `home_screen.dart` (kerangka halaman utama), `main_navigation.dart` (tampilan menu *sidebar/bottom bar*).
* **`widgets/`**: `product_grid.dart` (daftar menu kotak-kotak), `product_card.dart` (desain 1 kartu menu), `category_filter.dart` (tombol-tombol kategori di atas).
* **`providers/`**: `home_controller.dart` (mengatur menu apa yang sedang aktif di sidebar), `product_provider.dart` (menyimpan *state* pencarian dan data produk).
* **`services/`**: `product_api_service.dart` (API khusus untuk menarik daftar produk dan kategori dari server).

### C. `cart_checkout/` (Keranjang & Pembayaran)

Menangani proses menghitung pesanan hingga pelanggan membayar.

* **`screens/`**: `checkout_dialog.dart` (tampilan dialog saat tombol *Checkout* ditekan), `success_payment_screen.dart` (layar struk hijau "Pembayaran Berhasil").
* **`widgets/`**: `cart_panel.dart` (panel keranjang di sebelah kanan layar), `discount_panel.dart` (panel voucher diskon), `payment_selector.dart` (pilihan metode bayar Tunai/QRIS), dll.
* **`providers/`**: `cart_provider.dart` (menyimpan *state* keranjang: tambah produk, kurangi produk, hitung subtotal).
* **`services/`**: Berisi layanan pemrosesan eksternal jika ada.

### D. `orders/` (Pesanan & Riwayat Transaksi)

Menangani pesanan yang sedang diproses (*Pending*) dan yang sudah selesai (*Riwayat*).

* **`screens/`**: `history_screen.dart` (halaman riwayat transaksi/struk masa lalu).
* **`widgets/`**: `pending_order_panel.dart` (daftar pesanan meja yang belum dibayar), `order_notification_overlay.dart` (animasi *pop-up* notifikasi pesanan masuk).
* **`providers/`**: `order_provider.dart` (mengelola *state* riwayat pesanan).
* **`services/`**: `order_api_service.dart` (API untuk menarik riwayat dan membatalkan pesanan/Void).

### E. `shift/` (Manajemen Laci Kasir)

Mengelola status kerja kasir (buka/tutup toko).

* **`screens/`**: `shift_screen.dart` (halaman laporan shift saat ini).
* **`widgets/`**: `opening_cash_dialog.dart` (dialog input kas awal), `closing_cash_dialog.dart` (dialog input uang di laci saat mau pulang).
* **`providers/`**: `shift_provider.dart` (mencatat waktu mulai kerja dan total uang kasir).
* **`services/`**: `shift_api_service.dart` (API untuk menyetor laporan *shift* ke server).

### F. `printer/` (Manajemen Struk Fisik)

Menangani konektivitas dengan *printer thermal* Bluetooth atau *Network* (LAN/WiFi).

* **`screens/` & `widgets/`**: Halaman untuk mancari alat dan menyambungkan printer.
* **`services/`**: `printer_service.dart` (berisi *library* untuk mengirim data *Print* ke mesin cetak) dan `network_scanner_service.dart`.
* **`models/` & `utils/`**: Format perintah ESC/POS untuk memotong kertas, mencetak teks tebal, dll.

### G. `settings/` (Pengaturan Aplikasi)

* **`screens/`**: `setting_screen.dart` (halaman pengaturan umum) dan `profil_screen.dart` (tampilan akun kasir yang sedang login).

---

*Dokumen ini dibuat untuk memandu pengembang dalam menavigasi struktur kode berbasis Feature-first.*
