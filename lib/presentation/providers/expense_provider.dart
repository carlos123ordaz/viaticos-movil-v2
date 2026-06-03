import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../data/models/expense_model.dart';
import '../../data/services/expense_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _service;

  List<ExpenseModel> _expenses = [];
  bool _isLoading = false;
  String? _error;
  String _search = '';
  ExpenseCategory? _categoryFilter;

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  ExpenseProvider(this._service);

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;

  void enterSelectionMode(String firstId) {
    _isSelectionMode = true;
    _selectedIds.clear();
    _selectedIds.add(firstId);
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(List<String> ids) {
    _selectedIds.addAll(ids);
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

  Future<bool> assignTask(String taskId) async {
    if (_selectedIds.isEmpty) return false;
    try {
      await _service.assignTaskToExpenses(_selectedIds.toList(), taskId);
      // Remove assigned expenses from the current list — they now belong to a task
      _expenses.removeWhere((e) => _selectedIds.contains(e.id));
      exitSelectionMode();
      return true;
    } catch (e) {
      debugPrint('Error assigning task: $e');
      return false;
    }
  }

  List<ExpenseModel> get allExpenses => List<ExpenseModel>.from(_expenses);

  List<ExpenseModel> get expenses {
    var list = List<ExpenseModel>.from(_expenses);
    if (_categoryFilter != null) {
      list = list.where((e) => e.category == _categoryFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((e) =>
              e.description.toLowerCase().contains(q) ||
              e.category.label.toLowerCase().contains(q))
          .toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get search => _search;
  ExpenseCategory? get categoryFilter => _categoryFilter;

  double get totalAmount =>
      _expenses.fold(0, (sum, e) => sum + e.amount);

  double get monthAmount {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold(0, (sum, e) => sum + e.amount);
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setCategoryFilter(ExpenseCategory? cat) {
    _categoryFilter = cat;
    notifyListeners();
  }

  Future<void> load({String? taskId}) async {
    _expenses = [];
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _expenses = await _service.getExpenses(taskId: taskId);
    } catch (e) {
      _error = 'No se pudieron cargar las rendiciones';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _createError;
  String? get createError => _createError;

  Future<ExpenseModel?> create(Map<String, dynamic> body) async {
    _createError = null;
    try {
      final expense = await _service.createExpense(body);
      _expenses.insert(0, expense);
      notifyListeners();
      return expense;
    } catch (e) {
      debugPrint('Error creating expense: $e');
      if (e is DioException) {
        debugPrint('Server response: ${e.response?.data}');
        final serverMsg = _extractServerMessage(e.response?.data);
        _createError = serverMsg ?? 'Error al guardar la rendición (${e.response?.statusCode})';
      } else {
        _createError = 'Error inesperado: $e';
      }
      _error = _createError;
      notifyListeners();
      return null;
    }
  }

  String? _extractServerMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  Future<ExpenseModel?> update(String id, Map<String, dynamic> body) async {
    try {
      final updated = await _service.updateExpense(id, body);
      final idx = _expenses.indexWhere((e) => e.id == id);
      if (idx != -1) _expenses[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = 'Error al actualizar la rendición';
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _service.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al eliminar la rendición';
      notifyListeners();
      return false;
    }
  }
}
