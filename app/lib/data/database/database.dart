import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ── 表定义 ──────────────────────────────────────────

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('todo'))();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get parentId => integer().nullable().references(Tasks, #id)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100).unique()();
  TextColumn get color =>
      text().withDefault(const Constant('#6366F1'))();
}

class TaskTags extends Table {
  IntColumn get taskId => integer().references(Tasks, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => text()(); // user / assistant
  TextColumn get content => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ── 数据库类 ─────────────────────────────────────────

@DriftDatabase(tables: [Tasks, Tags, TaskTags, ChatMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(tasks, tasks.startTime);
            await migrator.addColumn(tasks, tasks.endTime);
          }
        },
      );

  // ── Task CRUD ──

  Future<List<Task>> getAllTasks() => select(tasks).get();

  Stream<List<Task>> watchAllTasks() => select(tasks).watch();

  Stream<List<Task>> watchTasksByStatus(String status) =>
      (select(tasks)..where((t) => t.status.equals(status))).watch();

  Future<Task> getTaskById(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingle();

  Future<List<Task>> getSubTasks(int parentId) =>
      (select(tasks)..where((t) => t.parentId.equals(parentId))).get();

  Future<int> insertTask(TasksCompanion entry) => into(tasks).insert(entry);

  Future<bool> updateTask(TasksCompanion entry) =>
      update(tasks).replace(entry);

  Future<int> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  // ── Tag CRUD ──

  Future<List<Tag>> getAllTags() => select(tags).get();

  Future<int> insertTag(TagsCompanion entry) => into(tags).insert(entry);

  Future<int> deleteTag(int id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();

  // ── TaskTag ──

  Future<void> setTagsForTask(int taskId, List<int> tagIds) async {
    await (delete(taskTags)..where((t) => t.taskId.equals(taskId))).go();
    for (final tagId in tagIds) {
      await into(taskTags).insert(
        TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
      );
    }
  }

  Future<List<Tag>> getTagsForTask(int taskId) async {
    final query = select(tags).join([
      innerJoin(taskTags, taskTags.tagId.equalsExp(tags.id)),
    ])
      ..where(taskTags.taskId.equals(taskId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(tags)).toList();
  }

  // ── Chat CRUD ──

  Future<List<ChatMessage>> getAllMessages() =>
      (select(chatMessages)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Stream<List<ChatMessage>> watchAllMessages() =>
      (select(chatMessages)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<int> insertMessage(ChatMessagesCompanion entry) =>
      into(chatMessages).insert(entry);

  Future<void> clearMessages() => delete(chatMessages).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'vibetasking.db'));
    return NativeDatabase.createInBackground(file);
  });
}
