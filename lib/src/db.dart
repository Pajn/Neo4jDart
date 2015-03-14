part of neo4j_dart;

/// Neo4j database connector
class Neo4j {
  /// The address of the Neo4j REST API
  final String host;

  Neo4j([this.host = 'http://127.0.0.1:7474']);

  /// Performs a single cypher query against the database
  Future<Map<String, List>> cypher(String query, [Map<String, dynamic> parameters]) =>
    cypherTransaction([new Statement(query, parameters)]).then((results) => results.first);

  /// Runs multiple cypher queries in a single transaction
  Future<List<Map<String, List>>> cypherTransaction(List<Statement> statements) {
    var body = JSON.encode({
      'statements' : statements.map((statement) => statement.toJson()).toList(growable: false)
    });

    return http.post('$host/db/data/transaction/commit', headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Content-Type': 'application/json',
      },
      body: body
    )
      .then((response) => response.body)
      .then(JSON.decode)
      .then((result) {
        if (result['errors'].isNotEmpty) {
          throw result;
        }
        return result['results'];
      });
  }
}
