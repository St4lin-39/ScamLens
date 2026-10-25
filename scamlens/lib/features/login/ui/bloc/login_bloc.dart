import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/usescases/login_usecase.dart';

abstract class LoginEvent {}

class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;

  LoginSubmitted({required this.email, required this.password});
}

enum LoginStatus {
  initial,
  loading,
  success,
  failure,
}

class LoginState {
  final LoginStatus status;
  final Profile? profile;
  final String? errorMessage;

  const LoginState({
    this.status = LoginStatus.initial,
    this.profile,
    this.errorMessage,
  });

  LoginState copyWith({
    LoginStatus? status,
    Profile? profile,
    String? errorMessage,
  }) {
    return LoginState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase loginUseCase;

  LoginBloc({
    required this.loginUseCase,
  }) : super(const LoginState()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginState(status: LoginStatus.loading));
    try {
      final profile = await loginUseCase(
        email: event.email,
        password: event.password,
      );
      emit(state.copyWith(status: LoginStatus.success, profile: profile));
    } catch (e) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
