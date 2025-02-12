import 'package:flutter/material.dart';

enum PanelShape { rectangle, rounded }

enum DockType { inside, outside }

enum PanelState { open, closed }

class FloatingMenuPanel extends StatefulWidget {
  //final Function(bool) isOpen;
  final double? positionBottom;
  final double? positionRight;
  final Color? borderColor;
  final double? borderWidth;
  final double? size;
  final double? iconSize;
  final IconData? panelIcon;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? contentColor;
  final PanelShape? panelShape;
  final PanelState? panelState;
  final int? panelAnimDuration;
  final Curve? panelAnimCurve;
  final DockType? dockType;
  final double? dockOffset;
  final int? dockAnimDuration;
  final Curve? dockAnimCurve;
  final Function(int) onPressed;
  final VoidCallback onPressedCloseMenuButton;
  final VoidCallback onPressedOpenMenuButton;
  final double widgetHeight;
  final double widgetWidth;

  const FloatingMenuPanel({
    super.key,
    this.positionBottom,
    this.positionRight,
    this.borderColor,
    this.borderWidth,
    this.iconSize,
    this.panelIcon,
    this.size,
    this.borderRadius,
    this.panelState,
    this.panelAnimDuration,
    this.panelAnimCurve,
    this.backgroundColor,
    this.contentColor,
    this.panelShape,
    this.dockType,
    this.dockOffset,
    this.dockAnimCurve,
    this.dockAnimDuration,
    required this.onPressed,
    required this.onPressedCloseMenuButton,
    required this.onPressedOpenMenuButton,
    required this.widgetHeight,
    required this.widgetWidth,
    //this.isOpen,
  });

  @override
  _FloatBoxState createState() => _FloatBoxState();
}

class _FloatBoxState extends State<FloatingMenuPanel> {
  // Required to set the default state to closed when the widget gets initialized;
  PanelState _panelState = PanelState.closed;

  // Default positions for the panel;
  double _positionBottom = 0.0;
  double _positionRight = 0.0;

  // ** PanOffset ** is used to calculate the distance from the edge of the panel
  // to the cursor, to calculate the position when being dragged;
  double _panOffsetTop = 0.0;
  double _panOffsetLeft = 0.0;

  // This is the animation duration for the panel movement, it's required to
  // dynamically change the speed depending on what the panel is being used for.
  // e.g: When panel opened or closed, the position should change in a different
  // speed than when the panel is being dragged;
  int _movementSpeed = 0;

