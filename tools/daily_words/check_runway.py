"""Fail CI before the daily word calendar runs out.

The server closes a daily game on a day with no published pack, so the
catalog must always reach well past today. Warns below --warn-days and
fails below --min-days (days counted in Türkiye time, UTC+3).
"""
import argparse
import json
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[2] / 'functions/config/daily_words_catalog.json'


def last_covered(catalog):
    daily = date.fromisoformat(max(catalog['daily']))
    # A weekly key is its Monday; the round stays open through Sunday.
    weekly = date.fromisoformat(max(catalog['weekly'])) + timedelta(days=6)
    return {'Günlük': daily, 'Haftalık': weekly}


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--min-days', type=int, default=14)
    parser.add_argument('--warn-days', type=int, default=45)
    parser.add_argument('--today', type=date.fromisoformat,
                        default=datetime.now(timezone(timedelta(hours=3))).date())
    parser.add_argument('--catalog', type=Path, default=CATALOG)
    args = parser.parse_args(argv)
    catalog = json.loads(args.catalog.read_text(encoding='utf-8'))
    failed = False
    for name, end in last_covered(catalog).items():
        left = (end - args.today).days
        line = f'{name} takvim {end.isoformat()} tarihine kadar: {left} gün kaldı.'
        if left < args.min_days:
            print(f'::error::{line} Yeni içerik yayımlanmazsa oyun kapanır.')
            failed = True
        elif left < args.warn_days:
            print(f'::warning::{line} İçerik genişletme planlanmalı.')
        else:
            print(line)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
