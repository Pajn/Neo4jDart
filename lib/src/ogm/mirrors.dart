part of neo4j_dart.ogm;

const _defaultConstructor = const Symbol('');

final _Relation = reflectType(Relation);
final _DateTime = reflectType(DateTime);
final _String = reflectType(String);
final _bool = reflectType(bool);
final _num = reflectType(num);
final _Iterable = reflectType(Iterable);

class _DbRelation {
  Symbol field;
  int edgeId;
  int entityId;
}

String _findLabel(DeclarationMirror cm) => MirrorSystem.getName(cm.simpleName);

List<String> _findLabels(object) {
  var labels = [];
  var cm = reflectClass(object.runtimeType);

  do {
    labels.add(_findLabel(cm));
    cm = cm.superclass;
  } while(cm.superclass != null);

  return labels;
}

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

bool _isReverseRelation(DeclarationMirror dm, [Symbol to]) =>
  dm.metadata.any((annotation) =>
    annotation.type.simpleName == #ReverseOf &&
    (to == null || annotation.reflectee.field == to)
  );

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
  var cm = im.type;

  for (var dm in _getReadableFields(cm)) {
    var value = im.getField(dm.simpleName).reflectee;

    if (value != null && _isSimpleType(value)) {
      properties[_findLabel(dm)] = _convertToDb(value);
    }
  }

  properties['@library'] = MirrorSystem.getName(cm.owner.simpleName);
  properties['@class'] = MirrorSystem.getName(cm.simpleName);

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

_setId(Object object, int id, [ClassMirror cm]) {
  if (cm == null) {
    cm = reflectClass(object.runtimeType);
  }

  // If the object contains an id variable or setter it's set to the database id
  if (_canSetType(_getDeclarations(cm), #id, int)) {
    object.id = id;
  }
}
