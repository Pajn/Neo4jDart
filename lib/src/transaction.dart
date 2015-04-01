part of neo4j_dart;

/// An open cypher transaction
class Transaction {
  /// The database this transaction is open against
  final Neo4j db;

  String _url;

  Transaction(this.db) {
    _url = '${db.host}/db/data/transaction';
  }

  /// Performs a single cypher query against the database in this transaction
  Future<Map<String, List>> cypher(String query, {
                                                    Map<String, dynamic> parameters,
                                                    List<String> resultDataContents,
                                                    bool commit: false
                                                  }) =>
    cypherStatements([new Statement(query, parameters, resultDataContents)], commit: commit)
      .then((results) => results.first);

  /// Runs multiple cypher queries in this transaction
  Future<List<Map<String, List>>> cypherStatements(List<Statement> statements, {bool commit: false}) async {
    var body = JSON.encode({
      'statements' : statements.map((statement) => statement.toJson()).toList(growable: false)
    });

    var url = commit? '$_url/commit' : _url;

    var response = await http.post(url, headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: body
    );

    if (response.statusCode == 201) {
      _url = response.headers['location'];
    }

    body = UTF8.decode(response.bodyBytes);
    response = JSON.decode(body);

    if (response['errors'].isNotEmpty) {
      throw response;
    }
    return response['results'];
  }
}
