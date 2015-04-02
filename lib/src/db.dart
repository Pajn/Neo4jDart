part of neo4j_dart;

/// Neo4j database connector
class Neo4j {
  /// The address of the Neo4j REST API
  final String host;
  String _auth;

  Neo4j({this.host: 'http://127.0.0.1:7474', String username, String password}) {
    if (username != null) {
      _auth = CryptoUtils.bytesToBase64(UTF8.encode("$username:$password"));
    }
  }

  /// Performs a single cypher query against the database
  Future<Map<String, List>> cypher(String query, {
                                                   Map<String, dynamic> parameters,
                                                   List<String> resultDataContents
                                                 }) =>
    new Transaction(this).cypher(
        query,
        parameters: parameters,
        resultDataContents: resultDataContents,
        commit: true
    );

  /// Runs multiple cypher queries in a single transaction
  Future<List<Map<String, List>>> cypherTransaction(List<Statement> statements) =>
    new Transaction(this).cypherStatements(statements, commit: true);

  /// Start a cypher transaction
  Transaction startCypherTransaction() =>
    new Transaction(this);
}
