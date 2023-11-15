import 'dart:collection';
import 'dart:math';

import 'package:pplib_coprocessor/pathfinding/geometry_util.dart';
import 'package:pplib_coprocessor/pathfinding/navgrid.dart';
import 'package:pplib_coprocessor/pathfinding/pathfinder.dart';

class ADStar extends Pathfinder {
  static const double smoothingAnchorPct = 0.8;
  static const double smoothingControlPct = 0.33;
  static final double kEPS = 2.5;

  NavGrid? navGrid;

  Point? startPos;
  GridPos? startGridPos;
  Point? goalPos;
  GridPos? goalGridPos;

  HashMap<GridPos, num> g = HashMap();
  HashMap<GridPos, num> rhs = HashMap();
  HashMap<GridPos, (num, num)> open = HashMap();
  HashMap<GridPos, (num, num)> incons = HashMap();
  HashSet<GridPos> closed = HashSet();
  HashSet<GridPos> staticObstacles = HashSet();
  HashSet<GridPos> dynamicObstacles = HashSet();
  HashSet<GridPos> obstacles = HashSet();

  double eps = kEPS;

  bool doMinor = true;
  bool doMajor = true;
  bool needsReset = true;

  ADStar({required super.pathGeneratedCallback});

  @override
  void setDynamicObstacles(
      List<(Point<num>, Point<num>)> obs, Point<num> currentRobotPos) {
    if (navGrid == null || goalPos == null) {
      return;
    }

    dynamicObstacles.clear();

    for ((Point<num>, Point<num>) obstacle in obs) {
      var gridPos1 = getGridPos(obstacle.$1);
      var gridPos2 = getGridPos(obstacle.$2);

      int minX = min(gridPos1.x, gridPos2.x);
      int maxX = max(gridPos1.x, gridPos2.x);

      int minY = min(gridPos1.y, gridPos2.y);
      int maxY = max(gridPos1.y, gridPos2.y);

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          dynamicObstacles.add(GridPos(x, y));
        }
      }
    }

    obstacles.clear();
    obstacles.addAll(staticObstacles);
    obstacles.addAll(dynamicObstacles);

    needsReset = true;
    doMinor = true;
    doMajor = true;

    setStartPosition(currentRobotPos);
    setGoalPosition(goalPos!);
  }

  @override
  void setGoalPosition(Point<num> goalPos) {
    if (navGrid == null) {
      return;
    }

    GridPos? pos = findClosestNonObstacle(getGridPos(goalPos));

    if (pos != null) {
      goalGridPos = pos;
      this.goalPos = goalPos;

      doMinor = true;
      doMajor = true;
      needsReset = true;
      doPathIteration();
    }
  }

  @override
  void setNavgrid(NavGrid navGrid) {
    this.navGrid = navGrid;

    staticObstacles.clear();
    for (int row = 0; row < navGrid.nodesY; row++) {
      for (int col = 0; col < navGrid.nodesX; col++) {
        if (navGrid.grid[row][col]) {
          staticObstacles.add(GridPos(col, row));
        }
      }
    }

    obstacles.clear();
    obstacles.addAll(staticObstacles);
    obstacles.addAll(dynamicObstacles);

    doMinor = true;
    doMajor = true;
    needsReset = true;

    doPathIteration();
  }

  @override
  void setStartPosition(Point<num> startPos) {
    if (navGrid == null) {
      return;
    }

    GridPos? pos = findClosestNonObstacle(getGridPos(startPos));

    if (pos != null && pos != startGridPos) {
      startGridPos = pos;
      this.startPos = startPos;

      doMinor = true;
      doPathIteration();
    }
  }

  void doPathIteration() {
    if (startGridPos == null || goalGridPos == null || navGrid == null) {
      return;
    }

    if (needsReset || doMinor || doMajor) {
      doWork();
    }

    if (needsReset || doMinor || doMajor) {
      doPathIteration();
    }
  }

  void doWork() {
    if (needsReset) {
      reset();
      needsReset = false;
    }

    if (doMinor) {
      computeOrImprovePath();
      pathGeneratedCallback(extractPath());
      doMinor = false;
    } else if (doMajor) {
      if (eps > 1.0) {
        eps -= 0.5;
        open.addAll(incons);

        for (GridPos s in open.keys) {
          open[s] = key(s);
        }
        closed.clear();
        computeOrImprovePath();
        pathGeneratedCallback(extractPath());
      }

      if (eps <= 1.0) {
        doMajor = false;
      }
    }
  }

  List<Point> extractPath() {
    if (goalGridPos! == startGridPos) {
      return [goalPos!];
    }

    List<GridPos> path = [];
    path.add(startGridPos!);

    GridPos s = startGridPos!;

    for (int k = 0; k < 200; k++) {
      HashMap<GridPos, num> gList = HashMap();

      for (GridPos x in getOpenNeighbors(s)) {
        gList[x] = g[x]!;
      }

      MapEntry<GridPos, num> min = MapEntry(goalGridPos!, double.infinity);
      for (var entry in gList.entries) {
        if (entry.value < min.value) {
          min = entry;
        }
      }
      s = min.key;

      path.add(s);
      if (s == goalGridPos) {
        break;
      }
    }

    List<GridPos> simplifiedPath = [];
    simplifiedPath.add(path[0]);
    for (int i = 1; i < path.length - 1; i++) {
      if (!walkable(simplifiedPath.last, path[i + 1])) {
        simplifiedPath.add(path[i]);
      }
    }
    simplifiedPath.add(path.last);

    List<Point> fieldPosPath = [];
    for (GridPos pos in simplifiedPath) {
      fieldPosPath.add(gridPosToPoint(pos));
    }

    // Replace start and end positions with their real positions
    fieldPosPath[0] = startPos!;
    fieldPosPath[fieldPosPath.length - 1] = goalPos!;

    List<Point> bezierPoints = [];
    bezierPoints.add(fieldPosPath[0]);
    bezierPoints.add(
        ((fieldPosPath[1] - fieldPosPath[0]) * smoothingControlPct) +
            fieldPosPath[0]);

    for (int i = 1; i < fieldPosPath.length - 1; i++) {
      Point last = fieldPosPath[i - 1];
      Point current = fieldPosPath[i];
      Point next = fieldPosPath[i + 1];

      Point anchor1 = ((current - last) * smoothingAnchorPct) + last;
      Point anchor2 = ((current - next) * smoothingAnchorPct) + next;

      double controlDist = anchor1.distanceTo(anchor2) * smoothingControlPct;

      Point prevControl1 = ((last - anchor1) * smoothingControlPct) + anchor1;
      Point nextControl1 = pointFromDistAndAngle(
              controlDist, pointToAngle(anchor1 - prevControl1)) +
          anchor1;

      Point prevControl2 =
          pointFromDistAndAngle(controlDist, pointToAngle(anchor2 - next)) +
              anchor2;
      Point nextControl2 = ((next - anchor2) * smoothingControlPct) + anchor2;

      bezierPoints.add(prevControl1);
      bezierPoints.add(anchor1);
      bezierPoints.add(nextControl1);

      bezierPoints.add(prevControl2);
      bezierPoints.add(anchor2);
      bezierPoints.add(nextControl2);
    }
    bezierPoints.add(((fieldPosPath[fieldPosPath.length - 2] -
                fieldPosPath[fieldPosPath.length - 1]) *
            smoothingControlPct) +
        fieldPosPath.last);
    bezierPoints.add(fieldPosPath.last);

    List<Point> pathPoints = [];
    int numSegments = (bezierPoints.length - 1) ~/ 3;
    for (int i = 0; i < numSegments; i++) {
      int iOffset = i * 3;

      Point p1 = bezierPoints[iOffset];
      Point p2 = bezierPoints[iOffset + 1];
      Point p3 = bezierPoints[iOffset + 2];
      Point p4 = bezierPoints[iOffset + 3];

      double resolution = 0.05;
      if (p1.distanceTo(p4) <= 1.0) {
        resolution = 0.2;
      }

      for (double t = 0.0; t < 1.0; t += resolution) {
        pathPoints.add(GeometryUtil.cubicLerp(p1, p2, p3, p4, t));
      }
    }
    pathPoints.add(bezierPoints.last);

    return pathPoints;
  }

  num pointToAngle(Point p) {
    return atan2(p.y, p.x);
  }

  Point pointFromDistAndAngle(num dist, num angle) {
    return Point(dist * cos(angle), dist * sin(angle));
  }

  GridPos? findClosestNonObstacle(GridPos pos) {
    if (!obstacles.contains(pos)) {
      return pos;
    }

    HashSet<GridPos> visited = HashSet();
    Queue<GridPos> queue = Queue.of(getAllNeighbors(pos));

    while (queue.isNotEmpty) {
      GridPos check = queue.removeFirst();
      if (!obstacles.contains(check)) {
        return check;
      }
      visited.add(check);

      for (GridPos neighbor in getAllNeighbors(check)) {
        if (!visited.contains(neighbor)) {
          queue.add(neighbor);
        }
      }
    }
    return null;
  }

  bool walkable(GridPos s1, GridPos s2) {
    int x0 = s1.x;
    int y0 = s1.y;
    int x1 = s2.x;
    int y1 = s2.y;

    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int x = x0;
    int y = y0;
    int n = 1 + dx + dy;
    int xInc = (x1 > x0) ? 1 : -1;
    int yInc = (y1 > y0) ? 1 : -1;
    int error = dx - dy;
    dx *= 2;
    dy *= 2;

    for (; n > 0; n--) {
      if (obstacles.contains(GridPos(x, y))) {
        return false;
      }

      if (error > 0) {
        x += xInc;
        error -= dy;
      } else if (error < 0) {
        y += yInc;
        error += dx;
      } else {
        x += xInc;
        y += yInc;
        error -= dy;
        error += dx;
        n--;
      }
    }

    return true;
  }

  void reset() {
    g.clear();
    rhs.clear();
    open.clear();
    incons.clear();
    closed.clear();

    for (int x = 0; x < navGrid!.nodesX; x++) {
      for (int y = 0; y < navGrid!.nodesY; y++) {
        g[GridPos(x, y)] = double.infinity;
        rhs[GridPos(x, y)] = double.infinity;
      }
    }

    rhs[goalGridPos!] = 0.0;
    eps = kEPS;
    open[goalGridPos!] = key(goalGridPos!);
  }

  void computeOrImprovePath() {
    while (true) {
      var sv = topKey();
      if (sv == null) {
        break;
      }
      var s = sv.$1;
      var v = sv.$2;

      if (comparePair(v, key(startGridPos!)) >= 0 &&
          rhs[startGridPos!]! == g[startGridPos!]) {
        break;
      }

      open.remove(s);

      if (g[s]! > rhs[s]!) {
        g[s] = rhs[s]!;
        closed.add(s);

        for (GridPos sn in getOpenNeighbors(s)) {
          updateState(sn);
        }
      } else {
        g[s] = double.infinity;
        for (GridPos sn in getOpenNeighbors(s)) {
          updateState(sn);
        }
        updateState(s);
      }
    }
  }

  void updateState(GridPos s) {
    if (s != goalGridPos!) {
      rhs[s] = double.infinity;

      for (GridPos x in getOpenNeighbors(s)) {
        rhs[s] = min(rhs[s]!, g[x]! + cost(s, x));
      }
    }

    open.remove(s);

    if (g[s] != rhs[s]) {
      if (!closed.contains(s)) {
        open[s] = key(s);
      } else {
        incons[s] = (0.0, 0.0);
      }
    }
  }

  num cost(GridPos sStart, GridPos sGoal) {
    if (isCollision(sStart, sGoal)) {
      return double.infinity;
    }

    return heuristic(sStart, sGoal);
  }

  bool isCollision(GridPos sStart, GridPos sEnd) {
    if (obstacles.contains(sStart) || obstacles.contains(sEnd)) {
      return true;
    }

    if (sStart.x != sEnd.x && sStart.y != sEnd.y) {
      GridPos s1;
      GridPos s2;

      if (sEnd.x - sStart.x == sStart.y - sEnd.y) {
        s1 = GridPos(min(sStart.x, sEnd.x), min(sStart.y, sEnd.y));
        s2 = GridPos(max(sStart.x, sEnd.x), max(sStart.y, sEnd.y));
      } else {
        s1 = GridPos(min(sStart.x, sEnd.x), max(sStart.y, sEnd.y));
        s2 = GridPos(max(sStart.x, sEnd.x), min(sStart.y, sEnd.y));
      }

      return obstacles.contains(s1) || obstacles.contains(s2);
    }

    return false;
  }

  List<GridPos> getOpenNeighbors(GridPos s) {
    List<GridPos> ret = [];

    for (int xMove = -1; xMove <= 1; xMove++) {
      for (int yMove = -1; yMove <= 1; yMove++) {
        GridPos sNext = GridPos(s.x + xMove, s.y + yMove);
        if (!obstacles.contains(sNext) &&
            sNext.x >= 0 &&
            sNext.x < navGrid!.nodesX &&
            sNext.y >= 0 &&
            sNext.y < navGrid!.nodesY) {
          ret.add(sNext);
        }
      }
    }
    return ret;
  }

  List<GridPos> getAllNeighbors(GridPos s) {
    List<GridPos> ret = [];

    for (int xMove = -1; xMove <= 1; xMove++) {
      for (int yMove = -1; yMove <= 1; yMove++) {
        GridPos sNext = GridPos(s.x + xMove, s.y + yMove);
        if (sNext.x >= 0 &&
            sNext.x < navGrid!.nodesX &&
            sNext.y >= 0 &&
            sNext.y < navGrid!.nodesY) {
          ret.add(sNext);
        }
      }
    }
    return ret;
  }

  (num, num) key(GridPos s) {
    if (g[s]! > rhs[s]!) {
      return (rhs[s]! + eps * heuristic(startGridPos!, s), rhs[s]!);
    } else {
      return (g[s]! + heuristic(startGridPos!, s), g[s]!);
    }
  }

  (GridPos, (num, num))? topKey() {
    MapEntry<GridPos, (num, num)>? min;
    for (var entry in open.entries) {
      if (min == null || comparePair(entry.value, min.value) < 0) {
        min = entry;
      }
    }

    if (min == null) {
      return null;
    }

    return (min.key, min.value);
  }

  num heuristic(GridPos sStart, GridPos sGoal) {
    return sqrt(pow(sGoal.x - sStart.x, 2) + pow(sGoal.y - sStart.y, 2));
  }

  int comparePair((num, num) a, (num, num) b) {
    int first = a.$1.compareTo(b.$1);

    if (first == 0) {
      return a.$2.compareTo(b.$2);
    } else {
      return first;
    }
  }

  GridPos getGridPos(Point pos) {
    int x = (pos.x / navGrid!.nodeSizeMeters).floor();
    int y = (pos.y / navGrid!.nodeSizeMeters).floor();

    return GridPos(x, y);
  }

  Point gridPosToPoint(GridPos pos) {
    return Point(
        (pos.x * navGrid!.nodeSizeMeters) + (navGrid!.nodeSizeMeters / 2.0),
        (pos.y * navGrid!.nodeSizeMeters) + (navGrid!.nodeSizeMeters / 2.0));
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
