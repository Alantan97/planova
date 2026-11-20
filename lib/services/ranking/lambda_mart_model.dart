/// Minimal evaluator for our versioned export, not a general LightGBM parser.
/// Leaf values already include the learning rate. Inputs must be complete.
class LambdaMartModel {
  LambdaMartModel._(this.id, this.sourceSha256, this._trees, this._ranges);

  static const features = [
    'days_until_due',
    'remaining_minutes',
    'assessment_weight_percent',
  ];
  final String id;
  final String sourceSha256;
  final List<_Node> _trees;
  final List<(double, double)> _ranges;

  factory LambdaMartModel.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['formatVersion'] != 1 ||
        json['status'] != 'experimental_provisional_rule_imitation' ||
        json['features'] is! List ||
        (json['features'] as List).join('|') != features.join('|') ||
        json['modelId'] is! String ||
        (json['modelId'] as String).isEmpty ||
        json['sourceModelSha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(json['sourceModelSha256'])) {
      throw const FormatException('Incompatible ranking model.');
    }
    final trees = json['trees'];
    final ranges = json['featureRanges'];
    if (trees is! List ||
        trees.isEmpty ||
        trees.length > 10000 ||
        ranges is! List ||
        ranges.length != features.length) {
      throw const FormatException('Invalid ranking model.');
    }
    final parsedRanges = ranges
        .map((range) {
          if (range is! List || range.length != 2) {
            throw const FormatException('Invalid feature range.');
          }
          final lower = _finite(range[0]);
          final upper = _finite(range[1]);
          if (lower > upper) {
            throw const FormatException('Invalid feature range.');
          }
          return (lower, upper);
        })
        .toList(growable: false);
    return LambdaMartModel._(
      json['modelId'],
      json['sourceModelSha256'],
      trees.map((tree) => _Node.parse(tree, 0)).toList(growable: false),
      parsedRanges,
    );
  }

  double predict(List<double> values) {
    if (values.length != features.length ||
        values.any((v) => !v.isFinite) ||
        values[0] < 0 ||
        values[1] <= 0 ||
        values[1] > 10080 ||
        values[2] < 0 ||
        values[2] > 100) {
      throw ArgumentError(
        'Expected days >= 0, minutes in (0,10080], and weight in [0,100].',
      );
    }
    return _trees.fold(0.0, (sum, tree) => sum + tree.evaluate(values));
  }

  bool outsideTrainingRange(List<double> values) => List.generate(
    features.length,
    (i) => i,
  ).any((i) => values[i] < _ranges[i].$1 || values[i] > _ranges[i].$2);
}

double _finite(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Model numbers must be finite.');
  }
  return value.toDouble();
}

class _Node {
  const _Node.leaf(this.value)
    : feature = null,
      threshold = null,
      left = null,
      right = null;
  const _Node.split(this.feature, this.threshold, this.left, this.right)
    : value = null;
  final double? value;
  final int? feature;
  final double? threshold;
  final _Node? left;
  final _Node? right;

  static _Node parse(Object? json, int depth) {
    if (depth > 64 || json is! Map<String, dynamic>) {
      throw const FormatException('Invalid ranking tree.');
    }
    if (json.containsKey('value') && json.length == 1) {
      return _Node.leaf(_finite(json['value']));
    }
    final feature = json['feature'];
    if (json.length != 4 || feature is! int || feature < 0 || feature >= 3) {
      throw const FormatException('Unsupported ranking split.');
    }
    return _Node.split(
      feature,
      _finite(json['threshold']),
      parse(json['left'], depth + 1),
      parse(json['right'], depth + 1),
    );
  }

  double evaluate(List<double> values) {
    var node = this;
    while (node.value == null) {
      node = values[node.feature!] <= node.threshold!
          ? node.left!
          : node.right!;
    }
    return node.value!;
  }
}
