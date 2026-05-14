import 'package:dio/dio.dart';
import 'api_service.dart';

class SignatureService {
  final ApiService _api;

  SignatureService(this._api);

  Future<String> uploadSignature(String userId, String imagePath) async {
    final formData = FormData.fromMap({
      'signature': await MultipartFile.fromFile(imagePath, filename: 'signature.jpg'),
    });
    final response = await _api.putFormData('/users/$userId/signature', formData);
    final data = response.data as Map<String, dynamic>;
    return data['signatureImageUrl'] as String? ?? '';
  }
}
