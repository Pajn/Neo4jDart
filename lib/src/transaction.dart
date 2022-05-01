import 'package:dio/dio.dart';

import 'db.dart';
import './network/network.dart';

class Transaction {
  final Neo4j db;
  final Dio dio;

  Transaction(this.db)
      : dio = Dio(
          BaseOptions(
              baseUrl: '${db.host}/db/${db.database}',
              connectTimeout: 5000,
              receiveTimeout: 3000,
              headers: {
                'Accept': 'application/json; charset=UTF-8',
                'Content-Type': 'application/json; charset=UTF-8',
                'X-Stream': 'true',
                'Authorization': 'Basic ${db.auth}',
              }),
        );

  Future<Result> cypher({
    required String query,
    Parameters? parameters,
  }) =>
      cypherStatements([
        Statement(
          statement: query,
          parameters: parameters,
        )
      ]).then((results) => results.results.first);

  Future<Results> cypherStatements(
    List<Statement> statements,
  ) async {
    dio.interceptors.add(LogInterceptor(
      responseBody: true,
      requestBody: true,
    ));

    final response = await dio.post(
      '/tx/commit',
      data: Query(statements: statements).toJson(),
    );

    return Results.fromJson(response.data);
  }
}
