class NavGrid {
  Size fieldSize;
  num nodeSizeMeters;
  List<List<bool>> grid;

  late int nodesX;
  late int nodesY;

  NavGrid({
    required this.fieldSize,
    required this.nodeSizeMeters,
    required this.grid,
  }) {
    nodesX = (fieldSize.width / nodeSizeMeters).ceil();
    nodesY = (fieldSize.height / nodeSizeMeters).ceil();
  }

  NavGrid.fromJson(Map<String, dynamic> json)
      : fieldSize = _sizeFromJson(json['field_size']),
        nodeSizeMeters = json['nodeSizeMeters'] ?? 0.2,
        grid = [] {
    grid = [
      for (var dynList in json['grid'] ?? [])
        (dynList as List<dynamic>).map((e) => e as bool).toList(),
    ];

    nodesY = (fieldSize.height / nodeSizeMeters).ceil();
    nodesX = (fieldSize.width / nodeSizeMeters).ceil();

    if (grid.isEmpty ||
        grid.length != nodesY ||
        grid[0].isEmpty ||
        grid[0].length != nodesX) {
      // Grid does not match what it should, replace it with an emptry grid
      grid = List.generate(nodesY, (index) => List.filled(nodesX, false));
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'field_size': {
        'x': fieldSize.width,
        'y': fieldSize.height,
      },
      'nodeSizeMeters': nodeSizeMeters,
      'grid': grid,
    };
  }

  static Size _sizeFromJson(Map<String, dynamic>? sizeJson) {
    if (sizeJson == null) {
      return Size(16.54, 8.02);
    }

    return Size.fromJson(sizeJson);
  }
}

class Size {
  final num width;
  final num height;

  const Size(this.width, this.height);

  Size.fromJson(Map<String, dynamic> json)
      : this(json['x'] ?? 16.54, json['y'] ?? 8.02);
}
