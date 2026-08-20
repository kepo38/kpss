# Hedef Kamu (KPSS Akademi) — Özellik Kataloğu

> **Son güncelleme:** 2026-08-20  
> **Dart paketi:** `kpss_akademi`  
> **Android applicationId (Play Store):** `com.hedefkamu.hedef_kamu`  
> **Stack:** Flutter mobil + Django REST API + içerik paneli (`/panel/`) + Unfold admin (`/admin/`)

Bu dosya uygulamadaki **tüm kullanıcı ve yönetici özelliklerini** tek kaynakta toplar. Yeni özellik eklendiğinde, mevcut bir özellik değiştirildiğinde veya kaldırıldığında **aynı PR/commit ile güncellenmelidir**.

---

## Bakım kuralı

| Ne zaman | Ne yapılır |
|---|---|
| Yeni ekran, servis veya API eklendiğinde | İlgili bölüme madde ekle; dosya yollarını yaz |
| Premium / reklam / kota değiştiğinde | [Erişim matrisi](#erişim-matrisi) bölümünü güncelle |
| Panel veya admin akışı değiştiğinde | [İçerik paneli](#i̇çerik-paneli-panel) veya [Unfold admin](#unfold-admin-admin) bölümünü güncelle |
| Özellik kaldırıldığında | Maddenin yanına `(kaldırıldı)` notu veya silme |

**Referans dosyalar:** `lib/screens/`, `lib/services/`, `lib/widgets/`, `backend/content/`

### 20 Ağustos 2026 — işlenen ekleme ve değişiklikler (bu commit)

Bu tarihte yapılan **yeni özellikler**, **davranış değişiklikleri** ve **panel/API** güncellemelerinin ayrıntılı kaydı. Katalog satırları aşağıda ilgili bölümlerde de yansıtılmıştır.

#### Mobil — özet konu kartları (yeni)

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Model** | Konuya bağlı kısa kart: `kind` = `formula` / `tip` / `osym`; başlık + gövde; sıralama; yayın bayrağı | `TopicSummaryCard` (`models.py`), migration `0041_topic_summary_card.py`, `TopicSummaryCardModel` (`content_models.dart`) |
| **API** | `GET /pack/` ve `GET /catalog/` yanıtına `summaryCards` listesi; revizyon sinyali kart kaydında | `serializers.py`, `views.py`, `revision.py` |
| **Panel CRUD** | Konu workspace sekmesi **Özet kartlar**; yeni/düzenle/sil; formül / püf / ÖSYM | `/panel/konu/<id>/summary/`, `/panel/konu/<id>/ozet/...`, `topic_workspace.html`, `summary_card_form.html`, `panel_summary_card_*` |
| **Konu detayı destesi** | Test listesinin üstünde Tinder tarzı deste: kaydır / **Biliyorum** / **Unuttum**; kalp ile favori | `topic_detail_screen.dart`, `topic_summary_swipe_deck.dart` |
| **İlerleme** | Kullanıcıya özel bilinen / zayıf / favori ID’ler (SharedPreferences scope); oturum değişince yeniden yüklenir | `summary_card_progress_service.dart`, `auth_service.dart`, `main.dart` |
| **Favorilerim** | İki sekme: **Soru Favorileri** · **Özet Kartlar**; özet tarafta filtre **Favoriler** / **Tekrar Et** | `favorites_screen.dart` |
| **İçerik bankası** | Katalog/pack’ten `_summaryCards` yükleme, konu/ID sorguları, disk persist | `content_bank_service.dart` |
| **Admin** | Unfold’da `TopicSummaryCard` kaydı | `admin.py` |

#### Mobil — yanlış defteri ve notlar

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Header / Akıllı Tekrar** | Üst balon kaldırıldı; **Akıllı Tekrar** başlığın altında ortalanmış pill; istatistik alt yazısı: uygulama konu testlerine göre analiz | `wrong_notebook_header.dart`, `wrong_questions_screen.dart`, `wrong_notebook_stats_row.dart` |
| **Kitaptaki yanlışlarım** | Pembe **KİTAPTAKİ YANLIŞLARIM** → ayrı ekran; **SORU EKLE** premium aksiyonu | `wrong_notebook_manual_screen.dart`, `wrong_notebook_manual_card.dart` |
| **Manuel foto soru** | Kamera/galeri; meta sheet **YANLIŞ SORULARIM**; ders→konu müfredattan zorunlu; not opsiyonel; uygulama özel dizini (galeriye düşmez); durum: Yeni / Tekrar Et / Çözüldü | `manual_question_model.dart`, `manual_question_service.dart`, `wrong_notebook_manual_meta_sheet.dart` |
| **Defter inceleme** | Karta tıklayınca süre ve Soru 1/1 yok; **Çıkış**; işaretli şık; **Not Al** + «KAYITLI KALIR»; normal testte «Daha önce» | `quiz_take_note_button.dart`, `quiz_question_note_card.dart`, `quiz_wrong_notebook_banner.dart`, `question_note_service.dart` |
| **Balon tetik** | Google + bitmiş konu testi + **defterde ≥1 yanlış**; Günün Denemesi / yarım test tetiklemez | `wrong_notebook_promo_bubble.dart`, `content_bank_service.dart` |
| **Benzer sorular** | Embedding sonucu: kaynak soru ve kök metni ≥%88 benzer kopyalar elenir | `embeddings.py`, `test_embeddings.py`, `QuestionFetchService` |

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
| **Eşleştirme şıkları** | Panel: `option-table.js` + CSS (değerler sütun, etiket başlık, dikey çizgi yok). Mobil: `option_column_layout.dart` | `option-table.js`, `option-table.css`, `option_column_layout.dart`, `exam_option_view.dart`, `question-preview.js` |
| **Yapıştırma** | Eşleştirme oku `->` / `\\rightarrow` → `→` | `rich-format.js` |

#### Panel — menü, promosyon, kullanıcılar

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **Sol menü** | Gruplar: İçerik · Deneme & sınav · Kullanıcı & satış · Kalite · Ayarlar | `base.html` |
| **Promosyon CRUD** | Liste / yeni / düzenle / sil / aktif-pasif (günlük iş Admin’de değil panelde) | `/panel/promosyon/`, `promo_codes.html`, `promo_code_form.html`, `panel_promo_*` |
| **Kullanıcılar** | Toplu sil, misafir filtresi, **Misafirleri temizle**; bir kerelik anonim misafir temizliği | `users.html`, `panel_views.py` |

#### Panel — harita editörü (genişletme)

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **İl boya** | ÖSYM bölge boyama; komşu aynı renk birleşir | `map-question-editor.js`, `map_provinces.py` |
| **Doğru / ışın / il adı** | İki tıklama doğru; ışın: merkez→adet→hedef iller; il adı etiketi; şehir adları açık/gizli | `map-question-editor.js`, `map_question_renderer.py` |
| **Elips** | Varsayılan kapalı; tıklayarak koy; Romen varsayılan kapalı; tutaçlarla boyut + dönüş | `map-question-editor.js` |
| **%170 düzenleme** | Tam ekran harita; araç çubuğu altta; Esc / %100 çıkış | `map-question.css` |
| **PNG zemin** | Açık kâğıt zemin (koyu temada Romen okunur) | `map_question_renderer.py` |
| **Mükerrer** | `[HARITA]` ve `(Not: …)` yok sayılır; aynı şıklar + benzer kök | `question_fingerprint.py` |

#### Geliştirici araçları / build

| Alan | Ne yapıldı | Dosyalar |
|---|---|---|
| **uygulamayi-yukle.bat** | Release APK derle → eski paketi **uninstall** → install → aç; uzun derlemede net mesaj; JDK/Flutter/adb PATH | `uygulamayi-yukle.bat` |
| **Play paket boyutu** | Release ABI: `armeabi-v7a` + `arm64-v8a`; native lib sıkıştırma; hedef ≤80 MB | `android/app/build.gradle.kts` |
| **Anayasa kuralı** | Dosya ayrımı (harita / option-table / önizleme ayrı dosya); büyük dosyaya yalnızca bağlama | `.cursor/rules/kpss-akademi.mdc` |
| **Testler** | Hata bildirimi, embedding benzerlik filtresi, anonim auth, watermark, kampanya, exam text parity | `test_error_report.py`, `test_embeddings.py`, `test_anonymous_auth.py`, `*_test.dart` |

### 19 Ağustos 2026 — işlenen davranış (önceki commit)

| Alan | Ne değişti | Dosyalar |
|---|---|---|
| **Açılış splash** | Ortada 657 `app_icon` gölge daireyi doldurur (soluk / solgun altın); üstte HEDEF KAMU biraz yukarı (yan logo yok), altta «Ataman Gerçekleşiyor» + kayan çizgi ikonun biraz daha altında (3,5 sn) | `boot_splash_screen.dart` |
| **Yanlış defteri balonu** | Yalnızca **Google hesabı** + **en az 1 konu testi bitmiş** + **defterde en az 1 yanlış** varken; panel açıkken. Günün Denemesi / yarım test tetiklemez. Sol yaslı; YANLIŞ→DEFTERİM 3D; teal çerçeve | `wrong_notebook_promo_bubble.dart`, `content_bank_service.dart` |
| **Yanlış defteri UI** | Header alt başlığı («X soru · Y ders») yok; en çok yanlış derste kırmızı adet rozeti; kart: konu chip sol üst, kalp+sil sağ üst; metin «İstediğiniz zaman silebilirsiniz»; karttan onaylı silme; silince alt SnackBar yok, ortada şampanya çerçeveli kutu (~3 sn): onay ikonu, «Defterden kaldırıldı», soru önizlemesi | `wrong_questions_screen.dart`, `wrong_notebook_*` |
| **Defter soru notu** | Karta tıklayınca süre ve Soru 1/1 yok; **Çıkış** (onaysız deftere dönüş); testte işaretlediği şık işaretli; normal testte aynı soru işaretsiz + mavi «Daha önce». Sağda seviye; solda **Not Al** + «KAYITLI KALIR». Bitmiş testte yanlış kalan sorular sonradan doğru cevaplansa istatistik güncellenmez | `quiz_take_note_button.dart`, `quiz_question_note_card.dart`, `quiz_wrong_notebook_banner.dart`, `question_note_service.dart`, `content_bank_service.dart` |
| **BENZER upsell** | Başlık **BENZER SORULAR**; alt metin «Yanlışlarını daha iyi analiz et» | `pro_upsell_sheet.dart` |
| **Misafir yanlış defteri** | Yalnızca **soru metni** hafif buzlu (metin okunur); kalp, sil, BENZER açık. **GİRİŞ YAP** yok; karta dokununca giriş ister | `wrong_notebook_guest_frost.dart`, `wrong_notebook_question_card.dart` |
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
5. [Erişim matrisi](#erişim-matrisi)
6. [Veri modelleri (özet)](#veri-modelleri-özet)
7. [Bilinen sınırlamalar](#bilinen-sınırlamalar)

---

## Mobil uygulama

### Uygulama kabuğu ve gezinme

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Ana sekme kabuğu** | Alt menü: Ana Sayfa, Dersler, Gelişim, Deneme; üstte profil | `lib/screens/main_shell.dart` |
| **Yanlış defteri balonu** | Yalnızca Google + en az 1 bitmiş konu testi + defterde yanlış varken; koyu teal zemin; **YANLIŞ** → **DEFTERİM** 3D; mavi-yeşil çerçeve; sağ üst X; sola yaslı (`left: -16`) | `lib/widgets/wrong_notebook_promo_bubble.dart` |
| **Genişletilmiş ana sayfa** | “Daha fazla” menüsü: modül listesi, görevler, araçlar, premium modüller | `lib/screens/home_screen.dart`, `lib/widgets/app_shell_top_bar.dart` |
| **Giriş yönlendirme** | Sınav seçilmemişse hemen onboarding → seçimden sonra «Ataman Gerçekleşiyor» (**3,5 sn**) → ana kabuk; oturum hatasında yeniden deneme | `lib/navigation/app_entry.dart`, `lib/main.dart`, `lib/screens/exam_track_onboarding_screen.dart` |
| **Derin link / bildirim** | Push veya yerel bildirimden duyuru, mesaj, paywall yönlendirmesi | `lib/navigation/app_navigator.dart` |
| **Hızlı açılış** | İlk açılış: sınav tipi seçimi hemen. Seçimden sonra veya kayıtlı kullanıcıda splash: ortada 657 `app_icon` siyah daire gölgeyi doldurur; üstünde HEDEF KAMU (yan logo yok), altında «Ataman Gerçekleşiyor» + kayan çizgi (**3,5 sn**) | `lib/services/boot_store.dart`, `lib/widgets/boot_splash_screen.dart`, `lib/main.dart` |
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
| **Özel Testler** | Dersler altında ortalanmış, büyütülmüş 3D `ÖZEL TESTLER` butonu; ÖSYM Sordu tarzı ışıklı dönen çerçeve; kategori ızgarası (ilk: **HARİTALARLA COĞRAFYA**); Coğrafya `map_template` soruları 20’lik sanal testler | `special_tests_entry.dart`, `osym_badge.dart`, `special_tests_screen.dart`, `backend/content/special_tests.py` | Ücretsiz; Coğrafya günlük kota |
| **Gelişim sekmesi** | Genel doğruluk (yalnızca **konu testleri**; günün mini denemesi 20 sorusu sayılmaz), yatay kaydırmalı ders kartları + nokta göstergesi, çalışma kasası; **Puan Hesaplama bu sekmede yok** | `lib/screens/analytics_hub_screen.dart`, `lib/services/performance_summary_service.dart` | Ücretsiz |
| **Konu listesi** | Konu bazında çözülen/toplam ilerleme | `study_hub_screen.dart` | Ücretsiz |
| **Konu detayı** | İstatistik, **özet kart destesi** (kaydır: Biliyorum/Unuttum + kalp), bilgi kartları, test listesi | `topic_detail_screen.dart`, `topic_summary_swipe_deck.dart` | Günlük kota |
| **Ders okuyucu** | Konuya özel bilgi kartları (markdown / zengin metin) | `lib/screens/lesson_reader_screen.dart` | Ücretsiz |
| **Kaldığın yerden devam** | Yarım test kartı SharedPreferences’ta durur; uygulama kapanınca soru gövdesi RAM’de olmasa da kart kalır, devamda sorular API’den çekilir | `continue_study_card.dart`, `last_study_session_service.dart` | Ücretsiz |
| **İçerik senkronu** | Yayınlanmış paket sürümü değişince indirme | `lib/services/content_sync_service.dart`, `lib/services/content_bank_service.dart` | Ağ gerekli |
| **Müfredat ağacı** | Statik ders/konu yapısı + API katalog eşlemesi | `lib/data/kpss_curriculum.dart` | Ücretsiz |

**Günlük test kotası (ücretsiz):** Her derste günde **1 test** (`ContentBankService.dailyFreeTestsPerSubject = 1`). Reklam izleyerek derse özel **+1 bonus test** (`AdRewardKind.dailyTestBonus`). Premium’da sınırsız. Kota dolunca şampanya çerçeveli diyalog (`daily_test_quota_dialog.dart`).

| **Deneme paketleri vitrini** | Dersler sekmesi altında yatay paket kartları; yalnızca panelde **aktif** paketler; Play SKU ile kilit/açma; **Google girişi zorunlu** | `lib/widgets/exam_pack_showcase.dart`, `lib/services/exam_pack_service.dart` | IAP + Google |
| **Deneme paketi detayı** | Alt deneme listesi → quiz; sorular 1000+ cevaplı orta zorluk; oturumda daha önce çözülen en fazla **%20**; bitince HEDEF KAMU kaydı | `lib/screens/exam_pack_detail_screen.dart`, `lib/services/exam_pack_analytics_bridge.dart`, `backend/content/exam_pack_personalize.py` | IAP + Google |

---

### Quiz ve soru deneyimi

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Quiz ekranı** | Test çözme, cevap seçimi, çözüm gösterme, oturum kaydı | `lib/screens/quiz_screen.dart` | Ücretsiz; reklamlı |
| **Soru kökü render** | Zengin metin, LaTeX (`flutter_math_fork`), görsel, SVG şekil | `lib/widgets/question_stem_content.dart`, `lib/widgets/formatted_text.dart` | Ücretsiz |
| **ÖSYM sordu rozeti** | Resmî kaynaklı sorularda rozet; her konuda testte mümkünse **4 ÖSYM** soru, **4 etiketsiz + 1 ÖSYM** sırası (etiketsiz yetmezse normal sıra) | `lib/widgets/osym_badge.dart`, `lib/models/question_model.dart`, `backend/content/test_grouping.py` | Ücretsiz |
| **Çizim katmanı** | Soru alanında kalem / yeşil fosfor (geniş vurgu) / silgi; işaretler kaydırınca metinde kalır; kalem kapalıyken görünür; test bitince kaydedilmez | `lib/widgets/quiz_drawing_overlay.dart` | Ücretsiz |
| **Favoriler** | Soruyu favorilere ekleme (quiz içi kalp); **Favorilerim** sekmeli: Soru Favorileri + Özet Kartlar (Favori / Tekrar Et) | `favorite_heart_button.dart`, `favorites_service.dart`, `summary_card_progress_service.dart`, `favorites_screen.dart` | Ücretsiz |
| **Soru puanlama** | 1–5 yıldız; oturum varsa sunucuya senkron | `lib/widgets/question_rating_bar.dart`, `lib/services/question_rating_service.dart` | Oturum önerilir |
| **Hata bildirimi** | Yanlış kök/şık/çözüm bildirimi; **Google girişi zorunlu**; ücretsiz **5**, Premium **3** konu testi bitirme; günde 1 bildirim | `lib/widgets/question_error_report_button.dart`, `lib/services/question_error_report_service.dart` | Google + 5 / Premium + 3 |
| **Çözüm kilidi** | Tam çözüm önce gizli; reklam veya Premium ile açılır | `quiz_screen.dart`, `lib/services/ad_manager.dart` | Reklam / Premium |
| **Ses ve titreşim** | Doğru/yanlış geri bildirimi | `lib/services/answer_feedback_service.dart` | Ücretsiz |
| **Sonuç paylaşımı** | Test sonucunu görsel kart olarak paylaşma; sonuç panelinde konu adı en üstte, motive mesajı, kazandığı XP ve seri; soru başı ortalama süre NET kutusunun üstünde | `lib/widgets/shareable_result_card.dart`, `lib/screens/quiz_screen.dart` | Ücretsiz |
| **Filigran** | Marka filigranı ücretsiz ve Premium’da; haritalı/görselli soruda metnin yanında görselin üstüne de biner | `lib/widgets/watermark_widget.dart`, `question_stem_content.dart` | Tüm planlar |
| **Quiz banner reklamı** | Test sırasında alt banner; test ortasında interstitial yok | `lib/services/ad_manager.dart` | Premium veya 12s kampanya |
| **Pro Üyelik üst bar CTA** | Kompakt pill (maskot yok); üst barda hizalı | `lib/widgets/premium_header_button.dart`, `lib/widgets/app_shell_top_bar.dart` | Ücretsiz kullanıcı |

**Biçimlendirme (soru metni):** Panelde `**kalın**`, `__altı__`, `{green}`/`{red}`/`{blue}`, `$...$` / `$$...$$` LaTeX. Mobilde `FormattedText` + `preserveLineBreaks` ile satır kırılımları korunur; display math (`\begin{array}`, `\frac` vb.) korunur. `\hline` çıkarma çizgisi metin renginde `\rule` satırına dönüştürülür; soru kökünde metin ve formül aynı punto kullanır.

**ÖSYM yazı standartları (`lib/theme/exam_typography.dart`):**

| Alan | ÖSYM | Uygulama |
|---|---|---|
| Soru kökü, şık, çözüm | Times New Roman | Google Fonts **Tinos** (mobil yedek); şık **15pt**, çözüm **15pt** |
| Formül / denklem | Cambria Math (italik) | KaTeX / flutter_math glifleri + italik math stili |
| Harita-şema harfi | Arial | `ExamTypography.sansLabel` |

Panel önizlemesi CSS: `--exam-serif`, `--exam-math`, `--exam-sans` (`panel.css`). Şık metni soldan hizalı. Eşleştirme şıkları (`Şehir - Şehir - Şehir` veya `İnanç: Şanlıurfa, Mağara: Antalya, Termal: Afyonkarahisar`) `option-table.js`: değerler sütunda, etiketler başlıkta.

---

### Günlük görevler ve mini deneme

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Günlük görev merkezi** | Ders bazlı günlük ilerleme çubukları (Türkçe, Mat, Tarih, Coğrafya, Vatandaşlık) | `lib/widgets/daily_mission_center.dart` | Ücretsiz |
| **Günün mini denemesi** | 20 soru; CTA «Denemeye Başla / Sıralamanı Gör» + 657 logo daireyi doldurur; kürsü PNG paylaşımı (ortada soluk Hedef Kamu); **Heyecan Dorukta!** → sayaç 4’te **İŞTE SIRALAMAN** → **BUGÜNKÜ SIRALAMAN** (en az 1 cevap); boş gönderim sıralamaya girmez; 00:00–06:00 dünün liderleri; demo seed kürsüde yok; **EN BAŞARILILAR** altta sabit **Bu ayın yanlış çözümleri** + **Devam Et** | `lib/widgets/daily_mini_exam/`, `lib/screens/quiz_screen.dart`, `lib/screens/daily_mini_exam_result_screen.dart`, `lib/services/daily_mini_exam_service.dart`, `backend/content/views.py`, `backend/content/daily_mini_exam.py` | Ücretsiz (misafir: ilk gün) |
| **Deneme paketleri vitrini** | Dersler sekmesi **en altında**; yumuşak yatay kaydırma; ortalanmış başlık | `lib/widgets/exam_pack_showcase.dart`, `lib/services/exam_pack_service.dart`, `GET /api/v1/exam-packs/` | Ücretsiz vitrin |
| **Mini deneme PDF upsell** | Sonuç sonrası Premium yönlendirmesi (aylık yanlış varsa) | `daily_mini_exam_result_screen.dart` | Upsell |
| **Tasarruf içgörüsü** | Ücretsiz testlerin tahmini TL değeri; 20 test kilometre taşı | `lib/widgets/savings_insight_banner.dart`, `lib/services/user_savings_insight_service.dart` | Ücretsiz |

---

### Akıllı tekrar ve yanlış defteri

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Akıllı tekrar** | Günlük 15 soruluk aralıklı tekrar seti (yanlışlar → vadesi gelen → zayıf konular) | `lib/screens/smart_review_screen.dart`, `lib/services/smart_review_service.dart` | Ücretsiz |
| **Yanlış defteri** | Konu testlerinden yanlışlar; **kullanıcı başına yerel** (SharedPreferences scope); karttan onaylı **kaldır**; karta tıklayınca inceleme (**Çıkış**, işaretli şık, **Not Al**). Normal testte işaretsiz + «Daha önce»; bitmiş test yanlışları sonradan doğru cevaplansa istatistik değişmez. **Akıllı Tekrar** başlık altında; **Kitaptaki Yanlışlarım** pembe butonu ile manuel foto sorular ayrı ekranda (ders filtresi). **Manuel foto soru:** kamera/galeri ile eklenir; **YANLIŞ SORULARIM** formunda ders/konu müfredattan zorunlu seçilir (ders → konular); not opsiyonel; uygulama özel dizininde tutulur (galeriye düşmez), durum etiketi (**Yeni / Tekrar Et / Çözüldü**) değiştirilebilir. **Misafir:** yalnızca soru metni hafif buzlu; karta dokununca giriş; kalp/BENZER açık | `lib/screens/wrong_questions_screen.dart`, `lib/screens/wrong_notebook_manual_screen.dart`, `lib/widgets/wrong_notebook/`, `lib/widgets/quiz_take_note_button.dart`, `lib/services/question_note_service.dart`, `lib/services/content_bank_service.dart`, `lib/services/manual_question_service.dart` | Ücretsiz; misafir metin hafif buzlu |
| **Benzer sorular** | Embedding tabanlı benzer soru seti (API); kaynak soru ve %88+ aynı kök metinli kopyalar hariç | `wrong_questions_screen.dart`, `QuestionFetchService.fetchSimilar`, `backend/content/embeddings.py` | **Premium** |
| **Boş kasa CTA** | Yanlış yokken 3 adımlı boş durum; şampanya etiket «Yanlış defteriyle deneme oluşturabilirsin»; ana CTA «Derslerden test çöz» | `lib/widgets/wrong_notebook/wrong_notebook_empty_state.dart` | Ücretsiz |

---

### Gelişim ve analitik

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Gelişim sekmesi** | Genel doğruluk (yalnızca konu testleri; mini deneme sayılmaz), yatay kaydırmalı ders kartları + nokta göstergesi, çalışma kasası; **Puan Hesaplama yok** | `lib/screens/analytics_hub_screen.dart`, `lib/services/performance_summary_service.dart` | Ücretsiz |
| **Ders analitiği** | Tek ders için konu/test geçmişi | `lib/screens/subject_analytics_detail_screen.dart` | Ücretsiz |
| **Çalışma kasası** | Yanlış / Favoriler / Notlar kısayolları | `lib/widgets/analytics_study_vault.dart` | Ücretsiz |
| **Favorilerim** | Soru favorileri + özet kartlar (Favori / Tekrar Et); soru orijinal test bağlamında açılır | `favorites_screen.dart`, `summary_card_progress_service.dart` | Ücretsiz |
| **Notlarım** | Ders etiketli çalışma notları (CRUD) | `lib/screens/notes_screen.dart`, `lib/services/notes_service.dart` | Ücretsiz |
| **Hesap bağlama kartı** | Google bağlamadan önce uyarı | `lib/widgets/account_link_card.dart` | Ücretsiz |

---

### Deneme analizi

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Deneme sekmesi** | AppBar’da dar, ortalanmış kompakt **PUAN HESAPLAMA** (`+` yok); FAB ile deneme ekleme | `lib/screens/premium/statistics_screen.dart`, `lib/widgets/puan_hesaplama_button.dart` | Sekmeden **ücretsiz**¹ |
| **Puan Hesaplama** | GY/GK net ve puan; etiketler **GY-Net** / **GK-Net** | `lib/screens/puan_hesaplama_screen.dart` | Ücretsiz |
| **Genel bakış** | Haftalık özet, net gelişim grafiği, GK/GY ayrımı | `lib/widgets/statistics_overview_tab.dart`, `lib/widgets/net_development_chart.dart` | Bkz. ¹ |
| **Yayınevleri** | Yayınevine göre performans karşılaştırma | `lib/widgets/statistics_publishers_tab.dart` | Bkz. ¹ |
| **Denemeler listesi** | Manuel deneme ekleme / silme | `lib/widgets/statistics_exams_tab.dart` | Bkz. ¹ |
| **Deneme ekleme** | GK/GY ders bazlı doğru/yanlış/boş → net hesabı | `lib/screens/premium/add_exam_sheet.dart`, `lib/services/practice_exam_service.dart` | Bkz. ¹ |
| **Haftalık özet bildirimi** | Yeni deneme eklenince yerel bildirim yenileme | `lib/services/notification_service.dart` | Premium odaklı |

> ¹ **Not:** Paywall ve ana sayfa araç listesinde “Deneme Analizi Pro” **Premium** olarak tanımlı; alt sekme şu an **PremiumGate olmadan** açılıyor. Pazarlama metni ile gerçek kapı farklı olabilir.

---

### Premium modüller

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Premium paywall** | Aylık/yıllık Google Play abonelik, özellik listesi, promosyon kodu | `lib/screens/premium/premium_paywall_screen.dart`, `lib/services/play_billing_service.dart` | Satın alma |
| **Promosyon kodu** | Backend’den Premium süresi; misafir kullanamaz; kod en fazla 32 karakter; 5/dk | `lib/services/promo_code_service.dart` | Google hesabı |
| **Konu takibi** | Müfredat maddelerini işaretleme, ilerleme yüzdesi | `lib/screens/premium/topic_tracking_screen.dart`, `lib/services/topic_progress_service.dart` | Premium |
| **Görev yönetimi** | Haftalık görevler, öncelik, tamamlama/silme | `lib/screens/premium/task_management_screen.dart`, `lib/services/task_service.dart` | Premium |
| **Odak · Pomodoro** | 25/50/90/özel dk, ortam sesleri, tamamlanınca XP | `lib/screens/premium/focus_mode_screen.dart`, `lib/services/pomodoro_service.dart` | Premium (araçlar menüsü) |
| **Bulut senkron** | Google/Apple senkron arayüzü (**mock**) | `lib/screens/premium/cloud_sync_screen.dart`, `lib/services/cloud_sync_service.dart` | Premium |
| **Offline paket** | Tüm soru paketini çevrimdışı indirme | `lib/screens/premium/offline_pack_screen.dart`, `lib/services/offline_pack_service.dart` | **Yıllık Premium** |
| **Sıralama** | Haftalık/aylık XP sıralaması (**demo veri**) | `lib/screens/premium/leaderboard_screen.dart`, `lib/services/leaderboard_service.dart` | Premium |
| **Premium kapısı** | Paywall’a yönlendirme yardımcısı | `lib/widgets/premium_gate.dart` | — |
| **Benzer sorular** | Yanlış defterinden embedding benzeri | `wrong_questions_screen.dart` | Premium |
| **Sınırsız test** | Günlük ders kotası kalkar | `content_bank_service.dart` | Premium |

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
| **Profil ekranı** | Avatar, ad, XP/streak/PREMIUM chip’leri; premium değilse hero’da kompakt “Premium’a Geç” pill (PREMIUM chip ile aynı stil); avatar altında Rozetler; Mesajlar/Duyurular; sağ üstte “Değerlendir” (giriş yapmış kullanıcı); modül listesi | `lib/screens/profile_screen.dart` |
| **Premium üyelik bilgisi** | Hero’daki PREMIUM chip köşesindeki bilgi ikonu → veriliş/bitiş tarihi bottom sheet | `profile_screen.dart` |
| **Google hesap bağlama** | Anonim → kalıcı Google hesabı | `lib/widgets/account_link_card.dart`, `lib/services/auth_service.dart` |
| **Görünen ad düzenleme** | Bağlı hesap gerekir | `profile_screen.dart` |
| **Tema** | Açık / koyu / sistem | `lib/widgets/theme_preference_picker.dart`, `lib/services/theme_preference_service.dart` |
| **Sınav hedefi değiştirme** | Geri sayım hedefini yeniden seçme | `lib/widgets/exam_track_picker_sheet.dart` |
| **Bildirim ayarları** | Sabah/akşam/haftalık aç-kapa (duyuru ve tasarruf sabit açık) | `lib/widgets/notification_settings_section.dart`, `lib/services/notification_preference_service.dart` |
| **Duyurular** | Admin yayınları; **Okundu** yalnızca kullanıcı açınca. **İlk kurulumdan önceki** duyurular profil listesinde yok | `lib/screens/announcements_screen.dart`, `lib/services/announcement_service.dart` |
| **Mesajlarım** | Doğrudan admin mesajları; **kurulumdan önceki** mesajlar profilde yok | `lib/screens/user_messages_screen.dart`, `lib/services/user_message_service.dart` |
| **Destek ve İletişim** | Deneme paketi talepleri; soru hata bildirimi (uyarı kartı); **İletişime Geç** ile destek e-postası (alıcı, konu, cihaz/sürüm/üyelik otomatik) — ekranda adres gösterilmez | `lib/screens/support_contact_screen.dart`, `lib/services/support_contact_service.dart` |
| **Çıkış** | Oturumu kapat (misafir değilse) | `profile_screen.dart` |

---

### Diğer araçlar

| Özellik | Açıklama | Dosyalar | Not |
|---|---|---|---|
| **Mikro öğrenme** | Kısa ders + mini quiz | `lib/screens/study_and_solve_screen.dart` | **Demo içerik** |
| **Güncel bilgiler** | Hikâye tarzı kartlar | `lib/screens/current_info_screen.dart` | **Yerel mock** |
| **Reklamsız kampanya** | 3 ödüllü reklam → 12 saat **quiz banner** yok; çözüm kilidi, günlük kota, benzer soru, sınırsız test, offline, konu takibi, pomodoro **açılmaz** | `lib/widgets/ad_free_campaign_card.dart`, `lib/services/ad_free_campaign_service.dart`, `lib/services/ad_manager.dart` | Ödüllü reklam |

---

### Kimlik doğrulama ve güvenlik

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Yerel misafir oturumu** | Çevrimdışı öncelikli yer tutucu kullanıcı | `lib/services/auth_service.dart` |
| **Anonim backend oturumu** | Firebase anonim + Django `AppUser` token | `auth_service.dart`, `backend/content/auth.py` |
| **Google giriş / bağlama** | ID token → `POST /api/v1/auth/google/`; hesap zaten bağlıysa `signInWithCredential`; beklemede **Giriş Yapılıyor…** | `auth_service.dart`, `login_screen.dart` |
| **Profil senkronu** | `GET/PATCH /api/v1/me/` — Premium bayrağı, görünen ad (haftada en fazla 1 değişiklik) | `backend/content/views.py` |
| **Ağ güvenliği engeli** | VPN/DNS/reklam engelleyici tespiti → ücretsiz kullanıcıda kilit; Play veya panel Premium süresince serbest | `lib/services/network_security_service.dart`, `lib/services/network_security_gate.dart`, `lib/screens/security_warning_modal.dart` |
| **Ekran görüntüsü yasağı** | Android `FLAG_SECURE` — ücretsiz ve Premium’da yasak (debug / geliştirici cihazı hariç) | `android/app/src/main/kotlin/com/hedefkamu/hedef_kamu/MainActivity.kt` |

---

### Reklam ve gelir modeli (mobil)

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **AdManager** | Quiz banner; geçiş interstitial; kampanya yalnızca banner kapatır | `lib/services/ad_manager.dart`, `lib/services/ad_constants.dart` |
| **AdService** | UI katmanının tek giriş noktası (doğrudan AdMob widget’ı yok) | `lib/services/ad_service.dart` |
| **Ödüllü reklam türleri** | `campaign` (12s banner’sız), `solutionUnlock`, `dailyTestBonus` | `ad_service.dart` |
| **Play Billing** | Abonelik, geri yükleme, Premium önbellek | `lib/services/play_billing_service.dart` |
| **PremiumService** | Play Billing **veya** sunucu `isPremium` — tek doğruluk kaynağı | `lib/services/premium_service.dart` |

---

### Bildirimler

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **Yerel bildirimler** | Sabah motivasyon (09:00), akşam (21:00), haftalık özet (Pazar 15:00), mini deneme, tasarruf kilometre taşı | `lib/services/notification_service.dart` |
| **FCM push** | Duyuru konusu, içerik güncelleme sessiz senkron | `lib/services/push_notification_service.dart` |
| **Cihaz token kaydı** | FCM token → `POST /api/v1/device-tokens/` | `push_notification_service.dart` |
| **İçerik güncelleme handler** | Push sonrası katalog yeniden senkron | `push_notification_service.dart` |

---

### Çevrimdışı ve yerel depolama

| Özellik | Açıklama | Dosyalar |
|---|---|---|
| **SQLite** | Deneme kayıtları, yanlış defteri, deneme geçmişi (365 gün) | `lib/services/local_database.dart`, `lib/services/database_bootstrap.dart` |
| **SharedPreferences** | Tercihler, oyunlaştırma, offline paket meta, boot store | `lib/services/app_preferences.dart` ve ilgili servisler |
| **Offline paket** | Tam içerik paketi indirme | `lib/services/offline_pack_service.dart` |
| **İçerik bankası önbelleği** | Yayınlanmış soru/test kataloğu bellek + disk | `lib/services/content_bank_service.dart` |

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
| **Özet konu kartı** CRUD (formül / püf / ÖSYM) | `/panel/konu/<id>/ozet/...` |
| Test CRUD, soru atama | `/panel/konu/<id>/test/...` |
| Senaryo grupları (ortak paragraf) | `/panel/konu/<id>/grup/...` |
| Soru CRUD (kök, A–E, çözüm, görsel, SVG, zorluk, ÖSYM) | `/panel/konu/<id>/soru/...` |
| Soru kopyalama | `/panel/soru/<id>/kopyala/` |
| Toplu soru silme | `/panel/konu/<id>/soru/toplu-sil/` |
| **Uygulama önizlemesi** | Canlı mobil benzeri önizleme — `question-preview.js`, `math-render.js`, `rich-format.js` |
| Tablo / eşleştirme şıkları | `A - B - C` veya `İnanç: …, Mağara: …, Termal: …`; başlık şıktan; dikey çizgi yok | `option-table.js`, `option-table.css` |
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
| İl boyama | Koordinatlı Türkiye haritasında **İl boya** ile ili tıklayıp doldurma (ÖSYM bölge boyama); komşu aynı renk birleşir | `_question_map_editor.html`, `map-question-editor.js`, `map_provinces.py`, `turkiye_iller.json` |
| Soru formu editörü | Şablon seç, `[HARITA]` yerleştir (düğme soru metnine yazar; şablon yoksa uyarı), elips/daire koy; seçili işareti **Delete / Backspace** siler | `_question_map_editor.html`, `map-question-editor.js` |
| Elips | **Elips ekle** varsayılan kapalı; seçilince haritaya tıklayarak konur. Romen numarası varsayılan kapalı (karttan açılabilir). Seçilince kenar tutaçlarıyla boyut, yeşil tutaçla 0–179° dönüş | `map-question-editor.js` |
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
| İncelenecek sorular (hata bildirimleri) | `/panel/incelenecek-sorular/` |
| Bildirim durumu güncelleme | `/panel/hata-bildirimi/<id>/durum/` |

### Kullanıcı, premium, iletişim

| Özellik | URL |
|---|---|
| Kullanıcı listesi (filtre, toplu sil, misafir temizle) | `/panel/kullanicilar/` |
| Premium ver / kaldır | `/panel/kullanici/<id>/premium/` |
| **Promosyon kodları** (liste / yeni / düzenle / sil / aktif-pasif) | `/panel/promosyon/` |
| Duyuru CRUD + push gönder | `/panel/duyuru/...` |
| Mobil arayüz (yanlış defteri balonu aç/kapa, metin) | `/panel/mobil-arayuz/` |
| Sınav türleri CRUD (geri sayım kataloğu) | `/panel/sinavlar/...` |
| Deneme dağılım şablonu CRUD | `/panel/deneme-sablon/...` |
| Deneme paketi düzenle / sil / aktif-pasif (Dersler vitrini) + şablondan üret | `/panel/deneme-paket/...` |

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
| `GET /pack/version/` | İçerik paketi sürümü | Hayır | `ContentSyncService` |
| `GET /pack/` | Tam yayın paketi (`summaryCards` dahil) | Hayır | `ContentSyncService` |
| `GET /catalog/` | Hafif katalog meta (`summaryCards` dahil) | Hayır | `ContentBankService` |
| `GET /curriculum/` | Müfredat yapısı | Hayır | — |
| `GET /questions/?ids=` | ID ile soru gövdeleri | Hayır | `QuestionFetchService` |
| `GET /questions/<id>/similar/` | Benzer sorular (limit 5) | Hayır | Yanlış defteri (Premium) |
| `GET/POST /questions/<id>/rating/` | Yıldız puanı | Bearer | `QuestionRatingService` |
| `POST /questions/<id>/attempt/` | Soru denemesi logu | Bearer | `QuestionAttemptService` |
| `GET/POST /questions/<id>/error-report/` | Hata bildirimi (Google; misafir 401) | Bearer (Google) | `QuestionErrorReportService` |
| `GET /tests/` | Yayın test listesi | Hayır | Katalog |
| `GET /tests/<id>/questions/` | Test soruları | Hayır | `QuestionFetchService` |
| `POST /tests/<id>/attempt/` | Test tamamlama | Bearer | Quiz |
| `GET /announcements/` | Aktif duyurular | Hayır | `AnnouncementService` |
| `GET /mobile-ui/` | Mobil arayüz ayarları (yanlış defteri balonu) | Hayır | `AppConfigService` |
| `POST /device-tokens/` | FCM token | Opsiyonel | `PushNotificationService` |
| `POST /auth/google/` | Google giriş | Hayır | `AuthService` |
| `GET/PATCH /me/` | Profil | Bearer | `AuthService` |
| `GET/PATCH/DELETE /me/messages/` | Kullanıcı mesajları | Bearer | `UserMessageService` |
| `GET/POST /daily-mini-exam/` | Mini deneme + gönderim | Opsiyonel/Bearer | `DailyMiniExamService` |
| `POST /promo/redeem/` | Promosyon kodu (Google; 5/dk; max 32) | Bearer (Google) | `PromoCodeService` |
| `GET /exam-types/` | Sınav geri sayım kataloğu | Hayır | `ExamCatalogService` |
| `GET /exam-packs/?exam_type=` | Yayınlanmış deneme paketleri | Hayır | `ExamPackService` |
| `GET /exam-packs/<id>/` | Paket detayı + deneme listesi | Hayır | `ExamPackService` |
| `GET /exam-packs/<id>/exams/<n>/questions/` | Paket denemesi soruları (Google zorunlu; max %20 daha önce çözülmüş) | Bearer (Google) | `ExamPackService` |

**Yasal:** `GET /gizlilik-politikasi/` — `backend/content/legal_views.py`

---

## Erişim matrisi

| Yetenek | Ücretsiz | Ödüllü reklam | Premium | Yıllık Premium |
|---|---|---|---|---|
| Müfredat ve ders okuma | ✓ | | | |
| Ders başına 1 test/gün | ✓ | | | |
| +1 bonus test/gün (derse özel) | | ✓ | | |
| Sınırsız konu testi | | | ✓ | ✓ |
| Quiz banner reklamı | ✓ | 12s kampanya | Bypass | Bypass |
| Sayfa geçiş interstitial | ✓ | | Bypass | Bypass |
| Çözüm kilidi açma | | ✓ | ✓ | ✓ |
| 12 saat banner’sız (3 reklam) | | ✓ | Bypass | Bypass |
| Günün mini denemesi | ✓ (reklamsız oturum) | | ✓ | ✓ |
| Akıllı tekrar | ✓ | | | |
| Yanlış defteri listesi | ✓ (misafir: yalnızca soru metni hafif buzlu) | | | |
| Benzer sorular | | | ✓ | ✓ |
| Favoriler ve notlar | ✓ | | | |
| Özet konu kartları (kaydır / favori / tekrar) | ✓ | | | |
| Gelişim merkezi | ✓ | | | |
| Deneme analizi | ✓ (sekme)¹ / Premium (ana menü) | | Pazarlama: ✓ | ✓ |
| Deneme paketleri (IAP) | Google hesabı + satın alma | | Google hesabı + satın alma | Google hesabı + satın alma |
| Konu takibi, görevler, pomodoro | | | ✓ | ✓ |
| Bulut senkron UI | | | ✓ (mock) | ✓ |
| Sıralama | | | ✓ (demo) | ✓ |
| Offline paket | | | | ✓ |
| Filigran | ✓ (tüm planlar) | | ✓ | ✓ |
| Promosyon Premium | | | ✓ | ✓ |

---

## Veri modelleri (özet)

`backend/content/models.py`:

- **Müfredat:** `Subject`, `Topic`, `TopicLesson`, `TopicSummaryCard`, `TopicTest`
- **İçerik:** `Question`, `QuestionScenario`, `MapTemplate`
- **Kullanıcı:** `AppUser`, `DeviceToken`, `UserMessage`
- **Etkileşim:** `QuestionRating`, `QuestionAttempt`, `QuestionErrorReport`
- **Mini deneme:** `DailyMiniExam`, `DailyMiniExamAttempt`
- **Operasyon:** `Announcement`, `ExamType`, `PromoCode`, `PromoCodeRedemption`, `OcrIngestLog`, `ContentRevision`
- **Deneme paketleri:** `ExamDistributionTemplate`, `ExamPack`, `ExamPackExam`, `ExamPackExamQuestion`
- **Embedding:** `Question.embedding` (JSON)

Mobil JSON alan eşlemesi: `backend/content/serializers.py` ↔ `lib/models/question_model.dart` (ör. `stem` → `soruMetni`).

---

## Bilinen sınırlamalar

1. **Bulut senkron** ve **sıralama** arayüzü hazır; backend entegrasyonu kısmen mock/demo.
2. **Mikro öğrenme** ve **güncel bilgiler** yerel/demo içerik kullanır (Django soru bankası değil).
3. **Deneme analizi** premium kapısı sekme ile ana menü arasında tutarsız olabilir.
4. **Instagram Reels** yalnızca backend servisi; panel UI yok.
5. **Anonim oturum** çevrimdışı çalışmayı destekler; senkron özellikler backend oturumu ister.
6. Soru metni/şık/çözüm **mobil kodda hardcode edilmez** — kaynak Django (`QuestionFetchService`, `ContentBankService`).
7. **Play Store / release APK** yalnızca `armeabi-v7a` + `arm64-v8a` (telefon); x86_64 emülatör bu release’i çalıştırmaz. Hedef paket **≤80 MB**.

---

## Sürüm notu (2026-08-20)

Bu sürümde öne çıkanlar (ayrıntı: [20 Ağustos 2026](#20-ağustos-2026--işlenen-ekleme-ve-değişiklikler-bu-commit)):

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
