part of neo4j_dart;

/// Neo4j database connector
class Neo4j {
  /// The address of the Neo4j REST API
  final String host;

  Neo4j([this.host = 'http://127.0.0.1:7474']);

  /// Performs a single cypher query against the database
  Future<Map<String, List>> cypher(String query, [Map<String, dynamic> parameters, List<String> resultDataContents]) =>
    cypherTransaction([new Statement(query, parameters, resultDataContents)])
      .then((results) => results.first);

  /// Runs multiple cypher queries in a single transaction
  Future<List<Map<String, List>>> cypherTransaction(List<Statement> statements) async {
    if (statements.isEmpty) {
      return new Future.value([]);
    }

    var body = JSON.encode({
      'statements' : statements.map((statement) => statement.toJson()).toList(growable: false)
    });

    var response = await http.post('$host/db/data/transaction/commit', headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Stream': 'true',
      },
      body: body
    );

    body = UTF8.decode(response.bodyBytes);
    response = JSON.decode(body);

    if (response['errors'].isNotEmpty) {
      throw response;
    }
    return response['results'];
  }
}
