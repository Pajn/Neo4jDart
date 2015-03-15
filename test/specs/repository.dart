library node_repository_spec;

import '../helpers.dart';
import '../helpers/domain.dart';

main() {
  var db = setUp();

  describe('Repository', () {
    Repository<Actor> actorRepository;
    MovieRepository movieRepository;
    Movie avatar, badBoys, cars, cars2, fury, theGreenMile, up;

    beforeEach(() {
      actorRepository = new Repository<Actor>(db);
      movieRepository = new MovieRepository(db);

      cars = new Movie()
        ..name = 'Cars'
        ..year = 2006;
      cars2 = new Movie()
        ..name = 'Cars 2'
        ..year = 2011
        ..predecessor = cars;
      up = new Movie()
        ..name = 'Up'
        ..year = 2009;

      return setUpTestData()
        .then((_) => movieRepository.find('name', 'Avatar'))
        .then((m) => avatar = m)
        .then((_) => movieRepository.find('name', 'Bad Boys'))
        .then((m) => badBoys = m)
        .then((_) => movieRepository.find('name', 'Fury'))
        .then((m) => fury = m)
        .then((_) => movieRepository.find('name', 'The Green Mile'))
        .then((m) => theGreenMile = m);
    });

    it('should be able to create a node', () {
      movieRepository.store(up);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('(a:Movie {name:"Up", year:2009})');
    });

    it('should be able to create multiple nodes', () {
      movieRepository.store(cars);
      movieRepository.store(up);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('''
        (a:Movie {name:"Cars", year:2006}),
        (b:Movie {name:"Up", year:2009})
      ''');
    });

    it('should be able to create multiple nodes with relations', () {
      movieRepository.store(cars);
      movieRepository.store(cars2);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('''
        (cars:Movie {name:"Cars", year:2006}),
        (cars2:Movie {name:"Cars 2", year:2011}),
        (cars2)-[:predecessor]->(cars)
      ''');
    });

    it('should be able to update a node', () {
      avatar.name = 'Profile';
      movieRepository.store(avatar);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('(a:Movie {name:"Profile", year:2009})');
    });

    it('should be able to update multiple nodes', () {
        fury.year = 10;
        theGreenMile.name = 'The Red Mile';

        movieRepository.store(fury);
        movieRepository.store(theGreenMile);

        var query = movieRepository.saveChanges();
        return expect(query).toHaveWritten('''
          (a:Movie {name:"Fury", year:10}),
          (b:Movie {name:"The Red Mile", year:1999})
        ''');
    });

    it('should be able to delete a node', () {
        movieRepository.delete(avatar);

        var query = movieRepository.saveChanges();
        return expect(query).toHaveDeleted('(a:Movie {name:"Avatar", year:2009})');
    });

    it('should be able to delete multiple nodes', () {
      movieRepository.delete(fury);
      movieRepository.delete(theGreenMile);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveDeleted('''
        (a:Movie {name:"Fury", year:2014}),
        (b:Movie {name:"The Green Mile", year:1999})
      ''');
    });

    describe('get', () {
      it('should get a node', () =>
        movieRepository.get(avatar.id)
          .then((a) {
            expect(a).toHaveSameProps(avatar);
          }));

      it('should be able to create referenses to related nodes', () =>
        movieRepository.get(badBoys.id)
          .then((badBoys) {
            expect(badBoys.name).toEqual('Bad Boys');
            expect(badBoys.year).toEqual(1995);
            expect(badBoys.sequel.name).toEqual('Bad Boys II');
            expect(badBoys.sequel.year).toEqual(2003);
//            expect(badBoys.sequel.sequel.name).toEqual('Bad Boys 3');
//            expect(badBoys.sequel.sequel.year).toBeNull();
//            expect(badBoys.sequel.sequel.predecessor).toBe(badBoys.sequel);
            expect(badBoys.sequel.predecessor).toBe(badBoys);
//            expect(badBoys.sequel.sequel.sequel).toBeNull();
            expect(badBoys.predecessor).toBeNull();
          }));
    });

    describe('findAll', () {
      it('should get all nodes', () =>
        movieRepository.findAll()
          .then((allMovies) =>
            expect(allMovies.map((movie) => movie.name).toList()..sort())
              .toEqual([
                'Avatar',
                'Bad Boys',
                'Bad Boys 3',
                'Bad Boys II',
                'Fury',
                'The Green Mile',
              ])));

        it('should create referenses to related nodes', () =>
          movieRepository.findAll()
            .then((allMovies) {
              var badBoys = allMovies.singleWhere((movie) => movie.name == 'Bad Boys');
              var badBoys2 = allMovies.singleWhere((movie) => movie.name == 'Bad Boys II');
              var badBoys3 = allMovies.singleWhere((movie) => movie.name == 'Bad Boys 3');

              expect(badBoys.sequel).toBe(badBoys2);
              expect(badBoys2.sequel).toBe(badBoys3);
              expect(badBoys3.sequel).toBeNull();
              expect(badBoys.predecessor).toBeNull();
              expect(badBoys2.predecessor).toBe(badBoys);
              expect(badBoys3.predecessor).toBe(badBoys2);
            }));
    });

    describe('cypher', () {
      it('should instanciate the returned nodes', () =>
        movieRepository.recentMovies
          .then(expectAsync((recentMovies) {
            expect(recentMovies.map((movie) => movie.name).toList()..sort())
              .toEqual(['Avatar', 'Fury']);
          })));
    });
  });
}
