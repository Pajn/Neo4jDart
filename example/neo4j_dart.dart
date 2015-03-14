// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library neo4j_dart.example;

import 'package:neo4j_dart/neo4j_dart.dart';

main() {
  var db = new Neo4j();
  db.cypher('''
        Create (dart:Language {dart})-[:connects_to]->(neo4j:Database {neo4j})
        Return id(dart) as dart, id(neo4j) as neo4j
      ''', {
      'dart': { 'name': 'Dart' },
      'neo4j': { 'name': 'Neo4j' },
  })
    .then((result) {
      print('successfully created two nodes with id ${result['data'][0]['row'].join(' and ')}');
    });
}
