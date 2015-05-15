part of neo4j_dart.warehouse;

var lg = new LookingGlass();

_labels(Object object) => findLabels(object.runtimeType).join(':');

class Neo4jSession extends GraphDbSessionBase<Neo4j> {
  @override
  final Neo4j db;
  ObjectBuilder _builder;

  @override
  get lookingGlass => lg;

  Neo4jSession(this.db) {
    _builder = new ObjectBuilder(this, lg);
  }

  /// Executes a custom cypher query.
  ///
  /// The results will be instantiated from the saved entity classes.
  /// If you want the raw results you should instead use the cypher method in [db].
  Future<List> cypher(String query, {Map<String, dynamic> parameters,
                                     List<String> resultDataContents: const ['graph']}) =>
    db.cypher(query, parameters: parameters, resultDataContents: resultDataContents)
      .then(_builder.build);

  @override
  Future get(int id, {depth: 1, Type type}) {
    var label = (type == null) ? '' : ':' + findLabel(type);

    return cypher(
        'Match (n$label) '
        'Where id(n) = {id} '
        'Return {id}, (n)-[*0..$depth]-()'
      , parameters: {'id': id}, resultDataContents: const ['graph', 'row']
    )
    .then((result) => result.isEmpty ? null : result.first);
  }

  @override
  Future<List> getAll(Iterable ids, {depth: 0, Type type}) {
    var label = (type == null) ? '' : ':' + findLabel(type);

    return cypher(
        'Match (n$label) '
        'Where id(n) IN {ids} '
        'Return id(n), (n)-[*0..$depth]-()'
      , parameters: {'ids': ids}, resultDataContents: const ['graph', 'row']
    );
  }

  @override
  Future<List> findAll({Map where, int skip: 0, int limit: 50, depth: 0, String sort, Type type}) {
    var parameters = {};
    var whereClause = buildWhereClause(where, parameters, lg);
    var sortClause = (sort == null) ? '' : 'Order By n.$sort ';
    var skipClause = (skip <= 0) ? '' : 'Skip $skip';
    var limitClause = (limit == null) ? '' : 'Limit $limit';
    var label = (type == null) ? '' : ':' + findLabel(type);

    var query =
      'Match (n$label) '
      '$whereClause '
      'Return id(n), (n)-[*0..$depth]-() '
      '$sortClause'
      '$skipClause $limitClause';

    return cypher(query, parameters: parameters, resultDataContents: const ['graph', 'row']);
  }

  @override
  Future<int> countAll({Map where, Type type}) async {
    var parameters = {};
    var whereClause = buildWhereClause(where, parameters, lg);
    var label = (type == null) ? '' : ':' + findLabel(type);

    var query =
      'Match (n$label) '
      '$whereClause '
      'Return count(n)';

    var response = await db.cypher(query, parameters: parameters);
    return response['data'][0]['row'][0];
  }

  @override
  Future deleteAll({Map where, Type type}) async {
    // TODO: implement deleteAll
    if (where != null || type != null) {
      throw 'parameters are not implemented';
    }

    var query =
      'Match (n) '
      'Optional Match (n)-[r]->() '
      'Delete n, r';

    await db.cypher(query);
  }

  @override
  Future resolveRelations(entity, {depth: 1}) {
    // TODO: implement resolveRelations
    throw 'not implemented';
  }

  @override
  Future writeQueue() async {
    var createdNodeIds = new Expando();
    var transaction = [];
    var dbTransaction = db.startCypherTransaction();

    List<DeleteEdgeOperation> edgesToDelete = [];
    List<EdgeOperation> edgesOperations = [];
    List<DbOperation> nodeOperations = [];

    for (var operation in queue) {
      if (operation is DeleteEdgeOperation) {
        // Edges to delete should come first as they may otherwise hinder deletion of nodes
        edgesToDelete.add(operation);
      } else if (operation is EdgeOperation) {
        // Edges to update and create needs to come last so that nodes are created before trying
        // to create an edge to that node
        edgesOperations.add(operation);
      } else {
        nodeOperations.add(operation);
      }
    }

    for (var operation in edgesToDelete) {
      transaction.add(new Statement('Match ()-[r]->() Where id(r) = {id} Delete r', {
        'id': operation.id,
      }));
    }

    if (transaction.isNotEmpty) {
      await dbTransaction.cypherStatements(
          transaction,
          // Commit directly if there are no more work to be done
          commit: nodeOperations.isEmpty && edgesOperations.isEmpty
      );
      transaction = [];
    }

    for (var operation in nodeOperations) {
      var properties;
      if (operation.type != OperationType.delete) {
        properties = lg.lookOnObject(operation.entity).serialize();
      }

      switch (operation.type) {
        case OperationType.create:
          transaction.add(new Statement(
              'Create (n:${_labels(operation.entity)}) Set n = {e} Return id(n)',
              { 'e': properties, }
          ));
          break;
        case OperationType.update:
          transaction.add(new Statement('Match (n) Where id(n) = {id} Set n = {e}', {
            'e': properties,
            'id': operation.id,
          }));
          break;
        case OperationType.delete:
          // TODO: With or without relation?
//            transaction.add(new Statement('''
//              Match (n)
//              Where id(n) = {id}
//              Optional Match (n)-[r]-()
//              Delete n, r
//            ''', { 'id': operation.id }));

          transaction.add(new Statement('Match (n) Where id(n) = {id} Delete n', {
            'id': operation.id,
          }));
          break;
      }
    }

    if (transaction.isNotEmpty) {
      var results = await dbTransaction.cypherStatements(
          transaction,
          commit: edgesOperations.isEmpty // Commit directly if there are no edges to store later
      );

      for (var i = 0; i < nodeOperations.length; i++) {
        var operation = nodeOperations[i];

        if (operation.type == OperationType.create) {
          operation.id = results[i]['data'][0]['row'][0];

          // Store id so it can be used when creating relations, if needed
          createdNodeIds[operation.entity] = operation.id;
        }
      }

      transaction = [];
    }

    for (var operation in edgesOperations) {
      var properties = const {};
      if (operation.entity != null) {
        properties = lg.lookOnObject(operation.entity).serialize();
      }

      switch (operation.type) {
        case OperationType.create:
          var headId = entityId(operation.startNode);
          var tailId = entityId(operation.endNode);
          if (headId == null) headId = createdNodeIds[operation.startNode];
          if (tailId == null) tailId = createdNodeIds[operation.endNode];

          if (headId == null) throw 'head id is null';
          if (tailId == null) throw 'tail id is null';

          transaction.add(new Statement(
              'Match (h), (t) '
              'Where id(h) = {h} and id(t) = {t} '
              'Create (h)-[e:${operation.label} {e}]->(t) '
              'Return id(e)'
            , {
              'e': properties,
              'h': headId,
              't': tailId,
            })
          );
          break;
        case OperationType.update:
          transaction.add(new Statement('Match ()-[r]->() Where id(r) = {id} Set r = {e}', {
            'e': properties,
            'id': operation.id,
          }));
          break;
      }
    }

    if (transaction.isNotEmpty) {
      var results = await dbTransaction.cypherStatements(transaction, commit: true);

      for (var i = 0; i < edgesOperations.length; i++) {
        var operation = edgesOperations[i];

        if (operation.type == OperationType.create) {
          operation.id = results[i]['data'][0]['row'][0];
        }
      }
    }
  }
}
