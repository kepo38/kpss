# Google / Play Store ile giriş

## Durum
- Firebase proje: `kpss-odak`
- Paket (applicationId): `com.example.kpss_odak`
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
`basla-telefon.bat` (eski `kpss_akademi` paketi ayrı uygulama gibi kalabilir; kaldırabilirsin)
