import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/features/auth/domain/entities/user_entity.dart';
import 'package:scamlens/features/auth/domain/usescases/register_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class RegisterEvent {}

class OnRegisterSubmittedEvent extends RegisterEvent {
  final String name;
  final String lastName;
  final String email;
  final String password;

  OnRegisterSubmittedEvent({
    required this.name,
    required this.lastName,
    required this.email,
    required this.password,
  });
}

abstract class RegisterState {}

class RegisterIdleState extends RegisterState {}

class RegisterLoadingState extends RegisterState {}

class RegisterErrorState extends RegisterState {
  final String errorMessage;
  RegisterErrorState({required this.errorMessage});
}

class RegisterSuccessState extends RegisterState {
  final UserEntity user;
  RegisterSuccessState({required this.user});
}

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final RegisterUseCase registerUseCase;

  RegisterBloc({required this.registerUseCase}) : super(RegisterIdleState()) {
    on<OnRegisterSubmittedEvent>(_onRegisterSubmitted);
  }

  Future<void> _onRegisterSubmitted(
    OnRegisterSubmittedEvent event,
    Emitter<RegisterState> emit,
  ) async {
    emit(RegisterLoadingState());
    try {
      final user = await registerUseCase(
        name: event.name,
        lastName: event.lastName,
        email: event.email,
        password: event.password,
      );
      emit(RegisterSuccessState(user: user));
    } on AuthException catch (e) {
      emit(RegisterErrorState(errorMessage: e.message));
    } catch (e) {
      emit(RegisterErrorState(errorMessage: e.toString()));
    }
  }
}
