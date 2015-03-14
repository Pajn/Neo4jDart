# Neo4j for Dart
A Neo4j driver for Dart.

## Usage
A simple usage example:

    import 'package:neo4j_dart/neo4j_dart.dart';

    main() {
      var db = new Neo4j();
      db.cypher('''
          Create (dart:Language {dart})-[:connects_to]->(neo4j:Database {neo4j})
          Return id(dart), id(neo4j)
        ''', {
        'dart': { 'name': 'Dart' },
        'neo4j': { 'name': 'Neo4j' },
      })
        .then((result) {
          print('successfully created two nodes with id ${result['data'][0]['row'].join(' and ')}');
        });
    }

## Features and bugs
Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Pajn/Neo4jDart/issues
