part of 'mf_bloc.dart';

enum MfSectionTab {
  holdings('Holdings'),
  sips('SIPs'),
  orders('Orders');

  const MfSectionTab(this.label);
  final String label;
}

sealed class MfEvent {
  const MfEvent();
}

final class MfStarted extends MfEvent {
  const MfStarted();
}

final class MfTabChanged extends MfEvent {
  const MfTabChanged(this.tab);
  final MfSectionTab tab;
}

final class MfRefreshed extends MfEvent {
  const MfRefreshed();
}
