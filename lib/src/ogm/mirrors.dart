part of neo4j_dart.ogm;

const defaultConstructor = const Symbol('');
final _objects = new Expando();
final _hasRelation = new Expando();

final _Edge = reflectType(Edge);
final _String = reflectType(String);
final _bool = reflectType(bool);
final _num = reflectType(num);

String _findLabel(DeclarationMirror cm) => MirrorSystem.getName(cm.simpleName);

bool _isSimpleType(TypeMirror tm) =>
  tm.isAssignableTo(_String) ||
  tm.isAssignableTo(_num) ||
  tm.isAssignableTo(_bool);

InstanceMirror _createInstance(ClassMirror cm, Map properties, int id) {
  var object = cm.newInstance(defaultConstructor, []);

  properties.forEach((property, value) {
    var declaration = cm.declarations[new Symbol(property)];
    if ((declaration is VariableMirror && !declaration.isStatic) ||
        (declaration is MethodMirror && declaration.isSetter)) {
      object.setField(new Symbol(property), value);
    }
  });

  _setId(object.reflectee, id, cm);
  return object;
}

void _instantiateObject(Map objects, ClassMirror cm, Map properties, int id) {
  if (!objects.containsKey(id)) {
    objects[id] = _createInstance(cm, properties, id);
  }
}

bool _hasEdgeObject(ClassMirror cm, Symbol field) {
  return cm.declarations[field].type.isAssignableTo(_Edge);
}

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

    if (end == null) {
      end = _findOtherObject(objects, notInstantiated[endId], start, startFieldName, #end, endId);
    }

    var endFieldName;
    try {
      endFieldName = end.type.declarations.values.firstWhere((dm) =>
        dm.metadata.any((annotation) =>
          annotation.type.simpleName == #ReverseOf &&
          annotation.reflectee.field == startFieldName
      )).simpleName;

      if (start == null) {
        start = _findOtherObject(
            objects, notInstantiated[startId], end, endFieldName, #start, startId
        );
      }
    } on StateError catch(e) {}

    if (_hasRelation[start.reflectee] == null) {
      _hasRelation[start.reflectee] = [{#field: startFieldName, #id: edgeId}];
    } else {
      _hasRelation[start.reflectee].add({#field: startFieldName, #id: edgeId});
    }

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

      if (_hasRelation[end.reflectee] == null) {
        _hasRelation[end.reflectee] = [{#field: endFieldName, #id: edgeId}];
      } else {
        _hasRelation[end.reflectee].add({#field: endFieldName, #id: edgeId});
      }
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

Map _getProperties(ClassMirror cm, object) {
  var properties = {};
  var im = reflect(object);

  var readable = cm.declarations.values.where((dm) => dm.simpleName != #id &&
                                                      dm.simpleName != #label &&
                                                      !dm.isPrivate && (
      (dm is VariableMirror && !dm.isStatic && _isSimpleType(dm.type)) ||
      (dm is MethodMirror && dm.isGetter && _isSimpleType(reflectType(dm.runtimeType)))
  ) && dm.type.simpleName != #dynamic);

  readable.forEach((dm) {
    properties[_findLabel(dm)] = im.getField(dm.simpleName).reflectee;
  });

  return properties;
}

Iterable<DeclarationMirror> _getRelationFields(ClassMirror cm) =>
  cm.declarations.values.where((dm) =>
    dm.simpleName != #id &&
    !dm.isPrivate && (
       (dm is VariableMirror && !dm.isStatic && !_isSimpleType(dm.type)) ||
       (dm is MethodMirror && dm.isGetter && !_isSimpleType(reflectType(dm.runtimeType)))
    ));

Iterable<Edge> _getEdges(ClassMirror cm, object) {
  var im = reflect(object);

  var relations = _getRelationFields(cm)
    .where(((dm) => im.getField(dm.simpleName).reflectee != null));

  var edges = relations
    .where((dm) => dm.type.isAssignableTo(_Edge))
    .map(((dm) => im.getField(dm.simpleName).reflectee))
    .toList();

  edges.addAll(relations
    .where((dm) => !dm.type.isAssignableTo(_Edge) &&
                   !dm.metadata.any((annotation) => annotation.type.simpleName == #ReverseOf))
    .map(((dm) => new Edge()
      ..start = object
      ..end = im.getField(dm.simpleName).reflectee
      ..label = MirrorSystem.getName(dm.simpleName))
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
  var idField = cm.declarations[#id];
  if ((idField is VariableMirror && !idField.isStatic) ||
      (idField is MethodMirror && idField.isSetter)) {
    reflect(object).setField(#id, id);
  }
}

/// Gets the database id of [entity] if it exist, or null otherwise
int entityId(entity) => _objects[entity];
