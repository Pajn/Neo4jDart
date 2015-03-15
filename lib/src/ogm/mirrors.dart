part of neo4j_dart.ogm;

const defaultConstructor = const Symbol('');
final _objects = new Expando();
final _hasRelation = new Expando();

final _Edge = reflectType(Edge);
final _String = reflectType(String);
final _bool = reflectType(bool);
final _num = reflectType(num);

String _findLabel(DeclarationMirror cm) => MirrorSystem.getName(cm.simpleName);

bool _isSimpleType(Object object) {
  var tm = reflectType(object.runtimeType);

  return tm.isAssignableTo(_String) ||
         tm.isAssignableTo(_num) ||
         tm.isAssignableTo(_bool);
}

Map<Symbol, DeclarationMirror> _getDeclarations(ClassMirror cm) {
  if (cm.superclass == null) {
    return const {};
  }

  return {}
    ..addAll(cm.declarations)
    ..addAll(_getDeclarations(cm.superclass));
}

bool _canSetType(Map<Symbol, DeclarationMirror> declarations, Symbol field, Type type) {
  var tm = reflectClass(type);

  if (!declarations.containsKey(field) ||
      (declarations[field] is MethodMirror && declarations[field].isGetter)) {
    field = new Symbol(MirrorSystem.getName(field) + '=');
  }
  if (!declarations.containsKey(field)) {
    return false;
  }
  var dm = declarations[field];

  return !dm.isPrivate && !dm.isStatic && (
      (dm is VariableMirror && !dm.isConst && !dm.isFinal && tm.isAssignableTo(dm.type)) ||
      (dm is MethodMirror && dm.isSetter && tm.isAssignableTo(dm.parameters.first.type))
  );
}

void _instantiateObject(Map objects, ClassMirror cm, Map properties, int id) {
  if (!objects.containsKey(id)) {
    var object = cm.newInstance(defaultConstructor, []);
    var declarations = _getDeclarations(cm);

    properties.forEach((property, value) {
      var field = new Symbol(property);
      if (_canSetType(declarations, field, value.runtimeType)) {
        object.setField(field, value);
      }
    });

    _setId(object.reflectee, id, cm);
    objects[id] = object;
  }
}

bool _isEdgeField(DeclarationMirror dm) =>
  (dm is VariableMirror && dm.type.isAssignableTo(_Edge)) ||
  (dm is MethodMirror && dm.returnType.isAssignableTo(_Edge));

bool _hasEdgeObject(ClassMirror cm, Symbol field) =>
  _isEdgeField(cm.declarations[field]);

Object _findOtherObject(Map objects, Map properties, Object start, Symbol field, Symbol edgeField,
                        int otherId) {
  var otherClass;
  if (_hasEdgeObject(start.type, field)) {
    otherClass = start.type.declarations[field].type.superclass.declarations[edgeField].type;
  } else {
    otherClass = start.type.declarations[field].type;
  }
  _instantiateObject(objects, otherClass, properties, otherId);
  return objects[otherId];
}

bool _isReverseRelation(DeclarationMirror dm, [Symbol to]) =>
  dm.metadata.any((annotation) =>
    annotation.type.simpleName == #ReverseOf &&
    (to == null || annotation.reflectee.field == to)
  );

void _keepRelation(Object object, Symbol field, int edgeId) {
  if (_hasRelation[object] == null) {
    _hasRelation[object] = [{#field: field, #id: edgeId}];
  } else {
    _hasRelation[object].add({#field: field, #id: edgeId});
  }
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

    var start = objects[startId];
    var end = objects[endId];

    var startFieldName = new Symbol(relation['type']);
    var endFieldName;

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
    } on StateError catch(e) {}

    _keepRelation(start.reflectee, startFieldName, edgeId);

    if (_hasEdgeObject(start.type, startFieldName)) {
      _instantiateObject(
          objects, start.type.declarations[startFieldName].type, relation['properties'], edgeId
      );

      var edge = objects[edgeId];
      start.setField(startFieldName, edge.reflectee);
      edge.setField(#start, start.reflectee);
      edge.setField(#end, end.reflectee);

      start = edge;
    } else {
      start.setField(startFieldName, end.reflectee);
    }

    if (endFieldName != null) {
      end.setField(endFieldName, start.reflectee);

      _keepRelation(end.reflectee, endFieldName, edgeId);
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

Iterable<DeclarationMirror> _getReadableFields(ClassMirror cm) =>
  _getDeclarations(cm).values.where((dm) =>
    dm.simpleName != #id && dm.simpleName != #label && !dm.isPrivate && (
        (dm is VariableMirror && !dm.isStatic) ||
        (dm is MethodMirror && dm.isGetter)
    ));

Map _getProperties(ClassMirror cm, object) {
  var properties = {};
  var im = reflect(object);

  for (var dm in _getReadableFields(cm)) {
    var object = im.getField(dm.simpleName).reflectee;

    if (object != null && _isSimpleType(object)) {
      properties[_findLabel(dm)] = object;
    }
  }

  return properties;
}

Iterable<Edge> _getEdges(ClassMirror cm, object) {
  var im = reflect(object);

  var relations = _getReadableFields(cm).where((dm) {
    var object = im.getField(dm.simpleName).reflectee;

    return object != null && !_isSimpleType(object);
  });

  var edges = relations
    .where(_isEdgeField)
    .map(((dm) => im.getField(dm.simpleName).reflectee))
    .toList();

  edges.addAll(relations
    .where((dm) => !_isEdgeField(dm) &&
                   !_isReverseRelation(dm))
    .map(((dm) => new Edge()
      ..start = object
      ..end = im.getField(dm.simpleName).reflectee
      ..label = _findLabel(dm))
    ));

  return edges;
}

Iterable<int> _removedRelations(Object object) {
  if (_hasRelation[object] == null) {
    return const [];
  }
  var im = reflect(object);

  return _hasRelation[object]
    .where((relation) => im.getField(relation[#field]).reflectee == null)
    .map((relation) => relation[#id]);
}

_setId(Object object, int id, [ClassMirror cm]) {
  _objects[object] = id;

  if (cm == null) {
    cm = reflectClass(object.runtimeType);
  }

  // If the object contains an id variable or setter it's set to the database id
  if (_canSetType(cm.declarations, #id, int)) {
    object.id = id;
  }
}

/// Gets the database id of [entity] if it exist, or null otherwise
int entityId(entity) => _objects[entity];
