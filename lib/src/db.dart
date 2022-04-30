part of neo4j_dart;

/// Neo4j database connector
class Neo4j {
  final String host;
  final String database;
  late final String _auth;

  Neo4j({
    required this.host,
    required this.database,
    required String username,
    required String password,
  }) {
    _auth = base64Encode(utf8.encode("$username:$password"));
  }

  /// Performs a single cypher query against the database
  Future<Map<String, List>> cypher({
    required String query,
    required List<String> resultDataContents,
    Map<String, dynamic>? parameters,
  }) =>
      new Transaction(db: this)
          .cypher(query: query, parameters: parameters, commit: true);

  /// Runs multiple cypher queries in a single transaction
  Future<List<dynamic>> cypherTransaction(List<Statement> statements) =>
      new Transaction(db: this).cypherStatements(statements, commit: true);

  /// Start a cypher transaction
  Transaction startCypherTransaction() => new Transaction(db: this);
}
