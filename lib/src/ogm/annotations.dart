part of neo4j_dart.ogm;

class Edge<START, END> {
  START start;
  END end;
  String label;

  Edge() {
    label = _findLabel(reflectType(this.runtimeType));
  }
}

class ReverseOf {
  final Symbol field;

  const ReverseOf(this.field);
}
