import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/usescases/get_profile_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/sign_out_usecase.dart';

// Eventos
abstract class ProfileEvent {}

class LoadProfileEvent extends ProfileEvent {
  final String? userId;
  LoadProfileEvent({this.userId});
}

class SignOutRequestedEvent extends ProfileEvent {}

// Estados
abstract class ProfileState {}

class ProfileLoadingState extends ProfileState {}

class ProfileLoadedState extends ProfileState {
  final Profile profile;
  ProfileLoadedState(this.profile);
}

class ProfileErrorState extends ProfileState {
  final String errorMessage;
  ProfileErrorState(this.errorMessage);
}

class ProfileUnauthenticatedState extends ProfileState {}

// Bloc
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final SignOutUseCase signOutUseCase;

  ProfileBloc({
    required this.getProfileUseCase,
    required this.signOutUseCase,
    Profile? initialProfile,
  }) : super(
          initialProfile != null
              ? ProfileLoadedState(initialProfile)
              : ProfileLoadingState(),
        ) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<SignOutRequestedEvent>(_onSignOutRequested);
  }

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoadingState());
    try {
      final profile = await getProfileUseCase(event.userId);
      emit(ProfileLoadedState(profile));
    } catch (e) {
      emit(ProfileErrorState(e.toString()));
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequestedEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoadingState());
    try {
      await signOutUseCase();
      emit(ProfileUnauthenticatedState());
    } catch (e) {
      emit(ProfileErrorState(e.toString()));
    }
  }
}
