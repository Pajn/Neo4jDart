/**
 * An Object to Graph mapper.
 *
 * The OGM is completely optional but can be used for a more integrated experience.
 * It uses the repository pattern with plain old dart objects for nodes/vertices and
 * subclasses of [Relation] for relation/edge objects.
 * All communication with the database is done through [Repository] objects.
 *
 * Example:
 * ```dart
 *  import 'dart:async';
 *  import 'package:neo4j_dart/ogm.dart';
 *
 *  /// You can inherit [Repository] to enhance it with custom methods
 *  class MovieRepository extends Repository<Movie> {
 *    MovieRepository(Neo4j db) : super(db);
 *
 *    Future<List<Movie>> get recentMovies =>
 *      cypher('Match (movie:Movie) Where movie.year > 2008 Return id(movie), movie');
 *   }
 *
 *  class Movie {
 *    // If you specify an id property it will be set to the database id
 *    int id;
 *
 *    String name;
 *    int year;
 *
 *    Movie predecessor;
 *
 *    // By specifying ReverseOf incoming relations will be queried as well
 *    @ReverseOf(#predecessor)
 *    Movie sequel;
 *
 *    @ReverseOf(#roles)
 *    Iterable<Role> cast;
 *  }
 *
 *  class Person {
 *    String name;
 *    DateTime birthDate;
 *  }
 *
 *  // Inherited properties works as any other
 *  class Actor extends Person {
 *    List<Role> roles;
 *  }
 *
 *  class Role extends Relation<Actor, Movie> {
 *    String name;
 *  }
 *
 *  main() async {
 *    var db = new Neo4j();
 *    var movieRepository = new MovieRepository(db);
 *    // For repositories that doesn't need any custom behaviour you can use the
 *    // Repository class directly
 *    var actorRepository = new Repository<Actor>(db);
 *
 *  var avatar = new Movie()
 *    ..name = 'Avatar'
 *    ..year = 2009;
 *
 *  var sam = new Actor()
 *    ..name = 'Sam Worthington'
 *    ..roles = [
 *      new Role()
 *        ..name = 'Jake Sully'
 *        ..end = avatar
 *    ];
 *
 *    // Mark the movie for creation
 *    movieRepository.store(avatar);
 *
 *    // Persist the movie to the database
 *    await movieRepository.saveChanges();
 *
 *    // Mark the actor for creation, note that it is related to the movie we just created and thus
 *    // have to be saved after it.
 *    actorRepository.store(sam);
 *    await actorRepository.saveChanges();
 *
 *    // Now we can query the data
 *    avatar = await movieRepository.find({'name': 'Avatar'});
 *
 *    // Relations to the node have been queried as well so we can directly work with its data
 *    print(avatar.cast.first.name);
 *  }
 * ```
 */
library neo4j_dart.ogm;

import 'dart:async';
import 'dart:mirrors';
import 'neo4j_dart.dart';

export 'neo4j_dart.dart';

part 'src/ogm/annotations.dart';
part 'src/ogm/is.dart';
part 'src/ogm/mirrors.dart';
part 'src/ogm/relation.dart';
part 'src/ogm/repository.dart';
