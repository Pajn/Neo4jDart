import 'package:test/test.dart';
import 'package:neo4j_dart/neo4j_dart.dart';

void main() {
  test('Test connection with the database', () async {
    Neo4j db = Neo4j(
      host: 'http://44.198.180.240:7474',
      username: 'neo4j',
      password: 'raincoat-bets-rules',
      database: 'neo4j',
    );

    var result = await db.cypherTransaction(
      [
        Statement(cypher: 'MATCH (n:Movie) RETURN n LIMIT 25'),
      ],
    );
    print(result);
  });
}
