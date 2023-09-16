import 'dart:async';

import 'package:flutter/material.dart';


class QrCodeWidgetList extends StatefulWidget {
  final Map<String, String> qrCodeWifiSSID;
  final Map<String, String> qrCodeValues;
  final Function(String wifiSSID, String qrCodeString) notifyParent;

  const QrCodeWidgetList({Key key , @required this.qrCodeWifiSSID, @required this.qrCodeValues ,@required this.notifyParent}) : super(key: key);

  @override
  State<QrCodeWidgetList> createState() => _QrCodeWidgetListState();
}

class _QrCodeWidgetListState extends State<QrCodeWidgetList> {
  bool disabled = false;
  @override
  void initState() {
    // TODO: implement initState
    disabled = false;
    super.initState();
  }
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    List<String> qrCodes = widget.qrCodeValues.keys.toList();
    return AbsorbPointer(
      absorbing: disabled,
      child: Center(
        child: ListView.builder(itemBuilder: (BuildContext context, int index) {  
          return Center(
            child: QrCodeWidget(
              qrCodeWifiSSID: widget.qrCodeWifiSSID, 
              qrCodes: qrCodes, 
              index: index, 
              notifyParent: notifyScanFinished,
              disableParent: disableParent,
              ),
          );
        },itemCount: qrCodes.length,
        shrinkWrap: true,
        ),
      ),
    );
  }

  void disableParent(bool d){
    setState(() {
      disabled = d;
    });
  }
  void notifyScanFinished(String qrCodeSSID, String qrCodeName){
    widget.notifyParent(qrCodeSSID, widget.qrCodeValues[qrCodeName]);
  }
}



class QrCodeWidget extends StatefulWidget {
  final Map<String, String> qrCodeWifiSSID;
  final List<String> qrCodes;
  final int index;
  final Function(String qrCodeSSID, String scanResult) notifyParent;
  final Function(bool disable) disableParent;
  const QrCodeWidget(
      {Key key, @required this.qrCodeWifiSSID, @required this.qrCodes,@required this.index,@required this.notifyParent, this.disableParent})
      : super(key: key);
  @override
  State<QrCodeWidget> createState() => _QrCodeWidgetState();
}

class _QrCodeWidgetState extends State<QrCodeWidget>
    with TickerProviderStateMixin {
  AnimationController _animationController;
  bool _animationStopped = false;
  String scanText = "Scan";
  bool scanning = false;
  bool scannerVisible = false;

  void animateScanAnimation(bool reverse) {
    if (reverse) {
      _animationController.reverse(from: 1.0);
    } else {
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void initState() {
    _animationController = new AnimationController(
        duration: new Duration(milliseconds: 250), vsync: this);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animateScanAnimation(true);
      } else if (status == AnimationStatus.dismissed) {
        animateScanAnimation(false);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            children: [Tooltip(
              message: "Scan this qr code",
              verticalOffset: 110,
              preferBelow: true,
              child: InkWell(
                child: MouseRegion(
                  cursor: SystemMouseCursors.progress,
                  child: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          border: Border.all(
                            width: 1,
                          )),
                      child: Image.asset(
                        widget.qrCodes[widget.index],
                        height: 350,
                      )),
                ),
                onTap: () {
                    // print("Todo Handle tap differently!");
                    widget.disableParent(true);
                    scannerVisible = true;
                    animateScanAnimation(false);
                    setState(() {
                      _animationStopped = false;
                      scanning = true;
                    });

                    Timer(Duration(milliseconds: 500), (){
                    scannerVisible = false;
                    widget.disableParent(false);
                    widget.notifyParent(widget.qrCodeWifiSSID[widget.qrCodes[widget.index]], widget.qrCodes[widget.index]);
                    setState(() {
                      _animationStopped = true;
                      scanning = false;
                    });
                    });
                },
              ),
            ),
            Visibility(
              child: ImageScannerAnimation(_animationStopped, 350, 115,animation: _animationController,),
              visible: scannerVisible,
              ),
            ]
          )
          // ,
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Text(
          //     "QR code for Wifi SSID: " +
          //         widget.qrCodeWifiSSID[widget.qrCodes[widget.index]],
          //     style: TextStyle(
          //         color: Colors.white,
          //         backgroundColor: Colors.grey,
          //         fontSize: 16),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class ImageScannerAnimation extends AnimatedWidget {
  final bool stopped;
  final double width;
  final double magic;

  ImageScannerAnimation(this.stopped, this.width, this.magic,
      {Key key, Animation<double> animation})
      : super(key: key, listenable: animation);

  Widget build(BuildContext context) {
    final Animation<double> animation = listenable;
    final scorePosition = (animation.value * this.magic) + 120;

    Color color1 = Color(0x5532CD32);
    Color color2 = Color(0x0032CD32);

    if (animation.status == AnimationStatus.reverse) {
      color1 = Color(0x0032CD32);
      color2 = Color(0x5532CD32);
    }

    return new Positioned(
        bottom: scorePosition,
        left: 16.0,
        child: new Opacity(
            opacity: (stopped) ? 0.0 : 1.0,
            child: Container(
              height: 100.0,
              width: width,
              decoration: new BoxDecoration(
                  gradient: new LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.1, 0.9],
                colors: [color1, color2],
              )),
            )));
  }
}
