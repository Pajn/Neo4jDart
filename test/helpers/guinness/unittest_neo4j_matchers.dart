part of guinness_neo4j;

class UnitTestMatchersWithNe4j extends gns.UnitTestMatchers implements Neo4jMatchers {

  Future toHaveWritten(query, expected) {
    var variables = getVariables(expected).join(', ');

    return query
      .then(unit.expectAsync((_) => cypherQuery('Match $expected Return $variables')))
      .then(unit.expectAsync((actual) {
        unit.expect(actual['errors'], unit.isEmpty);
        unit.expect(actual['results'], unit.isNot(unit.isEmpty));
      }));
  }

  Future toHaveDeleted(query, expected) {
    var variables = getVariables(expected).join(', ');

    return query
      .then(unit.expectAsync((_) => cypherQuery('Match $expected Return $variables')))
      .then(unit.expectAsync((actual) {
        unit.expect(actual['errors'], unit.isEmpty);
        unit.expect(actual['results'], unit.isEmpty);
      }));
  }

  Future toReturnTable(query, columns, List<List> rows) =>
    query.then(unit.expectAsync((actual) {
      unit.expect(actual['errors'], unit.isEmpty);
      actual = actual['results'][0];
      rows.sort((a, b) => a[0].compareTo(b[0]));
      actual['data'].sort((a, b) => a['row'][0].compareTo(b['row'][0]));
      unit.expect(actual, unit.equals({
        'columns': columns,
        'data': rows.map((row) => {'row': row}),
      }));
    }));

  Future toReturnNodes(query, Map<String, Map> expected) =>
    query.then((actual) {
      unit.expect(actual['errors'], unit.isEmpty);
      actual = actual['results'][0];
      (actual['data'] as List).sort(_sortNodeResult);
      expected.values.forEach((value) {
        value['data'].sort((a, b) => a[a.keys.first].compareTo(b[a.keys.first]));
      });
      unit.expect((actual['columns'] as List).toList()..sort(),
      unit.equals(expected.keys.toList()..sort()));

      List<String> columns = actual['columns'];
      for (var i = 0; i < columns.length; i++) {
        var column = columns[i];

        if (expected[column].containsKey('data')) {
          for (var row = 0; row < expected[column]['data'].length; row++) {
            unit.expect(expected[column]['data'][row],
            unit.equals(actual['data'][row]['row'][i]));
          }
        }
      }

      return actual;
    });

  int _sortNodeResult(a, b) {
    a = a['row'][0];
    b = b['row'][0];
    var aKey = (a.keys.toList()..sort()).first;
    var bKey = (b.keys.toList()..sort()).first;

    if (aKey != bKey) {
      return aKey.compareTo(bKey);
    }

    return a[aKey].compareTo(b[bKey]);
  }
}
