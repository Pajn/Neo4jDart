library test_helpers;

import 'package:neo4j_dart/neo4j_dart.dart';
import 'package:neo4j_dart/ogm.dart';
import 'helpers/guinness.dart';

export 'package:neo4j_dart/neo4j_dart.dart';
export 'package:neo4j_dart/ogm.dart';
export 'package:unittest/unittest.dart' show expectAsync;
export 'helpers/guinness.dart';
export 'helpers/testdata.dart';

Neo4j setUp() {
  guinnessEnableNeo4jMatchers();

  return new Neo4j();
}
