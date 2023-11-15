import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:nt4/nt4.dart';
import 'package:pplib_coprocessor/pathfinding/ad_star.dart';
import 'package:pplib_coprocessor/pathfinding/navgrid.dart';
import 'package:pplib_coprocessor/pathfinding/pathfinder.dart';

void runPathfinding() async {
  NT4Client ntClient =
      NT4Client(serverBaseAddress: '127.0.0.1'); // TODO: allow config

  DateTime startTime = DateTime.now();

  NT4Subscription navGridJsonSub = ntClient.subscribe(
      '/PPLibCoprocessor/navGrid',
      NT4SubscriptionOptions(periodicRateSeconds: 0.001, all: true));
  NT4Subscription startPosSub = ntClient.subscribe('/PPLibCoprocessor/startPos',
      NT4SubscriptionOptions(periodicRateSeconds: 0.001, all: true));
  NT4Subscription goalPosSub = ntClient.subscribe('/PPLibCoprocessor/goalPos',
      NT4SubscriptionOptions(periodicRateSeconds: 0.001, all: true));
  // TODO: dynamic obstacles

  NT4Topic pathTopic = ntClient.publishNewTopic(
      '/PPLibCoprocessor/pathPoints', NT4TypeStr.typeFloat64Arr);

  Pathfinder pathfinder = ADStar(pathGeneratedCallback: (points) {
    Duration generationTime = DateTime.now().difference(startTime);
    print('Generation took ${generationTime.inMicroseconds / 1000.0}ms');
    try {
      List<double> ntPoints = [];
      for (Point p in points) {
        ntPoints.add(p.x.toDouble());
        ntPoints.add(p.y.toDouble());
      }

      ntClient.addSample(pathTopic, ntPoints);
    } catch (_) {}
    print('path generated');
  });

  StreamSubscription navGridStream = navGridJsonSub.stream().listen((sample) {
    if (sample != null && sample is String) {
      try {
        pathfinder.setNavgrid(NavGrid.fromJson(jsonDecode(sample)));
      } catch (_) {}
    }
  });
  StreamSubscription startPosStream = startPosSub.stream().listen((sample) {
    if (sample != null && sample is List) {
      try {
        Point startPos = Point(sample[0] as num, sample[1] as num);
        pathfinder.setStartPosition(startPos);
      } catch (_) {}
    }
  });
  StreamSubscription goalPosStream = goalPosSub.stream().listen((sample) {
    if (sample != null && sample is List) {
      try {
        Point goalPos = Point(sample[0] as num, sample[1] as num);
        startTime = DateTime.now();
        pathfinder.setGoalPosition(goalPos);
      } catch (_) {}
    }
  });

  await Future.wait([
    navGridStream.asFuture(),
    startPosStream.asFuture(),
    goalPosStream.asFuture()
  ], eagerError: true);
}
