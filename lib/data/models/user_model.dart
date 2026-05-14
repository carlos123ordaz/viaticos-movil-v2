class UserModel {
  final String id;
  final String name;
  final String email;
  final String? dni;
  final String? jobTitle;
  final String? phone;
  final String? area;
  final String? avatarUrl;
  final bool isActive;
  final String? signatureImageUrl;
  final String? secondLastName;
  final String? displayLastName;
  final int? costCenterId;
  final int? subCostCenterId;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.dni,
    this.jobTitle,
    this.phone,
    this.area,
    this.avatarUrl,
    this.isActive = true,
    this.signatureImageUrl,
    this.secondLastName,
    this.displayLastName,
    this.costCenterId,
    this.subCostCenterId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString() ?? json['userId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      dni: json['dni'],
      jobTitle: json['jobTitle'] ?? json['position'],
      phone: json['phone'],
      area: json['area'] is String ? json['area'] : json['area']?['name'],
      avatarUrl: json['avatar'] ?? json['profilePicture'] ?? json['photoUrl'],
      isActive: json['isActive'] ?? json['ibActive'] ?? true,
      signatureImageUrl: json['signatureImageUrl'],
      secondLastName: json['secondLastName'],
      displayLastName: json['displayLastName'],
      costCenterId: (json['costCenterId'] as num?)?.toInt(),
      subCostCenterId: (json['subCostCenterId'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        if (dni != null) 'dni': dni,
        if (jobTitle != null) 'jobTitle': jobTitle,
        if (phone != null) 'phone': phone,
        if (area != null) 'area': area,
        if (avatarUrl != null) 'avatar': avatarUrl,
        'isActive': isActive,
        if (secondLastName != null) 'secondLastName': secondLastName,
        if (displayLastName != null) 'displayLastName': displayLastName,
        if (costCenterId != null) 'costCenterId': costCenterId,
        if (subCostCenterId != null) 'subCostCenterId': subCostCenterId,
      };
}
