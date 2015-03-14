part of guinness_neo4j;

abstract class Neo4jMatchers {
  Future toHaveWritten(actual, expected);
  Future toHaveDeleted(actual, expected);
  Future toReturnTable(actual, List<String> columns, List<List> rows);
  Future toReturnNodes(actual, expected);
}
