import 'package:test/test.dart';

import 'package:neo4j_dart/src/network/network.dart';

void main() {
  test('Query without parameters', () {
    final queryStatement = 'MATCH (n) RETURN n';
    final query = Query(
      statements: [Statement(statement: queryStatement)],
    );
    final json = query.toJson();

    expect(json['statements'][0].statement, queryStatement);
  });
  test('Convert Query to JSON', () {
    final queryStatement = 'MATCH (n) RETURN n';
    final queryParams = {'para1': 'param1value'};
    final query = Query(
      statements: [
        Statement(
          statement: queryStatement,
          parameters: Parameters(props: queryParams),
        )
      ],
    );
    final json = query.toJson();

    expect(json['statements'][0].statement, queryStatement);
    expect(json['statements'][0].parameters.props, queryParams);
  });
}
