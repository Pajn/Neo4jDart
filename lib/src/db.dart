part of neo4j_dart;

class Neo4j {
  final String host;

  Neo4j([this.host = 'http://127.0.0.1:7474']);

  Future<Map<String, List>> cypher(String query, [Map<String, dynamic> parameters]) =>
    cypherTransaction([new Statement(query, parameters)]);

  Future<Map<String, List>> cypherTransaction(List<Statement> statements) {
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
      .then(JSON.decode);
  }
}
