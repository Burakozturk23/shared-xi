# Linkball — Privacy / Data Safety Release Checklist

## Hosting

- [ ] `https://sharedix.web.app/privacy.html` HTTP 200
- [ ] `https://sharedix.web.app/account-deletion.html` HTTP 200
- [ ] Privacy sayfası Linkball adını ve gizlilik iletişimini gösteriyor
- [ ] Account deletion sayfası Linkball adını ve silme talebi yolunu gösteriyor
- [ ] Sayfalar giriş yapmadan görüntülenebiliyor

## App

- [ ] `Gizlilik & Hesap` ekranı erişilebilir
- [ ] In-app privacy URL doğru
- [ ] In-app account deletion URL doğru
- [ ] Hesap silme butonu çalışıyor
- [ ] Silme sonrası Firebase Auth hesabı yok
- [ ] Silme sonrası direct profile/daily data yok
- [ ] Paylaşılan kayıtların kimlik alanları scrub edilmiş

## Data Safety

- [ ] Name
- [ ] User IDs
- [ ] Approximate location (Analytics)
- [ ] App interactions
- [ ] Crash logs
- [ ] Diagnostics
- [ ] Device or other IDs
- [ ] Gameplay/account data için current Play category seçildi
- [ ] “Shared” istisnaları current Play yardım metniyle doğrulandı
- [ ] “Data sold” = No
- [ ] Encryption in transit = Yes
- [ ] Account deletion = Yes

## Firebase

- [ ] RTDB root public read kapalı
- [ ] App Check local debug token yalnız Console'da
- [ ] CI debug token yalnız secret store'da
- [ ] Production App Check provider = Play Integrity
- [ ] Analytics / Crashlytics disclosure privacy policy ile uyumlu

## Store listing identity

Google Play User Data policy, privacy policy'nin uygulamayı veya Store listing'de
görünen geliştirici/entity'yi açıkça tanımlamasını ister.

- [ ] Play Console'daki developer/entity adı privacy policy metninde aynen yer alıyor
