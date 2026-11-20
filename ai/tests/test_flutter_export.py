import copy
import json
import unittest
from pathlib import Path

from export_flutter_model import convert_node, export

ROOT = Path(__file__).resolve().parents[2]


class FlutterExportTests(unittest.TestCase):
    def test_unsupported_split_types_cannot_be_exported_silently(self):
        node = {'decision_type': '<=', 'missing_type': 'None', 'split_feature': 0,
                'threshold': 2, 'left_child': {'leaf_value': 1}, 'right_child': {'leaf_value': -1}}
        self.assertEqual(convert_node(node)['left'], {'value': 1})
        for change in [{'decision_type': '=='}, {'missing_type': 'Zero'},
                       {'split_feature': 3}, {'threshold': float('nan')}]:
            with self.assertRaises(ValueError):
                convert_node({**copy.deepcopy(node), **change})

    def test_bundled_forest_and_dart_reference_inputs_match_the_saved_model(self):
        run = ROOT / 'research/experiments/lambdamart/proforma-v1-003'
        if not (run / 'model.txt').is_file():
            self.skipTest('Private local model run is unavailable')
        asset, cases = export(run)
        self.assertEqual(asset, json.loads((ROOT / 'assets/ranking/provisional_v1.json').read_text(encoding='utf-8')))
        self.assertEqual(cases, json.loads((ROOT / 'test/support/ranking_prediction_cases.json').read_text(encoding='utf-8')))


if __name__ == '__main__':
    unittest.main()
