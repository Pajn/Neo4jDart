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
  /// The database this repository works with
  final Neo4j db;

  final _t = reflectClass(T);
  final List<T> _toCreate = [];
  final Map<int, Map> _toUpdate = {};
  final List<int> _toDelete = [];
  final List<int> _toDeleteWithRelations = [];
  final List<Relation> _edgesToCreate = [];
  final Map<int, Map> _edgesToUpdate = {};
  final List<int> _edgesToDelete = [];

  /// The label which nodes in the database created using this repository will have
  get label => _findLabel(_t);

  Repository(this.db);

  /**
   * Executes a custom cypher query, the results will be parsed as the type [T] of this repository.
   *
   * If you want the raw results you should instead use the cypher method in [db].
   */
  Future<List<T>> cypher(String query, [Map<String, dynamic> parameters,
                                        List<String> resultDataContents = const ['graph']]) =>
    db.cypher(query, parameters, resultDataContents)
      .then(_instantiate(_t));

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

    var query = '''
      Match (n:$label)
      $filterQuery
      Return id(n), (n)-[*0..$maxDepth]-()
      $skipQuery $limitQuery
    ''';

    return cypher(query, parameters, ['graph', 'row']);
  }

  /**
   * Gets a single node by its [id].
   *
   * Use [maxDepth] to specify how deep relations should be resolved.
   */
  Future<T> get(int id, {int maxDepth: 1}) =>
    cypher('''
      Match (n:$label)
      Where id(n) = {id}
      Return {id}, (n)-[*0..$maxDepth]-()
    ''', {'id': id}, ['graph', 'row'])
      .then((result) => result.isEmpty ? null : result.first);

  /**
   * Marks the node for deletion.
   *
   * Use [saveChanges] to persist the deletion.
   * By default relations will not be deleted and the deletion will be rejected by the database
   * if relations to the node exist. Set [deleteRelations] to *true* to also delete relations.
   */
  void delete(T entity, {bool deleteRelations: false}) {
    if (deleteRelations) {
      _toDeleteWithRelations.add(entityId(entity));
    } else {
      _toDelete.add(entityId(entity));
    }
  }

  /**
   * Marks the node for creation or update.
   *
   * Use [saveChanges] to persist the changes to [entity].
   * For relations to be created the other node must exist in the database or marked for creation
   * in the same repository instance.
   */
  void store(T entity) {
    if (entityId(entity) == null) {
      _toCreate.add(entity);
    } else {
      _toUpdate[entityId(entity)] = _getProperties(entity);
    }

    _edgesToDelete.addAll(_removedRelations(entity));

    var edges = _getEdges(_t, entity)
      .where((e) => entityId(e.end) != null || _toCreate.contains(e.end));

    for (var edge in edges) {
      if (entityId(edge) == null) {
        _edgesToCreate.add(edge);
      } else {
//        _toUpdate[id(edge)] = _getProperties(_t, edge);
      }
    }
  }

  /**
   * Persist changes to the database.
   *
   * The changes should have been queued using the [delete] or [store] methods.
   */
  Future saveChanges() async {
    var transaction = [];

    _toCreate.forEach((entity) =>
      transaction.add(new Statement('Create (n:$label {e}) Return id(n)', {
          'e': _getProperties(entity)
      })));

    _toUpdate.forEach((id, entity) =>
      transaction.add(new Statement('Match (n:$label) Where id(n) = {id} Set n = {e}', {
          'e': entity,
          'id': id,
      })));

    _edgesToDelete.forEach((id) =>
      transaction.add(new Statement('Match ()-[r]->() Where id(r) = {id} Delete r', {
          'id': id,
      })));

    _toDelete.forEach((id) =>
      transaction.add(new Statement('Match (n:$label) Where id(n) = {id} Delete n', {
          'id': id,
      })));

    _toDeleteWithRelations.forEach((id) =>
      transaction.add(new Statement('''
        Match (n:$label)
        Where id(n) = {id}
        Optional Match (n)-[r]-()
        Delete n, r
      ''', {
          'id': id,
      })));

    var results = await db.cypherTransaction(transaction);

    for (var i = 0; i < _toCreate.length; i++) {
      _setId(_toCreate[i], results[i]['data'][0]['row'][0], _t);
    }

    _toCreate.clear();
    _toUpdate.clear();
    _toDelete.clear();

    transaction = [];

    _edgesToCreate.forEach((edge) {
      transaction.add(new Statement('''
        Match (h), (t)
        Where id(h) = {h} and id(t) = {t}
        Create (h)-[e:${edge.label} {e}]->(t)
        Return id(e)
      ''', {
          'e': _getProperties(edge),
          'h': entityId(edge.start),
          't': entityId(edge.end),
      }));
    });

    results = await db.cypherTransaction(transaction);

    for (var i = 0; i < _edgesToCreate.length; i++) {
      _setId(_edgesToCreate[i], results[i]['data'][0]['row'][0]);
    }

    _edgesToCreate.clear();
    _edgesToUpdate.clear();
    _edgesToDelete.clear();
  }
}
