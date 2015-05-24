class Depth {
  final match = new StringBuffer();
  final toReturn = [];

  add(String path) {
    match.write('Optional Match p${toReturn.length}=$path ');
    toReturn.add('p${toReturn.length}');
  }
}

Depth buildEdgePattern(depth) {
  var count = 0;
  var depthMatch = new Depth();

  void visitDepth(depth, String start) {
    if (depth == 0) {
    } else if (depth is int) {
      depthMatch.toReturn.add('($start)-[*0..$depth]-()');
      count++;
    } else if (depth is String) {
      depthMatch.add('($start)-[:$depth]-()');
      count++;
    } else if (depth is List) {
      if (depth.every((value) => value is String)) {
        depthMatch.add('($start)-[:${depth.join('|')}]-()');
        count++;
      } else {
        depth.forEach((depth) {
          visitDepth(depth, start);
        });
      }
    } else if (depth is Map) {
      depth.forEach((key, value) {
        if (key is List) {
          key = key.join('|');
        }
        depthMatch.add('($start)-[:$key]-(n$count)');
        count++;
        visitDepth(value, 'n${count - 1}');
      });
    } else {
      throw 'unsupported depth value ${depth.runtimeType}, $depth';
    }
  }

  if (depth == 0) {
    depthMatch.toReturn.add('n');
  } else {
    visitDepth(depth, 'n');
  }

  return depthMatch;
}
