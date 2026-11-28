part of 'ipo_bloc.dart';

@immutable
final class IpoState {
  const IpoState({
    this.activeTab = IpoSectionTab.open,
    this.isLoading = false,
  });

  final IpoSectionTab activeTab;
  final bool isLoading;

  IpoState copyWith({
    IpoSectionTab? activeTab,
    bool? isLoading,
  }) {
    return IpoState(
      activeTab: activeTab ?? this.activeTab,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
