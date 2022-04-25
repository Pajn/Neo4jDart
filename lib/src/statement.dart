part of neo4j_dart;

/// A single cypher query
class Statement {
  final String cypher;
  final Map<String, dynamic> parameters;

  /**
   * Tells the database how the returned data should look
   *
   * The default mode is *row* which will return simple values or entities as maps with one
   * value per column.
   *
   * ## Other modes
   * ### graph
   * The graph format will return all returned nodes and relations in the query
   * with full entity description in separate node and relation lists.
   *
   * ### REST
   * The REST format will return all returned nodes and relations in the query with the full
   * REST API description with links for more data about the entity.
   */
  final List<String> resultDataContents;

  Statement(this.cypher, [this.parameters, this.resultDataContents]);

  Map toJson() {
    Map<String, dynamic> json = {'statement': cypher};
    if (parameters != null) {
      json['parameters'] = parameters;
    }
    if (resultDataContents != null) {
      json['resultDataContents'] = resultDataContents;
    }
    return json;
  }
}
