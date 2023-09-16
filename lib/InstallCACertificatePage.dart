import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_qr_survey_app/LoadingPage.dart';
import 'package:wifi_qr_survey_app/models/FixedData.dart';
import 'package:wifi_qr_survey_app/MainApp.dart';

class InstallCACertificate extends StatefulWidget {
  const InstallCACertificate({Key key}) : super(key: key);

  @override
  _InstallCACertificateState createState() => _InstallCACertificateState();
}

class _InstallCACertificateState extends State<InstallCACertificate> {
  List<String> validCertList;
  List<String> validCertState;
  bool showLoading = false;
  SharedPreferences prefs;
  String dropdownValue = "VPN and apps";
  TextEditingController certNameController;
  String certName;

  @override
  void initState() {
    super.initState();
    validCertList = [];
    validCertState = [];
    certNameController = TextEditingController();
    certNameController.addListener(() {
      this.certName = certNameController.text;
    },);
    populateCertList();
  }
  @override
  void dispose() {
    certNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(validCertList.length == validCertState.length);


    return StreamBuilder<Object>(
        stream: authService.auth.authStateChanges(),
        builder: (context, snapshot) {
          if (showLoading) return LoadingPage();
          print("Inside InstallCACertificatePage.dart");
          print("snapshot.hasData = ${snapshot.hasData}");
          print("snapshot.connectionstate = ${snapshot.connectionState}");

          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return LoadingPage();
          }

          if (!snapshot.hasData) {
            // redirect to SignInPage => user is not signed in
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              Navigator.pushNamedAndRemoveUntil(
                  context, "/", (Route<dynamic> route) => false);
            });
            print("Redirecting to / from InstallCACertif icatePage.dart");
            return LoadingPage(); // technically this is not possible to hang on to
          } else {
            User u = snapshot.data;
            currentUserInfo.setUserInfo(u);

          }
          return Scaffold(
            appBar: AppBar(
              title: Text("Install CA Certificates"),
              centerTitle: true,
              backgroundColor: Colors.grey[800],
            ),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Downloaded Certificates",
                      style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 40,
                          fontWeight: FontWeight.bold)),
                ),
                Container(
                  height: 300,
                  child: validCertList.length>0 ? ListView.builder(
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 3),
                        child: Padding(
                          padding:
                              const EdgeInsets.only(left: 200.0, right: 200),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SelectableText(
                                "${index + 1}. CA Certificate for domain: " + validCertList[index],
                                textAlign: TextAlign.justify,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 25,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left:8.0, right:8),
                                    child: SizedBox(
                                      width: 175,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (validCertState[index] == FixedData.certStateDownloaded) {
                                            showCertInstallDialog(index, setState);
                                          } else if (validCertState[index] == FixedData.certStateInstalled) {
                                            showCertUninstallDialog(index, false, setState);
                                          }
                                        },
                                        child: validCertState[index] ==
                                                FixedData.certStateInstalled
                                            ? Text("Uninstall certificate"): Text("Install certificate"),
                                        style: ButtonStyle(
                                            backgroundColor: validCertState[index] ==
                                                    FixedData.certStateInstalled
                                                ? MaterialStateProperty.all(
                                                    Colors.redAccent)
                                                : MaterialStateProperty.all(
                                                    Colors.blueAccent)),
                                      ),
                                    ),
                                  ),
                                   Padding(
                                     padding: const EdgeInsets.only(left:8.0, right:8),
                                     child: SizedBox(
                                      width: 100,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          showCertUninstallDialog(index, true, setState);
                                          setState(() {});
                                        },
                                        child: Text("Delete"),
                                        style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.orange)),
                                      ),
                                  ),
                                   ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                    itemCount: validCertList.length,
                  ):Center(child: Text("No downloaded certificate found!", style: TextStyle(fontSize: 20),)),
                )
              ],
            ),
          );
        });
  }

  void launchUrl(String _url) async {
    await canLaunch(_url) ? await launch(_url) : throw 'Could not launch $_url';
  }

  void populateCertList() async {
    showLoading = true;
    prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < FixedData.domainNames.length; i++) {
      String certState = prefs.getString(FixedData.domainNames[i]) ??
          FixedData.certStateNotDownloaded;
      if (certState != FixedData.certStateNotDownloaded) {
        validCertList.add(FixedData.domainNames[i]);
        validCertState.add(certState);
      }
    }
    setState(() {
      showLoading = false;
    });
  }

  Future<void> showCertInstallDialog(int index, Function parentSetState) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Name the certificate'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Certificate name:'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: certNameController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Credential use:"),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          items: <String>[FixedData.certModeVpn, FixedData.certModeWifi].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() {
                              dropdownValue = v;
                            });
                          },
                          value: dropdownValue,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Note: The issuer of this certificate may inspect all traffic to and from the device.", style: TextStyle(color: Colors.red, fontSize: 14),),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("The package contains:", style: TextStyle(color: Colors.grey, fontSize: 14),),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("one CA certificate", style: TextStyle(color: Colors.grey, fontSize: 14),),
                    )
                  ],
                ),
              );
            }
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                certNameController.clear();
              },
            ),
            TextButton(
              child: const Text('Ok'),
              onPressed: () async {
                Navigator.of(context).pop();
                await prefs.setString(validCertList[index], FixedData.certStateInstalled);
                validCertState[index] = FixedData.certStateInstalled;
                prefs.setString(validCertList[index]+"_NAME", certName);
                prefs.setString(validCertList[index]+"_MODE", dropdownValue);
                certNameController.clear();
                parentSetState(()=>{});
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showCertUninstallDialog(int index, bool delete, Function parentSetState) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Credential details'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: validCertState[index] == FixedData.certStateInstalled ? Text('${prefs.getString(validCertList[index]+"_NAME")}'):Text("Certificate not installed"),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: validCertState[index] == FixedData.certStateInstalled? Text("Installed for ${prefs.getString(validCertList[index]+"_MODE")}"): Text("Can be installed for VPN & apps, and Wi-Fi"),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("This entry contains:", style: TextStyle(color: Colors.grey, fontSize: 14),),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("   one CA certificate", style: TextStyle(color: Colors.grey, fontSize: 14),),
                    )
                  ],
                ),
              );
            }
          ),
          actions: <Widget>[
            TextButton(
              child: delete? Text("Delete"): Text('Remove'),
              onPressed: () async {
                Navigator.of(context).pop();
                prefs.remove(validCertList[index]+"_NAME");
                prefs.remove(validCertList[index]+"_MODE");
                if(delete){
                  await prefs.setString(validCertList[index], FixedData.certStateNotDownloaded);
                  validCertList.removeAt(index);
                  validCertState.removeAt(index);
                }
                else{
                  await prefs.setString(validCertList[index], FixedData.certStateDownloaded);
                  validCertState[index] = FixedData.certStateDownloaded;
                }
                parentSetState(()=>{});
              },
            ),
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

                // SizedBox(
                //   height: 10,
                // ),
                // Center(
                //     child: Card(
                //   borderOnForeground: true,
                //   shadowColor: Colors.blue,
                //   semanticContainer: true,
                //   color: Colors.grey[800],
                //   elevation: 5,
                //   margin: EdgeInsets.symmetric(vertical: 1.0, horizontal: 4.0),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Center(
                //         child: Icon(
                //           Icons.info_outline,
                //           color: Colors.white,
                //           size: 50,
                //         ),
                //       ),
                //       Text(
                //         "Manual installation of CA certificates is often cumbersome and may require multiple steps. For example, pixel phones' instruction for installing CA certificates can be found in the link below:",
                //         style: TextStyle(fontSize: 20, color: Colors.white),
                //       ),
                //       TextButton(
                //           onPressed: () {
                //             try {
                //               launchUrl(
                //                   "https://support.google.com/pixelphone/answer/2844832");
                //             } catch (e) {
                //               Toast.show("Failed to launch url!", context,
                //                   backgroundColor: Colors.grey,
                //                   textColor: Colors.white);
                //             }
                //           },
                //           child: Text(
                //             "Show CA certificate installation instruction for Google Pixel",
                //             style: TextStyle(
                //                 fontSize: 20, color: Colors.blueAccent),
                //           )),
                //       Text(
                //         "For now you can install CA certificate by clicking install button beside the domain names given below.",
                //         style: TextStyle(fontSize: 20, color: Colors.white),
                //       ),
                //     ],
                //   ),
                // )),
                // SizedBox(
                //   height: 30,
                // ),