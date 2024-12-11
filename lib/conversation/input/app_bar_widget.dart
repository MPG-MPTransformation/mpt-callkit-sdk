import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppBarWidget extends AppBar {
  AppBarWidget({
    Key? key,
    required BuildContext context,
    VoidCallback? onBackPressed,
    Widget? rightActions,
  }) : super(
          key: key,
          automaticallyImplyLeading: false,
          title: Align(
            alignment: Alignment.center,
            child: Row(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      if (onBackPressed != null) onBackPressed();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                          'packages/mpt_callkit/lib/assets/images/back.png',
                          width: 24,
                          height: 24),
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Bs. Lương Văn Luân',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      if (onBackPressed != null) onBackPressed();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                          'packages/mpt_callkit/lib/assets/images/call.png',
                          width: 24,
                          height: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          toolbarHeight: 100,
          elevation: 0.0,
        );
}
