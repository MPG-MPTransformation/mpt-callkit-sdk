import 'package:flutter/material.dart';

class MessageView extends StatelessWidget {
  const MessageView({required this.phoneNumber, super.key});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(phoneNumber),
      ),
    );
  }

}