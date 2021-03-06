library transaction_spec;

import '../helpers.dart';

main() {
  var db = setUp();

  describe('transactions', () {
    beforeEach(setUpTestData);
    afterEach(cleanUpTestData);

    it('should be able to write to the database', () {
      var query = db.cypherTransaction([
        new Statement('''
          Match (dart:Language {name:"Dart"}),
                (neo4j:Database {name:"Neo4j"})
          Create (dart)-[:ConnectsTo]->(neo4j)
        '''),
        new Statement('''
          Create (js:Language {js})
          Return js
        ''', {'js': {'name': 'JavaScript'}})
      ]);

      return expect(query).toReturnNodes([{}, {
          'js': { 'data': [{'name': 'JavaScript'}]}
        }])
        .then((_) =>
          expect(query).toHaveWritten('''
            (a:Language {name:"Dart"})-[b:ConnectsTo]->(c:Database {name:"Neo4j"}),
            (d:Language {name: "JavaScript"})
          '''));
    });

    it('should not commit any statement if any other fails', () {
      var query = db.cypherTransaction([
          new Statement('Create (:Language {name: "Scala"})'),
          new Statement('Create (:Language {name: "Scala"})'),
      ]).catchError(expectAsync((result) {
        expect(result).toBeA(Neo4jException);
        expect(result.errors[0]['code']).toEqual('Neo.ClientError.Schema.ConstraintViolation');
      }));

      return query.then((_) {
        expect(query).not.toHaveWritten('(a:Language {name: "Scala"})');
      });
    });

    it('should be able to handle an open transaction', () async {
      var transaction = db.startCypherTransaction();

      var query = transaction.cypher('''
        Match (dart:Language {name:"Dart"}),
              (neo4j:Database {name:"Neo4j"})
        Create (dart)-[:ConnectsTo]->(neo4j)
        Return dart
      ''');

      await expect(query).toReturnNodes([{
        'dart': { 'data': [{'name': 'Dart'}]}
      }]);

      await expect(query).not.toHaveWritten('''
        (a:Language {name:"Dart"})-[b:ConnectsTo]->(c:Database {name:"Neo4j"})
      ''');

      query = transaction.cypher('''
        Create (js:Language {js})
        Return js
      ''', parameters: {'js': {'name': 'JavaScript'}}, commit: true);

      await expect(query).toHaveWritten('''
        (a:Language {name:"Dart"})-[b:ConnectsTo]->(c:Database {name:"Neo4j"}),
        (d:Language {name: "JavaScript"})
      ''');

      await expect(query).toReturnNodes([{
        'js': { 'data': [{'name': 'JavaScript'}]}
      }]);
    });
  });
}
