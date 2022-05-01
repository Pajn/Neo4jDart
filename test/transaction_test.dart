import 'dart:io';

import 'package:neo4j_dart/neo4j_dart.dart';
import 'package:test/test.dart';

import 'test_server.dart';

void main() {
  TestServer? server;

  setUp(() async {
    server = TestServer();
    await server?.start();
  });

  tearDown(() async {
    server?.stop();
  });

  test('Test cypherStatements', () async {
    File sampleResponse = File('sample_responses/continents_success.json');

    server?.routes = [
      Route(
        statusCode: 200,
        content: await sampleResponse.readAsString(),
        path: "/db/neo4j/tx/commit",
      )
    ];

    Neo4j db = Neo4j(
      host: server!.url,
      username: 'neo4j',
      password: 'raincoat-bets-rules',
      database: 'neo4j',
    );

    var result = await Transaction(db).cypherStatements(
      [
        Statement(
          statement: 'MATCH (c:Continent) RETURN c',
        ),
      ],
    );

    expect(result.results[0].data[0].row[0], {
      'code': 'AF',
      'name': 'Africa',
      'url':
          'https://www.unwomen.org/sites/default/files/Communications/Headquarters/Images/01_WhereWeAreAfrica_675x350.jpg?la=es',
    });
  });

  test('Test cypher', () async {
    File sampleResponse = File('sample_responses/continents_success.json');

    server?.routes = [
      Route(
        statusCode: 200,
        content: await sampleResponse.readAsString(),
        path: "/db/neo4j/tx/commit",
      )
    ];

    Neo4j db = Neo4j(
      host: server!.url,
      username: 'neo4j',
      password: 'raincoat-bets-rules',
      database: 'neo4j',
    );

    var result = await db.cypher(
      query: 'MATCH (c:Continent) RETURN c',
    );

    expect(result.data[0].row[0], {
      'code': 'AF',
      'name': 'Africa',
      'url':
          'https://www.unwomen.org/sites/default/files/Communications/Headquarters/Images/01_WhereWeAreAfrica_675x350.jpg?la=es',
    });
  });
}
