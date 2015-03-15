part of neo4j_dart;

/// A single cypher query
class Statement {
  final String cypher;
  final Map<String, dynamic> parameters;
  final List<String> resultDataContents;

  Statement(this.cypher, [this.parameters, this.resultDataContents]);

  Map toJson() {
    var json = {'statement': cypher};
    if (parameters != null) {
      json['parameters'] = parameters;
    }
    if (resultDataContents != null) {
      json['resultDataContents'] = resultDataContents;
    }
    return json;
  }
}
