part of neo4j_dart.ogm;

const defaultConstructor = const Symbol('');
final _objects = new Expando();

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

_instantiateGraph(Map<int, InstanceMirror> objects, ClassMirror cm, Map<String, Map<String, List<Map>>> graph) {
  for (Map node in graph['nodes']) {
    node['id'] = int.parse(node['id']);
    _instantiateObject(objects, cm, node['properties'], node['id']);
  }

  for (Map relation in graph['relationships']) {
    var start = objects[int.parse(relation['startNode'])];
    var end = objects[int.parse(relation['endNode'])];

    var startFieldName = new Symbol(relation['type']);
    var endFieldName = end.type.declarations.values.firstWhere((dm) =>
      dm.metadata.any((annotation) =>
        annotation.type.simpleName == #ReverseOf &&
        annotation.reflectee.field == startFieldName
      )).simpleName;

    if (_hasEdgeObject(start.type, startFieldName)) {

    } else {
      start.setField(startFieldName, end.reflectee);
      end.setField(endFieldName, start.reflectee);
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
