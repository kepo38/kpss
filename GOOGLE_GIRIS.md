# Google / Play Store ile giriş

## Durum
- Firebase proje: `kpss-odak`
- Paket (applicationId / Play Store): `com.hedefkamu.hedef_kamu`
- `google-services.json` yolu: `android/app/google-services.json`

## SHA-1 ekle (zorunlu — oauth_client şu an boş)

Firebase Console → Project settings (dişli) → Your apps → Android  
→ **Add fingerprint**:

```
D7:0F:79:C6:D2:E1:CE:69:80:8F:D6:B3:83:47:31:B5:6A:03:34:18
```

Kaydet → **google-services.json’u yeniden indir** →  
`android/app/google-services.json` üzerine yaz.

Dosyada `"oauth_client": [ ... ]` dolu olmalı (boş `[]` olmamalı).

## Authentication
Build → Authentication → Sign-in method → **Google** → Enable

## Uygulamayı yükle
`basla-telefon.bat` (eski `com.example.kpss_odak` / `kpss_akademi` paketi ayrı uygulama gibi kalabilir; kaldırabilirsin)

## Paket adı değişikliği (Hedef Kamu)

Firebase Console → Project settings → **Add app** (Android)  
Paket adı: `com.hedefkamu.hedef_kamu`  
Aynı SHA-1 parmak izini ekleyin → yeni `google-services.json` indirin.

## «Google girişi yapılandırılmamış» hatası (Profil ekranı)

Bu mesaj genelde **telefondaki APK eski** veya **SHA-1 bu bilgisayarın imza anahtarıyla eşleşmiyor** demektir.

`android/app/google-services.json` dosyasında `"oauth_client": [ ... ]` dolu olsa bile, APK **json güncellenmeden önce** derlendiyse Google girişi çalışmaz.

### Hızlı çözüm

1. `android/app/google-services.json` güncel mi kontrol et (`package_name`: `com.hedefkamu.hedef_kamu`, `oauth_client` boş değil).
2. Proje kökünden **`uygulamayi-yukle.bat`** çalıştır (USB + hata ayıklama açık). Bu, güncel debug APK’yı telefona kurar.
3. Profil → **Google ile giriş yap**’ı tekrar dene.

### SHA-1 doğrula (bu PC)

PowerShell (Java/keytool PATH’te):

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Çıkan **SHA1** satırı Firebase’deki parmak iziyle aynı olmalı:

```
D7:0F:79:C6:D2:E1:CE:69:80:8F:D6:B3:83:47:31:B5:6A:03:34:18
```

Farklıysa Firebase Console → Android uygulaması → **Add fingerprint** → yeni SHA-1 → `google-services.json` yeniden indir → `uygulamayi-yukle.bat`.

### Firebase Authentication

Build → Authentication → Sign-in method → **Google** → **Enable** (kapalıysa giriş yine başarısız olur).

### Eski paket

Telefonda `com.example.kpss_odak` veya `kpss_akademi` adlı eski uygulama ayrı kalabilir; giriş testi için **Hedef Kamu** (`com.hedefkamu.hedef_kamu`) sürümünü kullan.
