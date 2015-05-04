# Neo4j for Dart
[![Build Status](https://travis-ci.org/Pajn/Neo4jDart.svg?branch=master)](https://travis-ci.org/Pajn/Neo4jDart)
[![Coverage Status](https://coveralls.io/repos/Pajn/Neo4jDart/badge.svg)](https://coveralls.io/r/Pajn/Neo4jDart)

A Neo4j driver for Dart.
Both a simple driver and an OGM (Object Graph Mapper) is provided in separate libraries.

## Usage
A simple usage example:
```dart
import 'package:neo4j_dart/neo4j_dart.dart';

main() async {
  var db = new Neo4j();
  var result = await db.cypher('''
        Create (dart:Language {dart})-[:connects_to]->(neo4j:Database {neo4j})
        Return id(dart), id(neo4j)
      ''', {
        'dart': { 'name': 'Dart' },
        'neo4j': { 'name': 'Neo4j' },
      });

  print('successfully created two nodes with id ${result['data'][0]['row'].join(' and ')}');
}
```

See the example or test folder for more example usages including examples on the OGM.

## Missing features
The most notable missing feature is updating relationship objects, currently they can only be
created or deleted. Ideas for a good API or how to implement it is welcome.

## Features and bugs
Please file feature requests and bugs at the [issue tracker][tracker].
See [waffle][waffle] for current work status.

[tracker]: https://github.com/Pajn/Neo4jDart/issues
[waffle]: https://waffle.io/Pajn/Neo4jDart
