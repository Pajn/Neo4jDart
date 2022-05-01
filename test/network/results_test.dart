import 'dart:convert';

import 'package:neo4j_dart/src/network/results/results.dart';
import 'package:test/test.dart';

import 'package:neo4j_dart/src/network/network.dart';

void main() {
  final sample_json_response = '''
  {
  "results": [
    {
      "columns": [
        "c"
      ],
      "data": [
        {
          "row": [
            {
              "code": "EU",
              "name": "Europe",
              "url": "some_url_1"
            }
          ],
          "meta": [
            {
              "id": 5,
              "type": "node",
              "deleted": false
            }
          ]
        }
      ]
    },
    {
      "columns": [
        "c"
      ],
      "data": [
        {
          "row": [
            {
              "code": "SA",
              "name": "South America",
              "url": "some_url_2"
            }
          ],
          "meta": [
            {
              "id": 6,
              "type": "node",
              "deleted": false
            }
          ]
        }
      ]
    }
  ]
}
  ''';

  test('Convert JSON string to Results', () {
    final json = jsonDecode(sample_json_response);
    final results = Results.fromJson(json);

    expect(results.results.length, 2);
    expect(results.results[0].data[0].row[0], {
      "code": "EU",
      "name": "Europe",
      "url": "some_url_1",
    });
  });
}
