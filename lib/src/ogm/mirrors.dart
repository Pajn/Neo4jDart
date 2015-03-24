part of neo4j_dart.ogm;

const _defaultConstructor = const Symbol('');
final _objects = new Expando();
final _hasRelation = new Expando<List<DbRelation>>();

final _Relation = reflectType(Relation);
final _DateTime = reflectType(DateTime);
final _String = reflectType(String);
final _bool = reflectType(bool);
final _num = reflectType(num);
final _Iterable = reflectType(Iterable);

class DbRelation {
  Symbol field;
  int edgeId;
  int entityId;
}

String _findLabel(DeclarationMirror cm) => MirrorSystem.getName(cm.simpleName);

bool _isSimpleType(object) {
  if (object is Iterable) {
    return object.isEmpty ||
           _isSimpleType(object.first);
  }

  return object is String ||
         object is num ||
         object is bool ||
         object is DateTime;
}

Map<Symbol, DeclarationMirror> _getDeclarations(ClassMirror cm) {
  if (cm.superclass == null) {
    return const {};
  }

  return {}
    ..addAll(cm.declarations)
    ..addAll(_getDeclarations(cm.superclass));
}

bool _isAssignableTo(ClassMirror value, TypeMirror field) =>
  value.isAssignableTo(field) ||
  (
      (
          value.isSubtypeOf(field.originalDeclaration) ||
          value.superinterfaces.any((cm) => cm.simpleName == field.simpleName) ||
          (value.superclass.mixin.simpleName == #ListBase && field.isSubtypeOf(reflectType(List)))
      ) &&
      field.typeArguments.isNotEmpty && value.typeArguments.isEmpty
  );

bool _canSetType(Map<Symbol, DeclarationMirror> declarations, Symbol field, Type type) {
  var tm = reflectClass(type);

  if (!declarations.containsKey(field) ||
      (declarations[field] is MethodMirror && declarations[field].isGetter)) {
    field = MirrorSystem.getSymbol(MirrorSystem.getName(field) + '=');
  }
  if (!declarations.containsKey(field)) {
    return false;
  }
  var dm = declarations[field];

  return !dm.isPrivate && !dm.isStatic && (
      (dm is VariableMirror && !dm.isConst && !dm.isFinal && _isAssignableTo(tm, dm.type)) ||
      (dm is MethodMirror && dm.isSetter && _isAssignableTo(tm, dm.parameters.first.type))
  );
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
    objects[id] = object;
  }
}

TypeMirror _getType(DeclarationMirror declaration) {
  if (declaration is VariableMirror) {
    return declaration.type;
  } else if (declaration is MethodMirror && declaration.isGetter) {
    return declaration.returnType;
  }

  return null;
}

bool _hasRelationObject(DeclarationMirror dm) {
  var type = _getType(dm);

  if (_isAssignableTo(_Iterable, type)) {
    type = type.typeArguments.first;
  }
  if (type.isAssignableTo(_Relation)) {
    return true;
  }

  return false;
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

bool _isReverseRelation(DeclarationMirror dm, [Symbol to]) =>
  dm.metadata.any((annotation) =>
    annotation.type.simpleName == #ReverseOf &&
    (to == null || annotation.reflectee.field == to)
  );

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

void _setField(InstanceMirror object, Symbol field, item, {Map<Symbol, DeclarationMirror>  declarations}) {
  if (declarations == null) {
    declarations = _getDeclarations(object.type);
  }

  if (_canSetType(declarations, field, List)) {
    if (object.getField(field).reflectee == null) {
      object.setField(field, [item]);
    } else {
      object.getField(field).reflectee.add(item);
    }
  } else {
    object.setField(field, item);
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

    InstanceMirror start = objects[startId];
    InstanceMirror end = objects[endId];

    Map<Symbol, DeclarationMirror> startDeclarations;

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

Iterable<DeclarationMirror> _getReadableFields(ClassMirror cm) =>
  _getDeclarations(cm).values.where((dm) =>
    dm.simpleName != #id && dm.simpleName != #label && !dm.isPrivate && (
        (dm is VariableMirror && !dm.isStatic) ||
        (dm is MethodMirror && dm.isGetter)
    ));

_convertToDb(value) {
  if (value is Iterable) {
    return value.map(_convertToDb).toList();
  }

  if (value is DateTime) {
    return value.toUtc().millisecondsSinceEpoch;
  }

  return value;
}

Map _getProperties(object) {
  var properties = {};
  var im = reflect(object);

  for (var dm in _getReadableFields(im.type)) {
    var value = im.getField(dm.simpleName).reflectee;

    if (value != null && _isSimpleType(value)) {
      properties[_findLabel(dm)] = _convertToDb(value);
    }
  }

  properties['@library'] = MirrorSystem.getName(im.type.owner.simpleName);
  properties['@class'] = MirrorSystem.getName(im.type.simpleName);

  return properties;
}

Iterable<Relation> _getEdges(start) {
  var im = reflect(start);

  var relations = _getReadableFields(im.type).where((dm) {
    var object = im.getField(dm.simpleName).reflectee;

    return object != null && !_isSimpleType(object);
  });

  var edges = relations
    .expand((dm) {
      var object = im.getField(dm.simpleName).reflectee;
      if (object is! Iterable) {
        object = [object];
      }

      if (object.isNotEmpty && object.first is Relation) {
        return object.map((edge) => edge
          ..start = start
          .._label = _findLabel(dm)
        );
      }

      return object.map((end) => new Relation()
        ..start = start
        ..end = end
        .._label = _findLabel(dm)
      );
    });

  return edges;
}

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

_setId(Object object, int id, [ClassMirror cm]) {
  _objects[object] = id;

  if (cm == null) {
    cm = reflectClass(object.runtimeType);
  }

  // If the object contains an id variable or setter it's set to the database id
  if (_canSetType(_getDeclarations(cm), #id, int)) {
    object.id = id;
  }
}

/// Gets the database id of [entity] if it exist, or null otherwise
int entityId(entity) => _objects[entity];
