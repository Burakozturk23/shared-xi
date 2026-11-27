"""py -3 -m unittest discover tools/moderation"""
import contextlib
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import moderate  # noqa: E402


class FakeFirebase:
    def __init__(self, tree):
        self.tree = tree
        self.updates = []

    def get(self, path):
        node = self.tree
        for part in [p for p in path.split("/") if p]:
            node = node.get(part) if isinstance(node, dict) else None
        return node

    def update(self, updates):
        self.updates.append(updates)


def tree():
    return {
        "safetyReports": {
            "r1": {"reportId": "r1", "reporterUid": "alice", "targetUid": "bob", "targetDisplayName": "Bob",
                   "category": "cheating", "status": "open", "createdAt": 2, "description": "Hile"},
            "r2": {"reportId": "r2", "reporterUid": "alice", "targetUid": "eve", "targetDisplayName": "Eve",
                   "category": "spam", "status": "closed", "createdAt": 1},
        },
        "communitySubmissions": {
            "c1": {"submissionId": "c1", "uid": "bob", "category": "bug_report", "subject": "Grid",
                   "message": "Hücre seçilmiyor", "status": "open", "createdAt": 3},
        },
    }


def run(argv, fb):
    with contextlib.redirect_stdout(io.StringIO()) as out:
        result = moderate.main(argv, fb=fb, now_ms=99)
    return result, out.getvalue()


class ModerateTest(unittest.TestCase):
    def test_lists_open_items_by_default(self):
        shown, text = run(["reports"], FakeFirebase(tree()))
        self.assertEqual([r["reportId"] for r in shown], ["r1"])
        self.assertIn("Hile", text)
        shown, _ = run(["reports", "--all"], FakeFirebase(tree()))
        self.assertEqual(len(shown), 2)
        shown, text = run(["requests"], FakeFirebase(tree()))
        self.assertEqual([r["submissionId"] for r in shown], ["c1"])
        self.assertIn("Hücre seçilmiyor", text)

    def test_status_moves_the_record_and_the_players_list_together(self):
        fb = FakeFirebase(tree())
        run(["report-status", "r1", "actioned"], fb)
        self.assertEqual(fb.updates, [{
            "safetyReports/r1/status": "actioned", "safetyReports/r1/updatedAt": 99,
            "safetyReportIndex/alice/r1/status": "actioned", "safetyReportIndex/alice/r1/updatedAt": 99,
        }])
        fb = FakeFirebase(tree())
        run(["request-status", "c1", "resolved"], fb)
        self.assertEqual(fb.updates[0]["communitySubmissionIndex/bob/c1/status"], "resolved")

    def test_unknown_ids_and_statuses_change_nothing(self):
        fb = FakeFirebase(tree())
        with self.assertRaises(SystemExit):
            run(["report-status", "r1", "nope", "closed"], fb)
        with self.assertRaises(SystemExit):
            run(["report-status", "r1", "resolved"], fb)  # a report status, not a request one
        self.assertEqual(fb.updates, [])


if __name__ == "__main__":
    unittest.main()
