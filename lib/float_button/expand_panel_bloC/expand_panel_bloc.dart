import 'dart:async';
import 'package:mpt_callkit/float_button/expand_panel_bloC/expand_panel_event.dart';

import 'expand_panel_state.dart';

class ExpandPanelBloc {
  bool isExpanded = false;

  final eventController = StreamController<ExpandPanelEvent>.broadcast();
  final stateController = StreamController<ExpandPanelState>.broadcast();

  ExpandPanelBloc() {
    eventController.stream.listen(_mapEventToState);
  }

  _mapEventToState(ExpandPanelEvent event) {
    if (event is ToggleExpandPanelEvent) {
      isExpanded = true;
    } else if (event is ToggleShrinkPanelEvent) {
      isExpanded = false;
    }

    stateController.sink.add(ExpandPanelState(isExpanded));
  }

  void dispose() {
    eventController.close();
    stateController.close();
  }
}
