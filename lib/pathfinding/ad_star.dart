import 'dart:collection';
import 'dart:math';

import 'package:pplib_coprocessor/pathfinding/navgrid.dart';
import 'package:pplib_coprocessor/pathfinding/pathfinder.dart';

class ADStar extends Pathfinder {
  NavGrid? navGrid;

  Point? startPos;
  GridPos? startGridPos;
  Point? goalPos;
  GridPos? goalGridPos;

  HashSet<GridPos> staticObstacles = HashSet();
  HashSet<GridPos> dynamicObstacles = HashSet();
  HashSet<GridPos> obstacles = HashSet();

  ADStar({required super.pathGeneratedCallback});

  @override
  void setDynamicObstacles(
      List<(Point<num>, Point<num>)> obs, Point<num> currentRobotPos) async {
    // TODO: implement setDynamicObstacles
  }

  @override
  void setGoalPosition(Point<num> goalPos) async {
    // TODO: implement setGoalPosition
  }

  @override
  void setNavgrid(NavGrid navGrid) async {
    // TODO: implement setNavgrid
  }

  @override
  void setStartPosition(Point<num> startPos) async {
    // TODO: implement setStartPosition
  }
}

class GridPos {
  final int x;
  final int y;

  const GridPos(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is GridPos &&
      other.runtimeType == runtimeType &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
