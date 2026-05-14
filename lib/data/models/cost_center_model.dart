class CostCenterModel {
  final int costCenterId;
  final String shortName;
  final String descrip;

  const CostCenterModel({
    required this.costCenterId,
    required this.shortName,
    required this.descrip,
  });

  factory CostCenterModel.fromJson(Map<String, dynamic> json) => CostCenterModel(
        costCenterId: (json['costCenterId'] as num).toInt(),
        shortName: json['shortName'] ?? '',
        descrip: json['descrip'] ?? '',
      );

  String get displayName => '$shortName - $descrip';
}

class SubCostCenterModel {
  final int subCostCenterId;
  final int costCenterId;
  final String shortName;
  final String descrip;

  const SubCostCenterModel({
    required this.subCostCenterId,
    required this.costCenterId,
    required this.shortName,
    required this.descrip,
  });

  factory SubCostCenterModel.fromJson(Map<String, dynamic> json) => SubCostCenterModel(
        subCostCenterId: (json['subCostCenterId'] as num).toInt(),
        costCenterId: (json['costCenterId'] as num).toInt(),
        shortName: json['shortName'] ?? '',
        descrip: json['descrip'] ?? '',
      );

  String get displayName => '$shortName - $descrip';
}

class SubSubCostCenterModel {
  final int subSubCostCenterId;
  final int subCostCenterId;
  final int costCenterId;
  final String shortName;
  final String descrip;
  final String? comment;

  const SubSubCostCenterModel({
    required this.subSubCostCenterId,
    required this.subCostCenterId,
    required this.costCenterId,
    required this.shortName,
    required this.descrip,
    this.comment,
  });

  factory SubSubCostCenterModel.fromJson(Map<String, dynamic> json) => SubSubCostCenterModel(
        subSubCostCenterId: (json['subSubCostCenterId'] as num).toInt(),
        subCostCenterId: (json['subCostCenterId'] as num).toInt(),
        costCenterId: (json['costCenterId'] as num).toInt(),
        shortName: json['shortName'] ?? '',
        descrip: json['descrip'] ?? '',
        comment: json['comment'],
      );

  String get displayName => '$shortName - $descrip';
}

class ExpenseCategoryModel {
  final int expenseCategoryId;
  final String name;
  final String expenseType;
  final String descrip;

  const ExpenseCategoryModel({
    required this.expenseCategoryId,
    required this.name,
    required this.expenseType,
    required this.descrip,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) => ExpenseCategoryModel(
        expenseCategoryId: (json['expenseCategoryId'] as num).toInt(),
        name: json['name'] ?? '',
        expenseType: json['expenseType'] ?? 'viatico',
        descrip: json['descrip'] ?? '',
      );
}

class ReceiptTypeModel {
  final int receiptTypeId;
  final String name;

  const ReceiptTypeModel({
    required this.receiptTypeId,
    required this.name,
  });

  factory ReceiptTypeModel.fromJson(Map<String, dynamic> json) => ReceiptTypeModel(
        receiptTypeId: (json['receiptTypeId'] as num).toInt(),
        name: json['name'] ?? '',
      );
}
