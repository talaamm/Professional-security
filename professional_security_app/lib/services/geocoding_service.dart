import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geo_place.dart';
import 'app_strings.dart';

class GeocodingException implements Exception {
  final String message;
  GeocodingException(this.message);

  @override
  String toString() => message;
}

/// Free place search via OpenStreetMap's Nominatim API - no API key or
/// billing account needed. Usage policy (max ~1 req/sec, a real
/// identifying User-Agent, no bulk geocoding) is fine for an admin
/// occasionally searching for a workplace by name:
/// https://operations.osmfoundation.org/policies/nominatim/
class GeocodingService {
  static const _endpoint = 'https://nominatim.openstreetmap.org/search';
  static const _userAgent = 'ProfessionalSecurityApp/1.0 (com.halabi.professionalsecurity)';

  // Workplaces are all in Israel, so restrict results to it - without this,
  // a query like "Sheba Hospital" can be outranked by unrelated global
  // matches instead of the Israeli site. Restricting the country also
  // surfaces more Israeli streets/addresses in the remaining result slots.
  static const _countryCode = 'il';

  Future<List<GeoPlace>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '10',
      'accept-language': AppStrings.current.value.code,
      'countrycodes': _countryCode,
    });

    http.Response response;
    try {
      response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw GeocodingException(AppStrings.t('location_picker_network_error'));
    }

    if (response.statusCode != 200) {
      throw GeocodingException(AppStrings.t('location_picker_search_error'));
    }

    try {
      final data = json.decode(response.body) as List;
      return data.map((e) => GeoPlace.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      throw GeocodingException(AppStrings.t('location_picker_search_error'));
    }
  }
}
