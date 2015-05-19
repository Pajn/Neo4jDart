part of neo4j_dart;

class Neo4jException implements Exception {
  final Map response;

  List<Map<String, String>> get errors => response['errors'];
  String get message => response.toString();

  Neo4jException(this.response);

  String toString() => message;
}
