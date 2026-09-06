# Linkball Gizlilik Politikası

**Son güncelleme:** 1 Eylül 2026  
**Uygulama:** Linkball  
**Paket:** `com.burakozturk.linkball`  
**Gizlilik iletişimi:** burakozturk1315@gmail.com

Bu doküman, yayımlanan `https://sharedix.web.app/privacy.html` sayfasının
kaynak/evidence sürümüdür.

## 1. Hangi verileri işliyoruz?

Linkball'ın çevrim içi özellikleri ve kullandığı Firebase SDK'ları aşağıdaki
veri gruplarını işleyebilir.

### Hesap ve oyun verileri

- Firebase Authentication tarafından oluşturulan anonim kullanıcı kimliği (UID).
- Kullanıcının seçtiği görünen ad.
- Profil istatistikleri: galibiyet, mağlubiyet, beraberlik, Elo ve maç geçmişi.
- Günlük meydan okuma skorları ve skor oturumu verileri.
- Çevrim içi eşleştirme kuyrukları, oda/maç durumu ve oyun sonuçları.

### Firebase Authentication ve Realtime Database teknik verileri

Firebase Authentication ve Firebase Realtime Database, hizmet güvenliği,
kötüye kullanımın önlenmesi ve hizmetin işletilmesi için IP adresi, kullanıcı
aracısı (user-agent) bilgileri ve Firebase uygulama tanımlayıcıları gibi teknik
bilgileri otomatik olarak işleyebilir. Kimliği doğrulanmış Realtime Database
istekleri ilgili Firebase UID'sini de içerir.

### Google Analytics for Firebase

Yayımlanan Android sürümünde Analytics etkinleştirildiğinde SDK; uygulama
açılışı, oturum ve ekran/uygulama etkileşimi gibi olayları işler. SDK ayrıca
uygulama örneği kimliği (app-instance ID), cihaz/uygulama bilgileri ve
maskelenmiş IP adresinden türetilen yaklaşık coğrafi konum gibi bilgileri
işleyebilir. Android Advertising ID cihazda kullanılabilir olduğu ve
yapılandırma tarafından devre dışı bırakılmadığı durumlarda SDK tarafından
işlenebilir.

Linkball, Firebase UID'sini Analytics kullanıcı kimliği olarak bağlamaz.

### Firebase Crashlytics ve Firebase Sessions

Crashlytics; çökme ve ANR kayıtları, stack trace, ilgili uygulama durumu,
cihaz meta verileri ve Crashlytics kurulum UUID'si gibi tanılama verilerini
işleyebilir. Crashlytics'in bağımlılıkları olan Firebase Installations ve
Firebase Sessions; Firebase Installation ID (FID), uygulama/cihaz meta
verileri, ağ bağlantı türü ve oturum başlangıcı gibi teknik bilgileri
işleyebilir.

Linkball, Firebase UID'sini Crashlytics kullanıcı kimliği olarak bağlamaz.

### Firebase App Check / Google Play Integrity

App Check ve production Android sürümünde Google Play Integrity; uygulama ve
istek bütünlüğünü doğrulamak, otomasyon/kötüye kullanımı azaltmak için Firebase
user-agent bilgileri ile integrity/attestation token ve sinyallerini işleyebilir.

## 2. Verileri hangi amaçlarla kullanıyoruz?

- Uygulama ve çevrim içi oyun özelliklerini sunmak.
- Kullanıcı hesabını, profilini, eşleştirmeyi, odaları ve skor tablolarını işletmek.
- Hile, bot, kötüye kullanım ve yetkisiz istekleri azaltmak.
- Çökme, ANR ve teknik hataları teşhis etmek.
- Uygulamanın kullanım ve kararlılık kalitesini ölçmek.

## 3. Kimlerle paylaşılır?

Linkball kişisel verileri **satmaz**.

Google Firebase/Google Analytics hizmetleri; Authentication, Realtime
Database, Cloud Functions, Analytics, Crashlytics, Installations, Sessions ve
App Check gibi altyapı/işlemci hizmetleri olarak kullanılmaktadır. Bu
hizmetlerin veriyi kendi alt işleyenleriyle işlemesi Google'ın ilgili hizmet
şartları ve gizlilik uygulamalarına tabidir.

Çevrim içi oyun kullanıcı tarafından başlatıldığında görünen ad, skor ve oyun
durumu gibi gerekli bilgiler rakibe veya skor tablosundaki diğer kullanıcılara
gösterilebilir.

## 4. Güvenlik

Firebase ile ağ üzerinden taşınan veriler HTTPS/TLS kullanılarak aktarılır.
Realtime Database production kuralları deny-by-default yapılandırılmıştır;
public olmayan kullanıcı/oyun yolları için kimlik doğrulaması uygulanır.
App Check / Play Integrity, desteklenen isteklerde ek bütünlük kontrolü sağlar.

## 5. Saklama

Hesap ve oyun verileri, özellikleri sunmak için gerekli olduğu sürece veya
kullanıcı hesap silme talebi verene kadar tutulabilir.

Hesap silme sonrasında:

- Firebase Authentication hesabı,
- Linkball kullanıcı profili ve istatistikleri,
- günlük skor ve skor oturumu verileri,
- eşleştirme kuyruğu referansları

silinir. Paylaşılan maç/oda kayıtlarındaki kullanıcıya ait kimlik ve görünen ad
gibi alanlar anonimleştirilir.

Kimliği kaldırılmış kayıtlar ile Analytics/Crashlytics gibi hizmetlerin teknik
saklama sürelerine tabi tanılama/ölçüm verileri ilgili hizmetin saklama
politikaları kapsamında bir süre daha tutulabilir.

## 6. Hesabını ve verilerini silme

Uygulama içinde:

**Gizlilik & Hesap → Hesabımı ve verilerimi sil**

Uygulamaya erişemeyen kullanıcılar için dış silme kaynağı:

https://sharedix.web.app/account-deletion.html

Hesap silme yalnızca hesabı dondurmaz; Linkball'ın kullanıcıyla doğrudan
ilişkilendirdiği hesap verilerinin silinmesi ve paylaşılan kayıtların
kimliksizleştirilmesi sürecini başlatır.

## 7. Kullanıcı seçenekleri

- Android cihaz ayarlarından Advertising ID sıfırlanabilir veya ilgili reklam
  kimliği seçenekleri yönetilebilir.
- Hesap, uygulama içinden veya yukarıdaki dış kaynak üzerinden silinebilir.
- Gizlilik/veri talepleri için aşağıdaki iletişim adresi kullanılabilir.

## 8. İletişim

Gizlilik, veri erişimi veya hesap silme soruları:

**burakozturk1315@gmail.com**

## 9. Politika değişiklikleri

Uygulamadaki veri işleme veya Firebase/Google SDK yapılandırması önemli ölçüde
değişirse bu politika ve Google Play Data Safety beyanı güncellenir.

## Teknik kaynaklar

- Google Play User Data policy:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Firebase Android / Google Play data disclosure:
  https://firebase.google.com/docs/android/play-data-disclosure
- Google Analytics for Firebase data collection:
  https://support.google.com/firebase/answer/6318039
