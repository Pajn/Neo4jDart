part of neo4j_dart.ogm;

/**
 * Keeps track of entities and there changes on a single database connection
 */
class DbSession {
  /// The database the session is working on
  final Neo4j db;

  final _entities = new Expando();
  final _hasRelation = new Expando();

  final List<Node> _toCreate = [];
  final List<Node> _toUpdate = [];
  final List<Node> _toDelete = [];
  final List<Node> _toDeleteWithRelations = [];
  final List _edgesToCreate = [];
  final Map<int, Map> _edgesToUpdate = {};
  final List<int> _edgesToDelete = [];

  final _created = new StreamController.broadcast();
  final _updated = new StreamController.broadcast();
  final _deleted = new StreamController.broadcast();

  /// A stream of [Node]s that have been created on this session
  Stream<Node> get onCreated => _created.stream;
  /// A stream of [Node]s that have been updated on this session
  Stream<Node> get onUpdated => _updated.stream;
  /// A stream of [Node]s that have been deleted on this session
  Stream<Node> get onDeleted => _deleted.stream;

  DbSession(this.db);

  /**
   * Attaches an entity to the session.
   *
   * By attaching an entity the session knows about the object and will call update instead of
   * create on store and allow deleting. This does normally don't need to be called manually but
   * can be called in case an object is created in other ways that through the session or a
   * [Repository] attached to a session.
   */
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

    var node = new Node()
      ..id = entityId(entity)
      ..labels = _findLabels(entity)
      ..entity = entity;

    if (deleteRelations) {
      _toDeleteWithRelations.add(node);
    } else {
      _toDelete.add(node);
    }
  }

  /**
   * Marks the node for creation or update.
   *
   * Use [saveChanges] to persist the changes to [entity].
   * For relations to be created the other node must exist in the database or marked for creation
   * in the same repository instance.
   */
  void store(entity) {

    var node = new Node()
      ..id = entityId(entity)
      ..labels = _findLabels(entity)
      ..entity = entity;

    if (node.id == null) {
      _toCreate.add(node);
    } else {
      _toUpdate.add(node);
    }

    _edgesToDelete.addAll(_removedRelations(entity));

    var edges = _getEdges(entity)
      .where((e) => entityId(e.end) != null || _toCreate.any((node) => node.entity == e.end));

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
    var dbTransaction = db.startCypherTransaction();

    for (var node in _toCreate) {
      var properties = _getProperties(node.entity);

      transaction.add(new Statement('Create (n:${node.labels.join(':')} {e}) Return id(n)', {
        'e': properties
      }));
    }

    for (var node in _toUpdate) {
      var properties = _getProperties(node.entity);

      transaction.add(new Statement('Match (n) Where id(n) = {id} Set n = {e}', {
        'e': properties,
        'id': node.id,
      }));
    }

    for (var id in _edgesToDelete) {
      transaction.add(new Statement('Match ()-[r]->() Where id(r) = {id} Delete r', { 'id': id }));
    }

    for (var node in _toDelete) {
      transaction.add(new Statement('Match (n) Where id(n) = {id} Delete n', { 'id': node.id }));
    }

    for (var node in _toDeleteWithRelations) {
      transaction.add(new Statement('''
        Match (n)
        Where id(n) = {id}
        Optional Match (n)-[r]-()
        Delete n, r
      ''', { 'id': node.id }));
    }

    if (transaction.isNotEmpty) {
      var results = await dbTransaction.cypherStatements(
          transaction,
          commit: _edgesToCreate.isEmpty // Commit directly if there are no edges to create
      );

      for (var i = 0; i < _toCreate.length; i++) {
        var entity = _toCreate[i].entity;
        var id = results[i]['data'][0]['row'][0];

        _toCreate[i].id = id;
        attach(entity, id);
        _setId(entity, id);
        _created.add(_toCreate[i]);
      }
    }

    _toUpdate.forEach(_updated.add);
    _toDelete.forEach(_deleted.add);
    _toDeleteWithRelations.forEach(_deleted.add);

    _toCreate.clear();
    _toUpdate.clear();
    _toDelete.clear();

    transaction = [];

    if (_edgesToCreate.isNotEmpty) {
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

      var results = await dbTransaction.cypherStatements(transaction, commit: true);

      for (var i = 0; i < _edgesToCreate.length; i++) {
        _setId(_edgesToCreate[i], results[i]['data'][0]['row'][0]);
      }
    }

    _edgesToCreate.clear();
    _edgesToUpdate.clear();
    _edgesToDelete.clear();
  }

  void _keepRelation(Object object, Symbol field, int edgeId, [int entityId]) {
    var relation = new _DbRelation()
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
        var mirrorSystem = currentMirrorSystem();
        var library = mirrorSystem.findLibrary(MirrorSystem.getSymbol(properties['@library']));
        var requestedClass = library.declarations[MirrorSystem.getSymbol(properties['@class'])];

        if (requestedClass != null) {
          cm = requestedClass;
        }
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

      if ((node['properties'].containsKey('@class') && node['properties'].containsKey('@library')) ||
          node['labels'].contains(className)) {
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
