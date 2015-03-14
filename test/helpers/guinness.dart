library guinness_neo4j;

import 'dart:async';
import 'package:guinness/guinness.dart' as gns;
import 'package:unittest/unittest.dart' as unit;
import 'api.dart';
import 'cypher.dart';

export 'package:guinness/guinness.dart';

part 'guinness/interfaces.dart';
part 'guinness/expect.dart';
part 'guinness/syntax.dart';
part 'guinness/unittest_neo4j_matchers.dart';

void guinnessEnableNeo4jMatchers() {
  gns.guinness.matchers = new UnitTestMatchersWithNe4j();
}
