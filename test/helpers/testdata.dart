library testdata;

import 'api.dart';

setUpTestData() =>
  cypherQuery('Match (n) Optional Match (n)-[r]->() Delete n, r')
    .then((_) =>
      cypherQuery('''
        Create (:Language {name:"Dart"}),
               (:Database {name:"Neo4j"}),
               (:Movie {name:"Fury", year:2014}),
               (:Movie {name:"The Green Mile", year:1999}),
               (:Movie {name:"Avatar", year:2009}),

               (:Movie {name:"Bad Boys", year:1995})
                 <-[:predecessor]-
               (:Movie {name:"Bad Boys II", year:2003})
                 <-[:predecessor]-
               (:Movie {name:"Bad Boys 3"})
      '''));
