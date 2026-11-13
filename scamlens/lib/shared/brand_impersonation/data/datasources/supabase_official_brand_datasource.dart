import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/official_brand_model.dart';

class SupabaseOfficialBrandDatasource {
  final SupabaseClient client;

  const SupabaseOfficialBrandDatasource({required this.client});

  Future<List<OfficialBrandModel>> fetchActiveBrands() async {
    final rows = await client
        .from('official_brand')
        .select()
        .eq('active', true);

    return (rows as List<dynamic>)
        .map((row) => OfficialBrandModel.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }
}
