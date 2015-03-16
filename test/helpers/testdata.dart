library testdata;

import 'api.dart';

setUpTestData() =>
  cleanUpTestData()
    .then((_) =>
      cypherQuery('CREATE CONSTRAINT ON (language:Language) ASSERT language.name IS UNIQUE'))
    .then((_) =>
      cypherQuery('''
        Create (:Language {name:"Dart"}),
               (:Database {name:"Neo4j"}),
               (:Movie {name:"Fury", year:2014}),
               (:Movie {name:"The Green Mile", year:1999}),
               (:Movie {name:"Avatar", year:2009})
                 -[:centralCharacter {role: "Jake Sully"}]->
               (:Actor {name: "Sam Worthington", birthDate: 207788400000}),

               (bb:Movie {name:"Bad Boys", year:1995})
                 <-[:predecessor]-
               (bb2:Movie {name:"Bad Boys II", year:2003})
                 <-[:predecessor]-
               (bb3:Movie {name:"Bad Boys 3"}),

               (ws:Actor {name:"Will Smith"})-[:actedIn {role: "Mike Lowrey"}]->(bb),
                                         (ws)-[:actedIn {role: "Mike Lowrey"}]->(bb2),
                                         (ws)-[:actedIn {role: "Mike Lowrey"}]->(bb3),

               (:SpecialCases {method: "Value on method", private: 5, defaultValue: "changed",
                               integer: "String", gettersAndSetters: 5, setter: 'set',
                               missingField: "test"})
      '''));

cleanUpTestData() =>
  cypherQuery('Match (n) Optional Match (n)-[r]->() Delete n, r')
  .then((_) =>
    cypherQuery('DROP CONSTRAINT ON (language:Language) ASSERT language.name IS UNIQUE'));
