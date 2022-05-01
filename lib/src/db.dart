import 'transaction.dart';
import 'network/network.dart';
import 'dart:convert';

class Neo4j {
  final String host;
  final String database;
  final String auth;

  Neo4j({
    required this.host,
    required this.database,
    required String username,
    required String password,
  }) : auth = base64Encode(utf8.encode("$username:$password"));

  /// Performs a single cypher query against the database
  Future<Result> cypher({
    required String query,
    Parameters? parameters,
  }) =>
      new Transaction(this).cypher(query: query, parameters: parameters);

  /// Runs multiple cypher queries in a single transaction
  Future<Results> cypherTransaction(List<Statement> statements) =>
      new Transaction(this).cypherStatements(statements);
}
