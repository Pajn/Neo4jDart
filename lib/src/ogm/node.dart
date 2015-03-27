part of neo4j_dart.ogm;

/// Sent as an event from [DbSession]
class Node {
  /// Database id of the node
  int id;
  /// The labels on the node
  List<String> labels;
  /// The entity object representing the node
  var entity;
}
