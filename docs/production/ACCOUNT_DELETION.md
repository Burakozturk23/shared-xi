# Linkball Account Deletion Architecture

## In-app

Ana ekran → **Gizlilik & Hesap** → **Hesabımı ve verilerimi sil**.

Kullanıcı `SİL` yazarak işlemi onaylar. Flutter istemcisi
`deleteMyAccount` callable Function'ını çağırır.

## Server-side deletion

`deleteMyAccount` yalnızca Firebase Authentication ile doğrulanmış çağrıları
kabul eder.

Silinen doğrudan veriler:

- `users/{uid}`
- `dailyScoreSessions/{uid}`
- `dailyLeaderboard/{date}/{uid}`
- `matchmaking/*Queue/{uid}` ve kuyruklarda UID referansları

Kimliksizleştirilen paylaşılan kayıtlar:

- `matches/*`
- `rooms/*`
- `gridMatches/*`
- `cinkoMatches/*`
- `fiveMatches/*`

Paylaşılan kayıtlarda UID anahtarları/değerleri kaldırılır; ilgili görünen ad
alanları `Silinmiş oyuncu` olarak değiştirilir. Diğer kullanıcıların
`matchHistory/{matchId}/opponentName` alanı da anonimleştirilir.

Son adımda Firebase Authentication kullanıcısı Admin SDK ile silinir.

## External request

Public resource:

https://sharedix.web.app/account-deletion.html

Bu sayfa, uygulamaya erişemeyen kullanıcıya burakozturk1315@gmail.com üzerinden
silme talebi başlatma yolu verir.

## Scalability note

Mevcut erken aşama veri hacminde Function paylaşılan match koleksiyonlarını
tarayıp UID referanslarını anonimleştirir. Kullanıcı/match hacmi büyüdüğünde
`userMatchRefs/{uid}/{collection}/{matchId}` benzeri server-maintained bir
indeks eklenmesi önerilir; böylece hesap silme O(user matches) olur.
