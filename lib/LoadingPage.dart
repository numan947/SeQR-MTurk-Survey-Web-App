import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:wifi_qr_survey_app/Configuration.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({Key key}) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  bool dbug = false;
  bool textVisibility = false;
  bool buttonVisibility = false;

  Timer visibilityTimer;

  @override
  void initState() {
    super.initState();
    visibilityTimer = Timer(
      Duration(seconds: 60),
      () {
        setState(() {
          textVisibility = true;
          buttonVisibility = true;
        });
      },
    );
  }

  @override
  void dispose() {
    visibilityTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {   
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitSpinningLines(color: Colors.purple[400]),
          Visibility(
            child: Text("NOT LOGGED IN?", style: TextStyle(
              fontSize: Configuration.TEXT_SIZE, 
              color: Colors.red[300], 
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none
              ),
              ),
            visible: textVisibility,
          ),
          Visibility(
            child: TextButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, "/", (Route<dynamic> route) => false);
              },
              child: Text("Login Here!", style: TextStyle(fontSize: Configuration.TEXT_SIZE),),
            ),
            visible: buttonVisibility,
          )
        ],
      ),
    );
  }
}
