import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/indicator_of_compromise_model.dart';

class SupabaseIocDatasource {
  final SupabaseClient client;

  const SupabaseIocDatasource({required this.client});

  Future<List<IndicatorOfCompromiseModel>> findActiveMatches(
    List<String> candidateValues,
  ) async {
    if (candidateValues.isEmpty) return const [];

    final rows = await client
        .from('indicator_of_compromise')
        .select()
        .eq('active', true)
        .inFilter('value', candidateValues);

    return (rows as List<dynamic>)
        .map(
          (row) => IndicatorOfCompromiseModel.fromJson(
            row as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }
}
