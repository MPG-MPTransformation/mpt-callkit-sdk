import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:mpt_callkit/conversation/input/send_button.dart';

class AppSendMessageField extends StatefulWidget {
  final GlobalKey<FlutterMentionsState> mentionsKey;
  final Function onSendPressed;
  final Function onTextChange;

  const AppSendMessageField({
    super.key,
    required this.onTextChange,
    required this.mentionsKey,
    required this.onSendPressed,
  });

  @override
  State<AppSendMessageField> createState() => _AppSendMessageFieldState();
}

class _AppSendMessageFieldState extends State<AppSendMessageField> {
  bool obscureText = false;

  Timer? _debounce;

  @override
  Widget build(BuildContext context) {
    return Portal(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                color: Colors.white,
                child: Image.asset(
                  'packages/mpt_callkit/lib/assets/images/camera.png',
                  // (blur ?? true) ? Icons.send : Icons.send_and_archive,
                  width: 24,
                  height: 24,
                )),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: const Color(0xffedf0f3), width: 1),
                  color: const Color(0xffedf0f3),
                ),
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        color: Colors.transparent,
                        child: Image.asset(
                          'packages/mpt_callkit/lib/assets/images/emoji.png',
                          // (blur ?? true) ? Icons.send : Icons.send_and_archive,
                          width: 24,
                          height: 24,
                        )),
                    Expanded(
                      child: FlutterMentions(
                        maxLength: 1000,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        appendSpaceOnAdd: false,
                        onChanged: _onTextChanged,
                        key: widget.mentionsKey,
                        enableSuggestions: false,
                        hideSuggestionList: true,
                        scrollPadding: const EdgeInsets.all(0),
                        suggestionPosition: SuggestionPosition.Bottom,
                        maxLines: 5,
                        minLines: 1,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.withOpacity(0.9)),
                        decoration: InputDecoration(
                          counterText: "",
                          hintText: 'Gửi thắc mắc',
                          hintStyle: TextStyle(
                              fontSize: 14, color: Colors.grey.withOpacity(0.5)),
                          border:
                              const UnderlineInputBorder(borderSide: BorderSide.none),
                          enabledBorder:
                              const UnderlineInputBorder(borderSide: BorderSide.none),
                          focusedBorder:
                              const UnderlineInputBorder(borderSide: BorderSide.none),
                        ),
                        mentions: [
                          Mention(
                              trigger: '@',
                              style: const TextStyle(
                                color: Colors.blue,
                              ),
                              data: [],
                              matchAll: false,
                              markupBuilder:
                                  (String trigger, String mention, String value) {
                                return "$trigger[$value]($mention)";
                              },
                              suggestionBuilder: (data) {
                                return Container();
                              }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SendButtonWidget(
                onPressed: () {
                  widget.onSendPressed();
                },
                blur: !obscureText),
          ],
        ),
      ),
    );
  }

  void _onTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      setState(() {
        obscureText = text.isNotEmpty;
      });
      widget.onTextChange(text);
    });
  }
}
