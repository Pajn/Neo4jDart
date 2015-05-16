part of neo4j_dart.ogm;

/**
 * A repository backed by the Neo4j database.
 *
 * The repository abstracts the database by providing methods for finding or storing objects
 * of the generic type T. It also provides a [cypher] method for more advanced queries.
 *
 *
 * ## Usage
 *
 * The repository needs a type of the objects it will work with. It can either be specified while
 * instantiating an object with `var movieRepository = new Repository<Movie>();` or by inheriting
 * the [Repository] class with `class MovieRepository extends Repository<Movie> {}`.
 */
class Repository<T> {
  /// The database session this repository works in
  final DbSession session;

  final _t = reflectClass(T);

  /// The label which nodes is queried from
  String get label => _findLabel(_t);

  Repository(this.session);

  /**
   * Executes a custom cypher query, the results will be parsed as the type [T] of this repository.
   *
   * If you want the raw results you should instead use the cypher method in [db].
   */
  Future<List<T>> cypher(String query, {
                                          Map<String, dynamic> parameters,
                                          List<String> resultDataContents: const ['graph']
                                       }) =>
    session.db.cypher(query, parameters: parameters, resultDataContents: resultDataContents)
      .then(session._instantiate(_t));

  /**
   * Finds a single node by the [where] [Map].
   *
   * For more info on [where] see [findAll].
   * Use [maxDepth] to specify how deep relations should be resolved.
   *
   * Example:
   *     var movie = await movieRepository.find({'name': 'Avatar'});
   */
  Future<T> find(Map where, {int maxDepth: 1}) =>
    findAll(where: where, limit: 1, maxDepth: maxDepth)
      .then((result) => result.isEmpty ? null : result.first);

  /**
   * Finds all nodes of th repository Type.
   *
   * The results can be filtered by passing a [Map] for [where]
   * For filtering pass the property name as key and the required value or matcher as a value.
   * When multiple properties have matchers, all is required to match a node.
   * For documentation on matchers see [Is] and [Do]
   *
   * The results can be paginated using the [limit] parameter which defines how many nodes will
   * be found and [skip] which defines the offset.
   *
   * Relations can be resolved by specifying a positive value to the [maxDepth] parameter.
   *
   * Examples:
   *     // Finds all movies released in 2014
   *     movieRepository.findAll(where: {'year': 2014})
   *
   *     // Finds all movies released since 2010
   *     movieRepository.findAll(where: {'year': IS >= 2010})
   *
   *     // Finds all movies released since 2010 with a name that begin on the letter A
   *     movieRepository.findAll(where: {
   *       'name': Do.match('A.*')
   *       'year': IS >= 2010,
   *     })
   *
   *     // Show page 2 with 10 movies per page
   *     movieRepository.findAll(limit: 10, skip: 10)
   *
   *     // Finds all movies released in 2014 and there direct relations
   *     movieRepository.findAll(where: {'year': 2014}, maxDepth: 1)
   */
  Future<List<T>> findAll({Map where, int limit, int skip: 0, int maxDepth: 0}) {
    var filterQuery = '';
    var parameters;

    if (where != null && where.isNotEmpty) {
      var filters = [];
      var index = 0;
      parameters = {};

      where.forEach((property, value) {

        if (value is Is) {
          filters.add(value.check('n.$property', '{v$index}'));
          value = value.value;
        } else {
          filters.add('n.$property = {v$index}');
        }

        if (value != null) {
          parameters['v$index'] = value;
        }

        index++;
      });

      filterQuery = 'Where ' + filters.join(' AND ');
    }

    var skipQuery = skip > 0 ? 'Skip $skip' : '';
    var limitQuery = limit != null ? 'Limit $limit' : '';
    var depthMatch = (maxDepth == 0) ? '' : '-[*0..$maxDepth]-()';

    var query = '''
      Match (n:$label)
      $filterQuery
      Return id(n), (n)$depthMatch
      $skipQuery $limitQuery
    ''';

    return cypher(query, parameters: parameters, resultDataContents: ['graph', 'row']);
  }

  /**
   * Gets a single node by its [id].
   *
   * Use [maxDepth] to specify how deep relations should be resolved.
   */
  Future<T> get(int id, {int maxDepth: 1}) {
    var depthMatch = (maxDepth == 0) ? '' : '-[*0..$maxDepth]-()';

    return cypher('''
      Match (n:$label)
      Where id(n) = {id}
      Return id(n), (n)$depthMatch
    ''', parameters: {'id': id}, resultDataContents: ['graph', 'row'])
      .then((result) => result.isEmpty ? null : result.first);
  }

  /**
   * Gets a a list of nodes by there [ids].
   *
   * Use [maxDepth] to specify how deep relations should be resolved.
   *
   * NOTE: When a node with specified id is missing it will be omitted, if the length
   * of the returned List is different than the passed List with [ids] this have happened.
   * When this happens the index of [ids] and the returned nodes may no longer line up and
   * you need to be careful to check the ids of the returned nodes.
   */
  Future<List<T>> getAll(List<int> ids, {int maxDepth: 1}) {
    var depthMatch = (maxDepth == 0) ? '' : '-[*0..$maxDepth]-()';

    return cypher('''
        Match (n:$label)
        Where id(n) IN {ids}
        Return id(n), (n)$depthMatch
      ''', parameters: {'ids': ids}, resultDataContents: ['graph', 'row']);
  }

  /**
   * Marks the node for deletion.
   *
   * Use [saveChanges] to persist the deletion.
   * By default relations will not be deleted and the deletion will be rejected by the database
   * if relations to the node exist. Set [deleteRelations] to *true* to also delete relations.
   */
  void delete(T entity, {bool deleteRelations: false}) =>
    session.delete(entity, deleteRelations: deleteRelations);

  /**
   * Marks the node for creation or update.
   *
   * Use [saveChanges] to persist the changes to [entity].
   * For relations to be created the other node must exist in the database or marked for creation
   * in the same repository instance.
   */
  void store(T entity, {bool onlyRelations: false}) => session.store(entity, onlyRelations: onlyRelations);

  /**
   * Persist changes to the database.
   *
   * The changes should have been queued using the [delete] or [store] methods.
   */
  Future saveChanges() => session.saveChanges();
}
