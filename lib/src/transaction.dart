part of neo4j_dart;

/// An open cypher transaction
class Transaction {
  /// The database this transaction is open against
  final Neo4j db;

  String _url;
  Map _headers;

  Transaction(this.db) {
    _url = '${db.host}/db/data/transaction';
    _headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Content-Type': 'application/json; charset=UTF-8',
      'X-Stream': 'true',
    };

    if (db._auth != null) {
      _headers['authorization'] = 'Basic ${db._auth}';
    }
  }

  /// Performs a single cypher query against the database in this transaction
  Future<Map<String, List>> cypher(String query,
          {Map<String, dynamic> parameters,
          List<String> resultDataContents,
          bool commit: false}) =>
      cypherStatements([new Statement(query, parameters, resultDataContents)],
              commit: commit)
          .then((results) => results.first);

  /// Runs multiple cypher queries in this transaction
  Future<List<Map<String, List>>> cypherStatements(List<Statement> statements,
      {bool commit: false}) async {
    var body = jsonEncode({
      'statements': statements
          .map((statement) => statement.toJson())
          .toList(growable: false)
    });

    var url = commit ? '$_url/commit' : _url;

    var response =
        await httpClient.post(Uri.parse(url), headers: _headers, body: body);

    if (response.statusCode == 201) {
      _url = response.headers['location'];
    }

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
