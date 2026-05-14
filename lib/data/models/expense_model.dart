// ExpenseCategory enum kept for UI display/filtering in history and cards.
enum ExpenseCategory {
  alimentacion,
  transporte,
  alojamiento,
  compras,
  otros;

  String get label {
    switch (this) {
      case alimentacion:
        return 'Alimentación';
      case transporte:
        return 'Transporte';
      case alojamiento:
        return 'Alojamiento';
      case compras:
        return 'Compras';
      case otros:
        return 'Otros';
    }
  }

  static ExpenseCategory fromString(String? value) {
    final v = value?.toLowerCase() ?? '';
    if (v.contains('aliment') || v.contains('food') || v.contains('comida')) {
      return alimentacion;
    }
    if (v.contains('transport') || v.contains('movil') || v.contains('taxi') ||
        v.contains('combustib') || v.contains('peaje')) {
      return transporte;
    }
    if (v.contains('alojam') || v.contains('hosped') || v.contains('hotel') ||
        v.contains('accommodation')) {
      return alojamiento;
    }
    if (v.contains('compra') || v.contains('shopping') || v.contains('material')) {
      return compras;
    }
    return otros;
  }
}

class ExpenseItem {
  final String descrip;
  final String? unitOfMeasure;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  String get name => descrip;

