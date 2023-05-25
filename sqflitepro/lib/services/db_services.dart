// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/foundation.dart' show immutable;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'crud_exceptions.dart';

class NotesService {
  Database? _db;
  Future<DataBaseNotes> updateNote(
      {required DataBaseNotes note, required String text}) async {
    final db = _getDataBaseThow();
    await getNote(id: note.id);
    final updatedCount = await db.update(noteTable, {
      textColumn: text,
      isSyncedWithServerColumn: 0,
    });
    if (updatedCount == 0) {
      throw CouldNotUpdateNote();
    } else {
      return await getNote(id: note.id);
    }
  }

  Future<Iterable<DataBaseNotes>> getAllNotes() async {
    final db = _getDataBaseThow();
    final notes = await db.query(noteTable);
    if (notes.isEmpty) {
      throw CouldNotFindNote();
    } else {
      final allNotes = notes.map((e) => DataBaseNotes.fromRow(e));
      return allNotes;
    }
  }

  Future<DataBaseNotes> getNote({required int id}) async {
    final db = _getDataBaseThow();
    final notes =
        await db.query(noteTable, limit: 1, where: 'id= ?', whereArgs: [id]);
    if (notes.isEmpty) {
      throw CouldNotFindNote();
    } else {
      return DataBaseNotes.fromRow(notes.first);
    }
  }

  Future<int> deleteAllNotes({required int id}) async {
    final db = _getDataBaseThow();

    ///Delte Entire Row from the table
    final deletedCount = await db.delete(noteTable);

    return deletedCount;
  }

  Future<void> deleteNote({required int id}) async {
    final db = _getDataBaseThow();
    final deletedCount =
        await db.delete(noteTable, where: 'id=?', whereArgs: [id]);
    if (deletedCount == 0) {
      throw CouldNotDeleteNote();
    }
  }

  Future<DataBaseNotes> createNote({required DataBaseUser owner}) async {
    final db = _getDataBaseThow();
    final currentDbUser = await getUser(email: owner.email);

    ///Make sure owner is exists in db wih id
    if (currentDbUser != owner) {
      throw CouldNotFindUser();
    }
    const text = '';

    ///create Note adn it gives[notes id]

    final noteId = await db.insert(noteTable, {
      userIdColumn: owner.id,
      textColumn: text,
      isSyncedWithServerColumn: 1
    });
    final note = DataBaseNotes(
      id: noteId,
      userId: owner.id,
      text: text,
      isSyncedWithServer: true,
    );
    return note;
  }

  Future<DataBaseUser> getUser({required String email}) async {
    final db = _getDataBaseThow();
    final results = await db.query(
      userTable,
      limit: 1,
      where: 'email=?',
      whereArgs: [email.toLowerCase()],
    );
    if (results.isEmpty) {
      throw CouldNotFindUser();
    } else {
      ///it gives first row of data
      return DataBaseUser.fromRow(results.first);
    }
  }

  Future<DataBaseUser> createUser({required String email}) async {
    final db = _getDataBaseThow();

    ///checkng user already exists or not
    final results = await db.query(
      userTable,
      limit: 1,
      where: 'email=?',
      whereArgs: [email.toLowerCase()],
    );
    if (results.isNotEmpty) {
      throw UserAlreadyExists();
    }

    ///it returns idby [insert query]
    final userId =
        await db.insert(userTable, {emailColumn: email.toLowerCase()});
    return DataBaseUser(id: userId, email: email);
  }

  Future<void> deleteUser({required String email}) async {
    final db = _getDataBaseThow();
    final deletedCount = await db.delete(
      userTable,
      where: 'email=?',

      /// the [?] means something
      whereArgs: [
        email.toLowerCase(),
      ],
    );
    if (deletedCount != 1) {
      throw CouldNotDeleteUser();
    }
  }

  Database _getDataBaseThow() {
    final db = _db;
    if (db == null) {
      throw DataBaseIsNotOpen();
    } else {
      return db;
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      throw DataBaseIsNotOpen();
    } else {
      db.close();
      _db = null;
    }
  }

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException;
    }
    try {
      final docsPath = await getApplicationDocumentsDirectory();
      final dbPath = join(docsPath.path, dbName);
      final db = await openDatabase(dbPath);
      _db = db;
//create user table
      await db.execute(QueryConstants.createUserTable);
//create notes table

      await db.execute(QueryConstants.createNotesTable);
    } on MissingPlatformDirectoryException {
      throw UnableTogetDocumnetDirectory;
    }
  }
}

@immutable
class QueryConstants {
  static const createUserTable = '''
  CREATE TABLE IF NOT EXISTS "User" (
	"Userid"	INTEGER NOT NULL,
	"email"	INTEGER NOT NULL UNIQUE,
	PRIMARY KEY("Userid" AUTOINCREMENT)
); ''';
  static const createNotesTable = ''' 
CREATE TABLE IF NOT EXISTS "notes" (
	"id"	INTEGER NOT NULL,
	"userid"	INTEGER NOT NULL,
	"text"	TEXT NOT NULL,
	"is_synced_with_server"	INTEGER NOT NULL DEFAULT 0,
	FOREIGN KEY("userid") REFERENCES "User"("Userid"),
	PRIMARY KEY("id" AUTOINCREMENT)

);''';
}

@immutable
class DataBaseUser {
  final int id;
  final String email;
  const DataBaseUser({
    required this.id,
    required this.email,
  });
  DataBaseUser.fromRow(Map<String, Object?> map)
      : id = map['id'] as int,
        email = map['email'] as String;

  @override
  bool operator ==(covariant DataBaseUser other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class DataBaseNotes {
  final int id;
  final int userId;
  final String text;
  final bool isSyncedWithServer;
  DataBaseNotes({
    required this.id,
    required this.userId,
    required this.text,
    required this.isSyncedWithServer,
  });
  DataBaseNotes.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userId = map['userId'] as int,
        text = map[textColumn] as String,
        isSyncedWithServer =
            map[isSyncedWithServerColumn] as int == 1 ? true : false;
  @override
  bool operator ==(covariant DataBaseNotes other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const dbName = 'nates.db';
const noteTable = 'note';
const userTable = 'user';
const idColumn = 'id';
const emailColumn = 'email';
const userIdColumn = 'user_id';
const textColumn = 'text';
const isSyncedWithServerColumn = 'is_sync_with_server';
