part of neo4j_dart.ogm;

class Repository<T> {
  final Neo4j db;

  final _t = reflectClass(T);
  final List<T> _toCreate = [];
  final Map<int, Map> _toUpdate = {};
  final List<int> _toDelete = [];
  final List<Edge> _edgesToCreate = [];
  final Map<int, Map> _edgesToUpdate = {};
  final List<int> _edgesToDelete = [];

  get label => _findLabel(_t);

  Repository(this.db);

  Future<List<T>> cypher(String query, [Map<String, dynamic> parameters, List<String> resultDataContents]) =>
    db.cypher(query, parameters, resultDataContents)
      .then(_instantiate(_t));

  Future<T> find(property, value) =>
    findAll(property: property, equals: value, limit: 1)
      .then((result) => result.isEmpty ? null : result.first);

  Future<List<T>> findAll({String property, equals, int limit, int skip: 0}) {
    var filterQuery = '';
    if (property != null && equals != null) {
      filterQuery = 'Where n.$property = {value}';
    } else if (property != null) {
      filterQuery = 'Where has(n.$property)';
    }
    var skipQuery = skip > 0 ? 'Skip $skip' : '';
    var limitQuery = limit != null ? 'Limit $limit' : '';

    var query = '''
      Match (n:$label)
      $filterQuery
      Optional Match (n)-[r]-(:$label)
      Return id(n), n, r
      $skipQuery $limitQuery
    ''';

    return cypher(query, {'value': equals}, ['graph', 'row']);
  }

  Future<T> get(int id, {int maxDepth: 1}) =>
    cypher('''
      Match p=(n:$label)-[*0..$maxDepth]-()
      Where id(n) = {id}
      Return {id}, p
    ''', {'id': id}, ['graph', 'row'])
      .then((result) => result.isEmpty ? null : result.first);

  void delete(T entity) {
    _toDelete.add(entityId(entity));
  }

  void store(T entity) {
    if (entityId(entity) == null) {
      _toCreate.add(entity);
    } else {
      _toUpdate[entityId(entity)] = _getProperties(_t, entity);
    }

    var edges = _getEdges(_t, entity).where((e) => entityId(e.end) != null || _toCreate.contains(e.end));
    for (var edge in edges) {
      if (entityId(edge) == null) {
        _edgesToCreate.add(edge);
      } else {
//        _toUpdate[id(edge)] = _getProperties(_t, edge);
      }
    }
  }

  Future saveChanges() {
    var transaction = [];

    _toCreate.forEach((entity) =>
      transaction.add(new Statement('Create (n:$label {e}) Return id(n)', {
          'e': _getProperties(_t, entity)
      })));

    _toUpdate.forEach((id, entity) =>
      transaction.add(new Statement('Match (n:$label) Where id(n) = {id} Set n = {e}', {
          'e': entity,
          'id': id,
      })));

    _toDelete.forEach((id) =>
      transaction.add(new Statement('Match (n:$label) Where id(n) = {id} Delete n', {
          'id': id,
      })));

    return db.cypherTransaction(transaction)
      .then((results) {
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
              'e': _getProperties(reflectType(edge.runtimeType), edge),
              'h': entityId(edge.start),
              't': entityId(edge.end),
          }));
        });

        return db.cypherTransaction(transaction);
      })
    .then((results) {
      for (var i = 0; i < _edgesToCreate.length; i++) {
        _setId(_edgesToCreate[i], results[i]['data'][0]['row'][0]);
      }

      _edgesToCreate.clear();
      _edgesToUpdate.clear();
      _edgesToDelete.clear();
    });
  }
}
