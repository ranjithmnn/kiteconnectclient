part of 'mf_bloc.dart';

@immutable
final class MfState {
  const MfState({
    this.activeTab = MfSectionTab.holdings,
    this.isLoading = false,
  });

  final MfSectionTab activeTab;
  final bool isLoading;

  MfState copyWith({
    MfSectionTab? activeTab,
    bool? isLoading,
  }) {
    return MfState(
      activeTab: activeTab ?? this.activeTab,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
