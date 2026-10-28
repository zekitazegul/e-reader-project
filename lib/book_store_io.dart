import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'dart:io';
import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'books.dart';
import 'sample_book.dart';

String _bookKey(BookFile book) => '${book.name}:${sha256.convert(book.bytes)}';

List<BookFile> _filterRemoved(
  ({List<BookFile> books, Set<String> removed}) data,
) =>
    data.books.where((book) => !data.removed.contains(_bookKey(book))).toList();

class BookStore {
  BookStore({this.includeSampleBook = true});
  final bool includeSampleBook;
  final _files = <String, ({FileStat stat, BookFile book})>{};
  static const _cacheBudget = 32 * 1024 * 1024;
  int _cachedBytes = 0;

  Future<BookFile?> _readFile(File file, {String? name}) async {
    name ??= file.uri.pathSegments.last;
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size > 100 * 1024 * 1024) {
      return null;
    }
    final cached = _files.remove(file.path);
    if (cached != null) _cachedBytes -= cached.book.bytes.length;
    final book =
        cached != null &&
            cached.book.name == name &&
            cached.stat.size == stat.size &&
            cached.stat.modified == stat.modified &&
            cached.stat.changed == stat.changed
        ? cached.book
        : BookFile(name, await file.readAsBytes());
    if (book.bytes.length <= _cacheBudget) {
      while (_files.isNotEmpty &&
          _cachedBytes + book.bytes.length > _cacheBudget) {
        _cachedBytes -= _files.remove(_files.keys.first)!.book.bytes.length;
      }
      _files[file.path] = (stat: stat, book: book);
      _cachedBytes += book.bytes.length;
    }
    return book;
  }

  static const folderChannel = MethodChannel('e_reader/folder');
  bool get supportsFolderSelection => true;
  Future<bool> discoverFolder() async => Platform.isAndroid
      ? await folderChannel.invokeMethod<bool>('discover') ?? false
      : false;
  Future<bool> selectFolder() async {
    if (Platform.isAndroid) {
      return await folderChannel.invokeMethod<bool>('pick') ?? false;
    }
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return false;
    await SharedPreferencesAsync().setString('library.folder.v1', path);
    return true;
  }

  Stream<void> changes() {
    StreamSubscription<FileSystemEvent>? watcher;
    bool cancelled = false;
    late final StreamController<void> events;
    events = StreamController<void>(
      onListen: () async {
        if (Platform.isAndroid) {
          folderChannel.setMethodCallHandler((call) async {
            if (call.method == 'changed' && !cancelled) events.add(null);
          });
        }
        try {
          final directory = await folder();
          if (!cancelled) {
            watcher = directory.watch().listen(
              (_) => events.add(null),
              onError: events.addError,
            );
          }
        } catch (error) {
          if (!cancelled) events.addError(error);
        }
      },
      onCancel: () async {
        cancelled = true;
        if (Platform.isAndroid) folderChannel.setMethodCallHandler(null);
        await watcher?.cancel();
      },
    );
    return events.stream;
  }

  Future<Directory> folder() async {
    if (!Platform.isAndroid) {
      final selected = await SharedPreferencesAsync().getString(
        'library.folder.v1',
      );
      if (selected != null) return Directory(selected);
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}e-books')
        .create(recursive: true);
  }

  Future<String> location() async {
    if (Platform.isAndroid) {
      final selected = await folderChannel.invokeMethod<String>('location');
      if (selected != null) return selected;
    }
    return (await folder()).path;
  }

  Future<List<BookFile>> scan() async {
    final books = <BookFile>[];
    final bundledRemoved =
        await SharedPreferencesAsync().getStringList(bundledRemovalKey) ?? [];
    if (includeSampleBook && !bundledRemoved.contains(sampleBookName)) {
      books.add(await loadSampleBook());
    }
    await for (final entity in (await folder()).list()) {
      if (entity is File && isBook(entity.path)) {
        final book = await _readFile(entity);
        if (book != null) books.add(book);
      }
    }
    if (Platform.isAndroid) {
      final selected = await folderChannel.invokeListMethod<dynamic>('scan');
      if (selected != null) {
        for (final item in selected.cast<Map<dynamic, dynamic>>()) {
          final book = await _readFile(
            File(item['path'] as String),
            name: item['name'] as String,
          );
          if (book != null) books.add(book);
        }
      }
    }
    final present = books.toSet();
    _files.removeWhere((_, entry) {
      if (present.contains(entry.book)) return false;
      _cachedBytes -= entry.book.bytes.length;
      return true;
    });
    books.sort((a, b) => a.name.compareTo(b.name));
    final removed =
        (await SharedPreferencesAsync().getStringList('library.removed.v1') ??
                [])
            .toSet();
    if (removed.isEmpty) return books;
    return compute(_filterRemoved, (books: books, removed: removed));
  }

  /// Hide a library entry persistently without deleting the user's source file.
  Future<void> remove(BookFile book) async {
    final prefs = SharedPreferencesAsync();
    if (book.name == sampleBookName) {
      final bundledRemoved =
          (await prefs.getStringList(bundledRemovalKey) ?? []).toSet();
      bundledRemoved.add(sampleBookName);
      await prefs.setStringList(bundledRemovalKey, bundledRemoved.toList());
    }
    final removed = (await prefs.getStringList('library.removed.v1') ?? [])
        .toSet();
    removed.add(_bookKey(book));
    await prefs.setStringList('library.removed.v1', removed.toList());
  }

  Future<void> add(BookFile book) async {
    final safeName = book.name.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    final directory = await folder();
    var destination = File(
      '${directory.path}${Platform.pathSeparator}$safeName',
    );
    var suffix = 1;
    while (await destination.exists()) {
      final dot = safeName.lastIndexOf('.');
      final stem = dot < 0 ? safeName : safeName.substring(0, dot);
      final ext = dot < 0 ? '' : safeName.substring(dot);
      destination = File(
        '${directory.path}${Platform.pathSeparator}$stem (${suffix++})$ext',
      );
    }
    await destination.writeAsBytes(book.bytes, flush: true);
    final prefs = SharedPreferencesAsync();
    final removed = (await prefs.getStringList('library.removed.v1') ?? [])
        .toSet();
    removed.remove(
      _bookKey(BookFile(destination.uri.pathSegments.last, book.bytes)),
    );
    await prefs.setStringList('library.removed.v1', removed.toList());
  }
}
