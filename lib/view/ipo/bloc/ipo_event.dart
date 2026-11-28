part of 'ipo_bloc.dart';

enum IpoSectionTab {
  open('Open'),
  upcoming('Upcoming'),
  applied('Applied');

  const IpoSectionTab(this.label);
  final String label;
}

sealed class IpoEvent {
  const IpoEvent();
}

final class IpoStarted extends IpoEvent {
  const IpoStarted();
}

final class IpoTabChanged extends IpoEvent {
  const IpoTabChanged(this.tab);
  final IpoSectionTab tab;
}

final class IpoRefreshed extends IpoEvent {
  const IpoRefreshed();
}
