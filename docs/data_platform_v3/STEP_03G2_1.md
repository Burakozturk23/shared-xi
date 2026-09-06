# 03G.2.1 — Career Timeline Gameplay Normalization

03G.2 transfer chronology açısından temizdir; ancak loan-return / registration işlemleri
bazı oyuncularda kısa parent-club spell'leri oluşturabilir.

Örnek:
- Mohamed Salah: Roma -> Chelsea -> Roma
- Kylian Mbappé: PSG -> Monaco -> PSG
- Antoine Griezmann: Atlético -> Barcelona -> Atlético

Bu ara adım resmi appearance tarihlerini tekrar tarar.

Kural:
- senior + HIGH/MEDIUM spell,
- başlangıç ve bitiş tarihi arasında en fazla 45 gün,
- bu aralıkta ilgili kulüp adına 0 resmi appearance

ise kayıt master tarihte korunur fakat gameplay timeline'ından çıkarılır.

Böylece gerçek loan spell'leri (resmi maç oynanan) korunurken yalnızca idari dönüşler
Career Puzzle / Player Journey'de sahte kariyer adımı olarak gösterilmez.

Bu adım `assets/data` dosyalarına yazmaz.
