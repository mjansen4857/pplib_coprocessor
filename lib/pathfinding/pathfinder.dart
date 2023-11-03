import 'dart:math';

import 'package:pplib_coprocessor/pathfinding/navgrid.dart';

abstract class Pathfinder {
  final Function(List<Point>) pathGeneratedCallback;

  Pathfinder({required this.pathGeneratedCallback});

  void setNavgrid(NavGrid navGrid);

  void setStartPosition(Point startPos);

  void setGoalPosition(Point goalPos);

  void setDynamicObstacles(List<(Point, Point)> obs, Point currentRobotPos);
}
