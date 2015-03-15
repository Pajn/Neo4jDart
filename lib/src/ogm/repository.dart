part of neo4j_dart.ogm;

class Repository<T> {
  final Neo4j db;

  final _t = reflectClass(T);
  final List<T> _toCreate = [];
  final Map<int, Map> _toUpdate = {};
  final List<int> _toDelete = [];
  final List<int> _toDeleteWithRelations = [];
  final List<Edge> _edgesToCreate = [];
  final Map<int, Map> _edgesToUpdate = {};
  final List<int> _edgesToDelete = [];

  get label => _findLabel(_t);

  Repository(this.db);

  Future<List<T>> cypher(String query, [Map<String, dynamic> parameters, List<String> resultDataContents]) =>
    db.cypher(query, parameters, resultDataContents)
      .then(_instantiate(_t));

  Future<T> find(property, value, {int maxDepth: 1}) =>
    findAll(property: property, equals: value, limit: 1, maxDepth: maxDepth)
      .then((result) => result.isEmpty ? null : result.first);

  Future<List<T>> findAll({String property, equals, int limit, int skip: 0, int maxDepth: 0}) {
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
      Return id(n), (n)-[*0..$maxDepth]-()
      $skipQuery $limitQuery
    ''';

    return cypher(query, {'value': equals}, ['graph', 'row']);
  }

  Future<T> get(int id, {int maxDepth: 1}) =>
    cypher('''
      Match (n:$label)
      Where id(n) = {id}
      Return {id}, (n)-[*0..$maxDepth]-()
    ''', {'id': id}, ['graph', 'row'])
      .then((result) => result.isEmpty ? null : result.first);

  void delete(T entity, {bool deleteRelations: false}) {
    if (deleteRelations) {
      _toDeleteWithRelations.add(entityId(entity));
    } else {
      _toDelete.add(entityId(entity));
    }
  }

  void store(T entity) {
    if (entityId(entity) == null) {
      _toCreate.add(entity);
    } else {
      _toUpdate[entityId(entity)] = _getProperties(_t, entity);
    }

    _edgesToDelete.addAll(_removedRelations(entity));

    var edges = _getEdges(_t, entity).where((e) => entityId(e.end) != null || _toCreate.contains(e.end));
    for (var edge in edges) {
      if (entityId(edge) == null) {
        _edgesToCreate.add(edge);
      } else {
//        _toUpdate[id(edge)] = _getProperties(_t, edge);
      }
    }
  }

  Future saveChanges() async {
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
          'e': _getProperties(reflectType(edge.runtimeType), edge),
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
