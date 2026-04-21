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
  // Claude YOLO 字段
  TextColumn get workingDir => text().nullable()();
  TextColumn get aiPrompt => text().nullable()();
  DateTimeColumn get aiScheduledAt => dateTime().nullable()();
  DateTimeColumn get aiLastRunAt => dateTime().nullable()();
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

// ── 账单类别表 ──

class BillCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get icon => text().withDefault(const Constant('💰'))();
  TextColumn get type => text()(); // income / expense
  TextColumn get color =>
      text().withDefault(const Constant('#6366F1'))();
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false))();
}

// ── 账单表 ──

class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // income / expense
  IntColumn get categoryId =>
      integer().nullable().references(BillCategories, #id)();
  IntColumn get taskId =>
      integer().nullable().references(Tasks, #id)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ── 数据库类 ─────────────────────────────────────────

@DriftDatabase(tables: [Tasks, Tags, TaskTags, ChatMessages, BillCategories, Bills])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(tasks, tasks.startTime);
            await migrator.addColumn(tasks, tasks.endTime);
          }
          if (from < 3) {
            await migrator.createTable(billCategories);
            await migrator.createTable(bills);
            // 插入默认类别
            await _insertDefaultCategories();
          }
          if (from < 4) {
            await migrator.addColumn(tasks, tasks.workingDir);
            await migrator.addColumn(tasks, tasks.aiPrompt);
            await migrator.addColumn(tasks, tasks.aiScheduledAt);
            await migrator.addColumn(tasks, tasks.aiLastRunAt);
          }
        },
        onCreate: (migrator) async {
          await migrator.createAll();
          await _insertDefaultCategories();
        },
      );

  Future<void> _insertDefaultCategories() async {
    final defaults = [
      // 支出类别
      ('餐饮', '🍜', 'expense', '#EF4444'),
      ('交通', '🚗', 'expense', '#F59E0B'),
      ('购物', '🛒', 'expense', '#8B5CF6'),
      ('娱乐', '🎮', 'expense', '#EC4899'),
      ('住房', '🏠', 'expense', '#6366F1'),
      ('通讯', '📱', 'expense', '#14B8A6'),
      ('医疗', '🏥', 'expense', '#F97316'),
      ('教育', '📚', 'expense', '#3B82F6'),
      ('其他支出', '📦', 'expense', '#6B7280'),
      // 收入类别
      ('工资', '💰', 'income', '#10B981'),
      ('奖金', '🎁', 'income', '#F59E0B'),
      ('投资', '📈', 'income', '#6366F1'),
      ('副业', '💼', 'income', '#8B5CF6'),
      ('其他收入', '💎', 'income', '#14B8A6'),
    ];
    for (final (name, icon, type, color) in defaults) {
      await into(billCategories).insert(BillCategoriesCompanion.insert(
        name: name,
        icon: Value(icon),
        type: type,
        color: Value(color),
        isDefault: const Value(true),
      ));
    }
  }

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

  /// 部分更新：只更新 Companion 中 present 的字段
  /// 比 replace 更安全，调用方不必传全量字段
  Future<int> updateTask(TasksCompanion entry) {
    final id = entry.id;
    if (id is! Value<int> || !id.present) {
      throw ArgumentError('updateTask requires a present id');
    }
    return (update(tasks)..where((t) => t.id.equals(id.value))).write(entry);
  }

  /// 删除任务：先清理所有 FK 引用（TaskTags + Bills.taskId + 子任务），再删任务
  Future<int> deleteTask(int id) async {
    return transaction(() async {
      // 1. 清理 TaskTags 关联
      await (delete(taskTags)..where((tt) => tt.taskId.equals(id))).go();
      // 2. 清理 Bill 关联（taskId 设为 null）
      await (update(bills)..where((b) => b.taskId.equals(id)))
          .write(const BillsCompanion(taskId: Value(null)));
      // 3. 递归删除子任务
      final subs = await (select(tasks)..where((t) => t.parentId.equals(id))).get();
      for (final sub in subs) {
        await (delete(taskTags)..where((tt) => tt.taskId.equals(sub.id))).go();
        await (update(bills)..where((b) => b.taskId.equals(sub.id)))
            .write(const BillsCompanion(taskId: Value(null)));
        await (delete(tasks)..where((t) => t.id.equals(sub.id))).go();
      }
      // 4. 删除任务本身
      return (delete(tasks)..where((t) => t.id.equals(id))).go();
    });
  }

  /// 获取所有未来调度的 YOLO 任务（用于应用启动时恢复 timer）
  Future<List<Task>> getScheduledYoloTasks() =>
      (select(tasks)..where((t) => t.aiScheduledAt.isNotNull())).get();

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

  // ── BillCategory CRUD ──

  Future<List<BillCategory>> getAllBillCategories() =>
      select(billCategories).get();

  Future<List<BillCategory>> getBillCategoriesByType(String type) =>
      (select(billCategories)..where((c) => c.type.equals(type))).get();

  Future<int> insertBillCategory(BillCategoriesCompanion entry) =>
      into(billCategories).insert(entry);

  Future<int> updateBillCategory(BillCategoriesCompanion entry) {
    final id = entry.id;
    if (id is! Value<int> || !id.present) {
      throw ArgumentError('updateBillCategory requires a present id');
    }
    return (update(billCategories)..where((c) => c.id.equals(id.value)))
        .write(entry);
  }

  /// 删除账单类别：先把所有引用它的 Bill.categoryId 设为 null，再删除类别
  Future<int> deleteBillCategory(int id) async {
    return transaction(() async {
      await (update(bills)..where((b) => b.categoryId.equals(id)))
          .write(const BillsCompanion(categoryId: Value(null)));
      return (delete(billCategories)..where((c) => c.id.equals(id))).go();
    });
  }

  // ── Bill CRUD ──

  Future<List<Bill>> getAllBills() =>
      (select(bills)..orderBy([(b) => OrderingTerm.desc(b.date)])).get();

  Future<List<Bill>> getBillsByDateRange(DateTime start, DateTime end) =>
      (select(bills)
            ..where((b) => b.date.isBetweenValues(start, end))
            ..orderBy([(b) => OrderingTerm.desc(b.date)]))
          .get();

  Future<List<Bill>> getBillsByTask(int taskId) =>
      (select(bills)..where((b) => b.taskId.equals(taskId))).get();

  Future<int> insertBill(BillsCompanion entry) => into(bills).insert(entry);

  Future<int> updateBill(BillsCompanion entry) {
    final id = entry.id;
    if (id is! Value<int> || !id.present) {
      throw ArgumentError('updateBill requires a present id');
    }
    return (update(bills)..where((b) => b.id.equals(id.value))).write(entry);
  }

  Future<int> deleteBill(int id) =>
      (delete(bills)..where((b) => b.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'vibetasking.db'));
    return NativeDatabase.createInBackground(file);
  });
}