  @override
  void initState() {
    _positionBottom =
        widget.widgetHeight - (widget.size ?? 70) - (widget.dockOffset ?? 20);
    _positionRight =
        widget.widgetWidth - (widget.size ?? 70) - (widget.dockOffset ?? 20);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Width and height of page is required for the dragging the panel;
    double pageWidth = MediaQuery.of(context).size.width;
    double pageHeight = MediaQuery.of(context).size.height;

    // Dock offset creates the boundary for the page depending on the DockType;
    double dockOffset = widget.dockOffset ?? 20.0;

    // Widget size if the width of the panel;
    double widgetSize = widget.size ?? 70.0;

    // **** METHODS ****

    // Dock boundary is calculated according to the dock offset and dock type.
    double dockBoundary() {
      if (widget.dockType != null && widget.dockType == DockType.inside) {
        // If it's an 'inside' type dock, dock offset will remain the same;
        return dockOffset;
      } else {
        // If it's an 'outside' type dock, dock offset will be inverted, hence
        // negative value;
        return -dockOffset;
      }
    }

    // If panel shape is set to rectangle, the border radius will be set to custom
    // border radius property of the WIDGET, else it will be set to the size of
    // widget to make all corners rounded.
    BorderRadius borderRadius() {
      if (widget.panelShape != null &&
          widget.panelShape == PanelShape.rounded) {
        // If panel shape is 'rectangle', border radius can be set to custom or 0;
        return widget.borderRadius ?? BorderRadius.circular(0);
      } else {
        // If panel shape is 'rounded', border radius will be the size of widget
        // to make it rounded;
        return BorderRadius.circular(widgetSize);
      }
    }

    double panelWidth() {
      return widgetSize + (widget.borderWidth ?? 0) * 2;
    }

    // Panel top needs to be recalculated while opening the panel, to make sure
    // the height doesn't exceed the bottom of the page;
    void calcPanelTop() {
      if (_positionBottom + widgetSize > pageHeight + dockBoundary()) {
        _positionBottom = pageHeight - widgetSize + dockBoundary();
      }
    }

    // Panel border is only enabled if the border width is greater than 0;
    Border? panelBorder() {
      if (widget.borderWidth != null && widget.borderWidth! > 0) {
        return Border.all(
          color: widget.borderColor ?? const Color(0xFF333333),
          width: widget.borderWidth ?? 0.0,
        );
      } else {
        return null;
      }
    }

    // Force dock will dock the panel to it's nearest edge of the screen;
    void forceDock() {
      // Calculate the center of the panel;
      double center = _positionRight + (widgetSize / 2);

      // Set movement speed to the custom duration property or '300' default;
      _movementSpeed = widget.dockAnimDuration ?? 300;

      // Check if the position of center of the panel is less than half of the
      // page;
      if (center < pageWidth / 2) {
        // Dock to the left edge;
        _positionRight = 0.0 + dockBoundary();
      } else {
        // Dock to the right edge;
        _positionRight = (pageWidth - widgetSize) - dockBoundary();
      }
    }

    // TODO implement close panel from screen without touch panel

    // Animated positioned widget can be moved to any part of the screen with
    // animation;
    return AnimatedPositioned(
      duration: Duration(
        milliseconds: _movementSpeed,
      ),
      top: _positionBottom,
      left: _positionRight,
      curve: widget.dockAnimCurve ?? Curves.fastLinearToSlowEaseIn,

      // Animated Container is used for easier animation of container height;
      child: AnimatedContainer(
        duration: Duration(milliseconds: widget.panelAnimDuration ?? 600),
        // width: widgetSize,
        // height: panelHeight(),
        width: panelWidth(),
        height: widgetSize,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? const Color(0xff00b0cb),
          borderRadius: borderRadius(),
          border: panelBorder(),
        ),
        curve: widget.panelAnimCurve ?? Curves.fastLinearToSlowEaseIn,
        child: Wrap(
          direction: Axis.vertical,
          children: [
            // Gesture detector is required to detect the tap and drag on the panel;
            GestureDetector(
              onPanEnd: (event) {
                // Shrink children
                widget.onPressedCloseMenuButton();
                setState(
                  () {
                    forceDock();
                  },
                );
              },
              onTapCancel: () {
                debugPrint('TAP_CANCEL');
              },
              onPanStart: (event) {
                // Detect the offset between the top and left side of the panel and
                // x and y position of the touch(click) event;

                _panOffsetTop = event.globalPosition.dy - _positionBottom;
                _panOffsetLeft = event.globalPosition.dx - _positionRight;
              },
              onPanUpdate: (event) {
                // Shrink children
                widget.onPressedCloseMenuButton();

                setState(() {
                  _panelState = PanelState.closed;
                  _movementSpeed = 0;

                  _positionBottom = event.globalPosition.dy - _panOffsetTop;
                  if (_positionBottom < 0 + dockBoundary()) {
                    _positionBottom = 0 + dockBoundary();
                  }
                  if (_positionBottom >
                      (pageHeight - widgetSize) - dockBoundary()) {
                    _positionBottom =
                        (pageHeight - widgetSize) - dockBoundary();
                  }

                  _positionRight = event.globalPosition.dx - _panOffsetLeft;
                  if (_positionRight < 0 + dockBoundary()) {
                    _positionRight = 0 + dockBoundary();
                  }
                  if (_positionRight >
                      (pageWidth - panelWidth()) - dockBoundary()) {
                    _positionRight =
                        (pageWidth - panelWidth()) - dockBoundary();
                  }
                });
              },
              onTap: () {
                setState(
                  () {
                    _positionBottom = pageHeight - widgetSize - dockOffset;
                    _positionRight = pageWidth - widgetSize - dockOffset;

                    // Set the animation speed to custom duration;
                    _movementSpeed = widget.panelAnimDuration ?? 200;

                    if (_panelState == PanelState.open) {
                      // If panel state is "open", set it to "closed";
                      _panelState = PanelState.closed;

                      // Reset panel position, dock it to nearest edge;
                      forceDock();
                      //widget.isOpen(false);

                      // Shrink children;
                      widget.onPressedCloseMenuButton();
                      debugPrint("Child view closed.");
                    } else {
                      // If panel state is "closed", set it to "open";
                      _panelState = PanelState.open;

                      //widget.isOpen(true);

                      // Expand children;
                      widget.onPressedOpenMenuButton();
                      debugPrint("Child view opened.");

                      calcPanelTop();
                    }
                  },
                );
              },
              child: _FloatButton(
                size: widget.size ?? 70.0,
                icon: widget.panelIcon ?? Icons.settings,
                color: widget.contentColor ?? Colors.white,
                iconSize: widget.iconSize ?? 36.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatButton extends StatelessWidget {
  final double? size;
  final Color? color;
  final IconData? icon;
  final double? iconSize;

  const _FloatButton({this.size, this.color, this.icon, this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.0),
      width: size ?? 70.0,
      height: size ?? 70.0,
      child: Icon(
        icon ?? Icons.settings,
        color: color ?? Colors.white,
        size: iconSize ?? 24.0,
      ),
    );
  }
}
