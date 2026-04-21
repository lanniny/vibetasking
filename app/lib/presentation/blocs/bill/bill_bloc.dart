// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/data/database/database.dart';

import 'bill_event.dart';
import 'bill_state.dart';

class BillBloc extends Bloc<BillEvent, BillState> {
  final AppDatabase _db;

  BillBloc(this._db)
      : super(BillState(
          selectedMonth: DateTime(DateTime.now().year, DateTime.now().month),
        )) {
    on<LoadBills>(_onLoadBills);
    on<LoadCategories>(_onLoadCategories);
    on<AddBill>(_onAddBill);
    on<EditBill>(_onEditBill);
    on<DeleteBill>(_onDeleteBill);
    on<FilterBillsByMonth>(_onFilterByMonth);
    on<AddCategory>(_onAddCategory);
    on<DeleteCategory>(_onDeleteCategory);
  }

  Future<void> _reload(Emitter<BillState> emit) async {
    final allBills = await _db.getAllBills();
    final allCategories = await _db.getAllBillCategories();
    emit(state.copyWith(
      bills: allBills,
      categories: allCategories,
      isLoading: false,
    ));
  }

  Future<void> _onLoadBills(LoadBills event, Emitter<BillState> emit) async {
    emit(state.copyWith(isLoading: true));
    await _reload(emit);
  }

  Future<void> _onLoadCategories(
      LoadCategories event, Emitter<BillState> emit) async {
    final categories = await _db.getAllBillCategories();
    emit(state.copyWith(categories: categories));
  }

  Future<void> _onAddBill(AddBill event, Emitter<BillState> emit) async {
    await _db.insertBill(BillsCompanion.insert(
      amount: event.amount,
      type: event.type,
      categoryId: Value(event.categoryId),
      taskId: Value(event.taskId),
      description: Value(event.description),
      date: event.date,
    ));
    await _reload(emit);
  }

  Future<void> _onEditBill(EditBill event, Emitter<BillState> emit) async {
    await _db.updateBill(BillsCompanion(
      id: Value(event.id),
      amount: Value(event.amount),
      type: Value(event.type),
      categoryId: Value(event.categoryId),
      taskId: Value(event.taskId),
      description: Value(event.description),
      date: Value(event.date),
      updatedAt: Value(DateTime.now()),
    ));
    await _reload(emit);
  }

  Future<void> _onDeleteBill(DeleteBill event, Emitter<BillState> emit) async {
    await _db.deleteBill(event.id);
    await _reload(emit);
  }

  Future<void> _onFilterByMonth(
      FilterBillsByMonth event, Emitter<BillState> emit) async {
    emit(state.copyWith(selectedMonth: event.month));
  }

  Future<void> _onAddCategory(
      AddCategory event, Emitter<BillState> emit) async {
    await _db.insertBillCategory(BillCategoriesCompanion.insert(
      name: event.name,
      icon: Value(event.icon),
      type: event.type,
      color: Value(event.color),
    ));
    await _reload(emit);
  }

  Future<void> _onDeleteCategory(
      DeleteCategory event, Emitter<BillState> emit) async {
    await _db.deleteBillCategory(event.id);
    await _reload(emit);
  }
}
