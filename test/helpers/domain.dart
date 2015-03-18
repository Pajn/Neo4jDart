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
  List<DateTime> releaseDates = [];

  Movie predecessor;
  Role centralCharacter;

  @ReverseOf(#predecessor)
  Movie sequel;

  @ReverseOf(#actedIn)
  Iterable<ActedIn> cast;
}

class Person {
  String name;
  List<String> nicknames;
  DateTime birthDate;
}

class Actor extends Person {
  List<ActedIn> actedIn;

  var _special;
  Iterable<SpecialCases> get specials => _special;
  set specials(value) => _special = value;
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

class ActedIn extends Relation<Actor, Movie> {
  String role;
}

class Role extends Relation<Movie, Actor> {
  String role;
}
