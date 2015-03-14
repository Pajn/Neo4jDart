part of neo4j_dart.ogm;

const defaultConstructor = const Symbol('');
final _objects = new Expando();

final _Edge = reflectType(Edge);
final _String = reflectType(String);
final _bool = reflectType(bool);
final _num = reflectType(num);

String _findLabel(DeclarationMirror cm) => MirrorSystem.getName(cm.simpleName);

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

Symbol _getReverseEdgeName(ClassMirror endType, Symbol startFieldName) =>
  endType.declarations.values.firstWhere((dm) =>
    (dm.metadata
      .firstWhere((annotation) =>
        annotation.type.simpleName == #ReverseOf &&
        annotation.reflectee.field == startFieldName, orElse: () => null)
    ) != null
  ).simpleName;

_instantiateEdges(objects, ClassMirror cm, object, row, rowOffset, {bool incoming}) {
  for (var i = 0; i < row[rowOffset].length; i++) {
    var startFieldName = new Symbol(row[rowOffset][i]);
    var endFieldName;
    VariableMirror thisField;
    InstanceMirror start;
    InstanceMirror end;
    ClassMirror otherType;

    if (incoming) {
      endFieldName = _getReverseEdgeName(cm, startFieldName);
      thisField = cm.declarations[endFieldName];
      end = object;
    } else {
      thisField = cm.declarations[startFieldName];
      start = object;
    }

    var hasEdgeObject = thisField.type.isAssignableTo(_Edge);

    if (hasEdgeObject) {
      if (incoming) {
        otherType = thisField.type.declarations[#end].type;
      } else {
        otherType = thisField.type.declarations[#start].type;
      }
    } else {
      otherType = thisField.type;
    }

    var other = objects[row[rowOffset + 4][i]];
    if (other == null) {
      other = _createInstance(otherType, row[rowOffset + 3][i], row[rowOffset + 4][i]);
      objects[row[rowOffset + 4][i]] = other;
    }

    if (incoming) {
      start = other;
    } else {
      end = other;
      endFieldName = _getReverseEdgeName(otherType, startFieldName);
    }

    if (hasEdgeObject) {
      var edge = _createInstance(thisField.type, row[rowOffset + 1][i], row[rowOffset + 2][i]);
      start.setField(endFieldName, edge.reflectee);
      edge.setField(#start, start.reflectee);
      edge.setField(#end, end.reflectee);
      end.setField(startFieldName, edge.reflectee);
    } else {
      start.setField(startFieldName, end.reflectee);
      end.setField(endFieldName, start.reflectee);
    }
  }
}

_instantiate(ClassMirror cm) => (Map result) {
  var objects = {};

  for (var row in result['data']) {
    row = row['row'];
    var object = objects[row[1]];
    if (object == null) {
      object = _createInstance(cm, row[0], row[1]);
      objects[row[1]] = object;
    }

    if (row.length == 12) {
      _instantiateEdges(objects, cm, object, row, 2, incoming: true);
      _instantiateEdges(objects, cm, object, row, 7, incoming: false);
    }
  }

  return objects.values.map((object) => object.reflectee);
};

Map _getProperties(ClassMirror cm, object) {
  var properties = {};
  var im = reflect(object);

  var readable = cm.declarations.values.where((dm) => dm.simpleName != #id &&
                                                      dm.simpleName != #label &&
                                                      !dm.isPrivate && (
      (dm is VariableMirror && !dm.isStatic) || (dm is MethodMirror && dm.isGetter)
  ) && (
      dm.type.isAssignableTo(_String) ||
      dm.type.isAssignableTo(_num) ||
      dm.type.isAssignableTo(_bool)
  ) && dm.type.simpleName != #dynamic);

  readable.forEach((dm) {
    properties[_findLabel(dm)] = im.getField(dm.simpleName).reflectee;
  });

  return properties;
}

Iterable<Edge> _getEdges(ClassMirror cm, object) {
  var im = reflect(object);


  var relations = cm.declarations.values.where((dm) => dm.simpleName != #id &&
                                                      !dm.isPrivate && (
      (dm is VariableMirror && !dm.isStatic) || (dm is MethodMirror && dm.isGetter)
  ) && !(
      dm.type.isAssignableTo(_String) ||
      dm.type.isAssignableTo(_num) ||
      dm.type.isAssignableTo(_bool)
  ) && im.getField(dm.simpleName).reflectee != null);

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
int id(entity) => _objects[entity];
