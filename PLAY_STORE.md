# Google Play Store — Premium Abonelik Kurulumu

KPSS Akademi yalnızca **Google Play** üzerinden premium abonelik satar.

**Android paket adı (applicationId):** `com.hedefkamu.hedef_kamu` — Play Console’da yeni uygulama oluştururken bu ID kullanılmalıdır.

## 1. Play Console'da Abonelik Oluşturma

1. [Google Play Console](https://play.google.com/console) → Uygulamanız
2. **Monetize → Products → Subscriptions**
3. Aşağıdaki ürünleri oluşturun:

| Product ID | Önerilen fiyat | Dönem |
|---|---|---|
| `kpss_premium_monthly` | ₺149,99 | Aylık |
| `kpss_premium_yearly` | ₺999,00 | Yıllık |

> Product ID'ler `lib/services/iap_constants.dart` ile birebir eşleşmelidir.

Her abonelik için en az bir **base plan** ekleyin ve fiyatlandırmayı Türkiye (TRY) için ayarlayın.

## 2. Test Hesapları

1. Play Console → **Setup → License testing**
2. Gmail test hesaplarınızı ekleyin
3. Test cihazında bu hesapla Play Store'a giriş yapın

## 3. Internal Testing Track

Abonelikler yalnızca en az **Internal testing** track'ine yüklenmiş bir APK/AAB ile test edilebilir:

```powershell
cd C:\Users\halit\Projects\kpss-akademi
flutter build appbundle --release
```

Oluşan dosya: `build/app/outputs/bundle/release/app-release.aab`

## 4. Uygulama İmzalama

Play Console'da **App signing** etkin olmalı. Release build için `android/key.properties` ve signing config ekleyin (Flutter docs: [Android deployment](https://docs.flutter.dev/deployment/android)).

## 5. Kod Yapısı

| Dosya | Görev |
|---|---|
| `lib/services/iap_constants.dart` | Play Console product ID'leri |
| `lib/services/play_billing_service.dart` | Satın alma, restore, premium durumu |
| `lib/screens/premium/premium_paywall_screen.dart` | Abonelik seçim UI |

## 6. Satın Alma Akışı

1. Kullanıcı premium modüle tıklar → paywall açılır
2. Aylık / yıllık plan seçilir → **Google Play ile Abone Ol**
3. Google Play ödeme ekranı açılır
4. Başarılı satın alma → premium aktif, reklamlar kapanır
5. **Satın Alımları Geri Yükle** → cihaz değişiminde restore

## 7. Production Güvenlik (Önerilen)

Şu an premium durumu cihazda `SharedPreferences` ile saklanır. Production için:

- `purchase.verificationData.serverVerificationData` backend'e gönderilmeli
- [Google Play Developer API](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptions) ile doğrulama yapılmalı
- Backend premium bitiş tarihini authoritative kaynak olarak tutmalı

## 8. Play Console Kontrol Listesi

- [ ] Abonelik ürünleri oluşturuldu ve **Active**
- [ ] Fiyatlandırma TRY olarak ayarlandı
- [ ] Internal test track'e AAB yüklendi
- [ ] License tester hesapları eklendi
- [ ] Gizlilik politikası URL'si Play Console'a girildi
- [ ] Abonelik iptal/yenileme metinleri paywall'da görünüyor
