#!/usr/bin/env bash
# Script yapisini denemek icin ornek CSV ile build (gercek TM degil)
set -e
cd "$(dirname "$0")"
cp -f input/_ornek_players.csv input/players.csv
cp -f input/_ornek_clubs.csv input/clubs.csv
cp -f input/_ornek_transfers.csv input/transfers.csv
python3 build.py
echo "Ornek cikti out/ klasorunde. Gercek veri icin ornek csv'leri silip TM csv koy."
