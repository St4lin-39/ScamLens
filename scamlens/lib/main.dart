import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:scamlens/features/auth/data/datasources/supabase_profile_datasource.dart';
import 'package:scamlens/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:scamlens/features/auth/data/repositories/profile_repository_impl.dart';
import 'package:scamlens/features/auth/domain/usescases/get_profile_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/login_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/register_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/sign_out_usecase.dart';
import 'package:scamlens/features/login/ui/bloc/login_bloc.dart';
import 'package:scamlens/features/login/ui/screens/login_screen.dart';
import 'package:scamlens/features/register/ui/bloc/register_bloc.dart';
import 'package:scamlens/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://whktztxzdruccvukxcuv.supabase.co';
const supabasePublishableKey = 'sb_publishable_rF5IjGKLYSvOH080Ybenbg_UiuKa5i3';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  final supabaseClient = Supabase.instance.client;
  final authDatasource = SupabaseAuthDatasource(client: supabaseClient);
  final profileDatasource = SupabaseProfileDatasource(client: supabaseClient);
  final authRepository = AuthRepositoryImpl(authDatasource);
  final profileRepository = ProfileRepositoryImpl(profileDatasource);

  final loginUseCase = LoginUseCase(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
  final registerUseCase = RegisterUseCase(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
  final getProfileUseCase = GetProfileUseCase(profileRepository);
  final signOutUseCase = SignOutUseCase(authRepository);

  runApp(
    MyApp(
      loginUseCase: loginUseCase,
      registerUseCase: registerUseCase,
      getProfileUseCase: getProfileUseCase,
      signOutUseCase: signOutUseCase,
    ),
  );
}

class MyApp extends StatelessWidget {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final GetProfileUseCase getProfileUseCase;
  final SignOutUseCase signOutUseCase;

  const MyApp({
    super.key,
    required this.loginUseCase,
    required this.registerUseCase,
    required this.getProfileUseCase,
    required this.signOutUseCase,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<GetProfileUseCase>.value(value: getProfileUseCase),
        RepositoryProvider<SignOutUseCase>.value(value: signOutUseCase),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<LoginBloc>(
            create: (_) => LoginBloc(loginUseCase: loginUseCase),
          ),
          BlocProvider<RegisterBloc>(
            create: (_) => RegisterBloc(registerUseCase: registerUseCase),
          ),
        ],
        child: MaterialApp(
          title: 'ScamLens',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const LoginScreen(),
        ),
      ),
    );
  }
}
