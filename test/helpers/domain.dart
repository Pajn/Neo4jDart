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

  @ReverseOf(#predecessor)
  Movie sequel;
}

class Following extends Edge<Movie, Movie> {

}

class Actor {
  String name;

  PlayedIn playedIn;
}

class PlayedIn extends Edge<Actor, Movie> {
  String role;
}
