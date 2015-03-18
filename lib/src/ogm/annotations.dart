part of neo4j_dart.ogm;

/**
 * Mark relations with [ReverseOf] to show that the relations is incoming from another node.
 */
class ReverseOf {
  /// The name of the relation going out from the other node
  final Symbol field;

  const ReverseOf(this.field);
}
