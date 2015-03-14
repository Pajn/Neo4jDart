part of neo4j_dart;

class Statement {
  final String cypher;
  final Map<String, dynamic> parameters;

  Statement(this.cypher, [this.parameters]);

  Map toJson() {
    var json = {'statement': cypher};
    if (parameters != null) {
      json['parameters'] = parameters;
    }
    return json;
  }
}
