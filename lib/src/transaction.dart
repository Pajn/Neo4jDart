part of neo4j_dart;

/// An open cypher transaction
class Transaction {
  /// The database this transaction is open against
  final Neo4j db;

  late final String _url;
  late final Map<String, String> _headers;

  Transaction({required this.db}) {
    _url = '${db.host}/db/${db.database}/tx';
    _headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Content-Type': 'application/json; charset=UTF-8',
      'X-Stream': 'true',
    };

    _headers['authorization'] = 'Basic ${db._auth}';
  }

  /// Performs a single cypher query against the database in this transaction
  Future<Map<String, List>> cypher({
    required String query,
    Map<String, dynamic>? parameters,
    bool commit: false,
  }) =>
      cypherStatements([
        new Statement(
          cypher: query,
          parameters: parameters,
        )
      ], commit: commit)
          .then((results) => results.first);

  /// Runs multiple cypher queries in this transaction
  Future<List<dynamic>> cypherStatements(List<Statement> statements,
      {bool commit: false}) async {
    var body = jsonEncode({
      'statements': statements
          .map((statement) => statement.toJson())
          .toList(growable: false)
    });

    var url = commit ? '$_url/commit' : _url;

    var response =
        await httpClient.post(Uri.parse(url), headers: _headers, body: body);

    // if (response.statusCode == 201) {
    //   _url = response.headers['location'];
    // }

    body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 400) {
      throw 'Status Code: ${response.statusCode}, body: $body';
    }

    Map<String, dynamic> responseBody = jsonDecode(body);

    if (responseBody['errors'].isNotEmpty) {
      throw new Neo4jException(responseBody);
    }
    return responseBody['results'];
  }
}
