class Neo4jResult {
  final List<dynamic> result;

  Neo4jResult(this.result);

  List<dynamic> rowGroups() {
    List<dynamic> rows = [];

    // Map<String, List<dynamic>> data = result['data'];
    return [];
  }
}

class SingleResult {
  final Map<String, dynamic> json;

  SingleResult(this.json);
}

class Data {}
