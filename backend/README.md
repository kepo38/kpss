# KPSS Odak — Django içerik yönetim paneli

Mobil uygulama yalnızca öğrenciler içindir. Soru, müfredat ve test yönetimi
bu Django projesinden yapılır.

## Kurulum

```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_curriculum
python manage.py ensure_admin
python manage.py runserver 0.0.0.0:8000
```

- Admin (Unfold): http://127.0.0.1:8000/admin/
  - Kullanıcı: `admin` / `admin`
- **İçerik paneli (önerilen):** http://127.0.0.1:8000/panel/
  - Ders → Konu (aktif/pasif) → Bilgi / Sorular / Testler
- API paket: http://127.0.0.1:8000/api/v1/pack/
- Sağlık: http://127.0.0.1:8000/api/v1/health/

Android emülatöründen PC’ye erişim için base URL: `http://10.0.2.2:8000`

## İş akışı

1. Admin’de **Ders / Konu** düzenle (seed ile gelir).
2. **Soru** ekle — metin, şıklar, görsel; `is_published` işaretle.
3. **Konu testi** oluştur, soruları seç, yayınla.
4. Mobil uygulama `/api/v1/pack/` ile yayın paketini çeker.
