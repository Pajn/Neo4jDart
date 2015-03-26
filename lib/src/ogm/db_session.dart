part of neo4j_dart.ogm;

class DbSession {
  final Neo4j db;

  final _entities = new Expando();
  final _hasRelation = new Expando();

  final List _toCreate = [];
  final Map<int, Map> _toUpdate = {};
  final List<int> _toDelete = [];
  final List<int> _toDeleteWithRelations = [];
  final List _edgesToCreate = [];
  final Map<int, Map> _edgesToUpdate = {};
  final List<int> _edgesToDelete = [];

  DbSession(this.db);

  void attach(entity, id) {
    _entities[entity] = id;
  }

  /// Gets the database id of [entity] if it exist, or null otherwise
  int entityId(entity) => _entities[entity];

  /**
   * Marks the node for deletion.
   *
   * Use [saveChanges] to persist the deletion.
   * By default relations will not be deleted and the deletion will be rejected by the database
   * if relations to the node exist. Set [deleteRelations] to *true* to also delete relations.
   */
  void delete(entity, {bool deleteRelations: false}) {
    if (entityId(entity) == null) throw 'The entity is not known by the session';

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
  void store(Object entity, [List<String> labels]) {
    if (entityId(entity) == null) {
      if (labels == null) {
        labels = _findLabels(entity);
      }

      _toCreate.add(entity);
    } else {
      _toUpdate[entityId(entity)] = _getProperties(entity);
    }

    _edgesToDelete.addAll(_removedRelations(entity));

    var edges = _getEdges(entity)
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

    for (var entity in _toCreate) {
      var labels = _findLabels(entity);
      var properties = _getProperties(entity);

      transaction.add(new Statement('Create (n:${labels.join(':')} {e}) Return id(n)', {
        'e': properties
      }));
    }

    _toUpdate.forEach((id, entity) {
      transaction.add(new Statement('Match (n) Where id(n) = {id} Set n = {e}', {
          'e': entity,
          'id': id,
      }));
    });

    for (var id in _edgesToDelete) {
      transaction.add(new Statement('Match ()-[r]->() Where id(r) = {id} Delete r', { 'id': id }));
    }

    for (var id in _toDelete) {
      transaction.add(new Statement('Match (n) Where id(n) = {id} Delete n', { 'id': id }));
    }

    for (var id in _toDeleteWithRelations) {
      transaction.add(new Statement('''
        Match (n)
        Where id(n) = {id}
        Optional Match (n)-[r]-()
        Delete n, r
      ''', { 'id': id }));
    }

    var results = await db.cypherTransaction(transaction);

    for (var i = 0; i < _toCreate.length; i++) {
      attach(_toCreate[i], results[i]['data'][0]['row'][0]);
      _setId(_toCreate[i], results[i]['data'][0]['row'][0]);
    }

    _toCreate.clear();
    _toUpdate.clear();
    _toDelete.clear();

    transaction = [];

    for (var edge in _edgesToCreate) {
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
    }

    results = await db.cypherTransaction(transaction);

    for (var i = 0; i < _edgesToCreate.length; i++) {
      _setId(_edgesToCreate[i], results[i]['data'][0]['row'][0]);
    }

    _edgesToCreate.clear();
    _edgesToUpdate.clear();
    _edgesToDelete.clear();
  }

  void _keepRelation(Object object, Symbol field, int edgeId, [int entityId]) {
    var relation = new DbRelation()
      ..edgeId = edgeId
      ..entityId = entityId
      ..field = field;

      if (_hasRelation[object] == null) {
        _hasRelation[object] = [relation];
      } else {
        _hasRelation[object].add(relation);
      }
  }

  void _instantiateObject(Map objects, ClassMirror cm, Map properties, int id) {
    if (!objects.containsKey(id)) {
      if (properties.containsKey('@class') && properties.containsKey('@library')) {
        var library = currentMirrorSystem().findLibrary(MirrorSystem.getSymbol(properties['@library']));
        cm = library.declarations[MirrorSystem.getSymbol(properties['@class'])];
      }

      var object = cm.newInstance(_defaultConstructor, []);
      var declarations = _getDeclarations(cm);

      properties.forEach((property, value) {
        var field = new Symbol(property);

        if (value is List && value.isNotEmpty && value.first is int &&
            _canSetType(declarations, field, <DateTime>[].runtimeType)) {
          object.setField(field, value.map((date) =>
          new DateTime.fromMillisecondsSinceEpoch(date, isUtc: true)).toList()
          );
        } else if (_canSetType(declarations, field, value.runtimeType)) {
          object.setField(field, value);
        } else if (value is int && _canSetType(declarations, field, DateTime)) {
          object.setField(field, new DateTime.fromMillisecondsSinceEpoch(value, isUtc: true));
        }
      });

      _setId(object.reflectee, id, cm);
      attach(object.reflectee, id);
      objects[id] = object;
    }
  }

  Object _findOtherObject(Map objects, Map properties, Object start, Symbol field, Symbol edgeField,
                          int otherId) {
    var startField = start.type.declarations[field];
    ClassMirror otherClass = _getType(startField);

    if (otherClass.isAssignableTo(_Iterable)) {
      otherClass = otherClass.typeArguments.first;
    }
    if (otherClass.isAssignableTo(_Relation)) {
      otherClass = otherClass.superclass.declarations[edgeField].type;
    }

    _instantiateObject(objects, otherClass, properties, otherId);
    return objects[otherId];
  }

  _instantiateGraph(Map<int, InstanceMirror> objects, ClassMirror cm, Map<String, Map<String, List<Map>>> graph) {
    var notInstantiated = {};

    for (Map node in graph['nodes']) {
      node['id'] = int.parse(node['id']);
      var className = MirrorSystem.getName(cm.simpleName);

      if (node['labels'].contains(className)) {
        _instantiateObject(objects, cm, node['properties'], node['id']);
      } else {
        notInstantiated[node['id']] = node['properties'];
      }
    }

    for (Map relation in graph['relationships']) {
      var startId = int.parse(relation['startNode']);
      var edgeId = int.parse(relation['id']);
      var endId = int.parse(relation['endNode']);

      InstanceMirror start = objects[startId];
      InstanceMirror end = objects[endId];

      Map<Symbol, DeclarationMirror> startDeclarations;

      var startFieldName = new Symbol(relation['type']);
      var endFieldName;

      if (start == null && end == null) continue;

      if (end == null) {
        end = _findOtherObject(objects, notInstantiated[endId], start, startFieldName, #end, endId);
      }

      try {
        endFieldName = end.type.declarations.values.firstWhere((dm) =>
        _isReverseRelation(dm, startFieldName)).simpleName;

        if (start == null) {
          start = _findOtherObject(
              objects, notInstantiated[startId], end, endFieldName, #start, startId
          );
        }
      } on StateError catch(e) {
        // StateError means that there doesn't exist any reverse field, which is okay.
      }

      startDeclarations = _getDeclarations(start.type);

      if (_hasRelationObject(startDeclarations[startFieldName])) {
        _keepRelation(start.reflectee, startFieldName, edgeId);

        var edgeType = _getType(startDeclarations[startFieldName]);
        if (_canSetType(startDeclarations, startFieldName, List)) {
          edgeType = edgeType.typeArguments.first;
        }
        _instantiateObject(objects, edgeType, relation['properties'], edgeId);
        var edge = objects[edgeId];
        _setField(start, startFieldName, edge.reflectee, declarations: startDeclarations);

        edge.setField(#start, start.reflectee);
        edge.setField(#end, end.reflectee);

        start = edge;
      } else {
        _keepRelation(start.reflectee, startFieldName, edgeId, entityId(end.reflectee));
        _setField(start, startFieldName, end.reflectee, declarations: startDeclarations);
      }

      if (endFieldName != null) {
        _keepRelation(end.reflectee, endFieldName, edgeId, entityId(start.reflectee));
        _setField(end, endFieldName, start.reflectee);
      }
    }
  }

  _instantiate(ClassMirror cm) => (Map result) {
    var objects = {};
    var hasRow = false;

    for (var row in result['data']) {
      if (row.containsKey('row')) {
        hasRow = true;
      }
      if (row.containsKey('graph')) {
        _instantiateGraph(objects, cm, row['graph']);
      } else if (row.containsKey('row')) {
        row = row['row'];
        _instantiateObject(objects, cm, row[1], row[0]);
      } else {
        throw 'Result must contain graph or row data';
      }
    }

    if (hasRow) {
      return result['data']
        .where((row) => row.containsKey('row') && objects.containsKey(row['row'][0]))
        .map((row) {
          var object = objects[row['row'][0]].reflectee;
          objects.remove(row['row'][0]);
          return object;
        })
        .toList();
    }

    return objects.values.map((object) => object.reflectee);
  };

  Iterable<int> _removedRelations(Object object) {
    if (_hasRelation[object] == null) {
      return const [];
    }
    var im = reflect(object);

    return _hasRelation[object]
    .where((relation) {
      var value = im.getField(relation.field).reflectee;

      if (value is Iterable) {
        return !value.any((edge) {
          if (edge is Relation) {
            return entityId(edge) == relation.edgeId;
          }
          return entityId(edge) == relation.entityId;
        });
      }

      return value == null;
    })
    .map((relation) => relation.edgeId);
  }
}
