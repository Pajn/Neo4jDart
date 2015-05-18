part of neo4j_dart.warehouse;

class Neo4jRepository<T> extends GraphRepository<T> {
  final Neo4jSession session;

  Neo4jRepository(GraphDbSession session, {List<Type> types})
      : this.session = session,
        super(session, types: types);

  /// Executes a custom cypher query.
  ///
  /// The results will be instantiated from the saved entity classes.
  /// If you want the raw results you should instead use the cypher method on [session.db].
  Future<List> cypher(String query, {Map<String, dynamic> parameters,
                                     List<String> resultDataContents: const ['graph']}) =>
    session.cypher(query, parameters: parameters, resultDataContents: resultDataContents);
}