  const ExpenseItem({
    required this.descrip,
    this.unitOfMeasure,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        descrip: json['descrip'] ?? json['name'] ?? json['description'] ?? '',
        unitOfMeasure: json['unitOfMeasure'],
        quantity: (json['quantity'] ?? 1).toDouble(),
        unitPrice: (json['unitPrice'] ?? json['price'] ?? 0).toDouble(),
        subtotal: (json['subtotal'] ?? json['total'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'descrip': descrip,
        if (unitOfMeasure != null) 'unitOfMeasure': unitOfMeasure,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
      };

  double get total => subtotal;
}

class CostCenterAllocation {
  final int? costCenterId;
  final String? costCenterName;
  final int? subCostCenterId;
  final String? subCostCenterName;
  final int? subSubCostCenterId;
  final String? subSubCostCenterName;
  final double percentage;

  const CostCenterAllocation({
    this.costCenterId,
    this.costCenterName,
    this.subCostCenterId,
    this.subCostCenterName,
    this.subSubCostCenterId,
    this.subSubCostCenterName,
    required this.percentage,
  });

  factory CostCenterAllocation.fromJson(Map<String, dynamic> json) =>
      CostCenterAllocation(
        costCenterId: json['costCenterId'] != null
            ? (json['costCenterId'] as num).toInt()
            : null,
        costCenterName: json['costCenterName'],
        subCostCenterId: json['subCostCenterId'] != null
            ? (json['subCostCenterId'] as num).toInt()
            : null,
        subCostCenterName: json['subCostCenterName'],
        subSubCostCenterId: json['subSubCostCenterId'] != null
            ? (json['subSubCostCenterId'] as num).toInt()
            : null,
        subSubCostCenterName: json['subSubCostCenterName'],
        percentage: (json['percentage'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'costCenterId': costCenterId,
        'subCostCenterId': subCostCenterId ?? 0,
        'subSubCostCenterId': subSubCostCenterId ?? 0,
        'percentage': percentage,
      };
}

class ExpenseModel {
  final String id;
  final String? type;
  final String? categoryName;
  final ExpenseCategory category;
  final String? ruc;
  final String? businessName;
  final String? address;
  final DateTime date;
  final DateTime? settlementDate;
  final double amount;
  final String currency;
  final double igv;
  final double? discount;
  final double? detraction;
  final bool? hasReceipt;
  final String? receiptDetail;
  final String? descrip;
  final String? imageUrl;
  final List<ExpenseItem> items;
  final String? taskId;
  final String? taskName;
  final String? receiptNumber;
  final String? documentType;
  final String? documentReference;
  final String? creationMethod;
  final List<CostCenterAllocation> costCenterAllocations;
  final bool? reviewed;
  final String? reviewedAt;
  final String? reviewComment;
  final String status;
  final DateTime createdAt;

  String get description => descrip ?? businessName ?? categoryName ?? '';

  const ExpenseModel({
    required this.id,
    this.type,
    this.categoryName,
    required this.category,
    this.ruc,
    this.businessName,
    this.address,
    required this.date,
    this.settlementDate,
    required this.amount,
    this.currency = 'PEN',
    this.igv = 0,
    this.discount,
    this.detraction,
    this.hasReceipt,
    this.receiptDetail,
    this.descrip,
    this.imageUrl,
    this.items = const [],
    this.taskId,
    this.taskName,
    this.receiptNumber,
    this.documentType,
    this.documentReference,
    this.creationMethod,
    this.costCenterAllocations = const [],
    this.reviewed,
    this.reviewedAt,
    this.reviewComment,
    this.status = 'pending',
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final catName = json['category']?.toString();
    return ExpenseModel(
      id: json['expenseId']?.toString() ??
          json['_id']?.toString() ??
          json['id']?.toString() ??
          '',
      type: json['type'],
      categoryName: catName,
      category: ExpenseCategory.fromString(catName),
      ruc: json['ruc'],
      businessName: json['businessName'],
      address: json['address'],
      date: json['expenseDate'] != null
          ? DateTime.tryParse(json['expenseDate'].toString()) ?? DateTime.now()
          : json['date'] != null
              ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
              : DateTime.now(),
      settlementDate: json['settlementDate'] != null
          ? DateTime.tryParse(json['settlementDate'].toString())
          : null,
      amount: (json['total'] ?? json['amount'] ?? 0).toDouble(),
      currency: json['currencyCode'] ?? json['currency'] ?? 'PEN',
      igv: (json['igv'] ?? 0).toDouble(),
      discount: json['discount'] != null ? (json['discount']).toDouble() : null,
      detraction:
          json['detraction'] != null ? (json['detraction']).toDouble() : null,
      hasReceipt: json['hasReceipt'],
      receiptDetail: json['receiptDetail'],
      descrip: json['descrip'] ?? json['description'],
      imageUrl: json['imageUrl'] ?? json['image'] ?? json['receiptUrl'],
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => ExpenseItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      taskId: json['taskId']?.toString() ?? json['bitrixTaskId']?.toString(),
      taskName: json['taskName'],
      receiptNumber: json['receiptNumber'],
      documentType: json['documentType'],
      documentReference: json['documentReference'],
      creationMethod: json['creationMethod'],
      costCenterAllocations:
          (json['costCenterAllocations'] as List<dynamic>? ??
                  json['allocations'] as List<dynamic>? ??
                  [])
              .map((a) =>
                  CostCenterAllocation.fromJson(a as Map<String, dynamic>))
              .toList(),
      reviewed: json['reviewed'],
      reviewedAt: json['reviewedAt'],
      reviewComment: json['reviewComment'],
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type,
        'category': categoryName ?? category.name,
        if (ruc != null) 'ruc': ruc,
        if (businessName != null) 'businessName': businessName,
        if (address != null) 'address': address,
        'expenseDate': date.toIso8601String(),
        'total': amount,
        'currencyCode': currency,
        'igv': igv,
        if (discount != null) 'discount': discount,
        if (detraction != null) 'detraction': detraction,
        if (hasReceipt != null) 'hasReceipt': hasReceipt,
        if (receiptDetail != null) 'receiptDetail': receiptDetail,
        if (descrip != null) 'descrip': descrip,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (items.isNotEmpty) 'items': items.map((i) => i.toJson()).toList(),
        if (taskId != null) 'taskId': taskId,
        if (receiptNumber != null) 'receiptNumber': receiptNumber,
        if (documentType != null) 'documentType': documentType,
        if (documentReference != null) 'documentReference': documentReference,
        if (costCenterAllocations.isNotEmpty)
          'costCenterAllocations':
              costCenterAllocations.map((a) => a.toJson()).toList(),
      };

  ExpenseModel copyWith({
    String? type,
    String? categoryName,
    ExpenseCategory? category,
    String? ruc,
    String? businessName,
    String? address,
    DateTime? date,
    double? amount,
    String? currency,
    double? igv,
    double? discount,
    double? detraction,
    bool? hasReceipt,
    String? receiptDetail,
    String? descrip,
    String? imageUrl,
    List<ExpenseItem>? items,
    String? taskId,
    String? taskName,
    String? receiptNumber,
    String? documentType,
    String? documentReference,
    List<CostCenterAllocation>? costCenterAllocations,
  }) {
    return ExpenseModel(
      id: id,
      type: type ?? this.type,
      categoryName: categoryName ?? this.categoryName,
      category: category ?? this.category,
      ruc: ruc ?? this.ruc,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      igv: igv ?? this.igv,
      discount: discount ?? this.discount,
      detraction: detraction ?? this.detraction,
      hasReceipt: hasReceipt ?? this.hasReceipt,
      receiptDetail: receiptDetail ?? this.receiptDetail,
      descrip: descrip ?? this.descrip,
      imageUrl: imageUrl ?? this.imageUrl,
      items: items ?? this.items,
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      documentType: documentType ?? this.documentType,
      documentReference: documentReference ?? this.documentReference,
      costCenterAllocations:
          costCenterAllocations ?? this.costCenterAllocations,
      status: status,
      createdAt: createdAt,
    );
  }
}
