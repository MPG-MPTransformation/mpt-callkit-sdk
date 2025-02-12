import 'package:flutter/material.dart';

import 'expand_panel_bloC/expand_panel_bloc.dart';
import 'expand_panel_bloC/expand_panel_event.dart';
import 'expand_panel_bloC/expand_panel_state.dart';
import 'floating_menu_button.dart';

class FloatingMenuButtonView extends StatefulWidget {
  const FloatingMenuButtonView({
    super.key,
    required this.child,
    required this.popupView,
    this.backgroundColor,
    // required this.floatingMenuPanel,
    this.panelPositionBottom,
    this.panelPositionRight,
    this.panelBorderColor,
    this.panelBorderWidth,
    this.panelIconSize,
    this.panelIcon,
    this.panelSize,
    this.panelBorderRadius,
    this.popupBorderRadius,
    this.panelState,
    this.panelAnimDuration,
    this.panelAnimCurve,
    this.panelBackgroundColor,
    this.panelContentColor,
    this.panelShape,
    this.panelDockType,
    this.panelDockOffset,
    this.panelDockAnimCurve,
    this.panelDockAnimDuration,
    required this.panelOnPressed,
  });

  final Widget child;
  final Widget popupView;
  // final FloatingMenuPanel floatingMenuPanel;

  final double? panelPositionBottom;
  final double? panelPositionRight;
  final Color? panelBorderColor;
  final Color? backgroundColor;
  final double? panelBorderWidth;
  final double? panelSize;
  final double? panelIconSize;
  final IconData? panelIcon;
  final BorderRadius? panelBorderRadius;
  final BorderRadius? popupBorderRadius;
  final Color? panelBackgroundColor;
  final Color? panelContentColor;
  final PanelShape? panelShape;
  final PanelState? panelState;
  final int? panelAnimDuration;
  final Curve? panelAnimCurve;
  final DockType? panelDockType;
  final double? panelDockOffset;
  final int? panelDockAnimDuration;
  final Curve? panelDockAnimCurve;
  final Function(int) panelOnPressed;

  @override
  State<FloatingMenuButtonView> createState() => _FloatMenuViewState();
}

class _FloatMenuViewState extends State<FloatingMenuButtonView> {
  final expandPanelBloC = ExpandPanelBloc();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final widgetHeight = constraints.maxHeight;
      final widgetWidth = constraints.maxWidth;
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          widget.child,
          StreamBuilder<ExpandPanelState>(
            stream: expandPanelBloC.stateController.stream,
            initialData: ExpandPanelState(false),
            builder: (context, expandSnapshot) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: expandSnapshot.data?.isExpanded == true
                    ? Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: widget.backgroundColor ?? Colors.grey,
                                borderRadius: widget.popupBorderRadius ??
                                    BorderRadius.circular(15),
                              ),
                              child: ClipRRect(
                                borderRadius: widget.popupBorderRadius ??
                                    BorderRadius.circular(15),
                                child: Material(child: widget.popupView),
                              ),
                            ),
                          ),
                          Container(
                            height: (widget.panelSize ?? 70) +
                                (widget.panelDockOffset ?? 20) * 2,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
          FloatingMenuPanel(
            widgetHeight: widgetHeight,
            widgetWidth: widgetWidth,
            backgroundColor: widget.panelBackgroundColor,
            contentColor: widget.panelContentColor,
            panelShape: widget.panelShape,
            borderRadius: widget.panelBorderRadius,
            dockType: widget.panelDockType,
            dockOffset: widget.panelDockOffset,
            panelAnimDuration: widget.panelAnimDuration,
            panelAnimCurve: widget.panelAnimCurve,
            dockAnimDuration: widget.panelDockAnimDuration,
            dockAnimCurve: widget.panelDockAnimCurve,
            panelIcon: widget.panelIcon,
            size: widget.panelSize,
            iconSize: widget.panelIconSize,
            borderWidth: widget.panelBorderWidth,
            borderColor: widget.panelBorderColor,
            panelState: widget.panelState,
            positionRight: widget.panelPositionRight,
            positionBottom: widget.panelPositionBottom,
            onPressed: (index) {
              widget.panelOnPressed;
            },
            onPressedOpenMenuButton: () {
              expandPanelBloC.eventController.sink.add(
                ToggleExpandPanelEvent(),
              );
            },
            onPressedCloseMenuButton: () {
              expandPanelBloC.eventController.sink.add(
                ToggleShrinkPanelEvent(),
              );
            },
          ),
        ],
      );
    });
  }
}
