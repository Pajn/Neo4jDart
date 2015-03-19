part of neo4j_dart.ogm;

/**
 * Base class for relation objects.
 *
 * If values should be specified on the relations rather than any of the nodes, the model class
 * should inherit [Relation]
 */
class Relation<S, E> {
  String _label;

  /// The node the relations starts or leaves from. (start)-[:relation]->(end)
  S start;
  /// The node the relations ends or enters into. (start)-[:relation]->(end)
  E end;
  /// The label of this relation, inferred from the field name of the start node
  String get label => _label;
}
