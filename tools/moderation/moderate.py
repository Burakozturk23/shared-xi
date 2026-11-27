"""Linkball moderation: player reports and community requests.

Runs on the owner's computer through the Firebase CLI that is already signed
in (no service account, no admin screen in the app). Status changes write the
record and the player's own list entry in one multi-path update, so the app's
"Açık / İnceleniyor / Sonuçlandı" filters follow at once.

  py -3 tools/moderation/moderate.py reports            # open + reviewing
  py -3 tools/moderation/moderate.py reports --all
  py -3 tools/moderation/moderate.py report-status <id> [<id>…] reviewing|actioned|closed
  py -3 tools/moderation/moderate.py requests [--all]
  py -3 tools/moderation/moderate.py request-status <id> [<id>…] reviewing|resolved|closed

Add --project <id> to use another Firebase project (default: sharedix).
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime

REPORT_STATUSES = ("open", "reviewing", "actioned", "closed")
REQUEST_STATUSES = ("open", "reviewing", "resolved", "closed")
ACTIVE = ("open", "reviewing")
STATUS_TR = {"open": "Açık", "reviewing": "İnceleniyor", "actioned": "İşlem yapıldı",
             "resolved": "Çözüldü", "closed": "Kapatıldı"}
REPORT_TR = {"harassment": "Taciz", "hate_speech": "Nefret söylemi", "cheating": "Hile",
             "inappropriate_name": "Uygunsuz ad", "spam": "Spam", "other": "Diğer"}
REQUEST_TR = {"suggestion": "Öneri", "bug_report": "Hata", "help": "Yardım",
              "matchmaking_issue": "Eşleşme sorunu", "feedback": "Geri bildirim"}


class Firebase:
    """The signed-in Firebase CLI; tests pass a fake with the same two methods."""

    def __init__(self, project):
        self.project = project

    def _run(self, args):
        cmd = ["firebase", *args, "--project", self.project]
        # On Windows the CLI is firebase.cmd, which needs the shell.
        out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                             shell=os.name == "nt")
        if out.returncode != 0:
            raise SystemExit(f"firebase {' '.join(args[:2])} başarısız:\n{out.stderr or out.stdout}")
        return out.stdout

    def get(self, path):
        text = self._run(["database:get", path]).strip()
        return json.loads(text) if text else None

    def update(self, updates):
        # One multi-path PATCH at the root: all paths change together or none.
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
            json.dump(updates, f, ensure_ascii=False)
            name = f.name
        try:
            self._run(["database:update", "/", name, "--force"])
        finally:
            os.unlink(name)


def when(ms):
    return datetime.fromtimestamp((ms or 0) / 1000).strftime("%d.%m.%Y %H:%M") if ms else "-"


def rows(value):
    return [v for v in (value or {}).values() if isinstance(v, dict)]


def list_reports(fb, show_all=False):
    reports = sorted(rows(fb.get("/safetyReports")), key=lambda r: r.get("createdAt") or 0, reverse=True)
    shown = [r for r in reports if show_all or r.get("status") in ACTIVE]
    for r in shown:
        print(f"{r.get('reportId')}  {when(r.get('createdAt'))}  [{STATUS_TR.get(r.get('status'), r.get('status'))}]  "
              f"{REPORT_TR.get(r.get('category'), r.get('category'))}  → {r.get('targetDisplayName')} "
              f"({r.get('targetUid')})  kaynak: {r.get('sourceContext')}")
        if r.get("description"):
            print(f"    “{r['description']}”")
    print(f"\n{len(shown)} rapor{'' if show_all else ' (açık / inceleniyor)'} · toplam {len(reports)}")
    return shown


def list_requests(fb, show_all=False):
    items = sorted(rows(fb.get("/communitySubmissions")), key=lambda r: r.get("createdAt") or 0, reverse=True)
    shown = [r for r in items if show_all or r.get("status") in ACTIVE]
    for r in shown:
        print(f"{r.get('submissionId')}  {when(r.get('createdAt'))}  [{STATUS_TR.get(r.get('status'), r.get('status'))}]  "
              f"{REQUEST_TR.get(r.get('category'), r.get('category'))}  {r.get('subject')}"
              f"{'  · ' + r['modeId'] if r.get('modeId') else ''}")
        print(f"    {r.get('message')}")
    print(f"\n{len(shown)} talep{'' if show_all else ' (açık / inceleniyor)'} · toplam {len(items)}")
    return shown


def status_updates(fb, kind, ids, status, now_ms):
    """The multi-path update that moves each record and its list entry to `status`."""
    if kind == "report":
        allowed, root, index, owner, key = REPORT_STATUSES, "safetyReports", "safetyReportIndex", "reporterUid", "rapor"
    else:
        allowed, root, index, owner, key = REQUEST_STATUSES, "communitySubmissions", "communitySubmissionIndex", "uid", "talep"
    if status not in allowed:
        raise SystemExit(f"Geçersiz durum: {status}. Seçenekler: {', '.join(allowed)}")
    updates = {}
    for item_id in ids:
        record = fb.get(f"/{root}/{item_id}")
        if not isinstance(record, dict) or not record.get(owner):
            raise SystemExit(f"{key} bulunamadı: {item_id} (hiçbir şey değişmedi)")
        for path in (f"{root}/{item_id}", f"{index}/{record[owner]}/{item_id}"):
            updates[f"{path}/status"] = status
            updates[f"{path}/updatedAt"] = now_ms
    return updates


def main(argv=None, fb=None, now_ms=None):
    parser = argparse.ArgumentParser(description="Linkball raporları ve topluluk talepleri.")
    parser.add_argument("--project", default="sharedix")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("reports", "requests"):
        p = sub.add_parser(name)
        p.add_argument("--all", action="store_true", help="kapananlar dahil")
    for name, choices in (("report-status", REPORT_STATUSES), ("request-status", REQUEST_STATUSES)):
        p = sub.add_parser(name)
        p.add_argument("ids", nargs="+", help="kimlik(ler) ve en sonda yeni durum")
    args = parser.parse_args(argv)
    fb = fb or Firebase(args.project)
    if args.command == "reports":
        return list_reports(fb, args.all)
    if args.command == "requests":
        return list_requests(fb, args.all)
    *ids, status = args.ids
    if not ids:
        raise SystemExit("En az bir kimlik ve bir durum ver.")
    kind = "report" if args.command == "report-status" else "request"
    updates = status_updates(fb, kind, ids, status, now_ms or int(time.time() * 1000))
    fb.update(updates)
    print(f"{len(ids)} {'rapor' if kind == 'report' else 'talep'} → {STATUS_TR[status]}")
    return updates


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
