library test_domain;

import 'dart:async';
import 'package:neo4j_dart/ogm.dart';

class MovieRepository extends Repository<Movie> {
  MovieRepository(DbSession session) : super(session);

  Future<List<Movie>> get recentMovies =>
    cypher('Match (movie:Movie) Where movie.year > 2008 Return movie');
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

  @ReverseOf(#favoriteMovie)
  Iterable<Person> favoredBy;
}

class SpecificMovie extends Movie {
  String genre;
}

class Person {
  String name;
  List<String> nicknames;
  DateTime birthDate;

  Movie favoriteMovie;
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

class Mixin {
  String mixedValue;
}

class MixedIn extends SpecialCases with Mixin {

}

class ActedIn extends Relation<Actor, Movie> {
  String role;
}

class Role extends Relation<Movie, Actor> {
  String role;
}
