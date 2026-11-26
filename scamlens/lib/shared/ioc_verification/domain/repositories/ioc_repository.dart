import '../entities/ioc_check_result.dart';

abstract class IocRepository {
  Future<IocCheckResult> checkCandidates(IocCandidateSet candidates);

  void invalidateCache();
}
