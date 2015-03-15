part of guinness_neo4j;

class Expect extends gns.Expect {
  Expect(actual) : super(actual);

  NotExpect get not => new NotExpect(actual);

  Future toHaveWritten(expected) => _m.toHaveWritten(actual, expected);
  Future toHaveDeleted(expected) => _m.toHaveDeleted(actual, expected);
  Future toReturnTable(List<String> columns, List<List> rows) =>
    _m.toReturnTable(actual, columns, rows);
  Future toReturnNodes(expected) => _m.toReturnNodes(actual, expected);

  Neo4jMatchers get _m => gns.guinness.matchers;
}

class NotExpect extends gns.NotExpect {
  NotExpect(actual) : super(actual);

  Future toHaveWritten(expected) => _m.toHaveDeleted(actual, expected);
  Future toHaveDeleted(expected) => _m.toHaveWritten(actual, expected);

  Neo4jMatchers get _m => gns.guinness.matchers;
}
