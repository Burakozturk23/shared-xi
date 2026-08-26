# Faz B — Gerçek veri derleme

Bu script senin kaynaklarından (TM-datasets / Kaggle + eski json)  
`clubs_min.json` / `players_min.json` / `coaches_min.json` üretir.

## 1) Kaynak indir

### A) Transfermarkt datasets (ana omurga)

Secenekler:

1. **Kaggle (aynı proje):**  
   https://www.kaggle.com/datasets/davidcariboo/player-scores  
   Indirip icinden su dosyalari al:
   - `players.csv`
   - `clubs.csv`
   - `transfers.csv`

2. **GitHub release / zip:**  
   https://github.com/dcaribou/transfermarkt-datasets  
   README’deki dataset zip / duckdb (CSV export da olur)

### B) (Opsiyonel) PlayerElo  
https://www.kaggle.com/datasets/mwolters/playerelo-football-ratings  
- Oyuncu rating CSV → `input/playerelo.csv` veya `input/elo.csv`  
- Kolon adlari esnek: `name` + `rating`/`elo`

### C) Senin mevcut veri  
Projenden kopyala:

```bash
cp assets/data/players.json tools/build_dataset/input/legacy_players.json
cp assets/data/clubs.json   tools/build_dataset/input/legacy_clubs.json
```

## 2) Dosya yerlesimi

```text
tools/build_dataset/
  input/
    players.csv           ← TM
    clubs.csv             ← TM
    transfers.csv         ← TM (cok onemli: clubIds)
    legacy_players.json   ← senin eski set
    legacy_clubs.json
    playerelo.csv         ← opsiyonel
    coaches.csv           ← opsiyonel
  patches/
    aliases.json          ← elle duzeltmeler
  build.py
  out/                    ← cikti burada olusur
```

## 3) Calistir

```bash
cd tools/build_dataset
python3 build.py
```

Cikti: `out/meta.json`, `clubs_min.json`, `players_min.json`, `coaches_min.json`

Tam min moda gecmeden once sadece uretimi test et (`preferMin` false kalir).

Min seti uygulamada kullanmak icin:

```bash
python3 build.py --prefer-min-meta
```

Sonra:

```bash
cp out/meta.json out/clubs_min.json out/players_min.json out/coaches_min.json ../../assets/data/
```

(proje kokune gore yolu ayarla)

## 4) Uygulama

Faz A kodu zaten min/legacy okuyor.

- `preferMin: false` → eski buyuk json  
- `preferMin: true` → min set  

**Tam min’e gecmeden** Shared XI / Keşif’te ornek cift dene (GS–FB, Real–Barca).

## 5) Ne birlestiriliyor?

| Kaynak | Kullanim |
|--------|----------|
| TM players | id, name, position, country, current_club |
| TM transfers | kariyer clubIds |
| legacy json | eksik clubIds + aliases |
| patches/aliases.json | elle alias |
| PlayerElo | rating (isim eslesirse) |

Logo URL **yazilmaz**. badgeKey/avatarKey sadece anahtar.

## 6) Gereksinim

- Python 3.10+  
- Standart kutuphane yeterli (CSV)  
- Parquet kullanacaksan: `pip install pandas pyarrow`
