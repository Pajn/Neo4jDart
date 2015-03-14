part of neo4j_dart;

class Neo4j {
  final String host;

  Neo4j([this.host = 'http://127.0.0.1:7474']);

  Future<Map<String, List>> cypher(String query, [Map<String, dynamic> parameters]) {
    var statement = { 'statement': query };
    if (parameters != null) {
      statement['parameters'] = parameters;
    }

    return http.post('$host/db/data/transaction/commit', headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Content-Type': 'application/json',
      },
      body: JSON.encode({
        'statements' : [statement]
      }))
        .then((response) => response.body)
        .then(JSON.decode);
  }
}
