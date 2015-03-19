part of neo4j_dart;

/// A single cypher query
class Statement {
  final String cypher;
  final Map<String, dynamic> parameters;

  /**
   * Tells the database how the returned data should look
   *
   * The default mode is *row* which will return the data as rows with one value per column.
   * Nodes will be encoded as a Map.
   *
   * The other mode is *graph* which will return all returned nodes and relations in the
   * query in a graph format with full entity description in one nodes and one relations
   * List.
   */
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
