library neo4j_dart.test.warehouse_conformance;

import 'package:warehouse/adapters/conformance_tests.dart';
import 'package:neo4j_dart/warehouse.dart';

main() {
  var db = new Neo4j();
  runConformanceTests(() => new Neo4jSession(db));
}
