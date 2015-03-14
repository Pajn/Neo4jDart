part of neo4j_dart;

class Neo4j {
  final String host;

  Neo4j([this.host = 'http://127.0.0.1:7474']);

  Future<Map<String, List>> cypher(String query) =>
    http.post('$host/db/data/cypher', body: JSON.encode({
      'query': query
    }))
    .then((response) => response.body)
    .then(JSON.decode);
}
