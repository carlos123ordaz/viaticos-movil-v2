class BitrixTaskModel {
  final String id;
  final String title;
  final String status;
  final DateTime? deadline;
  final String? description;
  final bool ibFinalized;
  final String? responsible;

  const BitrixTaskModel({
    required this.id,
    required this.title,
    required this.status,
    this.deadline,
    this.description,
    this.ibFinalized = false,
    this.responsible,
  });

  factory BitrixTaskModel.fromJson(Map<String, dynamic> json) {
    return BitrixTaskModel(
      id: json['id']?.toString() ?? json['ID']?.toString() ?? '',
      title: json['title'] ?? json['TITLE'] ?? '',
      status: json['status']?.toString() ?? json['STATUS']?.toString() ?? '2',
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'].toString())
          : json['DEADLINE'] != null
              ? DateTime.tryParse(json['DEADLINE'].toString())
              : null,
      description: json['description'] ?? json['DESCRIPTION'],
      ibFinalized: json['ibFinalized'] == true,
      responsible: json['responsible']?['name'] ?? json['RESPONSIBLE_ID']?.toString(),
    );
  }
}
