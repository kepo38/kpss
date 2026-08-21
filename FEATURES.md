# Hedef Kamu (KPSS Akademi) — Özellik Kataloğu

> **Son güncelleme:** 2026-08-21  
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
| Premium / reklam / kota değiştiğinde | [Erişim matrisi](#erişim-matrisi) bölümünü güncelle |
| Panel veya admin akışı değiştiğinde | [İçerik paneli](#i̇çerik-paneli-panel) veya [Unfold admin](#unfold-admin-admin) bölümünü güncelle |
| Özellik kaldırıldığında | Maddenin yanına `(kaldırıldı)` notu veya silme |

**Referans dosyalar:** `lib/screens/`, `lib/services/`, `lib/widgets/`, `backend/content/`

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
| **Finalize** | Idempotent; push + `UserMessage`; `--auto` / `--all-kpss` | `finalize_daily_mini_ranking.py`, `finalize-mini-oduller.bat` |
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
| **Mini deneme ödülleri** | Menü **Deneme & sınav**; aç-kapa; manuel finalize; kazanan tablosu | `/panel/mini-deneme-odulleri/`, `daily_mini_ranking.html`, `base.html` |
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
| **Header / Akıllı Tekrar** | **Akıllı Tekrar** sağ üst pill; **Kitaptaki** butonu iki satır (KİTAPTAKİ / YANLIŞLARIM), dar; istatistik alt yazısı konu testlerine göre | `wrong_notebook_header.dart`, `wrong_questions_screen.dart` |
| **Kitaptaki yanlışlarım** | Pembe giriş → ayrı ekran; üstte kompakt premium **SORU EKLE** foto butonu; boş ekran başlığı **Yanlış Sorularını Takip Et!** | `wrong_notebook_manual_screen.dart`, `WrongNotebookAddQuestionAction` |
| **Manuel foto soru** | Kamera/galeri; meta sheet **YANLIŞ SORULARIM**; ders→konu müfredattan zorunlu; not opsiyonel; uygulama özel dizini (galeriye düşmez); durum: Yeni / Tekrar Et / Çözüldü | `manual_question_model.dart`, `manual_question_service.dart`, `wrong_notebook_manual_meta_sheet.dart` |
| **Defter inceleme** | Karta tıklayınca süre ve Soru 1/1 yok; **Çıkış**; işaretli şık; **Not Al** + «KAYITLI KALIR»; normal testte «Daha önce» | `quiz_take_note_button.dart`, `quiz_question_note_card.dart`, `quiz_wrong_notebook_banner.dart`, `question_note_service.dart` |
| **Defter kayıtlı toast** | Konu testi + günlük denemede ortada premium toast (~3 sn): «YANLIŞ DEFTERİMDE / KAYITLI»; **Akıllı Tekrar**’da yok (`suppressWrongNotebookHint`) | `quiz_wrong_notebook_banner.dart`, `quiz_screen.dart`, `smart_review_screen.dart` |
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
| **Misafir yanlış defteri** | Yalnızca **soru metni** hafif buzlu; kalp, sil, BENZER açık. Karta dokununca Google ister; **bağlanınca defter Google hesabına aktarılır**, buz kalkar, soru açılır | `wrong_notebook_guest_frost.dart`, `content_bank_service.dart` (scope migrate), `question_note_service.dart`, `manual_question_service.dart`, `wrong_questions_screen.dart` |
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
| **Soru kökü render** | Zengin metin, LaTeX (`flutter_math_fork`), görsel, SVG şekil; soft satırlar birleşir; **TextAlign.justify** (Android/iOS) | `question_stem_content.dart`, `exam_stem_view.dart`, `formatted_text.dart` (`prepareExamJustifyText`) | Ücretsiz |
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

Panel önizlemesi CSS: `--exam-serif`, `--exam-math`, `--exam-sans` (`panel.css`). Şık metni soldan hizalı. Eşleştirme şıkları **2+ sütun**: `Olay — Sonuç`, `Şehir - Şehir - Şehir` veya `İnanç: …, Mağara: …, Termal: …`; başlık yoksa 2 sütunda **Olay / Sonuç** (`option-table.js` / `option_column_layout.dart`).

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
| **Yanlış defteri** | Konu testlerinden yanlışlar; kullanıcı başına yerel; karttan kaldır; inceleme (**Çıkış**, işaretli şık, **Not Al**). Normal testte «Daha önce» toast. **Akıllı Tekrar** pill (başlat Premium). **Kitaptaki Yanlışlarım:** manuel foto; **1. foto ücretsiz**, **2.+** Pro değilse ödüllü reklam; **kalem/annotate ücretsiz**. Misafir: metin buzlu → Google’da aktarım | `wrong_questions_screen.dart`, `wrong_notebook_manual_screen.dart`, `manual_question_annotate_viewer.dart`, `wrong_notebook/*`, `quiz_wrong_notebook_banner.dart` | Liste/annotate **ücretsiz**; benzer **Premium**; ekstra foto **reklam veya Premium** |
| **Benzer sorular** | Embedding tabanlı benzer set; kaynak + %88+ aynı kök hariç; ücretsizde `ProUpsellSheet` | `wrong_questions_screen.dart`, `pro_upsell_sheet.dart`, `embeddings.py` | **Premium** |
| **Boş kasa CTA** | Yanlış yokken 3 adımlı boş durum; şampanya etiket «Yanlış defteriyle deneme oluşturabilirsin»; ana CTA «Derslerden test çöz» | `lib/widgets/wrong_notebook/wrong_notebook_empty_state.dart` | Ücretsiz |

---

### Gelişim ve analitik

| Özellik | Açıklama | Dosyalar | Erişim |
|---|---|---|---|
| **Gelişim sekmesi** | Genel doğruluk (yalnızca konu testleri; mini deneme sayılmaz), yatay kaydırmalı ders kartları + nokta göstergesi, çalışma kasası; **Puan Hesaplama yok** | `lib/screens/analytics_hub_screen.dart`, `lib/services/performance_summary_service.dart` | Ücretsiz |
| **Ders analitiği** | Tek ders için konu/test geçmişi | `lib/screens/subject_analytics_detail_screen.dart` | Ücretsiz |
| **Çalışma kasası** | Yanlış / Favoriler / Notlar kısayolları | `lib/widgets/analytics_study_vault.dart` | Ücretsiz |
| **Favorilerim** | Soru favorileri + özet kartlar (Favori / Tekrar Et); özet karta tıklanınca tam ekran kart görüntüleyici; soru orijinal test bağlamında açılır | `favorites_screen.dart`, `topic_summary_swipe_deck.dart` (`SummaryCardFace.showViewer`), `summary_card_progress_service.dart` | Ücretsiz |
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
| **Offline paket** | Tüm soru paketini çevrimdışı indirme | `lib/screens/premium/offline_pack_screen.dart`, `lib/services/offline_pack_service.dart` | **Yalnızca yıllık Premium** (`canUseOfflinePack`) |
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
| **Profil ekranı** | Avatar, ad, XP/streak/PREMIUM chip’leri; premium değilse hero’da kompakt “Premium’a Geç” pill (PREMIUM chip ile aynı stil); avatar altında Rozetler; Mesajlar/Duyurular; sağ üstte “Değerlendir” (giriş yapmış kullanıcı); modül listesi | `lib/screens/profile_screen.dart` |
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
| **Özet konu kartı** CRUD (formül / püf / ÖSYM; görsel; stüdyo önizleme) | `/panel/ozet-kart/`, `/panel/konu/<id>/ozet/...` |
| Test CRUD, soru atama | `/panel/konu/<id>/test/...` |
| Senaryo grupları (ortak paragraf) | `/panel/konu/<id>/grup/...` |
| Soru CRUD (kök, A–E, çözüm, görsel, SVG, zorluk, ÖSYM) | `/panel/konu/<id>/soru/...` |
| Soru kopyalama | `/panel/soru/<id>/kopyala/` |
| Toplu soru silme | `/panel/konu/<id>/soru/toplu-sil/` |
| **Uygulama önizlemesi** | Canlı mobil benzeri önizleme — `question-preview.js`, `math-render.js`, `rich-format.js` |
| Tablo / eşleştirme şıkları | **2+ sütun**: `X — Y` (varsayılan başlık **Olay / Sonuç**) veya `A - B - C` / `İnanç: …, Mağara: …, Termal: …`; stem pipe / `<!--optcols:…-->` varsa onlar; dikey çizgi yok | `option-table.js`, `option-table.css`, `option_column_layout.dart` |
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
| İncelenecek sorular (hata bildirimleri) | `/panel/incelenecek-sorular/` |
| Bildirim durumu güncelleme | `/panel/hata-bildirimi/<id>/durum/` |

### Kullanıcı, premium, iletişim

| Özellik | URL |
|---|---|
| Kullanıcı listesi (filtre, toplu sil, misafir temizle) | `/panel/kullanicilar/` |
| Premium ver / kaldır | `/panel/kullanici/<id>/premium/` |
| **Promosyon kodları** (liste / yeni / düzenle / sil / aktif-pasif) | `/panel/promosyon/` |
| Duyuru CRUD + big-picture push önizleme | `/panel/duyuru/...`, `announcement-push-preview.*` |
| Mobil arayüz (yanlış defteri balonu aç/kapa, metin) | `/panel/mobil-arayuz/` |
| Sınav türleri CRUD (geri sayım kataloğu) | `/panel/sinavlar/...` |
| Deneme dağılım şablonu CRUD | `/panel/deneme-sablon/...` |
| Deneme paketi düzenle / sil / aktif-pasif (Dersler vitrini) + şablondan üret | `/panel/deneme-paket/...` |
| **Mini deneme ödülleri** (haftalık/aylık aç-kapa, manuel finalize, kazananlar) | `/panel/mini-deneme-odulleri/` |

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
| `GET /daily-mini-exam/period-ranking/` | Haftalık/aylık sıralama (`period`, `kpss_type`) | Opsiyonel/Bearer | `DailyMiniRankingService` |
| `GET /daily-mini-exam/reward-history/` | Finalize edilmiş dönem kazananları | Opsiyonel/Bearer | `DailyMiniRankingService` |
| `POST /promo/redeem/` | Promosyon kodu (Google; 5/dk; max 32) | Bearer (Google) | `PromoCodeService` |
| `GET /exam-types/` | Sınav geri sayım kataloğu | Hayır | `ExamCatalogService` |
| `GET /exam-packs/?exam_type=` | Yayınlanmış deneme paketleri | Hayır | `ExamPackService` |
| `GET /exam-packs/<id>/` | Paket detayı + deneme listesi | Hayır | `ExamPackService` |
| `GET /exam-packs/<id>/exams/<n>/questions/` | Paket denemesi soruları (Google zorunlu; max %20 daha önce çözülmüş) | Bearer (Google) | `ExamPackService` |

**Yasal:** `GET /gizlilik-politikasi/` — `backend/content/legal_views.py`

---

## Erişim matrisi

Kaynak doğruluk: `PremiumService` (Play Billing **veya** sunucu/panel `isPremium` / promo / ödül günleri). Reklam bypass: `AdManager.setPremium`. Offline indirme: yalnızca `isYearlyPremium` / `canUseOfflinePack`.

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
| **Çözüm tam açma** | Önizleme; tam çözüm kilitli | ✓ (`solutionUnlock`) | ✓ anında | ✓ |
| **Filigran** | ✓ | ✓ | ✓ | ✓ |
| **Hata bildirimi** | Google + **5** bitmiş konu testi; 1/gün | | Google + **3** bitmiş test; 1/gün | aynı |
| Favoriler, notlar, çalışma kasası | ✓ | | ✓ | ✓ |
| Gelişim sekmesi / ders analitiği | ✓ | | ✓ | ✓ |
| Deneme sekmesi + puan hesaplama | ✓¹ | | ✓ | ✓ |
| Stüdyo «Deneme Analizi» satırı | `PremiumGate` | | ✓ | ✓ |
| VPN/DNS ağ kilidi | Kilitlenebilir | | **muaf** | **muaf** |
| Ekran görüntüsü (`FLAG_SECURE`) | Yasak | | Yasak | Yasak |

> ¹ Alt **Deneme** sekmesi `PremiumGate` olmadan açılır; Stüdyo listesinde aynı ekran Premium kapılı. Pazarlama / kapı farkı bilinçli not.

### B) Yanlış defteri ve Akıllı Tekrar

| Yetenek | Ücretsiz | Ödüllü reklam | Premium | Yıllık |
|---|---|---|---|---|
| Yanlış defteri listesi / inceleme / Not Al | ✓ (misafir: metin buzlu) | | ✓ | ✓ |
| Defterden sil / kalp | ✓ | | ✓ | ✓ |
| **Benzer sorular** | Upsell sheet | | ✓ | ✓ |
| **Akıllı Tekrar ekranı** (paket özeti) | ✓ görüntüleme | | ✓ | ✓ |
| **AKILLI TEKRARI BAŞLAT** | Paywall | | ✓ | ✓ |
| Kitaptaki yanlışlar — **1. foto** | ✓ | | ✓ | ✓ |
| Kitaptaki — **2. ve sonraki foto** | | ✓ zorunlu | ✓ ücretsiz | ✓ |
| Kitaptaki — **kalem / annotate** | ✓ | | ✓ | ✓ |

### C) Stüdyo Premium suite (PRO kilit)

Stüdyo hub (`home_premium_module_list` + araçlarda pomodoro/analiz). Hepsi `PremiumGate.navigate` veya kendi ekranında yıllık kontrolü.

| Modül | Kapı | Not |
|---|---|---|
| **Offline Paket** | **Yalnızca yıllık** (`canUseOfflinePack`); aylık Premium’da kilit + «Yıllık Premium’a geç» | Tam pack indirme |
| **Konu Takibi** | Premium | Müfredat işaretleme |
| **Görev Yönetimi** | Premium | Haftalık plan |
| **Bulut Senkron** | Premium | UI; sync kısmen mock |
| **Sıralama** | Premium | Canlı haftalık/aylık toplam doğru (mini deneme API) |
| **Odak · Pomodoro** | Premium | Araçlar listesinde (`onNavigatePremium`) |
| **Deneme Analizi** (Stüdyo satırı) | Premium | Alt sekme ücretsiz¹ |

Paywall’da listelenen vaatler (`PremiumService.features`): Offline (yıllık), Konu Takibi, Odak/Pomodoro, Deneme Analizi Pro, Görev Yönetimi, Bulut Senkron, Sıralama. **Kodda ayrıca Premium olan ama paywall listesinde kısa geçenler:** Akıllı Tekrar başlat, Benzer sorular, sınırsız test, reklam bypass, çözüm kilidi, VPN muafiyeti, kitaptaki ekstra foto.

### D) Reklam kampanyası (Premium açmaz)

| Kampanya | Ne verir | Ne **açmaz** |
|---|---|---|
| 3 ödüllü reklam → **12 saat** | Yalnızca **quiz banner** kapalı | Çözüm kilidi, günlük kota, benzer, sınırsız test, offline, konu takibi, pomodoro, Akıllı Tekrar, VPN muafiyeti |

### E) Özet tablo (hızlı bakış)

| Yetenek | Ücretsiz | Ödüllü reklam | Premium | Yıllık Premium |
|---|---|---|---|---|
| Müfredat ve ders okuma | ✓ | | ✓ | ✓ |
| Ders başına 1 test/gün | ✓ | | | |
| +1 bonus test/gün | | ✓ | | |
| Sınırsız konu / özel test | | | ✓ | ✓ |
| Quiz banner | ✓ | 12s kampanya | Bypass | Bypass |
| Interstitial | ✓ | | Bypass | Bypass |
| Çözüm kilidi açma | | ✓ | ✓ | ✓ |
| Günün mini denemesi | ✓ | | ✓ | ✓ |
| Akıllı Tekrar **başlat** | | | ✓ | ✓ |
| Yanlış defteri listesi | ✓ | | ✓ | ✓ |
| Benzer sorular | | | ✓ | ✓ |
| Kitaptaki 1. foto / kalem | ✓ | | ✓ | ✓ |
| Kitaptaki 2.+ foto | | ✓ | ✓ | ✓ |
| Konu takibi, görev, pomodoro, sıralama, bulut UI | | | ✓ | ✓ |
| Deneme analizi (Stüdyo) | | | ✓ | ✓ |
| Deneme sekmesi | ✓¹ | | ✓ | ✓ |
| Offline paket | | | | ✓ |
| Filigran | ✓ | ✓ | ✓ | ✓ |
| Promosyon / ödül Premium günleri | | | ✓ | ✓ |

---

## Veri modelleri (özet)

`backend/content/models.py`:

- **Müfredat:** `Subject`, `Topic`, `TopicLesson`, `TopicSummaryCard`, `TopicTest`
- **İçerik:** `Question`, `QuestionScenario`, `MapTemplate`
- **Kullanıcı:** `AppUser`, `DeviceToken`, `UserMessage`
- **Etkileşim:** `QuestionRating`, `QuestionAttempt`, `QuestionErrorReport`
- **Mini deneme:** `DailyMiniExam`, `DailyMiniExamAttempt`, `DailyMiniRankingCampaign`, `DailyMiniRankingWinner`
- **Operasyon:** `Announcement`, `ExamType`, `PromoCode`, `PromoCodeRedemption`, `OcrIngestLog`, `ContentRevision`
- **Deneme paketleri:** `ExamDistributionTemplate`, `ExamPack`, `ExamPackExam`, `ExamPackExamQuestion`
- **Embedding:** `Question.embedding` (JSON)

Mobil JSON alan eşlemesi: `backend/content/serializers.py` ↔ `lib/models/question_model.dart` (ör. `stem` → `soruMetni`).

---

## Bilinen sınırlamalar

1. **Bulut senkron** arayüzü hazır; gerçek çok cihazlı sync backend’i kısmen mock.
2. **Mikro öğrenme** ve **güncel bilgiler** yerel/demo içerik kullanır (Django soru bankası değil).
3. **Deneme analizi** premium kapısı sekme ile ana menü arasında tutarsız olabilir.
4. **Instagram Reels** yalnızca backend servisi; panel UI yok.
5. **Anonim oturum** çevrimdışı çalışmayı destekler; senkron özellikler backend oturumu ister.
6. Soru metni/şık/çözüm **mobil kodda hardcode edilmez** — kaynak Django (`QuestionFetchService`, `ContentBankService`).
7. **Play Store / release APK** yalnızca `armeabi-v7a` + `arm64-v8a` (telefon); x86_64 emülatör bu release’i çalıştırmaz. Hedef paket **≤80 MB**.
8. **Mini deneme ödül finalize** otomatik için OS Task Scheduler / cron gerekir (`finalize-mini-oduller.bat` veya `manage.py … --auto`); panelden manuel de çalışır.
9. Canonical proje yolu **`D:\HEDEFKAMU`**; `D:\ozel\HEDEFKAMU` kopyası bat ile yönlendirilir — iki klonu aynı Gradle daemon ile açmayın.

---

## Sürüm notu (2026-08-21)

- **Premium:** Akıllı Tekrar başlat kapısı; FEATURES erişim matrisi A–E detaylandı
- **Kitaptaki yanlışlarım:** kalem ücretsiz; 2.+ foto reklam veya Pro
- **Splash:** siyah daire + içinde soluk `app_icon`
- **Stüdyo:** Premium’u keşfet / STÜDYO pill

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
