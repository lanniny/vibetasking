// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:equatable/equatable.dart';

abstract class BillEvent extends Equatable {
  const BillEvent();
  @override
  List<Object?> get props => [];
}

class LoadBills extends BillEvent {}

class LoadCategories extends BillEvent {}

class AddBill extends BillEvent {
  final double amount;
  final String type; // income / expense
  final int? categoryId;
  final int? taskId;
  final String? description;
  final DateTime date;

  const AddBill({
    required this.amount,
    required this.type,
    this.categoryId,
    this.taskId,
    this.description,
    required this.date,
  });

  @override
  List<Object?> get props =>
      [amount, type, categoryId, taskId, description, date];
}

class EditBill extends BillEvent {
  final int id;
  final double amount;
  final String type;
  final int? categoryId;
  final int? taskId;
  final String? description;
  final DateTime date;

  const EditBill({
    required this.id,
    required this.amount,
    required this.type,
    this.categoryId,
    this.taskId,
    this.description,
    required this.date,
  });

  @override
  List<Object?> get props =>
      [id, amount, type, categoryId, taskId, description, date];
}

class DeleteBill extends BillEvent {
  final int id;
  const DeleteBill(this.id);
  @override
  List<Object?> get props => [id];
}

class FilterBillsByMonth extends BillEvent {
  final DateTime month;
  const FilterBillsByMonth(this.month);
  @override
  List<Object?> get props => [month];
}

class AddCategory extends BillEvent {
  final String name;
  final String icon;
  final String type;
  final String color;

  const AddCategory({
    required this.name,
    required this.icon,
    required this.type,
    required this.color,
  });

  @override
  List<Object?> get props => [name, icon, type, color];
}

class DeleteCategory extends BillEvent {
  final int id;
  const DeleteCategory(this.id);
  @override
  List<Object?> get props => [id];
}
