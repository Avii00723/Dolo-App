import 'dart:convert';
import 'package:http/http.dart' as http;

import '../Constants/ApiConstants.dart';
import '../Models/PublicProfileModel.dart';

class PublicProfileService {
  final http.Client _client;

  PublicProfileService({http.Client? client}) : _client = client ?? http.Client();

  Future<PublicProfileResponse> getPublicProfile({
    required String userHashedId,
    required String viewerHashedId,
  }) async {
    final url = Uri.parse('${ApiConstants.publicProfileBaseUrl}/$userHashedId')
        .replace(queryParameters: {
      'viewerHashedId': viewerHashedId,
    });

    final res = await _client.get(
      url,
      headers: {
        'Accept': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      return PublicProfileResponse.fromJson(jsonMap);
    }

    if (res.statusCode == 404) {
      throw Exception('User not found');
    }

    throw Exception('Failed to fetch public profile (${res.statusCode})');
  }
}

