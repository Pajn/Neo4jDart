import 'dart:async';
import 'package:neo4j_dart/ogm.dart';

class MovieRepository extends Repository<Movie> {
  MovieRepository(Neo4j db) : super(db);

  Future<List<Movie>> get recentMovies =>
    cypher('Match (movie:Movie) Where movie.year > 2008 Return id(movie), movie');
}

class Movie {
  int id;
  String name;
  int year;

  Movie predecessor;
  Role centralCharacter;

  @ReverseOf(#predecessor)
  Movie sequel;

  @ReverseOf(#actedIn)
  ActedIn cast;
}

class Actor {
  String name;

  ActedIn actedIn;
}

class ActedIn extends Edge<Actor, Movie> {
  String role;
}

class Role extends Edge<Movie, Actor> {
  String role;
}
