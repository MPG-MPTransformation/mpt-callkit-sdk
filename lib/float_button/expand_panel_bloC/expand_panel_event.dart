abstract class ExpandPanelEvent {}

class ToggleExpandPanelEvent extends ExpandPanelEvent {
  ToggleExpandPanelEvent();
}

class ToggleShrinkPanelEvent extends ExpandPanelEvent {
  ToggleShrinkPanelEvent();
}
