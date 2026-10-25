import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/features/auth/domain/entities/user_entity.dart';
import 'package:scamlens/features/auth/domain/usescases/get_profile_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/sign_out_usecase.dart';

abstract class ProfileEvent {}

class OnLoadProfileEvent extends ProfileEvent {}

class OnSignOutEvent extends ProfileEvent {}

abstract class ProfileState {}

class ProfileLoadingState extends ProfileState {}

class ProfileLoadedState extends ProfileState {
  final UserEntity user;
  ProfileLoadedState({required this.user});
}

class ProfileErrorState extends ProfileState {
  final String errorMessage;
  ProfileErrorState({required this.errorMessage});
}

class ProfileSignedOutState extends ProfileState {}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final SignOutUseCase signOutUseCase;

  ProfileBloc({
    required this.getProfileUseCase,
    required this.signOutUseCase,
    UserEntity? initialUser,
  }) : super(
         initialUser != null
             ? ProfileLoadedState(user: initialUser)
             : ProfileLoadingState(),
       ) {
    on<OnLoadProfileEvent>(_onLoadProfile);
    on<OnSignOutEvent>(_onSignOut);
  }

  Future<void> _onLoadProfile(
    OnLoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoadingState());
    try {
      final user = await getProfileUseCase();
      emit(ProfileLoadedState(user: user));
    } catch (e) {
      emit(ProfileErrorState(errorMessage: e.toString()));
    }
  }

  Future<void> _onSignOut(
    OnSignOutEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoadingState());
    await signOutUseCase();
    emit(ProfileSignedOutState());
  }
}
