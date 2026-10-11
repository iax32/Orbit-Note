import 'dart:math' as math;

import 'geometry.dart';
import 'scene.dart';

enum CanvasArrangement {
  left,
  center,
  right,
  top,
  middle,
  bottom,
  horizontal,
  vertical,
  grid,
  stackH,
  stackV,
  radial,
  mindMap,
  timeline,
  treeV;

  String get label => switch (this) {
    left => 'Align left',
    center => 'Align horizontal centers',
    right => 'Align right',
    top => 'Align top',
    middle => 'Align vertical centers',
    bottom => 'Align bottom',
    horizontal => 'Distribute horizontally',
    vertical => 'Distribute vertically',
    grid => 'Arrange in grid',
    stackH => 'Stack horizontally',
    stackV => 'Stack vertically',
    radial => 'Arrange in radial circle',
    mindMap => 'Arrange in mind map',
    timeline => 'Arrange in timeline',
    treeV => 'Arrange in vertical tree',
  };
}

/// Pure geometry; callers apply the returned placements as one undo command.
List<CanvasElement> arrangeCanvas(
  Iterable<CanvasElement> selection,
  CanvasArrangement action,
) {
  final elements = selection.where((e) => !e.locked).toList();
  if (elements.length < 2) return [];
  final bounds = elements.map((e) => e.bounds).reduce((a, b) => a.union(b));
  if (action == CanvasArrangement.horizontal ||
      action == CanvasArrangement.vertical) {
    if (elements.length < 3) return [];
    final horizontal = action == CanvasArrangement.horizontal;
    elements.sort(
      (a, b) => (horizontal ? a.x.compareTo(b.x) : a.y.compareTo(b.y)),
    );
    final first = elements.first, last = elements.last;
    final start = horizontal ? first.x : first.y;
    final end = horizontal ? last.x + last.width : last.y + last.height;
    final total = elements.fold<double>(
      0,
      (sum, e) => sum + (horizontal ? e.width : e.height),
    );
    final gap = (end - start - total) / (elements.length - 1);
    var cursor = start;
    return elements.map((e) {
      final result = e.translated(
        horizontal
            ? CanvasPoint(cursor - e.x, 0)
            : CanvasPoint(0, cursor - e.y),
      );
      cursor += (horizontal ? e.width : e.height) + gap;
      return result;
    }).toList();
  }

  if (action == CanvasArrangement.grid) {
    final sorted = [...elements]
      ..sort((a, b) {
        final dy = (a.y / 20).round().compareTo((b.y / 20).round());
        if (dy != 0) return dy;
        return a.x.compareTo(b.x);
      });

    final count = sorted.length;
    final cols = math.max(2, math.sqrt(count).ceil());
    final rows = (count / cols).ceil();

    final colWidths = List<double>.filled(cols, 0.0);
    final rowHeights = List<double>.filled(rows, 0.0);

    for (var i = 0; i < count; i++) {
      final c = i % cols;
      final r = i ~/ cols;
      colWidths[c] = math.max(colWidths[c], sorted[i].width);
      rowHeights[r] = math.max(rowHeights[r], sorted[i].height);
    }

    const gap = 24.0;
    final colX = <double>[bounds.left];
    for (var c = 1; c < cols; c++) {
      colX.add(colX[c - 1] + colWidths[c - 1] + gap);
    }
    final rowY = <double>[bounds.top];
    for (var r = 1; r < rows; r++) {
      rowY.add(rowY[r - 1] + rowHeights[r - 1] + gap);
    }

    return sorted.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final c = i % cols;
      final r = i ~/ cols;
      final targetX = colX[c];
      final targetY = rowY[r];
      return e.translated(CanvasPoint(targetX - e.x, targetY - e.y));
    }).toList();
  }

  if (action == CanvasArrangement.stackH) {
    final sorted = [...elements]..sort((a, b) => a.x.compareTo(b.x));
    const gap = 24.0;
    var cursorX = bounds.left;
    return sorted.map((e) {
      final res = e.translated(CanvasPoint(cursorX - e.x, bounds.top - e.y));
      cursorX += e.width + gap;
      return res;
    }).toList();
  }

  if (action == CanvasArrangement.stackV) {
    final sorted = [...elements]..sort((a, b) => a.y.compareTo(b.y));
    const gap = 24.0;
    var cursorY = bounds.top;
    return sorted.map((e) {
      final res = e.translated(CanvasPoint(bounds.left - e.x, cursorY - e.y));
      cursorY += e.height + gap;
      return res;
    }).toList();
  }

  if (action == CanvasArrangement.radial) {
    final center = bounds.center;
    var rootIndex = 0;
    var minDist = double.infinity;
    for (var i = 0; i < elements.length; i++) {
      final d = (elements[i].bounds.center - center).length;
      if (d < minDist) {
        minDist = d;
        rootIndex = i;
      }
    }

    final root = elements[rootIndex];
    final rootCenter = root.bounds.center;
    final others = <CanvasElement>[];
    for (var i = 0; i < elements.length; i++) {
      if (i != rootIndex) others.add(elements[i]);
    }

    others.sort((a, b) {
      final angleA = math.atan2(
        a.bounds.center.y - rootCenter.y,
        a.bounds.center.x - rootCenter.x,
      );
      final angleB = math.atan2(
        b.bounds.center.y - rootCenter.y,
        b.bounds.center.x - rootCenter.x,
      );
      return angleA.compareTo(angleB);
    });

    final maxOtherDim = others.fold<double>(
      0.0,
      (max, e) => math.max(max, math.max(e.width, e.height)),
    );
    final rootDim = math.max(root.width, root.height);
    final minRadius = (rootDim / 2) + (maxOtherDim / 2) + 60.0;
    final minCircumference = others.length * (maxOtherDim + 24.0);
    final circRadius = minCircumference / (2 * math.pi);
    final radius = math.max(minRadius, circRadius);

    final angleStep = (2 * math.pi) / others.length;
    final results = <CanvasElement>[root];

    for (var i = 0; i < others.length; i++) {
      final e = others[i];
      final angle = i * angleStep;
      final targetCenterX = rootCenter.x + radius * math.cos(angle);
      final targetCenterY = rootCenter.y + radius * math.sin(angle);
      final targetLeft = targetCenterX - e.width / 2;
      final targetTop = targetCenterY - e.height / 2;
      results.add(e.translated(CanvasPoint(targetLeft - e.x, targetTop - e.y)));
    }
    return results;
  }

  if (action == CanvasArrangement.mindMap) {
    final center = bounds.center;
    var rootIndex = 0;
    var minDist = double.infinity;
    for (var i = 0; i < elements.length; i++) {
      final d = (elements[i].bounds.center - center).length;
      if (d < minDist) {
        minDist = d;
        rootIndex = i;
      }
    }

    final root = elements[rootIndex];
    final rootCenter = root.bounds.center;
    final others = <CanvasElement>[];
    for (var i = 0; i < elements.length; i++) {
      if (i != rootIndex) others.add(elements[i]);
    }

    final rightBranch = <CanvasElement>[];
    final leftBranch = <CanvasElement>[];
    for (var i = 0; i < others.length; i++) {
      if (i % 2 == 0) {
        rightBranch.add(others[i]);
      } else {
        leftBranch.add(others[i]);
      }
    }

    final results = <CanvasElement>[root];
    const horizontalGap = 80.0;
    const verticalGap = 20.0;

    if (rightBranch.isNotEmpty) {
      final totalH =
          rightBranch.fold<double>(0.0, (sum, e) => sum + e.height) +
          (rightBranch.length - 1) * verticalGap;
      var curY = rootCenter.y - totalH / 2;
      final targetX = root.x + root.width + horizontalGap;
      for (final e in rightBranch) {
        results.add(e.translated(CanvasPoint(targetX - e.x, curY - e.y)));
        curY += e.height + verticalGap;
      }
    }

    if (leftBranch.isNotEmpty) {
      final totalH =
          leftBranch.fold<double>(0.0, (sum, e) => sum + e.height) +
          (leftBranch.length - 1) * verticalGap;
      var curY = rootCenter.y - totalH / 2;
      for (final e in leftBranch) {
        final targetX = root.x - e.width - horizontalGap;
        results.add(e.translated(CanvasPoint(targetX - e.x, curY - e.y)));
        curY += e.height + verticalGap;
      }
    }

    return results;
  }

  if (action == CanvasArrangement.timeline) {
    final sorted = [...elements]..sort((a, b) => a.x.compareTo(b.x));
    const hGap = 40.0;
    const vOffset = 36.0;
    final axisY = bounds.center.y;
    var cursorX = bounds.left;

    return sorted.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final isTop = i % 2 == 0;
      final targetY = isTop ? axisY - e.height - vOffset : axisY + vOffset;
      final res = e.translated(CanvasPoint(cursorX - e.x, targetY - e.y));
      cursorX += e.width + hGap;
      return res;
    }).toList();
  }

  if (action == CanvasArrangement.treeV) {
    final sorted = [...elements]..sort((a, b) => a.y.compareTo(b.y));
    final root = sorted.first;
    final children = sorted.sublist(1);

    const levelGap = 64.0;
    const siblingGap = 28.0;

    final totalChildrenWidth =
        children.fold<double>(0.0, (sum, e) => sum + e.width) +
        (children.length - 1) * siblingGap;
    final startX = math.min(
      root.x,
      root.bounds.center.x - totalChildrenWidth / 2,
    );

    final results = <CanvasElement>[root];
    var cursorX = startX;
    final targetY = root.y + root.height + levelGap;

    for (final child in children) {
      results.add(
        child.translated(CanvasPoint(cursorX - child.x, targetY - child.y)),
      );
      cursorX += child.width + siblingGap;
    }
    return results;
  }

  return elements
      .map(
        (e) => e.translated(switch (action) {
          CanvasArrangement.left => CanvasPoint(bounds.left - e.x, 0),
          CanvasArrangement.center => CanvasPoint(
            bounds.center.x - e.bounds.center.x,
            0,
          ),
          CanvasArrangement.right => CanvasPoint(
            bounds.right - e.bounds.right,
            0,
          ),
          CanvasArrangement.top => CanvasPoint(0, bounds.top - e.y),
          CanvasArrangement.middle => CanvasPoint(
            0,
            bounds.center.y - e.bounds.center.y,
          ),
          CanvasArrangement.bottom => CanvasPoint(
            0,
            bounds.bottom - e.bounds.bottom,
          ),
          _ => const CanvasPoint(0, 0),
        }),
      )
      .toList();
}
