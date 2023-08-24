import 'package:flutter/material.dart';

class DescribePhoto extends StatelessWidget {
  const DescribePhoto({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Touchable photograph'),
        backgroundColor: const Color.fromARGB(255, 217, 229, 222),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate back to first route when tapped.
          },
          child: const Text('Go back to the Homepage'),
        ),
      ),
    );
  }
}