library neo4j_dart.example.warehouse;

import 'dart:async';
import 'package:neo4j_dart/warehouse.dart';
import 'package:warehouse/graph.dart';

/// You can inherit [Neo4jRepository] to enhance it with custom methods
class MovieRepository extends Neo4jRepository<Movie> {
  MovieRepository(Neo4jSession session) : super(session);

  Future<List<Movie>> get recentMovies =>
    cypher('Match (movie:Movie) Where movie.year > 2008 Return id(movie), movie');
}

class Movie {
  // If you specify an id property it will be set to the database id
  int id;

  String title;
  int year;

  Movie predecessor;

  // By specifying ReverseOf incoming relations will be queried as well
  @ReverseOf(#predecessor)
  Movie sequel;

  @ReverseOf(#roles)
  List<Role> cast;
}

class Person {
  String name;
  DateTime birthDate;
}

// Inherited properties works as any other
class Actor extends Person {
  List<Role> roles;
}

@Edge(Actor, Movie)
class Role {
  String role;
  Actor actor;
  Movie movie;
}

main() async {
  var db = new Neo4j();
  var dbSession = new Neo4jSession(db);
  var movieRepository = new MovieRepository(dbSession);

  var avatar = new Movie()
    ..title = 'Avatar'
    ..year = 2009;

  var sam = new Actor()
    ..name = 'Sam Worthington'
    ..roles = [
      new Role()
        ..role = 'Jake Sully'
        ..movie = avatar
    ];

  // Mark the movie and the actor for creation, note that the actor is dependant
  // on the movie and thus have to be stored after it.
  dbSession.store(avatar);
  dbSession.store(sam);

  // Persist the changes to the database
  await dbSession.saveChanges();

  // Now we can query the data
  avatar = await movieRepository.find({'title': 'Avatar'});
  var actors = await dbSession.findAll(types: [Actor]);

  // Relations to the node have been queried as well so we can directly work with its data
  print(avatar.cast.first.role);
  print(actors.map((actor) => actor.name));
}
