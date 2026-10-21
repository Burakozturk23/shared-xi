import copy
import unittest
from build_catalog import build, clean_profile, deduplicate, positive_count, resolve_identity, render, OUTPUT, REPORT


class CoachArchiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog, cls.audit = build()
        cls.coaches = {r['name']: r for r in cls.catalog['coaches']}

    def test_generated_files_are_reproducible(self):
        self.assertEqual(OUTPUT.read_text(encoding='utf-8'), render(self.catalog))
        self.assertEqual(REPORT.read_text(encoding='utf-8'), render(self.audit))

    def test_preserves_coverage_without_inventing_zeroes(self):
        self.assertEqual((self.audit['rawCoachRows'], len(self.coaches), self.audit['trophyRows']), (99, 98, 80))
        self.assertEqual(self.audit['missingTrophyRows'], 18)
        missing = self.coaches['Julian Nagelsmann']
        self.assertFalse(missing['hasTrophyRecord'])
        self.assertIsNone(missing['unclassifiedCount'])
        self.assertEqual(missing['honours'], [])
        self.assertIsNone(self.catalog['source']['snapshotDate'])

    def test_unknown_values_and_awards_are_not_cups(self):
        definitions = {c['id']: c for c in self.catalog['competitions']}
        pep = self.coaches['Pep Guardiola']
        self.assertEqual(pep['unclassifiedCount'], 1)
        self.assertNotIn('NONE', definitions)
        self.assertEqual(definitions['Worlds_Best_Club_Coach']['category'], 'individual')
        self.assertEqual(definitions['Olympic_medalist']['category'], 'medal')
        self.assertEqual(definitions['U21_Premier_League_champion']['category'], 'youth')
        self.assertEqual(definitions['Italienischer_Zweitligameister']['category'], 'lowerTier')
        self.assertIn('Copa_América_winner', definitions)
        self.assertEqual(self.audit['excludedNoneCount'], 62)
        for record in self.coaches.values():
            for h in record['honours']:
                self.assertIn(h['competitionId'], definitions)
                self.assertGreater(h['count'], 0)

    def test_shifted_fields_are_recovered_only_by_format(self):
        allegri = self.coaches['Massimiliano Allegri']['profile']
        self.assertIsNone(allegri['snapshotFormation'])
        self.assertEqual(allegri['snapshotLicence'], 'UEFA Pro Licence')
        self.assertEqual(allegri['snapshotAverageTermYears'], 1.46)
        garcia = self.coaches['Luis García']['profile']
        self.assertEqual(garcia['snapshotFormation'], '4-2-3-1')
        self.assertEqual(garcia['snapshotAverageTermYears'], 1.32)
        self.assertIsNone(garcia['snapshotLicence'])
        self.assertIsNone(self.coaches['Pep Guardiola']['profile']['snapshotLicence'])

    def test_deduplication_never_merges_conflicting_people(self):
        row = {'name': 'Example Coach', 'birth_date': '1970-01-01'}
        records, _, duplicates = deduplicate([row, row.copy()])
        self.assertEqual((len(records), len(duplicates)), (1, 1))
        other = copy.deepcopy(row); other['birth_date'] = '1980-01-01'
        with self.assertRaises(ValueError):
            deduplicate([row, other])

    def test_ambiguous_identities_stay_unlinked(self):
        for name in ['Luis García', 'Bruno Génésio', 'Christophe Pélissier']:
            self.assertIsNone(self.coaches[name]['coachId'])
        self.assertEqual(self.coaches['Pep Guardiola']['coachId'], 'coach_0')
        self.assertEqual(self.coaches['David Moyes']['coachId'], 'coach_26')
        self.assertEqual(self.audit['linkedCoaches'], 77)
        row = {'name': 'Coach', 'citizenship': 'Spain'}
        coach = {'id': 'x', 'name': 'Coach', 'countries': ['Germany']}
        self.assertEqual(resolve_identity(row, [coach], {})[1], 'country_conflict')

    def test_bad_counts_fail_closed(self):
        for value in ['-1', '1.5', 'NA', '', '1e2']:
            with self.assertRaises(ValueError):
                positive_count(value)


if __name__ == '__main__':
    unittest.main()
