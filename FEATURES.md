# Hedef Kamu (KPSS Akademi) — Özellik Kataloğu

> **Son güncelleme:** 2026-08-22  
> **Dart paketi:** `kpss_akademi`  
> **Android applicationId (Play Store):** `com.hedefkamu.hedef_kamu`  
> **Sürüm (mobil):** `1.0.1+3`  
> **Stack:** Flutter mobil + Django REST API + içerik paneli (`/panel/`) + Unfold admin (`/admin/`)

Bu dosya uygulamadaki **tüm kullanıcı ve yönetici özelliklerini** tek kaynakta toplar. Yeni özellik eklendiğinde, mevcut bir özellik değiştirildiğinde veya kaldırıldığında **aynı PR/commit ile güncellenmelidir**.

**Premium kaynağı:** Play Billing aboneliği **veya** panel/API `isPremium` / promosyon / mini deneme ödül günleri → `PremiumService.instance.isPremium` (`premium_service.dart`, `play_billing_service.dart`). Kapı yardımcısı: `PremiumGate.requirePremium` / `navigate` → paywall.

---

## Bakım kuralı

| Ne zaman | Ne yapılır |
|---|---|
| Yeni ekran, servis veya API eklendiğinde | İlgili bölüme madde ekle; dosya yollarını yaz |
| Premium / reklam / kota / Google kapısı değiştiğinde | [Erişim matrisi](#erişim-matrisi) — özellikle [Google](#-google-giriş-gerektiren-özellikler), [Reklam](#-ödüllü-reklam-izleme-gerektiren-özellikler), [Premium](#-premium-gerektiren-özellikler) |
| Panel veya admin akışı değiştiğinde | [İçerik paneli](#i̇çerik-paneli-panel) veya [Unfold admin](#unfold-admin-admin) bölümünü güncelle |
| Özellik kaldırıldığında | Maddenin yanına `(kaldırıldı)` notu veya silme |

**Referans dosyalar:** `lib/screens/`, `lib/services/`, `lib/widgets/`, `backend/content/`


### 22 Ağustos 2026 — Misafir↔Google aktarım · yanlış defteri · Telegram OCR

Bu tur: misafirken biriken yanlış defteri verisinin Google girişinde kaybolması düzeltildi; testte işaretlenen yanlış şık defter incelemesinde gösterilir; Telegram bot farklı fotoğrafları yanlışlıkla «aynı fotoğraf» sanmaz; ÖSYM arşiv kataloğuna AGS eklendi.

#### Misafir ↔ Google hesap ilişkisi (detay)

Yanlış defteri, notlar, kalem çizimleri ve kitaptaki yanlışlar **tamamen cihazda** tutulur; Django sunucusunda yanlış defteri tablosu yoktur. Google girişi yalnızca `AppUser` / analitik birleştirmesi için backend’e gider (`guest_sub` ile `merge_guest_user_into`).

| Kavram | Açıklama |
|:---|:---|
| **Misafir kimliği** | Firebase anonim `user.id` veya çevrimdışı `local:guest-{timestamp}` (`local_guest_id` prefs’te yedeklenir) |
| **Google kimliği** | Backend `AppUser.pk` string — kalıcı hesap (`hasPermanentAccount`) |
| **Veri kapsamı** | SharedPreferences / SQLite anahtarları `{anahtar}_{userId}` ile kullanıcıya özel |
| **Taşınan (misafir→Google)** | Yanlış soru listesi, işaretli şıklar, soru gövdeleri, TEKRAR ET/ÇÖZÜLDÜ, istatistik kilidi, notlar, kalem çizimleri, manuel foto sorular |
| **Taşınmayan** | Günlük test kotası ilerlemesi, deneme geçmişi (`TestAttempt`) — kasıtlı |

**Google giriş akışı (`signInWithGoogle`):**

1. Giriş **öncesi** `previousUserId = _user?.id` yakalanır.
2. Backend token exchange → yeni `_user` (Google hesabı).
3. `_relayUserScopedServices(previousUserId: …)` tüm yerel servisleri sırayla günceller.
4. Her servis: henüz yüklenmemişse önce `initialize()`, sonra misafir scope → Google scope **migrate** + yeniden yükle.

| Servis | Taşınan prefs / veri | Dosya |
|:---|:---|:---|
| **ContentBankService** | `content_wrong_question_*`, işaretli şıklar, gövdeler, stat kilidi | `content_bank_service.dart` |
| **ManualQuestionService** | SQLite `manual_wrong_questions` satırları `reassignUser` | `manual_question_service.dart` |
| **QuestionNoteService** | `question_notes_v1_{userId}` | `question_note_service.dart` |
| **WrongNotebookDrawingService** | `wrong_notebook_drawings_v1_{userId}` | `wrong_notebook_drawing_service.dart` |

**Yedek eşleme:** `local_guest_id` prefs anahtarı; servis `previousUserId` alamazsa misafir defterini buradan bulur (`_inferGuestScopeForMigration` / `_inferGuestUserId`).

**UI tetikleyiciler:** `AccountLinkCard.prompt` sonrası `AuthService.relayUserScopedServices(previousUserId: …)` — yanlış defteri buz kaldırma ve «Tüm yanlışları çöz» Google kapısı (`wrong_questions_screen.dart`).

**Bilinen sınır:** Daha önce hatalı sürümle Google’a geçilmiş ve defter boş kalmış cihazlarda veri yalnızca hâlâ `guest-…` anahtarlarındaysa yeni APK ile tekrar girişte taşınabilir.

#### Yanlış defteri — işaretli şık

| Alan | Ne yapıldı | Dosyalar |
|:---|:---|:---|
| **Kayıt hatası** | Test bitince `recordAttempt` yanlış şıkları quiz sırası yerine «önce doğru sonra yanlış» listesiyle eşleştiriyordu → yanlış/indeks kayması | `topic_detail_screen.dart`, `special_map_geography_screen.dart`, `daily_mini_exam_service.dart`, `continue_study_card.dart` |
| **Eşleme mantığı** | `_mergeWrongSelections` artık soru ID → cevap haritası kullanır | `content_bank_service.dart` |
| **Defter inceleme** | Açılışta `wrongSelectionFor` → `QuizScreen.initialAnswers`; testte verilen yanlış şık kırmızı, doğru yeşil | `wrong_questions_screen.dart`, `quiz_screen.dart` |
| **Anlık kayıt** | Defter modunda şık değişince `setWrongQuestionSelection` | `content_bank_service.dart`, `quiz_screen.dart` |

#### Telegram bot — OCR kuyruk düzeltmesi

| Alan | Ne yapıldı | Dosyalar |
|:---|:---|:---|
| **Paralel OCR** | Fotoğraflar arka planda işlenir (`TELEGRAM_OCR_WORKERS`, varsayılan 2); bir OCR sürerken diğer fotoğraf bloklanmaz | `telegram_bot.py` |
| **Anında onay** | «📷 Fotoğraf alındı, OCR başlıyor…» | `telegram_bot.py` |
| **Kilit anahtarı** | Eşzamanlılık kilidi `file_unique_id` yerine `chat_id:message_id` — farklı fotoğraflar birbirini «aynı fotoğraf» sanmaz | `telegram_bot.py` |
| **IntegrityError** | Kayıt çakışmasında yanıltıcı «aynı fotoğraf» metni düzeltildi; retry + mevcut kayıt bulma | `telegram_bot.py`, `test_telegram_ingest.py` |
| **Test modu** | `TELEGRAM_INLINE_PHOTOS=True` — birim testlerde senkron OCR | `test_telegram_ingest.py` |

#### ÖSYM arşiv — AGS katalog güncellemesi

| Alan | Ne yapıldı | Dosyalar |
|:---|:---|:---|
| **AGS eklendi** | «AGS · MEB Akademi Giriş Sınavı» (80 soru), 2019–2026 | `osym_archive.py` |
| **KPSS sadeleştirme** | Lisans’tan Eğitim Bilimleri kaldırıldı; tüm ÖABT branşları kaldırıldı (AGS ayrı sınav) | `osym_archive.py`, `test_osym_archive.py` |

### 22 Ağustos 2026 — ÖSYM Çıkmış Sorular arşiv yöneticisi

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Arşiv panosu** | Yıl × sınav × oturum kartları; tam / kısmi / eksik durumu; soru sayısı | `/panel/osym-cikmis/`, `osym_archive.html` |
| **Katalog** | KPSS (Lisans/Önlisans/Ortaöğretim), **AGS**, ALES, YKS (TYT/AYT), DGS — 2019–2026 | `osym_archive.py` |
| **Etiket biçimi** | «2025 KPSS Lisans · Genel Yetenek - Genel Kültür» (+ isteğe « · Soru 12») | `question_form.html`, `osym_cikmis_adi` |
| **Detay** | Oturumdaki sorular listesi → soru düzenleme | `/panel/osym-cikmis/detay/<etiket>/` |

### 22 Ağustos 2026 — Türkiye Geneli (TG) Deneme modülü

Tam kapsamlı TG deneme sistemi — normal konu testleri, deneme paketleri ve Telegram OCR akışından **ayrı paket** (`backend/content/tg_exam/`). Ayrıntılı özellik listesi: [Türkiye Geneli (TG) denemeleri](#türkiye-geneli-tg-denemeleri).

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Modül ayrımı** | TG kodu `content/tg_exam/` paketinde; ExamPack / TopicTest / Telegram ile çakışmaz | `tg_exam/*`, geriye uyum shim’leri |
| **Panel oluşturucu** | Wizard: ad/tarih → otomatik 120 soru → önizleme/değiştir → yayınla | `/panel/tg-deneme/`, `tg_exam_form.html`, `panel_views.py` |
| **Soru üretici** | Oranlı dağılım + alt konu/etiket eşleme; kolay/orta cooldown (son 4 TG) | `generator.py`, `distribution.py`, `cooldown.py` |
| **Mobil liste** | Deneme sekmesi **Aktif** / **Geçmiş** + **Yayında** rozeti | `tg_exams_section.dart` |
| **Oturum** | 130 dk geri sayım; son 10 dk uyarı sesi; süre bitince otomatik gönderim; reklamsız | `tg_exam_constants.dart`, `quiz_screen.dart`, `exam_welcome_screen.dart` |
| **ÖSYM rozeti yok** | Havuz sorularında TG ekranında «ÖSYM SORDU» gizlenir | `quiz_screen.dart`, `api_views.py`, `forTgExamDisplayList` |
| **FCM duyuru** | Yayın sonrası değil — **başlangıçtan 2 saat önce** tüm kullanıcılara | `announcements.py`, migration `0061` |
| **FCM sonuç** | `end_at` sonrası katılımcılara sonuç bildirimi | `ranking.py`, `push.py`, `finalize_tg_exams.py` |
| **API** | `/api/v1/tg-exams/` liste, detay, sorular, ilerleme, gönderim | `api_views.py`, `api_urls.py`, `tg_exam_service.dart` |

### 22 Ağustos 2026 — Konu testi tamamlama işareti · reklam düzeltmesi

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Test yeşil tik** | Bitirilen konu testinin yanında **BAŞLA** solunda yeşil ✓ | `topic_detail_screen.dart` (`_TestRow`) |
| **Banner yenileme** | SDK geç hazır olunca banner tekrar yüklenir; yükleme sonrası UI güncellenir | `ad_manager.dart`, `quiz_screen.dart` |

### 22 Ağustos 2026 — Erişim rehberi · yanlış defteri çizim · UI cilası

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **FEATURES erişim rehberi** | Google / ödüllü reklam / Premium / misafir matrisleri renkli simgelerle ayrı tablolar | `FEATURES.md` |
| **Yanlış defteri durum chip** | TEKRAR ET / ÇÖZÜLDÜ (test yanlışları) | `wrong_notebook_status_chip.dart`, `content_bank_service.dart` |
| **Yanlış defteri çizim** | Soru ve çözüm katmanları ayrı; Google hesabında kalıcı | `wrong_notebook_drawing_service.dart`, `quiz_screen.dart` |
| **Quiz başarı göstergesi** | Dikey kırmızı–yeşil çubuk + chip hizası | `brand_mark.dart` |
| **Matematik şık kartı** | Sol şerit harf + ortalı formül düzeni | `quiz_screen.dart`, `exam_option_view.dart` |
| **Özet Konular başlık** | 3D altın AppBar | `topic_summary_study_screen.dart` |
| **Odak sayaç** | Altta HEDEF Kamu; üst etiket kaldırıldı | `focus_mode_screen.dart` |

### 22 Ağustos 2026 — Banner panel · Özel test etiketleri · Zoom ipucu · paylaşım · NEDEN BİZ

Bu tur: panelden quiz banner aç/kapa; özel test bayrakları + keyword (kronoloji / padişah / çeldirici); günlük zoom ipucu; paylaşım hikâyesi marka başlığı; NEDEN BİZ metinleri; yanlış defteri BENZER/Akıllı Tekrar; ÖSYM/splash/test AppBar cilası; kalem `saveLayer` beyaz örtü düzeltmesi.

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Banner panel aç/kapa** | Mobil arayüz sayfasında checkbox; `GET /api/v1/mobile-ui/` → `bannerAdsEnabled`; kapalıyken yalnızca quiz banner (ödüllü/interstitial etkilenmez) | `MobileUiConfig`, `mobile_ui.html`, `AppConfigService`, `ad_manager.dart`, `0049_…` |
| **Özel test otomatik etiket** | `tag_kronoloji` / `tag_padisah_antlasma` / `tag_celdirici`; panel checkbox + keyword auto; yeni **Çeldiricisi Güçlü**; `retag_special_questions` | `special_question_tags.py`, `special_tests.py`, `0050_…`, panel form |
| **Zoom günlük ipucu** | Her gün / hesap kapsamında ilk testte ortada yumuşak toast: «Çift dokunarak SORU ve ÇÖZÜMLERİ yakınlaştır»; misafir ile Google ayrı slot | `quiz_zoom_daily_hint.dart`, `quiz_screen.dart` |
| **Zoom 1× kaydırma** | Ölçek ≈1’te dikey `ScrollView`; yakınken pan InteractiveViewer’da | `quiz_zoom_viewport.dart`, `quiz_screen.dart` |
| **Paylaşım kartı başlık** | Sol üst logo/YANLIŞ DEFTERİ yok; üst ortada büyük **HEDEF Kamu**; içerik alanı dolduran ölçekleyici | `wrong_notebook_share_card.dart`, `wrong_notebook_share_service.dart` |
| **NEDEN BİZ metin** | 5 uygulama avantajı + 3 kitap dezavantajı (başlık+açıklama); alt özet cümle kaldırıldı | `why_us_comparison_card.dart` |
| **Yanlış defteri BENZER** | Kart üst kenarının ortasına oturan rozet | `wrong_notebook_question_card.dart` |
| **Akıllı Tekrar pill** | Sağ üst buton büyütüldü | `wrong_notebook_header.dart` |
| **KAYITLI KALIR** | Not Al altında büyütülüp ortalandı | `quiz_take_note_button.dart` |
| **ÖSYM rozeti** | Eski boyut (44/52); AppBar Soru X/Y ile aynı dikey eksen | `brand_mark.dart` |
| **Başarı chip** | Sağa yaslıdan biraz içeride | `brand_mark.dart` |
| **Test AppBar adı** | Serif başlık 14→16 | `quiz_screen.dart` |
| **Splash 657 diski** | Siyah daire soluklaştırıldı | `boot_splash_screen.dart` |
| **Kalem beyaz örtü** | Boş `saveLayer` yalnızca silgi gerektiğinde; Impeller’da soru metnini kaplayan beyaz alan giderildi | `quiz_drawing_overlay.dart` |

### 21 Ağustos 2026 — Quiz zoom · şık hizası · paylaşım 9:16 · Odak chip · çizim sürükle

Bu tur: quiz içerik yakınlaştırma; şık biçim kuralı netleşti; yanlış defteri paylaşım görseli tam ekran hikâye; Odak tam ekran süre chip’i; kalem araç çubuğu sürüklenir; paylaşım yakalama logları.

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Quiz pinch-to-zoom** | Soru gövdesi (kök + şık/çözüm) `InteractiveViewer` (1×–4×); çift dokunuş 2.2× / sıfırla; yakınken **Sıfırla** FAB | `quiz_zoom_viewport.dart`, `quiz_screen.dart` |
| **Zoom ↔ çizim** | Kalem açıkken zoom kilit + matris sıfır; kalem kapalıyken zoom açık; mevcut çizimler zoom’da `QuizStrokeLayer` ile içerikle birlikte | `quiz_screen.dart`, `quiz_drawing_overlay.dart` |
| **Şık hizası (kural)** | **Tüm şıklar sola**; yalnızca `$…$` LaTeX büyük punto. Eski ≤20 karakter ortala kuralı kaldırıldı (A–E uyumsuzluğu) | `exam_option_view.dart`, `exam_text_parity_test.dart` |
| **Başarı chip** | Veri yoksa da `Başarı: —` (gizlenmez) | `quiz_screen.dart` |
| **Yanlış defteri paylaşım 9:16** | 1080×1920 hikâye karesi; tek soluk filigran; daire harfli şıklar; pill kutular yok | `wrong_notebook_share_card.dart`, `wrong_notebook_share_service.dart` |
| **Paylaşım yakalama** | Overlay + adım kodlu `WrongNotebookShare` log; snackbar’da `FAIL` kodu; `ScreenshotGate` | `wrong_notebook_share_service.dart`, `screenshot_gate.dart`, `MainActivity.kt` |
| **Paylaşım hakkı metni** | **GÜNDE 1 SORU PAYLAŞABİLİRSİNİZ** | `wrong_notebook_share_service.dart` |
| **Kalem araç çubuğu** | Üst tutamaçla yukarı/aşağı sürüklenir | `quiz_drawing_overlay.dart` |
| **Odak tam ekran** | Sayaç altında aktif **20/40/60** chip (ana ekranla aynı stil); isim arkasında quiz filigranı (eğik soluk) | `focus_mode_screen.dart` |

### 21 Ağustos 2026 — Odak Dalga/Kafe · çözüm kotası · NEDEN BİZ · paylaşım · kota · canlı istatistik

Bu tur: Pomodoro ortam sesleri yenilendi; çözüm reklam kotası; profil NEDEN BİZ; yanlış defteri WhatsApp paylaşımı + FLAG_SECURE geçici açma; ders bazlı günlük kota API; panel canlı kullanıcı istatistiği; matematik holder sızıntısı düzeltmesi.

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Odak ortam: Dalga** | Eski **Yağmur** → **Dalga**; `ambient_wave.mp3`; ikon `waves`; Deep Work ile aynı loop + complete/state yedek + `ensureAmbientKeepsPlaying` | `pomodoro_session_model.dart`, `pomodoro_service.dart`, `focus_mode_screen.dart`, `assets/sounds/ambient_wave.mp3` |
| **Odak ortam: Kafe** | Eski **Orman** → **Kafe**; `ambient_cafe.mp3`; ikon `local_cafe` | aynı + `assets/sounds/ambient_cafe.mp3` |
| **Eski WAV silindi** | `ambient_rain.wav` + `ambient_forest.wav` kaldırıldı (~7 MB APK) | `assets/sounds/` |
| **Odak süre** | Preset **yalnızca 20 / 40 / 60** (`dk80` yok); ortalanmış chip’ler; misafirde 40/60 Google kilidi | `PomodoroPreset`, `focus_mode_screen.dart` |
| **Odak tam ekran** | Sol üst **DERS ÇALIŞIYORUM** + bugünkü çalışma chip’i; kullanıcı adı `FittedBox`; premium **kronometre** ikonu | `focus_mode_screen.dart` |
| **Ortam UI** | «Ortam Sesi» başlık/alt yazı yok; Dalga/Kafe + ses seviyesi; tekrar dokununca sessiz | `focus_mode_screen.dart` |
| **Çözüm reklam kotası** | Test başına ilk **4** tam/kısa çözüm ücretsiz (`freeSolutionsPerTest`); 5.+ her biri ödüllü; sıra bağımsız sayaç; ücretsiz haklar ad-unlock’tan ayrı | `ad_constants.dart`, `ad_manager.dart`, `quiz_screen.dart` |
| **NEDEN BİZ** | Profil hero paneli üst kenarında rozet; diyalog: HEDEF Kamu vs klasik kitap karşılaştırması (panel sırası: önce uygulama) | `why_us_comparison_card.dart`, `profile_screen.dart` |
| **Yanlış defteri WhatsApp** | Google zorunlu; yalnızca filigranlı PNG kart (+ kısa yardım cümlesi); soru metni düz gitmez. Ücretsiz: **1/gün** (+ödüllü reklam); Premium: **3/gün**. Kota dolunca paylaşım yok | `wrong_notebook_share_service.dart`, `wrong_notebook_share_card.dart`, `ad_manager.dart`, `wrong_notebook_*_card.dart` |
| **ScreenshotGate** | Paylaşım yakalama anında Android `FLAG_SECURE` geçici kapatılır (release’te capture kırılmaz); MethodChannel `hedef_kamu/screenshot_gate` | `screenshot_gate.dart`, `MainActivity.kt` |
| **iOS kayıt kalkanı** | Ekran kaydı sırasında siyah örtü | `AppDelegate.swift` |
| **Günlük test kotası (ders)** | Kota **ders başına** (global değil); snackbar «Bu derste…»; sunucu `DailySubjectFreeUsage` + `GET/POST /api/v1/daily-quota/` | `daily_quota_service.dart`, `content_bank_service.dart`, `views.py`, `0047_…`, `test_daily_quota.py` |
| **Panel canlı istatistik** | `/panel/uygulama-durumu/` — aktif / günlük kullanıcı (`AppUser.last_active_at`) | `app_live_stats.py`, `app_stats.html`, `panel_views.py`, `0048_…` |
| **LaTeX holder sızıntısı** | `§§C0§§` → `§§#0#§§` (upright math letter wrap bozmaz) | `formatted_text.dart`, `formatted_text_test.dart` |

### 21 Ağustos 2026 — LaTeX hyphen / kompakt şık / APK ambient trim / quiz başlık

Önceki aynı gün Focus/Deep Work + quiz AppBar oturumunun üstüne: matematik metninin Türkçe soft-hyphen ile bozulmaması, kısa/math şık tipografisi, kullanılmayan ambient WAV silimi (APK), Test başlığı sola kaydırma. Panel `math-formulas.js`.

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **LaTeX soft-hyphen** | `$…$` / `$$…$$` / `\(…\)` / `\[…\]` bölgeleri hyphenate dışı; `displaystyle` / `begin` kırılması önlendi | `turkish_hyphenation.dart`, `formatted_text.dart`, ilgili testler |
| **Panel math-formulas** | Formül yardımcıları ayrı `math-formulas.js`; base/question_form + rich-format/math-render bağları | `backend/static/panel/math-formulas.js`, `math-render.js`, `rich-format.js`, `base.html`, `question_form.html` |
| **Kısa/math şık** | ≤20 görünür karakter veya `$` içeren şık: ortalı + **18pt**; uzun düz metin sola 15pt | `exam_option_view.dart` |
| **Quiz AppBar başlık** | Test 1 sola kaydırıldı (`leadingWidth` 48, `-10` inset) | `quiz_screen.dart` |
| **APK ambient trim** | Eski kafe/kütüphane/deniz/binaural WAV’ler silindi; sonraki turda yağmur/orman da silindi → Dalga/Kafe MP3 | `assets/sounds/`, `pubspec.yaml` |
| **Odak / Deep Work** | Sonraki turda Dalga/Kafe + Deep Work loop/sürdürme ile hizalandı | (üst madde) |

### 21 Ağustos 2026 — Odak Deep Work MP3 / soru viewCount / telefon bat / quiz·profil (later session)

Önceki aynı gün commit’inin (`eca90bd` neon/pack/tablo/Özel Notlarım; `acc4bf3` panel şablon) üstüne: Focus ortam sadeleştirme + yerel Deep Work müziği, soru görüntüleme sayacı, telefon LAN launcher düzeltmeleri, quiz AppBar / profil / Gelişim CTA cilası.

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Soru görüntüleme sayacı** | `Question.view_count` + `QuestionView` (user×question unique); şık seçilmeden / boş bırakılsa da soru açılınca sayılır; tekrarlayan kullanıcı artırmaz | `models.py`, `0046_question_view_count.py`, `serializers.py` (`viewCount`), `admin.py` |
| **POST view API** | `POST /api/v1/questions/<id>/view/` → `{viewCount}`; oturumlu kullanıcı kaydı; oturum yoksa artırmaz, mevcut sayı döner | `QuestionViewRecordView`, `urls.py`, `question_view_service.dart`, `api_config.dart` |
| **Quiz «N kişi gördü»** | Şerit `attemptLabel` gerçek `viewCount` / yerel cache; placeholder kaldırıldı | `quiz_screen.dart`, `question_model.dart` |
| **Quiz AppBar** | **Test** sola + **Soru X/Y** ekran ortasında (ÖSYM ile aynı eksen); boş başlıkta yalnızca Soru (tüm yanlışları çöz → **YANLIŞLARIM** yok) | `quiz_screen.dart`, `wrong_questions_screen.dart` |
| **Profil Görünüm** | Modül satırı varsayılan **kapalı** (`_open = false`) | `profile_screen.dart` |
| **Odak ortam sesleri** | **Dalga / Kafe** chip’leri (eski yağmur/orman + WAV’ler kaldırıldı); Sessiz chip yok (tekrar dokununca sessize); Deep Work ile aynı loop/sürdürme | `pomodoro_session_model.dart`, `focus_mode_screen.dart`, `ambient_wave.mp3`, `ambient_cafe.mp3` |
| **Deep Work Music** | Yerel loop MP3 (`assets/sounds/deep_work_music.mp3`); YouTube/Premium değil; ambient ile karşılıklı exclusive; müziksiz oynatma OK | `pomodoro_service.dart`, `focus_mode_screen.dart`, `pubspec.yaml` assets |
| **Odak kontroller** | **Sıfırla** preset altında; süre **20/40/60** (`80` yok); Deep Work play ile preset arasında; Dalga/Kafe + volume | `focus_mode_screen.dart`, `PomodoroPreset` |
| **Kilit / bitiş** | Kilit ekranında ambient + Deep Work (`stayAwake` / media focus); süre bitiş bildirimi+zil (önceki oturumda; bu turda korunur) | `pomodoro_service.dart`, `notification_service.dart` |
| **Gelişim ODAK CTA** | Ink+şampanya → **mavi↔mor** gradient pill | `app_shell_top_bar.dart` |
| **basla-telefon.bat** | LAN IP → `--dart-define=KPSS_API_BASE`; Django `0.0.0.0:8000`; ASCII/`__INNER__` Explorer launcher; `goto :fail` / health bekleme; ozel→HEDEFKAMU yönlendirme | `basla-telefon.bat` |
| **Telefon yardımcıları** | `get-lan-ip.ps1`, `run-django-telefon.bat`, `basla-telefon-test.bat` (Flutter’sız LAN/health smoke) | `scripts/`, kök bat |
| **Auth / API URL hataları** | Wi-Fi + `basla-telefon.bat` ipucu; exchange log’da `baseUrl`; Firebase yapılandırma / jeton mesajları netleştirildi | `auth_service.dart`, `api_config.dart`, `auth.py`, `views.py` (GoogleAuth) |
| **Pack Bearer yıllık** | Önceki commit’te; boşluk yok — Bearer + `is_yearly_premium` / `POST /premium/sync/` | (doğrulandı) |
| **option_table Yok/İkili/Üçlü** | Önceki commit’te; katalog + panel notu güncel | (doğrulandı) |
| **Özel Notlarım** | Önceki commit’te; Stüdyo satırı + mock kartlar | (doğrulandı) |

### 21 Ağustos 2026 — Odak neon / pack auth / tablo bayrağı / quiz header / Özel Notlarım

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Odak Modu UI** | Neon kırmızı↔cyan arka plan; süre halkası altında play/pause (+ küçük sıfırla); Başlat satırı kaldırıldı | `focus_mode_screen.dart` |
| **Ortam sesleri** | Yağmur, Orman, Kafe, Kütüphane, Deniz, binaural 40/60/80 Hz; kafe/kütüphane/deniz WAV yenilendi; kilitliyken çalma (`stayAwake`, `wakelock_plus`, iOS `UIBackgroundModes: audio`) | `pomodoro_session_model.dart`, `pomodoro_service.dart`, `assets/sounds/ambient_*.wav`, `Info.plist`, `AndroidManifest.xml` |
| **Süre bitiş uyarısı** | Yerel bildirim + `focus_complete.wav` zil + haptic; bitiş zamanına göre senkron (arka plan) | `notification_service.dart`, `focus_mode_screen.dart` |
| **Gelişim Pomodoro CTA** | Sağ üst ink+şampanya **ODAK / Pomodoro** pill (nabız glow); Odak Modu açar | `app_shell_top_bar.dart` |
| **Offline pack auth** | `GET /pack/` + `pack/version/` → Bearer zorunlu + **yıllık** premium (`is_yearly_premium`); 401/403; `POST /premium/sync/` Play ürün bilgisini sunucuya yazar | `views.py`, `models.py` (`premium_product_id`), `0045_…`, `premium_sync_service.dart`, `content_sync_service.dart`, `offline_pack_service.dart` |
| **Tablo sorusu bayrağı** | Panel **Yok / İkili / Üçlü**; otomatik tire algısı kapalı; Flutter yalnızca `optionTable` dual/triple iken sütun; başlık↔hücre hizası | `Question.option_table`, `0044_…`, `question_form.html`, `option-table.js`, `question_model.dart`, `exam_option_view.dart`, `quiz_screen.dart` |
| **Özel Notlarım** | Stüdyo «Güncel Bilgiler» → **ÖZEL NOTLARIM**; kart PageView aynı; mock kişisel not | `home_tools_module_list.dart`, `current_info_screen.dart`, `database_service.dart` |
| **Quiz AppBar / şerit** | **Test N** sola; **Soru X/Y** AppBar’da; eski Soru yerinde yeşil **Başarı: %N** (`correctRate`); **ÖSYM** rozeti ortada aynı yerde | `quiz_screen.dart`, `brand_mark.dart` (`QuizHeaderStrip.successLabel`) |

### 21 Ağustos 2026 — Stüdyo: Pomodoro + Deneme Analizi ücretsiz

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Odak · Pomodoro** | Stüdyo satırı `onNavigatePremium` → `onNavigate` (PremiumGate yok) | `home_tools_module_list.dart` |
| **Deneme Analizi** | Aynı; alt Deneme sekmesi zaten ücretsizdi | `home_tools_module_list.dart`, `main_shell.dart` |
| **Paywall listesi** | Odak/Pomodoro ve Deneme Analizi Pro kaldırıldı | `premium_service.dart` |
| **Erişim matrisi** | A/C/D/E + katalog satırları ücretsiz | `FEATURES.md` |

### 21 Ağustos 2026 — Quiz / ContentBank / mini sonuç / konu detay (bu commit)

Önceki aynı gün commit'inin (6a6f501 günlük sıra/ÖDÜL/TDK/quiz scroll) üstüne eklenen şık tablosu, isolate, filigran, misafir kapısı ve sonuç UI düzeltmeleri.

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Şık tablosu 2+** | Eşleştirme eşiği 
>=2; varsayılan başlık **Olay / Sonuç**; 3+ sütun aynı; panel option-table.js?v=7 | option-table.js, question_form.html, option_column_layout.dart, exam_text_parity_test.dart |
| **ContentBank isolate** | Isolate.run → compute + yalnızca gönderilebilir harita/liste; **Illegal argument in isolate message** (Future/closure) düzeltmesi | content_bank_service.dart |
| **Kök filigran** | Metin bloklarında harita ile uyumlu stem watermark (watermarkOnText varsayılan açık, centered) | question_stem_content.dart, watermark_widget.dart, quiz_screen.dart |
| **Çözüm frost** | Kilit overlay'de **Reklam izle** üstte (MainAxisAlignment.start) | quiz_screen.dart |
| **SENİN SIRAN** | Kart başlığı/footer rafine; günlük mini önizleme | daily_mini_exam_card.dart, daily_mini_exam_leaderboard.dart |
| **Konu detay** | Ortalı ders/konu başlıkları; premium **Konuyu Öğren** CTA | 	opic_detail_screen.dart |
| **Misafir / reklam** | Tüm yanlışları çöz → hesap bağlama kapısı; ödüllü reklam uture.timeout(90s) | wrong_questions_screen.dart, d_manager.dart |
| **Günlük mini sonuç** | **GÜNÜN SIRALAMASI** / **GENEL SIRALAMA**; sıra çerçevesi yok; alt CTA'lar | daily_mini_exam_result_screen.dart |
| **ÖDÜL asma** | Hang madalyon CTA üst sağında; paylaş ikonundan sola kaydırma; kürsü önizlemesinde ÖDÜL yok | daily_mini_exam_card.dart, daily_mini_exam_leaderboard.dart, daily_mini_rewards_screen.dart |
| **ÖDÜL ekranı** | Yerleşim / sol kaydırma ve SENİN SIRAN polish | daily_mini_rewards_screen.dart |

### 21 Ağustos 2026 — Deneme / Profil / ÖDÜL / Quiz / Push (önceki commit)

Önceki aynı gün commit'inin (`b18dc23` Stüdyo/Gelişim/görev/splash) üstüne eklenen UI, sıralama, OCR ve araç düzeltmeleri.

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Deneme istatistik** | Ortalama net (kümülatif değil); mist track + altın/yeşil dolum; **PUAN HESAPLAMA** üst bara yakın; «Genel bakış» alt yazısı kaldırıldı | `statistics_overview_tab.dart`, `statistics_screen.dart`, `practice_exam_service.dart` |
| **Profil** | AppBar taşması / hayalet HESAP–Profil bleed düzeltmesi; `AccountLinkCard` opak/solid | `profile_screen.dart`, `account_link_card.dart` |
| **Stüdyo** *(önceki commit)* | Araç listesinden Profil satırı kaldırıldı; **STÜDYO** pill genişliği; beyaz «Stüdyo» başlığı yok | `home_screen.dart`, `home_hero_section.dart` |
| **Gelişim** *(önceki commit)* | Google **G** markası; gereksiz soru/not etiketleri kaldırıldı; ders carousel peek + fade | `analytics_hub_screen.dart`, `analytics_study_vault.dart`, `google_g_mark.dart` |
| **Günlük görev** *(önceki commit)* | Chevron + kontrast; **Denemeye Başla** gradyan tersi; 657 madalyon kaldırıldı | `daily_mission_center.dart`, `daily_mini_exam_cta.dart` |
| **Splash** *(önceki commit)* | Ataman metni yukarı (lift) | `boot_splash_screen.dart` |
| **Destek mailto** | `From` hardcode yok; kurumsal gövde şablonu (yazma alanı + teknik footer) | `support_contact_service.dart` |
| **Günlük mini** | 10 sn sıra reveal yarış düzeltmesi; tamamlandı UI vs Denemeye Başla; **Senin sıran** + Haftalık\|Aylık Row; EN BAŞARILILAR → günlük liste; AppBar **ÖDÜL** butonu kaldırıldı; TR tarih aralığı; eşitlik metni; ÖDÜL modal madalyalar, Kapat yok, anında navigasyon | `daily_mini_exam_*`, `daily_mini_rewards_screen.dart`, `daily_mini_odul_button.dart`, `daily_mini_exam_constants.dart`, `daily_mini_exam_logic.dart` |
| **Push** | FCM topic+token çift gönderim düzeltmesi (önce topic; OK ise multicast yok) | `push.py`, `tests.py` |
| **Quiz** | ÖSYM rozeti ortada; şıklar sola + TR soft-hyphen; watermark clip; **Çözümü Gör** şık seçilmeden kapalı | `quiz_screen.dart`, `exam_option_view.dart`, `exam_stem_view.dart`, `watermark_widget.dart`, `turkish_hyphenation.dart`, `formatted_text_test.dart` |
| **Şık tablosu 2+** | Eşleştirme eşiği `n>=2`; Olay/Sonuç varsayılan başlık; 3+ sütun aynı | `option-table.js` (`?v=7`), `option_column_layout.dart`, `exam_text_parity_test.dart` |
| **OCR / ğ** | Mojibake onarımı (`Ä`/`ğ`); `gerekti ini` vb. güvenli kalıplar; tarama komutu | `ocr.py`, `scan_missing_gbreve.py` |
| **basla.bat** | Orphan `runserver` temizliği; venv/Python bulma; port 8000 kontrolü; güvenilir start | `basla.bat`, `scripts/stop-django-runserver.ps1` |

### 21 Ağustos 2026 — ContentBank / Premium kapı / splash (önceki commit)

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Akıllı Tekrar** | «AKILLI TEKRARI BAŞLAT» yalnızca **Premium**; tıklanınca `PremiumGate` → paywall; CTA’da kilit + **PRO** rozeti | `smart_review_screen.dart`, `premium_gate.dart` |
| **Kitaptaki yanlışlarım** | Kalem/annotate **ücretsiz**; **1. foto ücretsiz**, **2.+ foto** Pro değilse ödüllü reklam; istatistik rozeti ders adının yanında | `wrong_notebook_manual_screen.dart`, `manual_question_annotate_viewer.dart`, `wrong_notebook_stats_row.dart` |
| **Annotate toolbar** | Sol çizim araçları, ayırıcı, sağda Undo + çöp; aktif renk belirgin | `quiz_drawing_overlay.dart` |
| **Açılış splash** | 657 + defne çelengi **parlak altın** (`#FFE08A`); daire **tam ekran ortası** (Y); üstte HEDEF KAMU, altta Ataman + kayan çizgi | `boot_splash_screen.dart` |
| **Stüdyo hero** | Üst sağ **Premium’u keşfet**; ortada **STÜDYO** pill; alt yazı kaldırıldı | `home_hero_section.dart` |
| **ÖDÜL UI** | Kürsüde/CTA’da sarkan madalyon; Premium 1–2–3 + haftalık/aylık sütun butonları; «Senin sıran» gold CTA | `daily_mini_odul_button.dart`, `daily_mini_rewards_screen.dart` |
| **Konuyu Öğren** | Konu detayından gömülü deste kaldırıldı; geniş **Konuyu Öğren** → `TopicSummaryStudyScreen` (Unuttum/Biliyorum) | `topic_detail_screen.dart`, `topic_summary_study_screen.dart` |
| **İstatistik** | Başlık **Deneme İstatistiklerim**; alt yazı **Netlerine göre tahmini**; Pazar 10:00 deneme hatırlatması | `statistics_overview_tab.dart`, `notification_service.dart` |
| **Destek UI** | Bilgi satırları butonumsu değil; UYARI amber/bronz; başlık ortalı; e-posta metni yok | `support_contact_screen.dart` |
| **ContentBank performans** | Pack/metadata + JSON decode **Isolate**; sorular SQLite `content_question_bank` (db v5); notify debounce 80ms | `content_bank_isolate.dart`, `content_bank_service.dart`, `local_database.dart` |
| **Yeniden çizim / kilit** | Theme-only `ListenableBuilder`; Auth/KPSS gated `setState`; MainShell IndexedStack; ads soft-init; paywall/smart-review/daily-mini mounted guard | `main.dart`, `main_shell.dart`, `ad_manager.dart`, `study_hub_screen.dart` |
| **FEATURES** | Premium alanlar matrisi + bu günün maddeleri | `FEATURES.md` |

### 20 Ağustos 2026 — işlenen ekleme ve değişiklikler

Bu tarihte yapılan **yeni özellikler**, **davranış değişiklikleri** ve **panel/API** güncellemelerinin ayrıntılı kaydı. Katalog satırları aşağıda ilgili bölümlerde de yansıtılmıştır.

#### Mobil — mini deneme haftalık/aylık ÖDÜL (yeni)

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Metrik** | Dönem sıralaması: **toplam doğru**; eşitlikte **toplam süre** (kısa üstte) | `daily_mini_ranking.py` |
| **Ödül** | 1.→3 gün, 2.→2 gün, 3.→1 gün Premium; haftalık ve aylık aynı | `REWARD_DAYS`, `grant_premium_days` |
| **ÖDÜL ekranı** | Herkese açık: canlı haftalık/aylık liste + geçmiş kazananlar; kart ve sonuç AppBar’dan **ÖDÜL** | `daily_mini_rewards_screen.dart`, `daily_mini_exam_card.dart`, `daily_mini_exam_result_screen.dart` |
| **API** | `GET /daily-mini-exam/period-ranking/?period=weekly\|monthly`, `GET /daily-mini-exam/reward-history/` | `views.py`, `urls.py`, `api_config.dart`, `daily_mini_ranking_service.dart` |
| **Model / migrate** | `DailyMiniRankingCampaign` (singleton), `DailyMiniRankingWinner` | `models.py`, `0043_daily_mini_ranking_rewards.py` |
| **Finalize** | Idempotent; push + `UserMessage`; panelde yalnızca **Haftalık / Aylık** (sınav tipi chip yok; içeride tüm depo anahtarları taranır); CLI `--auto` / `--all-kpss` | `finalize_daily_mini_ranking.py`, `finalize-mini-oduller.bat`, `daily_mini_ranking.html` |
| **Premium Sıralama** | Mock XP kaldırıldı; canlı dönem listesi («X doğru») | `leaderboard_screen.dart`, `leaderboard_service.dart`, `leaderboard_model.dart` |

#### Mobil — Stüdyo hub (Daha fazla)

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Giriş** | Üst bar kare ikon (`Icons.apps_outlined`) → Stüdyo; ink/champagne premium dil | `app_shell_top_bar.dart`, `main_shell.dart` → `home_screen.dart` |
| **Hero** | Marka + «Stüdyo» + kısa vaat + Premium CTA / aktif rozet; geri tuşu | `home_hero_section.dart` |
| **Bölümler** | Çalışma araçları (ücretsiz) · Premium suite (PRO kilit rozeti) · Profil | `home_tools_module_list.dart`, `home_premium_module_list.dart`, `home_module_row.dart`, `home_section_header.dart` |
| **Sadeleştirme** | Bu hub’dan günlük görev / ders ızgarası kaldırıldı (Ana Sayfa / Dersler’de kalır) | `home_screen.dart` |

#### Mobil — soru metni justify + biçim

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Justify** | Soft `\n` tek paragrafta birleşir; `TextAlign.justify` (Android/iOS); `$$` / madde satırları korunur | `exam_stem_view.dart`, `formatted_text.dart` (`prepareExamJustifyText`, `_DocumentText`) |
| **Kalın boşluk** | Harf/`**` bitişikte otomatik boşluk; tighten iç boşluğu dışarı taşır | `math-render.js`, `rich-format.js`, `formatted_text.dart` |
| **III. Selim kırığı** | Aynı Romen tekrarı madde listesi sayılmaz; yalnızca ≥2 farklı Romen | `math-render.js`, `formatted_text.dart` |

#### Mobil — özet kart / favoriler

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Favori özet kart** | Tıklanınca `SummaryCardFace.showViewer()`; konuya gitmez | `favorites_screen.dart`, `topic_summary_swipe_deck.dart` |
| **Konu detayı** | Geniş **Konuyu Öğren** CTA → ayrı çalışma ekranı (`TopicSummaryStudyScreen`); gömülü deste yok | `topic_detail_screen.dart`, `topic_summary_study_screen.dart` |

#### Panel — ödül, markdown, harita fırça

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Mini deneme ödülleri** | Menü **Deneme & sınav**; aç-kapa; manuel **Haftalık/Aylık** finalize (lisans·önlisans·ortaöğretim yok); kazanan tablosu | `/panel/mini-deneme-odulleri/`, `daily_mini_ranking.html`, `base.html` |
| **Çözüm/önizleme markdown** | `**…**` koruması; bölünmüş kalın onarımı; cache `math-render.js?v=8`, `rich-format.js?v=3` | `math-render.js`, `rich-format.js`, `base.html`, `question_form.html` |
| **Akıllı Fırça önizleme** | İl maskesi birleşik canvas + tek `destination-in` (boş önizleme düzeltmesi) | `map-smart-brush.js` |

#### Geliştirici araçları / build

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Canonical path** | `D:\ozel\HEDEFKAMU` bat’ları `D:\HEDEFKAMU`’ye yönlendirir; `GRADLE_USER_HOME=D:\.gradle` | `basla.bat`, `basla-telefon.bat`, `uygulamayi-yukle.bat` |
| **APK yükleme** | L8 hata sonrası clean retry; gereksiz her seferinde full clean yok | `uygulamayi-yukle.bat` |
| **Ödül cron** | Task Scheduler: günde 00:15 `finalize-mini-oduller.bat` (`--auto`) | `finalize-mini-oduller.bat` |

#### Mobil — özet konu kartları (yeni)

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Model** | Konuya bağlı kısa kart: `kind` = `formula` / `tip` / `osym`; başlık + gövde; isteğe bağlı **görsel**; sıralama; yayın bayrağı | `TopicSummaryCard` (`models.py`), migration `0041` + `0042_topicsummarycard_image.py`, `TopicSummaryCardModel` (`content_models.dart`) |
| **API** | `GET /pack/` ve `GET /catalog/` yanıtına `summaryCards` listesi (`imageUrl` dahil); revizyon sinyali kart kaydında | `serializers.py`, `views.py`, `revision.py` |
| **Panel CRUD** | Sol menü **Konu kartı ekle** (`/panel/ozet-kart/`): ders→konu, metin+görsel, sağda telefon önizleme; konu workspace sekmesi aynı stüdyoya yönlenir | `summary_card_studio.html` + `.js`/`.css`, `panel_summary_card_studio`, `base.html`, `topic_workspace.html` |
| **Konu detayı destesi** | Test listesinin üstünde Tinder tarzı deste: kaydır / **Biliyorum** / **Unuttum**; kalp ile favori; görsel varsa kartta | `topic_detail_screen.dart`, `topic_summary_swipe_deck.dart` |
| **İlerleme** | Kullanıcıya özel bilinen / zayıf / favori ID’ler (SharedPreferences scope); oturum değişince yeniden yüklenir | `summary_card_progress_service.dart`, `auth_service.dart`, `main.dart` |
| **Favorilerim** | İki sekme: **Soru Favorileri** · **Özet Kartlar**; özet tarafta filtre **Favoriler** / **Tekrar Et** | `favorites_screen.dart` |
| **İçerik bankası** | Katalog/pack’ten `_summaryCards` yükleme, konu/ID sorguları, disk persist | `content_bank_service.dart` |
| **Admin** | Unfold’da `TopicSummaryCard` kaydı | `admin.py` |

#### Mobil — yanlış defteri ve notlar

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Header / Akıllı Tekrar** | **Akıllı Tekrar** sağ üst pill (büyütülmüş); **Kitaptaki** butonu iki satır (KİTAPTAKİ / YANLIŞLARIM), dar; istatistik alt yazısı konu testlerine göre | `wrong_notebook_header.dart`, `wrong_questions_screen.dart` |
| **Kitaptaki yanlışlarım** | Pembe giriş → ayrı ekran; üstte kompakt premium **SORU EKLE** foto butonu; boş ekran başlığı **Yanlış Sorularını Takip Et!** | `wrong_notebook_manual_screen.dart`, `WrongNotebookAddQuestionAction` |
| **Manuel foto soru** | Kamera/galeri; meta sheet **YANLIŞ SORULARIM**; ders→konu müfredattan zorunlu; not opsiyonel; uygulama özel dizini (galeriye düşmez); durum: Yeni / Tekrar Et / Çözüldü | `manual_question_model.dart`, `manual_question_service.dart`, `wrong_notebook_manual_meta_sheet.dart` |
| **Defter inceleme** | Karta tıklayınca süre ve Soru 1/1 yok; **Çıkış**; işaretli şık; **Not Al** + büyütülmüş ortalı «KAYITLI KALIR»; normal testte «Daha önce» | `quiz_take_note_button.dart`, `quiz_question_note_card.dart`, `quiz_wrong_notebook_banner.dart`, `question_note_service.dart` |
| **Defter kayıtlı toast** | Konu testi + günlük denemede ortada premium toast (~3 sn): «YANLIŞ DEFTERİMDE / KAYITLI»; **Akıllı Tekrar**’da yok (`suppressWrongNotebookHint`) | `quiz_wrong_notebook_banner.dart`, `quiz_screen.dart`, `smart_review_screen.dart` |
| **Balon tetik** | Google + bitmiş konu testi + **defterde ≥1 yanlış**; Günün Denemesi / yarım test tetiklemez | `wrong_notebook_promo_bubble.dart`, `content_bank_service.dart` |
| **Benzer sorular** | Embedding sonucu: kaynak soru ve kök metni ≥%88 benzer kopyalar elenir. Kartta **BENZER** üst kenar ortası rozet | `embeddings.py`, `test_embeddings.py`, `QuestionFetchService`, `wrong_notebook_question_card.dart` |
| **WhatsApp paylaşımı** | Google zorunlu; soru metni gitmez. **1080×1920 (9:16)** hikâye PNG; üst ortada büyük **HEDEF Kamu**; yardım cümlesi. Ücretsiz: günde **1** (+ödüllü reklam); Premium: günde **3**. Capture: `ScreenshotGate` | `wrong_notebook_share_service.dart`, `wrong_notebook_share_card.dart`, `screenshot_gate.dart`, `ad_manager.dart` |

#### Mobil — destek, güvenlik, kota, reklam

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **İletişime Geç** | `mailto` konu + gövde: sürüm, cihaz, OS, üyelik; ekranda e-posta chip yok; Android `queries` + iOS LSApplicationQueriesSchemes | `support_contact_service.dart`, `support_contact_screen.dart`, `AndroidManifest.xml`, `Info.plist` |
| **Ağ güvenliği** | VPN/DNS engeli ücretsizde kilit; Play veya panel Premium süresince geçiş (`network_security_gate`) | `network_security_gate.dart`, `network_security_service.dart` |
| **Günlük test kotası** | Kota dolunca şampanya çerçeveli diyalog | `daily_test_quota_dialog.dart` |
| **Reklamsız kampanya** | 3 ödüllü → 12 saat yalnızca **quiz banner** kapalı; çözüm kilidi / kota / benzer / sınırsız test / offline / konu takibi / pomodoro **açılmaz** | `ad_free_campaign_service.dart`, `ad_manager.dart` |
| **Filigran** | Ücretsiz ve Premium’da açık; haritalı/görselli soruda görsel üstüne de biner | `watermark_widget.dart`, `question_stem_content.dart` |

#### Mobil — soru UI / ÖSYM şık tablosu

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Eşleştirme şıkları** | **2+ sütun** (Olay/Sonuç veya 3+ İnanç/Mağara/Termal): Panel `option-table.js` + CSS (değerler sütun, etiket başlık, dikey çizgi yok). Mobil: `option_column_layout.dart` | `option-table.js`, `option-table.css`, `option_column_layout.dart`, `exam_option_view.dart`, `question-preview.js` |
| **Yapıştırma** | Eşleştirme oku `->` / `\\rightarrow` → `→` | `rich-format.js` |

#### Panel — menü, promosyon, kullanıcılar

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Sol menü** | Gruplar: İçerik · Deneme & sınav (Sınavlar, şablon, paket, **Mini deneme ödülleri**) · Kullanıcı & satış · Kalite · Ayarlar | `base.html` |
| **Promosyon CRUD** | Liste / yeni / düzenle / sil / aktif-pasif (günlük iş Admin’de değil panelde) | `/panel/promosyon/`, `promo_codes.html`, `promo_code_form.html`, `panel_promo_*` |
| **Kullanıcılar** | Toplu sil, misafir filtresi, **Misafirleri temizle**; bir kerelik anonim misafir temizliği | `users.html`, `panel_views.py` |
| **Duyuru şablonu** | Hepsiburada tarzı big-picture önizleme (görsel + başlık + metin); hazır şablon chipleri; FCM görseli korunur; uygulama ön planda da big picture | `announcement_form.html`, `announcement-push-preview.css`/`.js`, `push_notification_service.dart` |

#### Panel — harita editörü (genişletme)

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **İl boya** | ÖSYM bölge boyama; komşu aynı renk birleşir | `map-question-editor.js`, `map_provinces.py` |
| **Akıllı Fırça** | Kalınlıklı serbest stroke; kara maskesi clip; `shape:brush` + width/points; İl boya’dan ayrı | `map-smart-brush.js`, `map_provinces.draw_brush_strokes` |
| **Doğru / ışın / il adı** | İki tıklama doğru; ışın: merkez→adet→hedef iller; il adı etiketi; şehir adları açık/gizli | `map-question-editor.js`, `map_question_renderer.py` |
| **Elips** | Varsayılan kapalı; tıklayarak koy; Romen varsayılan kapalı; tutaçlarla boyut + dönüş; Romen **A− / A+** ile ±2 punto | `map-question-editor.js` |
| **%170 düzenleme** | Tam ekran harita; araç çubuğu altta; Esc / %100 çıkış | `map-question.css` |
| **PNG zemin** | Açık kâğıt zemin (koyu temada Romen okunur) | `map_question_renderer.py` |
| **Mükerrer** | `[HARITA]` ve `(Not: …)` yok sayılır; aynı şıklar + benzer kök | `question_fingerprint.py` |

#### Geliştirici araçları / build

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **uygulamayi-yukle.bat** | Canonical `D:\HEDEFKAMU`; Release APK → uninstall → install → aç; L8 hata sonrası clean retry; JDK/Flutter/adb PATH | `uygulamayi-yukle.bat` |
| **basla / basla-telefon** | ozel kopyadan yönlendirme; `GRADLE_USER_HOME=D:\.gradle`, `PUB_CACHE` proje içi | `basla.bat`, `basla-telefon.bat` |
| **Ödül finalize cron** | `finalize_daily_mini_ranking --auto`; bat + Task Scheduler örneği | `finalize-mini-oduller.bat`, `finalize_daily_mini_ranking.py` |
| **Play paket boyutu** | Release ABI: `armeabi-v7a` + `arm64-v8a`; native lib sıkıştırma; hedef ≤80 MB | `android/app/build.gradle.kts` |
| **Anayasa kuralı** | Dosya ayrımı (harita / option-table / önizleme ayrı dosya); büyük dosyaya yalnızca bağlama | `.cursor/rules/kpss-akademi.mdc` |
| **Testler** | Hata bildirimi, embedding benzerlik filtresi, anonim auth, watermark, kampanya, exam text parity | `test_error_report.py`, `test_embeddings.py`, `test_anonymous_auth.py`, `*_test.dart` |

### 19 Ağustos 2026 — işlenen davranış (önceki commit)

| Alan | Ne değişti | Dosyalar |
|---|---|---|
| **Açılış splash** | Ortada 657 + defne **parlak altın**; daire tam ekran Y ortası; üstte HEDEF KAMU, altta «Ataman Gerçekleşiyor» + kayan çizgi (3,5 sn) | `boot_splash_screen.dart` |
| **Yanlış defteri balonu** | Yalnızca **Google hesabı** + **en az 1 konu testi bitmiş** + **defterde en az 1 yanlış** varken; panel açıkken. Günün Denemesi / yarım test tetiklemez. Sol yaslı; YANLIŞ→DEFTERİM 3D; teal çerçeve | `wrong_notebook_promo_bubble.dart`, `content_bank_service.dart` |
| **Yanlış defteri UI** | Header alt başlığı («X soru · Y ders») yok; en çok yanlış derste kırmızı adet rozeti; kart: konu chip sol üst, kalp+sil sağ üst; metin «İstediğiniz zaman silebilirsiniz»; karttan onaylı silme; silince alt SnackBar yok, ortada şampanya çerçeveli kutu (~3 sn): onay ikonu, «Defterden kaldırıldı», soru önizlemesi | `wrong_questions_screen.dart`, `wrong_notebook_*` |
| **Defter soru notu** | Karta tıklayınca süre ve Soru 1/1 yok; **Çıkış** (onaysız deftere dönüş); testte işaretlediği şık işaretli; normal testte aynı soru işaretsiz + mavi «Daha önce». Sağda seviye; solda **Not Al** + «KAYITLI KALIR». Bitmiş testte yanlış kalan sorular sonradan doğru cevaplansa istatistik güncellenmez | `quiz_take_note_button.dart`, `quiz_question_note_card.dart`, `quiz_wrong_notebook_banner.dart`, `question_note_service.dart`, `content_bank_service.dart` |
| **Defter kayıtlı toast** | Ortada premium toast, 3 sn; konu testleri + günlük deneme; **Akıllı Tekrar**’da bastırılır | `quiz_wrong_notebook_banner.dart`, `quiz_screen.dart`, `smart_review_screen.dart` |
| **BENZER upsell** | Başlık **BENZER SORULAR**; üstte 👯; alt metin «Yanlışlarını daha iyi analiz et» | `pro_upsell_sheet.dart` |
| **Misafir yanlış defteri** | Yalnızca **soru metni** hafif buzlu; kalp, sil, BENZER açık. Karta dokununca Google ister; **bağlanınca defter Google hesabına aktarılır** (soru listesi, işaretli şıklar, notlar, çizimler, manuel foto), buz kalkar, soru açılır. `relayUserScopedServices(previousUserId)` + `local_guest_id` yedek eşleme | `wrong_notebook_guest_frost.dart`, `auth_service.dart`, `content_bank_service.dart`, `manual_question_service.dart`, `question_note_service.dart`, `wrong_notebook_drawing_service.dart`, `wrong_questions_screen.dart` |
| **Puan Hesaplama** | Gelişim’den kaldırıldı. Deneme sekmesi AppBar’da dar, ortalanmış kompakt **PUAN HESAPLAMA** (eski «Deneme» + `+` yok; FAB «Deneme Ekle» durur) | `analytics_hub_screen.dart`, `statistics_screen.dart`, `puan_hesaplama_button.dart` |
| **Puan ekranı etiketleri** | **GY-Net** / **GK-Net** (üstte puan; net ayrı) | `puan_hesaplama_screen.dart` |
| **Quiz sonuç** | Konu adı üstte; motive satır; +XP ve seri chip; soru başı ortalama süre **NET** kutusunun üstünde | `quiz_screen.dart`, `shareable_result_card.dart`, `gamification_service.dart` |
| **Günün denemesi sıralama** | «BUGÜNKÜ SIRALAMAN» yalnız en az bir işaretlenmiş cevap varsa; boş gönderim kilitlemez | `daily_mini_exam_service.dart`, `views.py`, `daily_mini_exam.py` |
| **EN BAŞARILILAR** | Liste kayar; altta sabit **Bu ayın yanlış çözümleri** (eski altın tasarım, küçük) + **Devam Et** (küçük) | `daily_mini_exam_result_screen.dart` |
| **Google giriş** | «credential-already-in-use» olunca mevcut credential ile giriş; beklemede **Giriş Yapılıyor…** overlay | `auth_service.dart`, `login_screen.dart` |
| **Play Store paket boyutu** | Release yalnızca `armeabi-v7a` + `arm64-v8a` (x86_64 yok); native lib sıkıştırılır; hedef **≤80 MB** | `android/app/build.gradle.kts` |

---

## İçindekiler

1. [Mobil uygulama](#mobil-uygulama)
2. [İçerik paneli (`/panel/`)](#i̇çerik-paneli-panel) — haritalar ayrı: [Harita soruları](#harita-soruları)
3. [Unfold admin (`/admin/`)](#unfold-admin-admin)
4. [Backend API (`/api/v1/`)](#backend-api-apiv1)
5. [Erişim matrisi](#erişim-matrisi) — [Google](#-google-giriş-gerektiren-özellikler) · [Reklam](#-ödüllü-reklam-izleme-gerektiren-özellikler) · [Premium](#-premium-gerektiren-özellikler)
6. [Veri modelleri (özet)](#veri-modelleri-özet)
7. [Bilinen sınırlamalar](#bilinen-sınırlamalar)
8. [Türkiye Geneli (TG) denemeleri](#türkiye-geneli-tg-denemeleri)

---

## Mobil uygulama

### Uygulama kabuğu ve gezinme

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Ana sekme kabuğu** | Alt menü: Ana Sayfa, Dersler, Gelişim, Deneme; üstte profil | `lib/screens/main_shell.dart` |
| **Yanlış defteri balonu** | Yalnızca Google + en az 1 bitmiş konu testi + defterde yanlış varken; koyu teal zemin; **YANLIŞ** → **DEFTERİM** 3D; mavi-yeşil çerçeve; sağ üst X; sola yaslı (`left: -16`) | `lib/widgets/wrong_notebook_promo_bubble.dart` |
| **Stüdyo (Daha fazla)** | Pro Üyelik solundaki kare ikon → ink/champagne **Stüdyo** hub: çalışma araçları + Premium suite + Profil; görev/ders ızgarası yok | `home_screen.dart`, `home_hero_section.dart`, `home_module_row.dart`, `app_shell_top_bar.dart` |
| **Giriş yönlendirme** | Sınav seçilmemişse hemen onboarding → seçimden sonra «Ataman Gerçekleşiyor» (**3,5 sn**) → ana kabuk; oturum hatasında yeniden deneme | `lib/navigation/app_entry.dart`, `lib/main.dart`, `lib/screens/exam_track_onboarding_screen.dart` |
| **Derin link / bildirim** | Push veya yerel bildirimden duyuru, mesaj, paywall yönlendirmesi | `lib/navigation/app_navigator.dart` |
| **Hızlı açılış** | İlk açılış: sınav tipi seçimi hemen. Seçimden sonra veya kayıtlı kullanıcıda splash: **parlak altın 657** daire (tam ekran ortası); üstte HEDEF KAMU, altta Ataman + kayan çizgi (**3,5 sn**) | `lib/services/boot_store.dart`, `lib/widgets/boot_splash_screen.dart`, `lib/main.dart` |
| **Dikey ekran kilidi** | Tüm cihazlarda yalnızca portrait | `lib/services/orientation_policy.dart`, `android/.../AndroidManifest.xml` |
| **Web önizleme çerçevesi** | Masaüstü web’de telefon boyutunda kart | `lib/main.dart` |

---

### Onboarding ve sınav hedefi

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Sınav takibi seçimi** | İlk açılışta hedef sınav (KPSS Lisans/Ön Lisans/Ortaöğretim, ALES, DGS vb.) | `lib/screens/exam_track_onboarding_screen.dart`, `lib/services/kpss_preference_service.dart` |
| **Geri sayım paneli** | Seçilen sınav adı, tarihi, kalan süre; hedef **sınav günü 10:00**; dokunarak değiştirme | `lib/widgets/exam_focus_panel.dart`, `lib/widgets/countdown_widget.dart` |
| **Sınav kataloğu senkronu** | API’den aktif sınav türleri; yerel önbellek yedek | `lib/services/exam_catalog_service.dart` |
| **KPSS içerik tipi** | Lisans / Ön Lisans / Ortaöğretim — müfredat ve soru bankası filtresi | `lib/widgets/kpss_type_preference_picker.dart` |

---

### Çalışma merkezi ve müfredat

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Ana Sayfa sekmesi** | Günün mini denemesi, günlük görevler, tasarruf banner’ı, sınav odağı | `lib/screens/study_hub_screen.dart` | Ücretsiz |
| **Dersler başlığı** | «Dersler · N soru» satırının sağında dikdörtgen **Notlarım** (kırık beyaz zemin, siyah yazı) | `lib/screens/study_hub_screen.dart` | Ücretsiz |
| **Dersler sekmesi** | 2 sütunlu ders ızgarası (daha alçak kartlar); kartta soru sayısı + ilerleme; katalog yenileme | `lib/screens/study_hub_screen.dart` | Ücretsiz |
| **Özel Testler** | Dersler altında 3D `ÖZEL TESTLER`; kategoriler: **HARİTALARLA COĞRAFYA**, **TARİH KRONOLOJİ**, **PADİŞAHLAR VE ANTLAŞMALAR**, **ÇELDİRİCİSİ GÜÇLÜ**; bayrak + keyword ile 20’lik sanal testler | `special_tests_entry.dart`, `special_tests_screen.dart`, `special_map_geography_screen.dart`, `backend/content/special_tests.py`, `special_question_tags.py` | Ücretsiz; ilgili ders günlük kotası |
| **Gelişim sekmesi** | Genel doğruluk (yalnızca **konu testleri**; günün mini denemesi 20 sorusu sayılmaz), yatay kaydırmalı ders kartları + nokta göstergesi, çalışma kasası; **Puan Hesaplama bu sekmede yok** | `lib/screens/analytics_hub_screen.dart`, `lib/services/performance_summary_service.dart` | Ücretsiz |
| **Konu listesi** | Konu bazında çözülen/toplam ilerleme | `study_hub_screen.dart` | Ücretsiz |
| **Konu detayı** | İstatistik, özet kart destesi, test listesi; bitirilen testte **BAŞLA** yanında yeşil ✓ | `topic_detail_screen.dart`, `topic_summary_swipe_deck.dart` | Günlük kota |
| **Ders okuyucu** | Konuya özel bilgi kartları (markdown / zengin metin) | `lib/screens/lesson_reader_screen.dart` | Ücretsiz |
| **Kaldığın yerden devam** | Yarım test kartı SharedPreferences’ta durur; uygulama kapanınca soru gövdesi RAM’de olmasa da kart kalır, devamda sorular API’den çekilir | `continue_study_card.dart`, `last_study_session_service.dart` | Ücretsiz |
| **İçerik senkronu** | Yayınlanmış paket sürümü değişince indirme | `lib/services/content_sync_service.dart`, `lib/services/content_bank_service.dart` | Ağ gerekli |
| **Müfredat ağacı** | Statik ders/konu yapısı + API katalog eşlemesi | `lib/data/kpss_curriculum.dart` | Ücretsiz |

**Günlük test kotası (ücretsiz):** **Ders başına** günde **1 test** (global değil; snackbar «Bu derste…»). Sunucu `DailySubjectFreeUsage` + `GET/POST /api/v1/daily-quota/?subject=`. **Misafir cihaz yanığı** (misafir→Google çift hak yok). **Google hesap yanığı** telefon↔tablet senkron; **farklı Google hesapları ayrı hak**. Reklamla **+1**. Premium sınırsız.

| **Deneme paketleri vitrini** | Dersler sekmesi altında yatay paket kartları; yalnızca panelde **aktif** paketler; Play SKU ile kilit/açma; **Google girişi zorunlu** | `lib/widgets/exam_pack_showcase.dart`, `lib/services/exam_pack_service.dart` | IAP + Google |
| **Deneme paketi detayı** | Alt deneme listesi → quiz; sorular 1000+ cevaplı orta zorluk; oturumda daha önce çözülen en fazla **%20**; bitince HEDEF KAMU kaydı | `lib/screens/exam_pack_detail_screen.dart`, `lib/services/exam_pack_analytics_bridge.dart`, `backend/content/exam_pack_personalize.py` | IAP + Google |

---

### Quiz ve soru deneyimi

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Quiz ekranı** | Test çözme, cevap seçimi, çözüm gösterme, oturum kaydı; AppBar: **Test sola** (16pt) + **Soru X/Y** ortada (ÖSYM ekseni); şeritte yeşil **Başarı**; **pinch-to-zoom** + günlük ortada zoom ipucu; kalem açıkken zoom kilit | `quiz_screen.dart`, `quiz_zoom_viewport.dart`, `quiz_zoom_daily_hint.dart`, `brand_mark.dart`, `question_view_service.dart` | Ücretsiz; reklamlı |
| **Soru kökü render** | Zengin metin, LaTeX (`flutter_math_fork`), görsel, SVG şekil; soft satırlar birleşir; **TextAlign.justify** (Android/iOS) | `question_stem_content.dart`, `exam_stem_view.dart`, `formatted_text.dart` (`prepareExamJustifyText`) | Ücretsiz |
| **ÖSYM sordu rozeti** | Resmî kaynaklı sorularda rozet; üst şeritte **ekran ortası** (Stack); yer değiştirilmez | `lib/widgets/osym_badge.dart`, `lib/models/question_model.dart`, `backend/content/test_grouping.py` | Ücretsiz |
| **Başarı oranı** | Şerit sağ üst: `Başarı: %49` veya veri yoksa `Başarı: —`; `correctRate` / canlı şık yüzdesi; yeşil `#34D399` | `quiz_screen.dart`, `QuizHeaderStrip.successLabel` | Ücretsiz |
| **Görüntüleme sayacı** | Benzersiz kullanıcı; soru açılınca (cevap/boş fark etmez); `POST …/view/` + şerit «N kişi gördü» | `question_view_service.dart`, `Question.view_count` / `QuestionView`, `quiz_screen.dart` | Oturum ile artar |
| **Yakınlaştırma** | İki parmak / çift dokunuş; 1×–4×; kalem açıkken kilitlenir | `quiz_zoom_viewport.dart`, `quiz_screen.dart` | Ücretsiz |
| **Çizim katmanı** | Kalem / yeşil fosfor / silgi; araç çubuğu **sürüklenebilir**; zoom ile exclusive (kalem↔zoom) | `quiz_drawing_overlay.dart`, `quiz_screen.dart` | Ücretsiz |
| **Favoriler** | Soruyu favorilere ekleme (quiz içi kalp); **Favorilerim** sekmeli: Soru Favorileri + Özet Kartlar (Favori / Tekrar Et) | `favorite_heart_button.dart`, `favorites_service.dart`, `summary_card_progress_service.dart`, `favorites_screen.dart` | Ücretsiz |
| **Soru puanlama** | 1–5 yıldız; oturum varsa sunucuya senkron | `lib/widgets/question_rating_bar.dart`, `lib/services/question_rating_service.dart` | Oturum önerilir |
| **Hata bildirimi** | Yanlış kök/şık/çözüm bildirimi; **Google girişi zorunlu**; ücretsiz **5**, Premium **3** konu testi bitirme; günde 1 bildirim | `lib/widgets/question_error_report_button.dart`, `lib/services/question_error_report_service.dart` | Google + 5 / Premium + 3 |
| **Çözüm kilidi** | Test başına ilk **4** tam/kısa çözüm ücretsiz; 5.+ her biri ödüllü reklam veya Premium; sıra bağımsız | `quiz_screen.dart`, `ad_manager.dart`, `ad_constants.dart` (`freeSolutionsPerTest`) | 4 ücretsiz / reklam / Premium |
| **Ses ve titreşim** | Doğru/yanlış geri bildirimi | `lib/services/answer_feedback_service.dart` | Ücretsiz |
| **Sonuç paylaşımı** | Test sonucunu görsel kart olarak paylaşma; sonuç panelinde konu adı en üstte, motive mesajı, kazandığı XP ve seri; soru başı ortalama süre NET kutusunun üstünde | `lib/widgets/shareable_result_card.dart`, `lib/screens/quiz_screen.dart` | Ücretsiz |
| **Filigran** | Marka filigranı ücretsiz ve Premium’da; haritalı/görselli soruda metnin yanında görselin üstüne de biner | `lib/widgets/watermark_widget.dart`, `question_stem_content.dart` | Tüm planlar |
| **Quiz banner reklamı** | Test sırasında alt banner; test ortasında interstitial yok | `lib/services/ad_manager.dart` | Premium veya 12s kampanya |
| **Pro Üyelik üst bar CTA** | Kompakt pill (maskot yok); Ana/Dersler/Deneme sekmelerinde | `lib/widgets/premium_header_button.dart`, `lib/widgets/app_shell_top_bar.dart` | Ücretsiz kullanıcı |
| **Gelişim · ODAK CTA** | Gelişim sekmesi sağ üst: **mavi↔mor** gradient **ODAK** pill → `FocusModeScreen` | `app_shell_top_bar.dart`, `main_shell.dart` | Ücretsiz |

**Biçimlendirme (soru metni):** Panelde `**kalın**`, `__altı__`, `{green}`/`{red}`/`{blue}`, `$...$` / `$$...$$` LaTeX. Mobilde `FormattedText` + `preserveLineBreaks` ile satır kırılımları korunur; display math (`\begin{array}`, `\frac` vb.) korunur. `\hline` çıkarma çizgisi metin renginde `\rule` satırına dönüştürülür; soru kökünde metin ve formül aynı punto kullanır.

**ÖSYM yazı standartları (`lib/theme/exam_typography.dart`):**

| Alan | ÖSYM | Uygulama |
|---|---|---|
| Soru kökü, şık, çözüm | Times New Roman | Google Fonts **Tinos** (mobil yedek); şık **15pt**, çözüm **15pt** |
| Formül / denklem | Cambria Math (italik) | KaTeX / flutter_math glifleri + italik math stili |
| Harita-şema harfi | Arial | `ExamTypography.sansLabel` |

Panel önizlemesi CSS: `--exam-serif`, `--exam-math`, `--exam-sans` (`panel.css`). Şık metni **sola hizalı** (A–E tutarlı). Yalnızca `$…$` içeren şıklar daha büyük punto; uzunluk eşiği ile ortalama **yok**. **Tablo sorusu** panelde açık işaretlenir (`option_table`: `none` | `dual` | `triple`); şık metni `X — Y` / pipe / etiketli hücre. Başlık: `<!--optcols:…-->` veya 2 sütunda **Olay / Sonuç**. Otomatik tire algısı **yok** — yalnızca bayraklı sorularda sütun UI (`option-table.js`, `option_column_layout.dart`, `exam_option_view.dart`).

---

### Günlük görevler ve mini deneme

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Günlük görev merkezi** | Ders bazlı günlük ilerleme çubukları (Türkçe, Mat, Tarih, Coğrafya, Vatandaşlık) | `lib/widgets/daily_mission_center.dart` | Ücretsiz |
| **Günün mini denemesi** | 20 soru; CTA «Denemeye Başla / Sıralamanı Gör» + 657 logo daireyi doldurur; kürsü PNG paylaşımı (ortada soluk Hedef Kamu); **Heyecan Dorukta!** → sayaç 4’te **İŞTE SIRALAMAN** → **BUGÜNKÜ SIRALAMAN** (en az 1 cevap); boş gönderim sıralamaya girmez; 00:00–06:00 dünün liderleri; demo seed kürsüde yok; **EN BAŞARILILAR** altta sabit **Bu ayın yanlış çözümleri** + **Devam Et** | `lib/widgets/daily_mini_exam/`, `lib/screens/quiz_screen.dart`, `lib/screens/daily_mini_exam_result_screen.dart`, `lib/services/daily_mini_exam_service.dart`, `backend/content/views.py`, `backend/content/daily_mini_exam.py` | Ücretsiz (misafir: ilk gün) |
| **Haftalık/aylık ÖDÜL sıralaması** | Toplam doğru + toplam süre (eşitlikte daha kısa süre üstte); 1.→3 gün, 2.→2 gün, 3.→1 gün Premium (haftalık ve aylık); **ÖDÜL** ekranı herkese açık; panel ayar + manuel finalize; otomatik: `finalize_daily_mini_ranking --auto` / `finalize-mini-oduller.bat` (günde 1, idempotent) | `daily_mini_rewards_screen.dart`, `daily_mini_ranking_service.dart`, `daily_mini_ranking.py`, `finalize_daily_mini_ranking.py`, `finalize-mini-oduller.bat`, `GET …/period-ranking/`, `GET …/reward-history/` | Ücretsiz |
| **Deneme paketleri vitrini** | Dersler sekmesi **en altında**; yumuşak yatay kaydırma; ortalanmış başlık | `lib/widgets/exam_pack_showcase.dart`, `lib/services/exam_pack_service.dart`, `GET /api/v1/exam-packs/` | Ücretsiz vitrin |
| **Mini deneme PDF upsell** | Sonuç sonrası Premium yönlendirmesi (aylık yanlış varsa) | `daily_mini_exam_result_screen.dart` | Upsell |
| **Tasarruf içgörüsü** | Ücretsiz testlerin tahmini TL değeri; 20 test kilometre taşı | `lib/widgets/savings_insight_banner.dart`, `lib/services/user_savings_insight_service.dart` | Ücretsiz |

---

### Akıllı tekrar ve yanlış defteri

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Akıllı tekrar** | Ders filtresi; set yanlış defteri + %60 altı konular; «AKILLI TEKRARI BAŞLAT» → `PremiumGate.requirePremium` (PRO rozeti + kilit ikonu); ekranı görmek ücretsiz, **oturumu başlatmak Premium** | `lib/screens/smart_review_screen.dart`, `lib/services/smart_review_service.dart`, `premium_gate.dart` | **Premium** (başlat) |
| **Yanlış defteri** | Konu testlerinden yanlışlar; kullanıcı başına yerel; karttan kaldır; inceleme (**Çıkış**, **testte işaretlenen yanlış şık** kırmızı / doğru yeşil, **Not Al**). **Tüm yanlışları çöz** quiz başlığı boş (AppBar’da YANLIŞLARIM yok). Normal testte «Daha önce» toast. **Akıllı Tekrar** pill (başlat Premium). **Kitaptaki Yanlışlarım:** manuel foto; **1. foto ücretsiz**, **2.+** Pro değilse ödüllü reklam; **kalem/annotate ücretsiz**. Misafir: metin buzlu → Google’da tam aktarım (`relayUserScopedServices`) | `wrong_questions_screen.dart`, `wrong_notebook_manual_screen.dart`, `content_bank_service.dart`, `auth_service.dart`, `wrong_notebook/*`, `quiz_wrong_notebook_banner.dart` | Liste/annotate **ücretsiz**; benzer **Premium**; ekstra foto **reklam veya Premium** |
| **Benzer sorular** | Embedding tabanlı benzer set; kaynak + %88+ aynı kök hariç; ücretsizde `ProUpsellSheet` | `wrong_questions_screen.dart`, `pro_upsell_sheet.dart`, `embeddings.py` | **Premium** |
| **Boş kasa CTA** | Yanlış yokken 3 adımlı boş durum; şampanya etiket «Yanlış defteriyle deneme oluşturabilirsin»; ana CTA «Derslerden test çöz» | `lib/widgets/wrong_notebook/wrong_notebook_empty_state.dart` | Ücretsiz |

---

### Gelişim ve analitik

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Gelişim sekmesi** | Genel doğruluk (yalnızca konu testleri; mini deneme sayılmaz), yatay kaydırmalı ders kartları + nokta göstergesi, çalışma kasası; **Puan Hesaplama yok**; üst barda **ODAK · Pomodoro** CTA | `lib/screens/analytics_hub_screen.dart`, `lib/services/performance_summary_service.dart`, `app_shell_top_bar.dart` | Ücretsiz |
| **Ders analitiği** | Tek ders için konu/test geçmişi | `lib/screens/subject_analytics_detail_screen.dart` | Ücretsiz |
| **Çalışma kasası** | Yanlış / Favoriler / Notlar kısayolları | `lib/widgets/analytics_study_vault.dart` | Ücretsiz |
| **Favorilerim** | Soru favorileri + özet kartlar (Favori / Tekrar Et); özet karta tıklanınca tam ekran kart görüntüleyici; soru orijinal test bağlamında açılır | `favorites_screen.dart`, `topic_summary_swipe_deck.dart` (`SummaryCardFace.showViewer`), `summary_card_progress_service.dart` | Ücretsiz |
| **Notlarım** | Ders etiketli çalışma notları (CRUD) | `lib/screens/notes_screen.dart`, `lib/services/notes_service.dart` | Ücretsiz |
| **Hesap bağlama kartı** | Google bağlamadan önce uyarı | `lib/widgets/account_link_card.dart` | Ücretsiz |

---

### Deneme analizi

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Deneme sekmesi** | AppBar’da **PUAN HESAPLAMA**; FAB ile deneme ekleme; **TG Denemelerim** (Aktif/Geçmiş) | `statistics_screen.dart`, `tg_exams_section.dart`, `puan_hesaplama_button.dart` | **Ücretsiz** |
| **Stüdyo · Deneme Analizi** | Aynı `StatisticsScreen`; `onNavigate` (PremiumGate yok) | `home_tools_module_list.dart` | **Ücretsiz** |
| **Puan Hesaplama** | GY/GK net ve puan; etiketler **GY-Net** / **GK-Net** | `lib/screens/puan_hesaplama_screen.dart` | Ücretsiz |
| **Genel bakış** | Haftalık özet, net gelişim grafiği, GK/GY ayrımı | `lib/widgets/statistics_overview_tab.dart`, `lib/widgets/net_development_chart.dart` | Ücretsiz |
| **Yayınevleri** | Yayınevine göre performans karşılaştırma | `lib/widgets/statistics_publishers_tab.dart` | Ücretsiz |
| **Denemeler listesi** | Manuel deneme ekleme / silme | `lib/widgets/statistics_exams_tab.dart` | Ücretsiz |
| **Deneme ekleme** | GK/GY ders bazlı doğru/yanlış/boş → net hesabı | `lib/screens/premium/add_exam_sheet.dart`, `lib/services/practice_exam_service.dart` | Ücretsiz |
| **Haftalık özet bildirimi** | Yeni deneme eklenince yerel bildirim yenileme | `lib/services/notification_service.dart` | Ücretsiz (deneme ekleyince) |

---

### Premium modüller

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Premium paywall** | Aylık/yıllık Google Play abonelik, özellik listesi, promosyon kodu | `lib/screens/premium/premium_paywall_screen.dart`, `lib/services/play_billing_service.dart` | Satın alma |
| **Promosyon kodu** | Backend’den Premium süresi; misafir kullanamaz; kod en fazla 32 karakter; 5/dk | `lib/services/promo_code_service.dart` | Google hesabı |
| **Konu takibi** | Müfredat maddelerini işaretleme, ilerleme yüzdesi | `lib/screens/premium/topic_tracking_screen.dart`, `lib/services/topic_progress_service.dart` | Premium |
| **Görev yönetimi** | Haftalık görevler, öncelik, tamamlama/silme | `lib/screens/premium/task_management_screen.dart`, `lib/services/task_service.dart` | Premium |
| **Odak · Pomodoro** | Neon UI; süre **20/40/60 dk** (80 yok); ortam **Dalga** / **Kafe** MP3 — Deep Work loop/sürdürme; ambient↔Deep Work exclusive; **Deep Work Music**; tam ekranda **DERS ÇALIŞIYORUM** + bugünkü süre + kullanıcı adı (arkada soluk filigran) + premium kronometre + **aktif süre chip’i** (sayacın altında); Sıfırla; XP | `focus_mode_screen.dart`, `pomodoro_service.dart`, `pomodoro_session_model.dart`, `ambient_wave.mp3`, `ambient_cafe.mp3`, `deep_work_music.mp3` | **Ücretsiz** |
| **Bulut senkron** | Google/Apple senkron arayüzü (**mock**) | `lib/screens/premium/cloud_sync_screen.dart`, `lib/services/cloud_sync_service.dart` | Premium |
| **Offline paket** | Tam pack indirme; istemci yıllık Play + Google oturumu; sunucu Bearer + `is_yearly_premium`; `POST /premium/sync/` | `offline_pack_screen.dart`, `offline_pack_service.dart`, `content_sync_service.dart`, `premium_sync_service.dart` | **Yalnızca yıllık Premium** (`canUseOfflinePack`) |
| **Sıralama** | Haftalık/aylık **toplam doğru** (mini deneme dönem API, canlı); PremiumGate | `leaderboard_screen.dart`, `leaderboard_service.dart`, `daily_mini_ranking_service.dart` | Premium |
| **Akıllı Tekrar (başlat)** | Stüdyo / yanlış defteri girişinden ekran açık; oturum başlatma kapılı | `smart_review_screen.dart` | Premium |
| **Premium kapısı** | Paywall’a yönlendirme yardımcısı | `lib/widgets/premium_gate.dart` | — |
| **Benzer sorular** | Yanlış defterinden embedding benzeri | `wrong_questions_screen.dart` | Premium |
| **Sınırsız test** | Günlük ders kotası + özel test (harita) kotası kalkar | `content_bank_service.dart`, `topic_detail_screen.dart`, `special_map_geography_screen.dart` | Premium |

**Abonelik ürünleri:** `kpss_premium_monthly`, `kpss_premium_yearly` — `lib/services/iap_constants.dart`

---

### Oyunlaştırma ve sosyal

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **XP ve seviye** | Doğru/yanlış, test bonusu, çalışma dakikasından XP | `lib/services/gamification_service.dart` |
| **Günlük seri (streak)** | Ardışık çalışma günü | `gamification_service.dart` |
| **Rozetler** | Seviye halkası, günlük hedef kısayolları, sıradaki rozet, ilerleme çubuğu; dokununca nasıl kazanılır | `lib/screens/premium/badges_screen.dart` |
| **Profil gamification kartı** | XP, seviye, seri | `lib/screens/profile_screen.dart` |
| **Instagram bağlantısı** | Harici sosyal link | `lib/widgets/instagram_link_button.dart`, `lib/services/social_links_service.dart` |
| **Mağaza değerlendirme** | Play Store inceleme istemi (Premium kullanıcılar) | `lib/services/store_rating_service.dart`, `lib/widgets/store_rating_card.dart` |

---

### Profil ve ayarlar

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Profil ekranı** | Avatar, ad, XP/streak/PREMIUM chip’leri; hero üst kenarında **NEDEN BİZ** (5 avantaj / 3 kitap dezavantajı); premium değilse “Premium’a Geç” pill; Rozetler; Mesajlar/Duyurular; “Değerlendir”; modül listesi; **Görünüm** varsayılan kapalı | `profile_screen.dart`, `why_us_comparison_card.dart` |
| **Premium üyelik bilgisi** | Hero’daki PREMIUM chip köşesindeki bilgi ikonu → veriliş/bitiş tarihi bottom sheet | `profile_screen.dart` |
| **Google hesap bağlama** | Anonim → kalıcı Google hesabı | `lib/widgets/account_link_card.dart`, `lib/services/auth_service.dart` |
| **Görünen ad düzenleme** | Bağlı hesap gerekir | `profile_screen.dart` |
| **Tema** | Açık / koyu / sistem | `lib/widgets/theme_preference_picker.dart`, `lib/services/theme_preference_service.dart` |
| **Sınav hedefi değiştirme** | Geri sayım hedefini yeniden seçme | `lib/widgets/exam_track_picker_sheet.dart` |
| **Bildirim ayarları** | Sabah/akşam/haftalık aç-kapa (duyuru ve tasarruf sabit açık) | `lib/widgets/notification_settings_section.dart`, `lib/services/notification_preference_service.dart` |
| **Duyurular** | Admin yayınları; **Okundu** yalnızca kullanıcı açınca. **İlk kurulumdan önceki** duyurular profil listesinde yok | `lib/screens/announcements_screen.dart`, `lib/services/announcement_service.dart` |
| **Mesajlarım** | Doğrudan admin mesajları; **kurulumdan önceki** mesajlar profilde yok | `lib/screens/user_messages_screen.dart`, `lib/services/user_message_service.dart` |
| **Destek ve İletişim** | Bilgi satırları (buton değil); soru hata **UYARI** amber; başlık ortalı; **İletişime Geç** → mailto (ekranda e-posta yok) | `lib/screens/support_contact_screen.dart`, `lib/services/support_contact_service.dart` |
| **Çıkış** | Oturumu kapat (misafir değilse) | `profile_screen.dart` |

---

### Diğer araçlar

| Özellik | Açıklama | Dosyalar | Not |
|---|---|---|---|
| **Mikro öğrenme** | Kısa ders + mini quiz | `lib/screens/study_and_solve_screen.dart` | **Demo içerik** |
| **Özel Notlarım** | Stüdyo araç satırı; hikaye tarzı kaydırmalı kişisel not kartları (PageView + scale) | `current_info_screen.dart`, `home_tools_module_list.dart`, `database_service.dart` | **Yerel mock** |
| **Reklamsız kampanya** | 3 ödüllü reklam → 12 saat **quiz banner** yok; çözüm kilidi, günlük kota, benzer soru, sınırsız test, offline, konu takibi, pomodoro **açılmaz** | `lib/widgets/ad_free_campaign_card.dart`, `lib/services/ad_free_campaign_service.dart`, `lib/services/ad_manager.dart` | Ödüllü reklam |

---

### Kimlik doğrulama ve güvenlik

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Yerel misafir oturumu** | Çevrimdışı öncelikli yer tutucu kullanıcı | `lib/services/auth_service.dart` |
| **Anonim backend oturumu** | Firebase anonim + Django `AppUser` token | `auth_service.dart`, `backend/content/auth.py` |
| **Google giriş / bağlama** | ID token → `POST /api/v1/auth/google/`; hesap zaten bağlıysa `signInWithCredential`; beklemede **Giriş Yapılıyor…** | `auth_service.dart`, `login_screen.dart` |
| **Profil senkronu** | `GET/PATCH /api/v1/me/` — Premium bayrağı, görünen ad (haftada en fazla 1 değişiklik); `premiumProductId` / `isYearlyPremium` | `backend/content/views.py`, `auth.py` |
| **Premium sync** | Play ürün id + süre → `POST /api/v1/premium/sync/` (Bearer); offline pack sunucu kapısı | `premium_sync_service.dart`, `play_billing_service.dart`, `PremiumSyncView` |
| **Ağ güvenliği engeli** | VPN/DNS/reklam engelleyici tespiti → ücretsiz kullanıcıda kilit; Play veya panel Premium süresince serbest | `lib/services/network_security_service.dart`, `lib/services/network_security_gate.dart`, `lib/screens/security_warning_modal.dart` |
| **Ekran görüntüsü yasağı** | Android `FLAG_SECURE` (release; debug/QA allowlist hariç). Paylaşım yakalama: `ScreenshotGate` geçici açar. iOS ekran kaydında siyah örtü. Yanlış defteri paylaşımı: ücretsiz **1/gün** (+reklam), Premium **3/gün**, filigranlı PNG. Quiz banner: panel `bannerAdsEnabled` | `MainActivity.kt`, `AppDelegate.swift`, `screenshot_gate.dart`, `wrong_notebook_share_service.dart`, `ad_manager.dart`, `app_config_service.dart` |
| **Pack indirme güvenliği** | Tam pack **Bearer + yıllık premium**; katalog hafif meta açık kalabilir; at-rest şifreleme yok (SQLite düz JSON) — DRM değil, scrape engeli | `ContentPackView`, `content_sync_service.dart` |

---

### Reklam ve gelir modeli (mobil)

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **AdManager** | Quiz banner; geçiş interstitial; kampanya yalnızca banner kapatır | `lib/services/ad_manager.dart`, `lib/services/ad_constants.dart` |
| **AdService** | UI katmanının tek giriş noktası (doğrudan AdMob widget’ı yok) | `lib/services/ad_service.dart` |
| **Ödüllü reklam türleri** | `campaign` (12s banner’sız), `solutionUnlock` (testte 5.+ çözüm), `dailyTestBonus`, `wrongNotebookShare` (ücretsiz kota) | `ad_service.dart`, `ad_constants.dart` |
| **Play Billing** | Abonelik, geri yükleme, Premium önbellek | `lib/services/play_billing_service.dart` |
| **PremiumService** | Play Billing **veya** sunucu `isPremium` — tek doğruluk kaynağı | `lib/services/premium_service.dart` |

---

### Bildirimler

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Yerel bildirimler** | Sabah motivasyon (09:00), akşam (21:00), haftalık özet (Pazar 15:00), mini deneme, tasarruf kilometre taşı, **Odak süre bitişi** (`focus_timer`) | `lib/services/notification_service.dart` |
| **FCM push** | Duyuru konusu, içerik güncelleme sessiz senkron | `lib/services/push_notification_service.dart` |
| **Cihaz token kaydı** | FCM token → `POST /api/v1/device-tokens/` | `push_notification_service.dart` |
| **İçerik güncelleme handler** | Push sonrası katalog yeniden senkron | `push_notification_service.dart` |

---

### Çevrimdışı ve yerel depolama

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **SQLite** | Deneme kayıtları, yanlış defteri, deneme geçmişi (365 gün) | `lib/services/local_database.dart`, `lib/services/database_bootstrap.dart` |
| **SharedPreferences** | Tercihler, oyunlaştırma, offline paket meta, boot store | `lib/services/app_preferences.dart` ve ilgili servisler |
| **Offline paket** | Tam içerik paketi indirme; auth header + yıllık sunucu kapısı; 401/403 Türkçe hata | `offline_pack_service.dart`, `content_sync_service.dart`, `premium_sync_service.dart` |
| **İçerik bankası önbelleği** | Yayınlanmış soru/test kataloğu bellek + disk (SQLite `content_question_bank`; düz JSON — şifreli değil) | `lib/services/content_bank_service.dart` |

---

## İçerik paneli (`/panel/`)

Staff-only Django görünümleri: `backend/content/panel_views.py`, `backend/content/panel_urls.py`, şablonlar `backend/templates/panel/`, statik `backend/static/panel/`.

Sol menü bölümleri: **İçerik** · **Deneme & sınav** · **Kullanıcı & satış** · **Kalite** · **Ayarlar**. Günlük işler panelde; Django Admin yalnızca gelişmiş işlemler için.

### Müfredat ve soru yönetimi

| Özellik | URL / dosya |
|---|---|
| Panel ana sayfa (ders listesi) | `/panel/` |
| Ders → konu listesi | `/panel/ders/<id>/` |
| Konu CRUD, sıralama, aktif/pasif | `/panel/konu/...` |
| Konu kapasitesi (test gruplama) | `/panel/konu/<id>/kapasite/` |
| Konu sekmeleri: dersler, **özet kartlar**, sorular, testler, senaryolar | `/panel/konu/<id>/<tab>/` |
| Bilgi kartı (ders) CRUD | `/panel/konu/<id>/bilgi/...` |
| **Özet konu kartı** CRUD (formül / püf / ÖSYM; görsel; stüdyo önizleme) | `/panel/ozet-kart/`, `/panel/konu/<id>/ozet/...` |
| Test CRUD, soru atama | `/panel/konu/<id>/test/...` |
| Senaryo grupları (ortak paragraf) | `/panel/konu/<id>/grup/...` |
| Soru CRUD (kök, A–E, çözüm, görsel, SVG, zorluk, ÖSYM, **Tablo sorusu Yok/İkili/Üçlü**) | `/panel/konu/<id>/soru/...` |
| Soru kopyalama | `/panel/soru/<id>/kopyala/` |
| Toplu soru silme | `/panel/konu/<id>/soru/toplu-sil/` |
| **Uygulama önizlemesi** | Canlı mobil benzeri önizleme — `question-preview.js`, `math-render.js`, `rich-format.js` |
| Tablo / eşleştirme şıkları | Panel **Tablo sorusu** select → `option_table`; sütun başlıkları + `<!--optcols:…-->`; mobil `optionTable` | `option-table.js`, `option-table.css`, `option_column_layout.dart`, `exam_option_view.dart` |
| Biçim araç çubuğu | Kalın / italik / altı çizili / renk (K, I, A, G, R, M) |
| Zengin yapıştırma | Word/Docs/sohbet HTML panosu `**` / `__` işaretine çevrilir (CF_HTML dahil); iç içe kalın ve kalın+altı çizili (`**__**kelime**__**`) tek işarete iner; kalın+altı çizili kelimeye renk (`**__{green}…{/green}__**`) önizleme ve uygulamada korunur; sohbet kopyasında çift madde işareti (`- -`) ve fazladan tire temizlenir; eşleştirme oku `->` / `\\rightarrow` sınav `→` olur | `rich-format.js` |

### OCR ve soru alma

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| Hızlı soru (görselden) | Görsel yükle → OCR → mükerrer kontrol → taslak | `/panel/soru/hizli/` |
| Manuel soru | OCR’sız yapıştır/yaz | `/panel/soru/manuel/` |
| Editör içi OCR API | JSON OCR | `/panel/api/ocr-question/` |
| Tesseract OCR | Türkçe, A–E ayrıştırma | `backend/content/ocr.py` |
| Gemini Vision OCR | Matematik / LaTeX (Tesseract yedek) | `backend/content/ocr_gemini.py` |
| OCR ingest log | Hash, pHash, durum, mükerrer | `OcrIngestLog`, `question_fingerprint.py` |
| Mükerrer tespiti | İçerik + görsel parmak izi; `[HARITA]` ve `(Not: …)` editör notu yok sayılır; aynı şıklar + benzer kök de yakalanır | `question_fingerprint.py` |

### Harita soruları

Panel harita işleri bu dosyalarda; soru formuna gömülmez.

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| Şablon kütüphanesi | Sistem + yüklenen haritalar; koordinatlı işaret veya tematik (işaret yok) | `/panel/haritalar/`, `maps.html`, `map_catalog.py` |
| İl boyama | **İl boya:** tıkla → ili doldur. **Akıllı Fırça:** kalınlıklı serbest karalama; boya kara maskesine (il poligon birleşimi) clip edilir, denize yazılmaz; kayıt `shape:"brush"` | `_question_map_editor.html`, `map-smart-brush.js`, `map-question-editor.js`, `map_provinces.py` |
| Soru formu editörü | Şablon seç, `[HARITA]` yerleştir (düğme soru metnine yazar; şablon yoksa uyarı), elips/daire koy; seçili işareti **Delete / Backspace** siler | `_question_map_editor.html`, `map-question-editor.js` |
| Elips | **Elips ekle** varsayılan kapalı; seçilince haritaya tıklayarak konur. Romen numarası varsayılan kapalı (karttan açılabilir); **A− / A+** ile ±2 punto. Seçilince kenar tutaçlarıyla boyut, yeşil tutaçla 0–179° dönüş | `map-question-editor.js` |
| Doğru çizgisi | **Doğru çiz**: iki tıklama. **Işın çiz**: merkez → kaç doğru → hedef iller. **İl adı**: tıklanan il, doğru/ışın etiketiyle aynı kalın yazı (sürüklenebilir). **Şehir adları: açık/gizli** | `map-question-editor.js`, `map_question_renderer.py`, `map_provinces.py` |
| Daire | Çap = harita genişliğinin %’si; kare kutu → tam daire (yükseklik % kullanılmaz) | `map-question-editor.js`, `map_question_renderer.py` |
| Önizleme / kayıt PNG | Açık kâğıt zemin (deniz şeffaf olsa da koyu temada Romen okunur); Romen rakamları Arial/Helvetica | `map_question_renderer.py` |
| %170 / büyük düzenleme | Harita tam ekran; araç çubuğu altta sabit. Doğru kartı haritayı küçültmez; `%100` veya Esc ile döner | `map-question-editor.js`, `map-question.css` |
| Stil | Kütüphane kartları + editör | `map-question.css` |

### Şekiller (SVG)

| Özellik | Dosyalar |
|---|---|
| SVG sanitizasyon | `backend/content/svg_sanitize.py` |

### Kalite ve moderasyon

| Özellik | URL |
|---|---|
| Kalite panosu (düşük puanlı sorular) | `/panel/kalite/` |
| **ÖSYM Çıkmış Sorular arşivi** (yıl/sınav/oturum, eksik-tam, soru sayısı) | `/panel/osym-cikmis/` |
| İncelenecek sorular (hata bildirimleri) | `/panel/incelenecek-sorular/` |
| Bildirim durumu güncelleme | `/panel/hata-bildirimi/<id>/durum/` |

### Kullanıcı, premium, iletişim

| Özellik | URL |
|---|---|
| Kullanıcı listesi (filtre, toplu sil, misafir temizle) | `/panel/kullanicilar/` |
| Premium ver / kaldır | `/panel/kullanici/<id>/premium/` |
| **Promosyon kodları** (liste / yeni / düzenle / sil / aktif-pasif) | `/panel/promosyon/` |
| Duyuru CRUD + big-picture push önizleme | `/panel/duyuru/...`, `announcement-push-preview.*` |
| Mobil arayüz (yanlış defteri balonu + quiz banner aç/kapa) | `/panel/mobil-arayuz/` |
| Sınav türleri CRUD (geri sayım kataloğu) | `/panel/sinavlar/...` |
| Deneme dağılım şablonu CRUD | `/panel/deneme-sablon/...` |
| Deneme paketi düzenle / sil / aktif-pasif (Dersler vitrini) + şablondan üret | `/panel/deneme-paket/...` |
| **Mini deneme ödülleri** (haftalık/aylık aç-kapa; tek düğmeli finalize; kazananlar) | `/panel/mini-deneme-odulleri/` |
| **TG Deneme Oluşturucu** | Planla, otomatik 120 soru, önizle, yayınla, duyuru 2 saat önce | `/panel/tg-deneme/` |
| **Uygulama canlı istatistik** (aktif / günlük kullanıcı; `last_active_at`) | `/panel/uygulama-durumu/` |

### Embedding ve test gruplama

| Özellik | Dosyalar |
|---|---|
| Soru embedding (OpenAI veya yerel hash) | `backend/content/embeddings.py` |
| Toplu embed komutu | `management/commands/embed_questions.py` |
| Otomatik test gruplama | `backend/content/test_grouping.py` |
| İçerik revizyon + FCM | `backend/content/revision.py` |

### Instagram otomasyonu (ops)

| Özellik | Dosyalar |
|---|---|
| Reels üretimi (rastgele yayın soru → MP4) | `backend/content/services/instagram_automation.py` |
| Graph API yayınlama | Ortam: `INSTAGRAM_GRAPH_*`, `PUBLIC_BASE_URL` |

Panel URL’lerinde doğrudan UI yok; operasyonel/script ile çalışır.

---

## Unfold admin (`/admin/`)

`backend/content/admin.py` — Unfold arayüzü.

| Alan | Modeller / aksiyonlar |
|---|---|
| Müfredat | `Subject`, `Topic`, `TopicLesson`, `TopicSummaryCard`, `TopicTest` |
| Sorular | `Question` — puan özeti, filtreler, toplu işlemler |
| Haritalar | `MapTemplate` |
| Puanlama / deneme | `QuestionRating`, `QuestionAttempt` (salt okunur) |
| Hata bildirimleri | `QuestionErrorReport` |
| OCR logları | `OcrIngestLog` |
| Kullanıcılar | `AppUser` — premium ver/kaldır, mesaj gönder, engelle; panelde seçimli **toplu sil**, misafir filtresi, **Misafirleri temizle** |
| Mesajlar | `UserMessage` — push yeniden gönder |
| Push | `DeviceToken` |
| Mini deneme | `DailyMiniExam`, `DailyMiniExamAttempt` |
| Sınav kataloğu | `ExamType` |
| Deneme paketleri | `ExamPack` — aktif/pasif, düzenle, sil; `ExamPackExam` |
| Promosyon | `PromoCode`, `PromoCodeRedemption` |
| Duyurular | `Announcement` — push aksiyonu |
| Staff | Django `User`, `Group` |

Yönetim komutları: `ensure_admin`, `seed_curriculum`.

---

## Backend API (`/api/v1/`)

Tanım: `backend/content/urls.py`, `views.py`, `serializers.py`. Mobil taban: `lib/config/api_config.dart`.

| Endpoint | Açıklama | Auth | Mobil tüketici |
|---|---|---|---|
| `GET /health/` | Sağlık kontrolü | Hayır | — |
| `GET /pack/version/` | İçerik paketi sürümü | **Bearer + yıllık Premium** | `ContentSyncService` |
| `GET /pack/` | Tam yayın paketi (`summaryCards` dahil) | **Bearer + yıllık Premium** | `ContentSyncService` / `OfflinePackService` |
| `GET /catalog/` | Hafif katalog meta (`summaryCards` dahil) | Hayır | `ContentBankService` |
| `POST /premium/sync/` | Play `productId` / `isPremium` / `expiresAt` → `AppUser` | Bearer | `PremiumSyncService` |
| `GET/POST /daily-quota/` | Ders bazlı ücretsiz test hakkı (`?subject=`); Google hesap yanığı | Bearer (Google) | `DailyQuotaService` |
| `GET /curriculum/` | Müfredat yapısı | Hayır | — |
| `GET /questions/?ids=` | ID ile soru gövdeleri | Hayır | `QuestionFetchService` |
| `GET /questions/<id>/similar/` | Benzer sorular (limit 5) | Hayır | Yanlış defteri (Premium) |
| `GET/POST /questions/<id>/rating/` | Yıldız puanı | Bearer | `QuestionRatingService` |
| `POST /questions/<id>/attempt/` | Soru denemesi logu | Bearer | `QuestionAttemptService` |
| `POST /questions/<id>/view/` | Benzersiz kullanıcı görüntüleme; `{viewCount}`; oturumsuz artırmaz | Opsiyonel Bearer | `QuestionViewService` |
| `GET/POST /questions/<id>/error-report/` | Hata bildirimi (Google; misafir 401) | Bearer (Google) | `QuestionErrorReportService` |
| `GET /tests/` | Yayın test listesi | Hayır | Katalog |
| `GET /tests/<id>/questions/` | Test soruları | Hayır | `QuestionFetchService` |
| `POST /tests/<id>/attempt/` | Test tamamlama | Bearer | Quiz |
| `GET /announcements/` | Aktif duyurular | Hayır | `AnnouncementService` |
| `GET /mobile-ui/` | Mobil arayüz (`wrongNotebookBubble*`, `bannerAdsEnabled`) | Hayır | `AppConfigService` |
| `POST /device-tokens/` | FCM token | Opsiyonel | `PushNotificationService` |
| `POST /auth/google/` | Google giriş | Hayır | `AuthService` |
| `GET/PATCH /me/` | Profil | Bearer | `AuthService` |
| `GET/PATCH/DELETE /me/messages/` | Kullanıcı mesajları | Bearer | `UserMessageService` |
| `GET/POST /daily-mini-exam/` | Mini deneme + gönderim | Opsiyonel/Bearer | `DailyMiniExamService` |
| `GET /daily-mini-exam/period-ranking/` | Haftalık/aylık sıralama (`period`, `kpss_type`) | Opsiyonel/Bearer | `DailyMiniRankingService` |
| `GET /daily-mini-exam/reward-history/` | Finalize edilmiş dönem kazananları | Opsiyonel/Bearer | `DailyMiniRankingService` |
| `POST /promo/redeem/` | Promosyon kodu (Google; 5/dk; max 32) | Bearer (Google) | `PromoCodeService` |
| `GET /exam-types/` | Sınav geri sayım kataloğu | Hayır | `ExamCatalogService` |
| `GET /exam-packs/?exam_type=` | Yayınlanmış deneme paketleri | Hayır | `ExamPackService` |
| `GET /exam-packs/<id>/` | Paket detayı + deneme listesi | Hayır | `ExamPackService` |
| `GET /exam-packs/<id>/exams/<n>/questions/` | Paket denemesi soruları (Google zorunlu; max %20 daha önce çözülmüş) | Bearer (Google) | `ExamPackService` |
| `GET /tg-exams/?kpss_type=` | TG deneme listesi + attempt özeti | Opsiyonel Bearer | `TgExamService` |
| `GET /tg-exams/<id>/` | TG deneme detayı | Opsiyonel Bearer | `TgExamService` |
| `GET /tg-exams/<id>/questions/` | TG oturum soruları (`osymSordu` false) | Bearer | `TgExamService` |
| `POST /tg-exams/<id>/progress/` | TG ilerleme kaydı | Bearer | `TgExamService` |
| `POST /tg-exams/<id>/submit/` | TG gönderim → net, sıra | Bearer | `TgExamService` |

**Yasal:** `GET /gizlilik-politikasi/` — `backend/content/legal_views.py`

---

## Erişim matrisi

> **Kaynak doğruluk:** `AuthService.hasPermanentAccount` (Google), `PremiumService.isPremium`, `AdManager`, `AdRewardKind`, `AdConstants`.  
> **Misafir:** Firebase anonim oturum — uygulama açılır; birçok özellik **Google ile kalıcı hesap** ister.  
> **Premium:** Play Billing aboneliği **veya** panel/API `isPremium` / promosyon / mini deneme ödül günleri.

### Renk / simge efsanesi

| Simge | Etiket | Ne demek? |
|:---:|:---|:---|
| 🟢 | **Ücretsiz** | Misafir dahil; ek giriş/reklam/Premium yok |
| 🟣 | **Misafir kısıtlı** | Anonim kullanır; Google ile tam açılır |
| <span style="color:#2563EB">**🔵 Google**</span> | **Google giriş** | `hasPermanentAccount` — Play/Google hesabı bağlı olmalı |
| <span style="color:#DC2626">**📺 Reklam**</span> | **Ödüllü reklam** | Kullanıcı **30 sn video izler**; izlemezse özellik açılmaz |
| <span style="color:#F59E0B">**📢 Otomatik**</span> | **Banner / geçiş** | Test sırasında gösterilir; izleme değil — Premium veya kampanya kapatır |
| <span style="color:#7C3AED">**👑 Premium**</span> | **Premium** | Aylık veya yıllık abonelik / sunucu grant |
| <span style="color:#CA8A04">**🟡 Yıllık**</span> | **Yıllık Premium** | `isYearlyPremium` / `canUseOfflinePack` |
| ⚪ | **—** | Bu kapı o özellik için geçerli değil |

---

### 🔵 Google giriş gerektiren özellikler

Google giriş = Profil → **Google ile giriş yap** (`AccountLinkCard` / `signInWithGoogle`). Anonim oturum tek başına yetmez.

| Özellik | Misafir | Google giriş sonrası | Dosya / not |
|:---|:---:|:---|:---|
| **Yanlış defteri — soru metni** | 🟣 Buzlu / kilitli | 🟢 Tam metin + misafir defteri taşınır | `wrong_questions_screen.dart`, `auth_service.dart` |
| **Yanlış defteri — işaretli şık** | 🟢 Testte kaydedilir (cihaz) | 🟢 Defter incelemesinde gösterilir | `content_bank_service.dart`, `quiz_screen.dart` |
| **Yanlış defteri — WhatsApp paylaşım** | 🔵 Zorunlu | 🟢 + günlük kota | `wrong_notebook_share_service.dart` |
| **Yanlış defteri — Not Al** | 🟣 Misafir notu taşınmaz* | 🟢 Kalıcı not (Google’a taşınır) | `question_note_service.dart` |
| **Yanlış defteri — kalem çizimi** | 🟢 Oturum içi | 🟢 Soru/çözüm ayrı kayıt (Google’a taşınır) | `wrong_notebook_drawing_service.dart` |
| **Yanlış defteri — TEKRAR ET / ÇÖZÜLDÜ** | 🟢 | 🟢 Cihazda kalır | `content_bank_service.dart` |
| **Kitaptaki yanlışlar — foto ekle** | 🟣 İlk foto sınırı | 🟢 Misafir defteri Google’a taşınır | `manual_question_service.dart` |
| **Günlük test kotası (sunucu)** | 🟣 Yalnız cihaz yanığı | 🟢 Hesap bazlı `DailyQuotaService` | `daily_quota_service.dart` |
| **Canlı başarı / «N kişi gördü»** | 🟣 API’ye yazılmaz | 🟢 `QuestionAttempt` + `QuestionView` | `question_attempt_service.dart`, `question_view_service.dart` |
| **Soru puanlama (yıldız)** | 🔵 Google | 🟢 | `question_rating_service.dart` |
| **Hata bildirimi** | 🔵 Google + test sayısı | 🟢 Ücretsiz: 5 test; Premium: 3 test | `question_error_report_service.dart` |
| **Günün mini denemesi — 2. gün+** | 🔵 Misafir yalnız 1. gün | 🟢 Sıralama devam | `daily_mini_exam_service.dart` |
| **Odak — 40 / 60 dk preset** | 🔵 | 🟢 Misafir max 20 dk | `focus_mode_screen.dart` |
| **Odak — tam ekran modu** | 🔵 | 🟢 | `focus_mode_screen.dart` |
| **Offline paket indirme** | 🔵 + 🟡 | 🟢 Bearer + yıllık | `offline_pack_service.dart`, `content_sync_service.dart` |
| **Deneme paketi satın al / çöz** | 🔵 | 🟢 Play SKU | `exam_pack_detail_screen.dart` |
| **Promosyon kodu kullan** | 🔵 | 🟢 | `promo_code_service.dart` |
| **Premium satın al / kod** | 🔵 | 🟢 Play Billing | `premium_paywall_screen.dart` |
| **Gelişim — hesap kartı / senkron vaadi** | 🟣 Kısıtlı | 🟢 | `analytics_hub_screen.dart`, `account_link_card.dart` |
| **Zoom günlük ipucu slotu** | 🟢 Ayrı sayılır | 🟢 Ayrı sayılır | `quiz_zoom_daily_hint.dart` |

**Google gerektirmeyen (misafir OK):** müfredat okuma, özet kart destesi, konu testi (günlük kota dahil), Günün mini denemesi (1. gün), Odak 20 dk, yanlış defteri listesi (buzlu metin), kalem (oturum), favoriler (yerel), Deneme sekmesi, Stüdyo Odak/Deneme Analizi.

---

### 📺 Ödüllü reklam izleme gerektiren özellikler

Kullanıcı **bilinçli olarak** «Reklam izle» / tam çözüm / paylaşım onayına basar. `AdRewardKind` → `AdService.showRewardedAd`.

| Özellik | Ne zaman? | Ücretsiz limit | Premium farkı | `AdRewardKind` |
|:---|:---|:---|:---|:---|
| **Tam / kısa çözüm kilidi** | Testte **5. ve sonraki** tam çözüm açma (ilk **4** ücretsiz; sıra karışık) | 4/test oturumu | 👑 Anında açılır | `solutionUnlock` |
| **Konu testi +1 hak** | Ders başına günlük 1 test bittikten sonra | 1/gün/derse +1 | 👑 Sınırsız — gerekmez | `dailyTestBonus` |
| **Özel Testler · Haritalarla Coğrafya** | Aynı günlük kota mantığı | Kota dolunca | 👑 Sınırsız | `dailyTestBonus` |
| **Yanlış defteri WhatsApp paylaşım** | Ücretsiz kullanıcı paylaşım öncesi (Google şart) | **1/gün** | 👑 **3/gün**, reklam yok | `wrongNotebookShare` |
| **Kitaptaki yanlış — 2.+ foto** | İlk foto ücretsiz; sonrakiler | 2.+ foto başına | 👑 Reklamsız | `dailyTestBonus` |
| **12 saat banner kampanyası** | Ana sayfa «3 reklam izle» kartı | 3 ödüllü → 12s | 👑 Zaten bypass | `campaign` |

**Ödüllü reklam *gerektirmeyen* reklamlar (📢 otomatik):**

| Tür | Ne zaman? | Kimden gizlenir? |
|:---|:---|:---|
| **Quiz alt banner** | Konu testi çözülürken | 👑 Premium; 12s kampanya; Günün Denemesi oturumu |
| **Sayfa geçiş interstitial** | ~her 3 geçişte bir | 👑 Premium |
| **Test bitiş interstitial** | «Bitir» sonrası | 👑 Premium; tanıtım oturumları |

---

### 👑 Premium gerektiren özellikler

| Özellik | Ücretsiz | Premium | Yalnızca yıllık |
|:---|:---|:---|:---:|
| **Sınırsız konu / özel test** | 1/gün/derse (+ reklam bonusu) | ✓ | |
| **Tüm reklamlar (banner, geçiş, çözüm kilidi)** | 📢 + 📺 | Bypass | |
| **Akıllı Tekrar — oturum başlat** | Paywall | ✓ | |
| **Benzer sorular (yanlış defteri)** | PRO upsell | ✓ | |
| **Konu Takibi** | Kilit | ✓ | |
| **Görev Yönetimi** | Kilit | ✓ | |
| **Sıralama (Stüdyo)** | Kilit | ✓ | |
| **Bulut Senkron UI** | Kilit | ✓ (kısmen mock) | |
| **Kitaptaki 2.+ foto** | 📺 | Reklamsız | |
| **Yanlış defteri paylaşım** | 1/gün + 📺 | 3/gün | |
| **Hata bildirimi eşiği** | 5 bitmiş test | 3 bitmiş test | |
| **VPN/DNS ağ kilidi** | Uygulanır | Muaf | |
| **Offline paket** | — | — | 🟡 **Zorunlu** |

Paywall listesi: `PremiumService.features` · Kapı: `PremiumGate` / `ProUpsellSheet`.

---

### 🟣 Misafir → Google: pratik özet

| Durum | Misafir (anonim) | Google hesabı |
|:---|:---|:---|
| Uygulamayı aç / ders oku | ✓ | ✓ |
| 1 konu testi / gün / ders | ✓ (cihaz yanığı) | ✓ (hesap + sunucu kotası) |
| Yanlış defteri tam metin | ✗ buzlu | ✓ |
| Yanlış defteri → Google taşıma | — | ✓ tek seferlik migrate (giriş anında) |
| Testte işaretlenen yanlış şık | ✓ yerel kayıt | ✓ defter incelemesinde görünür |
| Canlı «Başarı %» / «N kişi gördü» | Kısmen yerel | ✓ sunucu |
| WhatsApp paylaşım | ✗ | ✓ |
| Mini deneme sıralama | Yalnız 1. gün | ✓ |
| Odak 40–60 dk / tam ekran | ✗ | ✓ |
| Offline paket | ✗ | ✓ + yıllık Premium |

\* **Not taşıma:** Google girişinde `QuestionNoteService.onUserSessionChanged` misafir notlarını birleştirir; giriş öncesi not yoksa tablo boş kalır.

#### Misafir → Google teknik akış (geliştirici)

```
Misafir test çözer → yanlışlar prefs’te {key}_{guestId}
       ↓
Profil / AccountLinkCard → signInWithGoogle()
       ↓
previousUserId yakalanır → backend exchange → yeni userId
       ↓
AuthService._relayUserScopedServices(previousUserId)
       ├─ ContentBankService.onUserSessionChanged
       ├─ ManualQuestionService.onUserSessionChanged
       ├─ QuestionNoteService.onUserSessionChanged
       └─ WrongNotebookDrawingService.onUserSessionChanged
       ↓
Scoped prefs merge → Google userId altında kalıcı
```

**Prefs örnekleri:** `content_wrong_questions_{userId}`, `content_wrong_question_selections_{userId}`, `question_notes_v1_{userId}`, `wrong_notebook_drawings_v1_{userId}`, `local_guest_id` (yedek misafir kimliği).

**Backend:** `POST /api/v1/auth/google/` + isteğe `guest_sub` — yalnızca `AppUser` birleştirme; yanlış defteri sunucuya gitmez.

**Doğrulama:** Misafirken 1+ yanlış ekle → Google bağla → Yanlış Defteri aynı sorular + işaretli şıklar; `uygulamayi-yukle.bat` ile güncel APK gerekir.

---

### A) Çalışma ve test (freemium)

| Yetenek | Ücretsiz | Ödüllü reklam | Premium (aylık veya yıllık) | Yıllık Premium |
|---|---|---|---|---|
| Müfredat, ders okuma, özet kart destesi | ✓ | | ✓ | ✓ |
| Ders başına **1 konu testi / gün** | ✓ | | sınırsız | sınırsız |
| **+1 bonus test / gün** (derse özel) | | ✓ (`dailyTestBonus`) | gerekmez | gerekmez |
| **Sınırsız konu testi** | | | ✓ | ✓ |
| **Özel Testler · Haritalarla Coğrafya** | Aynı günlük kota mantığı | kota dolunca reklam/Premium diyalog | sınırsız | sınırsız |
| **Günün mini denemesi** (20 soru) | ✓ (oturumda banner yok) | | ✓ | ✓ |
| Mini deneme **ÖDÜL** ekranı (hafta/ay liste) | ✓ (herkese açık) | | ✓ | ✓ |
| Mini deneme sıralama ödülü (1./2./3.) | Kazanınca **Premium gün** (3/2/1) | | | |
| Quiz **banner** reklamı | ✓ | 12s kampanya kapatır | **Bypass** | **Bypass** |
| Sayfa geçiş **interstitial** | ✓ | | **Bypass** | **Bypass** |
| **Çözüm tam açma** | Testte ilk **4** tam/kısa çözüm ücretsiz; **5.+ her biri** ödüllü reklam (sıra karışık da sayılır); önizleme her zaman | ✓ (5.+) | ✓ anında | ✓ |
| **Filigran** | ✓ | ✓ | ✓ | ✓ |
| **Hata bildirimi** | Google + **5** bitmiş konu testi; 1/gün | | Google + **3** bitmiş test; 1/gün | aynı |
| Favoriler, notlar, çalışma kasası | ✓ | | ✓ | ✓ |
| Gelişim sekmesi / ders analitiği | ✓ | | ✓ | ✓ |
| Deneme sekmesi + puan hesaplama | ✓ | | ✓ | ✓ |
| Stüdyo «Deneme Analizi» / «Odak · Pomodoro» | ✓ (`onNavigate`) | | ✓ | ✓ |
| VPN/DNS ağ kilidi | Kilitlenebilir | | **muaf** | **muaf** |
| Ekran görüntüsü (`FLAG_SECURE`) | Yasak | | Yasak | Yasak |

### B) Yanlış defteri ve Akıllı Tekrar

| Yetenek | Ücretsiz | Ödüllü reklam | Premium | Yıllık |
|---|---|---|---|---|
| Yanlış defteri listesi / inceleme / Not Al | ✓ (misafir: metin buzlu) | | ✓ | ✓ |
| Defterden sil / kalp | ✓ | | ✓ | ✓ |
| **WhatsApp paylaşımı** (filigranlı PNG) | ✓ Google + **1/gün** | ✓ (ücretsiz kota için) | ✓ Google + **3/gün** | aynı |
| **Benzer sorular** | Upsell sheet | | ✓ | ✓ |
| **Akıllı Tekrar ekranı** (paket özeti) | ✓ görüntüleme | | ✓ | ✓ |
| **AKILLI TEKRARI BAŞLAT** | Paywall | | ✓ | ✓ |
| Kitaptaki yanlışlar — **1. foto** | ✓ | | ✓ | ✓ |
| Kitaptaki — **2. ve sonraki foto** | | ✓ zorunlu | ✓ ücretsiz | ✓ |
| Kitaptaki — **kalem / annotate** | ✓ | | ✓ | ✓ |

### C) Stüdyo Premium suite (PRO kilit)

Stüdyo hub (`home_premium_module_list`). Hepsi `PremiumGate.navigate` veya kendi ekranında yıllık kontrolü. **Odak · Pomodoro** ve **Deneme Analizi** çalışma araçlarında ücretsiz (`onNavigate`).

| Modül | Kapı | Not |
|---|---|---|
| **Offline Paket** | **Yalnızca yıllık** (`canUseOfflinePack` + sunucu `is_yearly_premium`); Bearer zorunlu; aylık Premium’da kilit | Tam pack; `POST /premium/sync/` |
| **Konu Takibi** | Premium | Müfredat işaretleme |
| **Görev Yönetimi** | Premium | Haftalık plan |
| **Bulut Senkron** | Premium | UI; sync kısmen mock |
| **Sıralama** | Premium | Canlı haftalık/aylık toplam doğru (mini deneme API) |

Paywall’da listelenen vaatler (`PremiumService.features`): Offline (yıllık), Konu Takibi, Görev Yönetimi, Bulut Senkron, Sıralama, Akıllı Tekrar, Benzer sorular, sınırsız test. **Kodda ayrıca Premium:** reklam bypass, çözüm kilidi, VPN muafiyeti, kitaptaki ekstra foto.

### D) Reklam kampanyası (Premium açmaz)

| Kampanya | Ne verir | Ne **açmaz** |
|---|---|---|
| 3 ödüllü reklam → **12 saat** | Yalnızca **quiz banner** kapalı | Çözüm kilidi, günlük kota, benzer, sınırsız test, offline, konu takibi, Akıllı Tekrar, VPN muafiyeti |

### E) Özet tablo (hızlı bakış)

| Yetenek | Ücretsiz | Ödüllü reklam | Premium | Yıllık Premium |
|---|---|---|---|---|
| Müfredat ve ders okuma | ✓ | | ✓ | ✓ |
| Ders başına 1 test/gün | ✓ | | | |
| +1 bonus test/gün | | ✓ | | |
| Sınırsız konu / özel test | | | ✓ | ✓ |
| Quiz banner | ✓ | 12s kampanya | Bypass | Bypass |
| Interstitial | ✓ | | Bypass | Bypass |
| Çözüm kilidi açma | İlk 4 ücretsiz; 5.+ | ✓ (5.+) | ✓ | ✓ |
| Günün mini denemesi | ✓ | | ✓ | ✓ |
| Akıllı Tekrar **başlat** | | | ✓ | ✓ |
| Yanlış defteri listesi | ✓ | | ✓ | ✓ |
| Benzer sorular | | | ✓ | ✓ |
| Kitaptaki 1. foto / kalem | ✓ | | ✓ | ✓ |
| Kitaptaki 2.+ foto | | ✓ | ✓ | ✓ |
| Konu takibi, görev, sıralama, bulut UI | | | ✓ | ✓ |
| Deneme analizi (Stüdyo + sekme) | ✓ | | ✓ | ✓ |
| Odak · Pomodoro | ✓ | | ✓ | ✓ |
| Offline paket | | | | ✓ |
| Filigran | ✓ | ✓ | ✓ | ✓ |
| Promosyon / ödül Premium günleri | | | ✓ | ✓ |

---

## Türkiye Geneli (TG) denemeleri

Aylık **Türkiye Geneli** deneme sistemi. Normal **konu testleri** (`TopicTest`), **deneme paketleri** (`ExamPack`) ve **Telegram OCR** akışından bilinçli olarak ayrıdır; ortak soru havuzunu kullanır ancak kendi API’si, paneli, puanlama/sıralama ve bildirim zamanlaması vardır.

**Kaynak paket:** `backend/content/tg_exam/`  
**Mobil:** `lib/services/tg_exam_service.dart`, `lib/screens/tg_exam/`, `lib/widgets/tg_exams_section.dart`  
**Sabitler:** `TG_EXAM_DURATION_MINUTES = 130` (backend), `TgExamConstants.examDurationMinutes` (mobil)

### TG — Mobil uygulama

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Deneme sekmesi — TG listesi** | «TG Denemelerim»: **Aktif Denemeler** (sonuçlar henüz açılmamış) ve **Geçmiş Denemeler** (sonuçlar yayımlandı) | `tg_exams_section.dart` | 🟢 KPSS tipine göre filtre |
| **Yayında rozeti** | `start_at ≤ now < end_at` iken kartta **Yayında** | `tg_exams_section.dart` | 🟢 |
| **Karşılama ekranı** | Bildirim deeplink veya listeden; özet, **Başla** / **Devam et** / **Sonuçlar** | `exam_welcome_screen.dart` | 🔵 Google (soru çekme) |
| **130 dk geri sayım** | **2 saat 10 dakika** geriye sayım; cevap sonrası süre durmaz | `tg_exam_constants.dart`, `quiz_screen.dart` | 🟢 Oturumda reklamsız |
| **Son 10 dk uyarı** | Kalan ≤10 dk: bir kez uyarı sesi + sayaç urgent mod | `answer_feedback_service.dart` | 🟢 |
| **Süre bitince otomatik bitir** | Sayaç 0 → otomatik gönderim; diyalog yok | `quiz_screen.dart` | 🟢 |
| **Reklamsız oturum** | Banner, bitiş interstitial, çözüm kilidi yok | `exam_welcome_screen.dart`, `ad_manager.dart` | 🟢 |
| **ÖSYM rozeti gizli** | Havuz sorularında TG quiz’te «ÖSYM SORDU» gösterilmez | `quiz_screen.dart`, API strip | 🟢 |
| **Çözüm inceleme** | Sonuç sonrası tüm şıklar + çözümler; süre yok | `tg_exam_result_screen.dart` | 🟢 Sonuç açıkken |
| **İlerleme / devam** | Cevaplar + süre sunucuda; yarım oturum devam | `tg_exam_service.dart` | 🔵 Google |
| **Anlık özet** | Gönderim sonrası net, doğru/yanlış/boş | `tg_exam_instant_summary_screen.dart` | 🟢 |
| **Sonuç detayı** | Türkiye geneli sıra, ders net dağılımı, çözüm inceleme | `tg_exam_result_screen.dart` | 🟢 |
| **Push deeplink** | `tg_exam` → karşılama; `tg_exam_results` → sonuç | `app_navigator.dart`, `push.py` | 🟢 |

**TG quiz farkları:** başarı yüzdesi / görüntülenme yok; şık seçince anında kayıt; chip altın/beyaz; **Tamamla** düğmesi; `statisticsTestId` yok.

### TG — Soru üretimi ve cooldown

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Dağılım (120 soru)** | TR 30, Mat 30, Tarih 27, Coğ 18 (fiziki 7 / ekonomik 7 / beşeri 4), Vat 9, Güncel 6 | `distribution.py` |
| **Otomatik üretim** | KPSS tipi + alt konu/etiket eşleme | `generator.py` |
| **Panelde değiştir** | Önizlemede tek soru rastgele swap (yayında kapalı) | `panel_views.py` |
| **Cooldown** | Son **4** TG’de sorulmuş kolay/orta hariç; 5. denemeden itibaren havuza döner | `cooldown.py`, `signals.py` |

### TG — Puanlama, sıralama, sonuç

| Özellik | Dosyalar |
|---|---|
| KPSS net (4 yanlış = 1 doğru) | `grading.py` |
| Sıralama: net ↓, süre ↑ | `ranking.py` |
| `end_at` sonrası otomatik sonuç + FCM | `finalize_due_tg_exams`, `finalize_tg_exams.py` |

### TG — Bildirimler (FCM)

| Bildirim | Zaman | Kime |
|---|---|---|
| **Duyuru** | `start_at − 2 saat` | Tüm kullanıcılar (topic / token) |
| **Sonuç** | `end_at` sonrası finalize | Göndermiş katılımcılar |

Yayın anında duyuru gitmez. Tetik: API trafiği veya `manage.py finalize_tg_exams` / `finalize-tg-exams.bat`.

### TG — İçerik paneli

| Özellik | URL |
|---|---|
| Liste | `/panel/tg-deneme/` |
| Wizard (kaydet → üret → önizle → yayınla) | `/panel/tg-deneme/yeni/`, `/panel/tg-deneme/<id>/` |
| Duyuru planı UI | Formda «2 saat önce otomatik» + gönderim durumu |

### TG — Backend API

| Endpoint | Açıklama | Auth |
|---|---|---|
| `GET /api/v1/tg-exams/` | Liste + attempt özeti | Opsiyonel |
| `GET /api/v1/tg-exams/<id>/` | Detay | Opsiyonel |
| `GET /api/v1/tg-exams/<id>/questions/` | Sorular (`osymSordu: false`) | Bearer; pencere içi |
| `POST /api/v1/tg-exams/<id>/progress/` | İlerleme kaydı | Bearer |
| `POST /api/v1/tg-exams/<id>/submit/` | Gönderim → net, sıra | Bearer |

**Durumlar:** `not_started` · `active` · `in_progress` · `submitted_waiting` · `ended` · `results`

### TG — Admin ve modeller

- **Admin:** `TgExam`, `TgExamAttempt`; sonuç yayınla / duyuru gönder aksiyonları  
- **Modeller:** `TgExam`, `TgExamAttempt`; `Question.last_used_in_tg_exam_at`, `tg_exam_cooldown_counter`  
- **Migrasyonlar:** `0058`–`0061`

### TG — Erişim

| | Misafir | Google |
|---|---|---|
| Liste görme | ✓ | ✓ |
| Katılma / sonuç | ✗ | ✓ |
| Reklam | — | Yok (ad-free oturum) |

---

## Veri modelleri (özet)

`backend/content/models.py`:

- **Müfredat:** `Subject`, `Topic`, `TopicLesson`, `TopicSummaryCard`, `TopicTest`
- **İçerik:** `Question` (`option_table`: none/dual/triple), `QuestionScenario`, `MapTemplate`
- **Kullanıcı:** `AppUser` (`premium_product_id`, `is_yearly_premium`, `last_active_at`), `DeviceToken`, `UserMessage`, `DailySubjectFreeUsage`
- **Etkileşim:** `QuestionRating`, `QuestionAttempt`, `QuestionErrorReport`
- **Mini deneme:** `DailyMiniExam`, `DailyMiniExamAttempt`, `DailyMiniRankingCampaign`, `DailyMiniRankingWinner`
- **Operasyon:** `Announcement`, `ExamType`, `PromoCode`, `PromoCodeRedemption`, `OcrIngestLog`, `ContentRevision`
- **Deneme paketleri:** `ExamDistributionTemplate`, `ExamPack`, `ExamPackExam`, `ExamPackExamQuestion`
- **Türkiye Geneli:** `TgExam`, `TgExamAttempt` (+ `Question` TG cooldown alanları)
- **Embedding:** `Question.embedding` (JSON)

Mobil JSON alan eşlemesi: `backend/content/serializers.py` ↔ `lib/models/question_model.dart` (ör. `stem` → `soruMetni`).

---

## Bilinen sınırlamalar

1. **Bulut senkron** arayüzü hazır; gerçek çok cihazlı sync backend’i kısmen mock.
2. **Mikro Öğrenme** ve **Özel Notlarım** yerel/demo içerik kullanır (Django soru bankası değil).
3. **Instagram Reels** yalnızca backend servisi; panel UI yok.
4. **Anonim oturum** çevrimdışı çalışmayı destekler; senkron özellikler backend oturumu ister.
5. Soru metni/şık/çözüm **mobil kodda hardcode edilmez** — kaynak Django (`QuestionFetchService`, `ContentBankService`).
6. **Play Store / release APK** yalnızca `armeabi-v7a` + `arm64-v8a` (telefon); x86_64 emülatör bu release’i çalıştırmaz. Hedef paket **≤80 MB**.
7. **Mini deneme ödül finalize** otomatik için OS Task Scheduler / cron gerekir (`finalize-mini-oduller.bat` veya `manage.py … --auto`); panelden manuel de çalışır.
8. Canonical proje yolu **`D:\HEDEFKAMU`**; `D:\ozel\HEDEFKAMU` kopyası bat ile yönlendirilir — iki klonu aynı Gradle daemon ile açmayın.

---

## Sürüm notu (2026-08-22)

- **TG Deneme modülü:** panel oluşturucu, 120 soru üretici, cooldown, mobil Aktif/Geçmiş, 130 dk geri sayım, ÖSYM rozeti gizleme, FCM duyuru (2 saat önce) + sonuç bildirimi — bkz. [TG denemeleri](#türkiye-geneli-tg-denemeleri)
- **Konu testi yeşil tik:** bitirilen testlerde ✓ işareti
- **Reklam banner:** SDK geç hazır olunca yeniden yükleme
- **Erişim rehberi:** Google / ödüllü reklam / Premium / misafir tabloları
- **Yanlış defteri:** TEKRAR ET·ÇÖZÜLDÜ chip; soru/çözüm kalem katmanları; kalıcı çizim
- **Quiz:** başarı dikey çubuk; matematik şık kart düzeni
- **Özet Konular:** 3D altın başlık; **Odak:** sayaç altında HEDEF Kamu
- **Banner panel:** Mobil arayüzden quiz banner aç/kapa (`bannerAdsEnabled`)
- **Özel test etiketleri:** `tag_kronoloji` / `tag_padisah_antlasma` / `tag_celdirici`; keyword auto + panel; kategori **Çeldiricisi Güçlü**; `retag_special_questions`
- **Zoom ipucu:** günlük ilk testte ortada yumuşak toast; misafir/Google ayrı
- **Paylaşım kartı:** üst ortada büyük HEDEF Kamu; sol üst marka satırı yok
- **NEDEN BİZ:** güncel avantaj/dezavantaj maddeleri
- **Yanlış defteri:** BENZER üst rozet; Akıllı Tekrar büyütüldü
- **Kalem:** boş saveLayer beyaz örtü düzeltmesi
- **ÖSYM / splash / Test başlık / Başarı chip** cilası

## Sürüm notu (2026-08-21)

- **Quiz zoom:** pinch + çift dokunuş; kalem açıkken zoom kilit
- **Şık kuralı:** tüm şıklar sola; yalnızca LaTeX büyük punto
- **Başarı chip:** veri yoksa `Başarı: —`
- **Yanlış defteri paylaşım:** 1080×1920 hikâye; detaylı capture log
- **Kalem toolbar:** dikey sürüklenir
- **Odak tam ekran:** sayaç altında aktif süre chip + filigranlı isim
- **Odak ortam:** Dalga / Kafe MP3; 20/40/60
- **Çözüm:** testte ilk 4 ücretsiz
- **NEDEN BİZ**, ders bazlı kota, panel `/panel/uygulama-durumu/`

### Sürüm notu (2026-08-20)

Bu sürümde öne çıkanlar (ayrıntı: [20 Ağustos 2026](#20-ağustos-2026--işlenen-ekleme-ve-değişiklikler)):

- **Özet konu kartları:** panel CRUD + pack/catalog `summaryCards` + konu detayında kaydırma destesi + Favorilerim sekmeleri
- **Yanlış defteri:** Kitaptaki yanlışlarım (manuel foto), defter notu, benzer soru kök kopya filtresi
- **Panel:** menü grupları, promosyon CRUD, kullanıcı toplu/misafir temizleme, harita doğru/ışın/il adı, eşleştirme şık tablosu
- **Destek mailto** cihaz/sürüm gövdesi; **reklamsız kampanya** yalnızca banner; **uygulamayi-yukle.bat** uninstall→install

### Sürüm notu (2026-08-18)

Bu sürümde dokümana eklenen son mobil/panel iyileştirmeler:

- Soru kökünde satır kırılımları (birden fazla Romen madde `I. II. III.`; `**ifadelerinden**` cümlesi) panel önizlemesi ile uyumlu; `III. Jeolojik Zaman` gibi tek Romen kullanımında satır kırılmaz
- Display math (`\begin{array}`, `\hline`, `\frac`) mobilde `$$...$$` olarak korunur
- Tüm cihazlarda dikey ekran kilidi
- Deneme paketleri panelde aktif/pasif, düzenleme ve silme (`/panel/deneme-paket/`)
