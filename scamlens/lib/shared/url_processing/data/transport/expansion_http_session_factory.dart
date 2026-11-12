import 'expansion_http_session.dart';
import 'expansion_http_session_stub.dart'
    if (dart.library.io) 'expansion_http_session_io.dart'
    as platform;

/// Each invocation owns independent cancellation and network resources.
ExpansionHttpSession createExpansionHttpSession() => platform.createSession();
