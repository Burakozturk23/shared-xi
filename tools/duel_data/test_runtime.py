"""Integration invariants, independently of the online collection step."""
import hashlib
import json
import unittest

import build_runtime as build


class RuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data, cls.audit = build.build()

    def test_reproducible_client_server_package(self):
        raw = build.dumps(self.data).encode()
        for name in ['assets/data/duel/runtime.json', 'functions/config/duel_runtime.json']:
            self.assertEqual((build.ROOT/name).read_bytes(), raw)
        manifest = build.read(build.ROOT/'assets/data/duel/manifest.json')
        self.assertEqual(hashlib.sha256(raw).hexdigest(), manifest['sha256'])
        self.assertEqual(len(raw), manifest['bytes'])
        self.assertEqual(build.digest(build.DB), self.data['baseDatabaseSha256'])

    def test_all_approved_criteria_preserved_without_unearned_enablement(self):
        criteria = self.data['criteria']
        self.assertEqual(len(criteria), 24)
        self.assertEqual(sum(c['stage'] == 'core' for c in criteria), 14)
        self.assertFalse(any(c['enabled'] for c in criteria))
        self.assertEqual({c['id'] for c in criteria if c['goalkeeperZeroAllowed']}, set(build.GOALKEEPER_ZERO))
        self.assertEqual(self.data['formation'], ['GK','DEF','MID','DEF','MID','FWD'])

    def test_sources_do_not_become_scoring_by_accident(self):
        self.assertEqual(self.audit['matchedProfiles'], 456)
        self.assertEqual(len(self.data['profileObservations']), 1342)
        for row in self.data['profileObservations']:
            self.assertNotEqual(row['status'], 'verified')
            self.assertNotEqual(row['field'], 'height_cm')
            if row['field'] == 'height_inches':
                self.assertIn('rounded_imperial_measurement', row['blockedForScoring'])
            if row['field'] == 'citizenship':
                self.assertIn('football_country_not_established', row['blockedForCondition'])
        self.assertEqual({m['criterionId'] for m in self.data['verifiedMetrics']}, {'F15','F16','F18'})

    def test_played_matches_not_unused_bench_or_whole_careers(self):
        self.assertEqual(self.audit['matchCount'], 7)
        self.assertEqual(self.audit['appearedRows'], 189)
        self.assertEqual(self.audit['unusedRowsExcluded'], 53)
        self.assertEqual(self.audit['mappedAppearanceRows'], 137)
        for row in self.data['matchAppearances']:
            self.assertTrue(row['positions'])
            self.assertEqual(row['coverage'], 'single_official_match')
            self.assertLessEqual(row['date'], self.data['cutoff'])
        for coach in self.data['externalCoaches']:
            self.assertIsNone(coach['canonicalId'])
            self.assertEqual(coach['role'], 'head_coach')

    def test_final_career_corrections_have_matching_scope(self):
        facts = {(m['playerId'],m['criterionId']):m for m in self.data['verifiedMetrics']}
        self.assertEqual(len(facts), 7)
        for key,value in { (5023,'F15'):176, (3207,'F15'):123, (3207,'F16'):51,
                           (3207,'F18'):50, (4000000056,'F15'):70,
                           (4000000056,'F16'):34, (4000000056,'F18'):56 }.items():
            self.assertEqual(facts[key]['value'], value)
        self.assertNotIn((5023,'F12'), facts)  # Missing never becomes zero.
        scopes = {c['id']:c['scopeId'] for c in self.data['criteria']}
        for row in facts.values():
            self.assertEqual(row['scopeId'], scopes[row['criterionId']])
            self.assertEqual(row['cutoff'], self.data['cutoff'])
            self.assertTrue(row['finalCareer'])
            self.assertTrue(all(s in self.data['sources'] for s in row['sources']))

    def test_conditions_have_primary_participation_evidence(self):
        for row in self.data['conditions']:
            self.assertEqual(row['status'], 'verified')
            self.assertTrue(row['sources'])
            self.assertEqual(row['meaning'], 'official_senior_appearance' if row['kind']=='club' else 'senior_national_team')
        self.assertEqual({r['key'] for r in self.data['conditions'] if r['kind']=='country'}, {'Italy','France','Netherlands'})


if __name__ == '__main__':
    unittest.main()
