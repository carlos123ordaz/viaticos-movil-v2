import '../../core/constants/api_constants.dart';
import '../models/cost_center_model.dart';
import 'api_service.dart';

class CostCenterService {
  final ApiService _api;

  CostCenterService(this._api);

  Future<List<CostCenterModel>> getCostCenters() async {
    final response = await _api.get(ApiConstants.costCenters);
    final List<dynamic> list = response.data is List
        ? response.data as List
        : (response.data as Map<String, dynamic>?)?['data'] as List? ?? [];
    return list.map((e) => CostCenterModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SubCostCenterModel>> getSubCostCenters({int? costCenterId}) async {
    final response = await _api.get(
      ApiConstants.subCostCenters,
      params: costCenterId != null ? {'cc': costCenterId} : null,
    );
    final List<dynamic> list = response.data is List
        ? response.data as List
        : (response.data as Map<String, dynamic>?)?['data'] as List? ?? [];
    return list.map((e) => SubCostCenterModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SubSubCostCenterModel>> getSubSubCostCenters({int? subCostCenterId}) async {
    final response = await _api.get(
      ApiConstants.subSubCostCenters,
      params: subCostCenterId != null ? {'scc': subCostCenterId} : null,
    );
    final List<dynamic> list = response.data is List
        ? response.data as List
        : (response.data as Map<String, dynamic>?)?['data'] as List? ?? [];
    return list.map((e) => SubSubCostCenterModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
