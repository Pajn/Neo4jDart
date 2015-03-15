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

class Person {
  String name;
}

class Actor extends Person {
  ActedIn actedIn;
}

class SpecialCases {
  Map id;

  int _private = 10;
  int get private => _private;

  int _gettersAndSetter = 10;
  get gettersAndSetters => _gettersAndSetter;
  set gettersAndSetters(value) => _gettersAndSetter = value - 1;

  int integer;

  var defaultValue = 'default';

  var withSetter;
  set setter(value) => withSetter = value;

  method() {
    throw 'Should not be called';
  }
}

class ActedIn extends Edge<Actor, Movie> {
  String role;
}

class Role extends Edge<Movie, Actor> {
  String role;
}
