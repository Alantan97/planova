"""Export the supported numerical LambdaMART forest for offline Flutter inference.

No PDF, student record, assessment name or training row is included in the asset.
The saved experiment remains unchanged. Unsupported model types fail explicitly.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path

import lightgbm as lgb
import numpy as np

from planova_ranking.dataset import FEATURES, feature_matrix


def convert_node(node: dict) -> dict:
    if 'leaf_value' in node:
        if node.get('leaf_coeff') or not math.isfinite(node['leaf_value']):
            raise ValueError('Only finite constant leaves are supported')
        return {'value': node['leaf_value']}
    if node['decision_type'] != '<=' or node['missing_type'] != 'None':
        raise ValueError('Only numerical <= splits without missing-value routing are supported')
    if node['split_feature'] not in range(len(FEATURES)) or not math.isfinite(node['threshold']):
        raise ValueError('Invalid split feature or threshold')
    return {'feature': node['split_feature'], 'threshold': node['threshold'],
            'left': convert_node(node['left_child']), 'right': convert_node(node['right_child'])}


def tree_score(node: dict, values: list[float]) -> float:
    while 'value' not in node:
        node = node['left'] if values[node['feature']] <= node['threshold'] else node['right']
    return node['value']


def export(run_dir: Path) -> tuple[dict, dict]:
    model_path = run_dir / 'model.txt'
    digest = hashlib.sha256(model_path.read_bytes()).hexdigest()
    report = json.loads((run_dir / 'report.json').read_text(encoding='utf-8'))
    if report['model_sha256'] != digest or report['features'] != FEATURES:
        raise ValueError('Model or feature schema differs from the saved manifest')
    model = lgb.Booster(model_file=str(model_path))
    dump = model.dump_model()
    if (dump['objective'] != 'lambdarank' or dump['num_class'] != 1
            or dump['num_tree_per_iteration'] != 1 or dump['average_output']
            or dump['feature_names'] != FEATURES):
        raise ValueError('Unsupported model configuration')
    trees = [convert_node(tree['tree_structure']) for tree in dump['tree_info']]
    if not trees:
        raise ValueError('No trees found')
    asset = {'formatVersion': 1, 'modelId': run_dir.name, 'sourceModelSha256': digest,
             'features': FEATURES, 'status': 'experimental_provisional_rule_imitation',
             'featureRanges': [[dump['feature_infos'][f]['min_value'],
                                dump['feature_infos'][f]['max_value']] for f in FEATURES],
             'trees': trees}
    vectors = [list(v) for v in itertools.product(
        [0, 1, 2, 3, 6, 7, 10, 11, 30, 31, 90],
        [1, 30, 60, 75, 76, 120, 240, 10080], [0, 5, 15, 25, 27.5, 30, 40, 100])]
    def add_boundaries(node):
        if 'value' in node:
            return
        feature, threshold = node['feature'], node['threshold']
        for value in [math.nextafter(threshold, -math.inf), threshold, math.nextafter(threshold, math.inf)]:
            vector = [7, 120, 25]
            vector[feature] = value
            try:
                feature_matrix([dict(zip(FEATURES, vector))])
            except ValueError:
                continue
            vectors.append(vector)
        add_boundaries(node['left'])
        add_boundaries(node['right'])
    for tree in trees:
        add_boundaries(tree)
    vectors = list({tuple(v): v for v in vectors}.values())
    expected = model.predict(np.array(vectors, dtype=float)).tolist()
    exported = [sum(tree_score(tree, v) for tree in trees) for v in vectors]
    if not np.allclose(expected, exported, atol=1e-12, rtol=0):
        raise ValueError('Exported forest does not reproduce LightGBM predictions')
    cases = {'sourceModelSha256': digest, 'features': FEATURES,
             'description': 'Invented boundary/grid inputs with LightGBM reference scores. No research rows.',
             'cases': [{'values': v, 'score': score} for v, score in zip(vectors, expected)]}
    return asset, cases


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cases-output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists() or args.cases_output.exists():
        raise FileExistsError('Use new output paths; existing assets/fixtures are not overwritten')
    asset, cases = export(args.run_dir)
    for target, content in [(args.output, asset), (args.cases_output, cases)]:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(content, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    print(f'Exported {len(asset["trees"])} trees; verified {len(cases["cases"])} reference inputs.')
