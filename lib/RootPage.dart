import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_qr_survey_app/Configuration.dart';
import 'package:wifi_qr_survey_app/LoadingPage.dart';
import 'package:wifi_qr_survey_app/MainApp.dart';

class SummaryInformation {
  Pair<int> rngCounter = Pair(-1, -1);
  int totalWorkerCount;
  int totalTask1ResponseCount;
  int totalTask2ResponseCount;
  int totalQuestionnaireResponseCount;
  int totalAMTCodeGenerated;
}

class RootPage extends StatefulWidget {
  @override
  _RootPageState createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static double buttonWidth = 180;
  static double buttonHeight = 50;

  SummaryInformation si = SummaryInformation();

  String surveyState;
  String AMTCode;
  bool consentGiven = false;
  bool showAMTCode = false;
  bool showLoading = false;
  List<String> implementationList = [
    "OLD_IMPLEMENTATION",
    "NEW_IMPLEMENTATION"
  ];
  List<String> sListOld1 = [OTB, OTA, OTR];
  List<String> sListOld2 = [OTA, OTB, OTR];
  List<String> sListOld3 = [OTR, OTB, OTA];
  List<String> sListOld4 = [OTB, OTR, OTA];
  List<String> sListOld5 = [OTA, OTR, OTB];
  List<String> sListOld6 = [OTR, OTA, OTB];
  List<List<String>> allOldLists;

  List<String> sListNew1 = [NTB, NTA, NTR];
  List<String> sListNew2 = [NTA, NTB, NTR];
  List<String> sListNew3 = [NTR, NTB, NTA];
  List<String> sListNew4 = [NTB, NTR, NTA];
  List<String> sListNew5 = [NTA, NTR, NTB];
  List<String> sListNew6 = [NTR, NTA, NTB];
  List<List<String>> allNewLists;

  Map<String, String> taskMap;
  Map<String, String> revTaskMap;
  String blackList;
  String rng1List;
  String rng2List;

  String oldImpTaskStringBenign;
  String oldImpTaskStringAttack;
  String oldImpTaskStringReality;
  String newImpTaskStringBenign;
  String newImpTaskStringAttack;
  String newImpTaskStringReality;
  TextEditingController consentTextController = TextEditingController();
  TextEditingController editTextController = TextEditingController();
  String localConsentHtml;

  @override
  void initState() {
    super.initState();
    AMTCode = "No Code Generated";
  }

  @override
  void dispose() {
    // TODO: implement dispose
    consentTextController.dispose();
    editTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
        stream: authService.auth.authStateChanges(),
        builder: (context, snapshot) {
          if (dbug) {
            print("Inside RootPage.dart");
            print("snapshot.connectionState = ${snapshot.connectionState}");
            print("snapshot.hasData = ${snapshot.hasData}");
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingPage();
          }
          if (!snapshot.hasData) {
            return LoadingPage(); // this shouldn't be possible, as there's no reference to rootpage, but WTH -_-
          } else {
            User u = snapshot.data;
            currentUserInfo.setUserInfo(u);

            if (allNewLists == null || allOldLists == null) {
              allOldLists = [
                sListOld1,
                sListOld2,
                sListOld3,
                sListOld4,
                sListOld5,
                sListOld6
              ];
              allNewLists = [
                sListNew1,
                sListNew2,
                sListNew3,
                sListNew4,
                sListNew5,
                sListNew6
              ];
            }
            if (surveyState == null) {
              readAndSetSurveyStateAndUpdateWorkerIDAndUpdateTaskMapAndSetupInstructionMapAndGetConsentFromDB();
              showLoading = true;
            } else {
              showLoading = false;
            }

            if (showLoading) {
              if (dbug) {
                print("SURVEYSTATE = $surveyState");
                print("TASKMAP = $taskMap");
              }

              return LoadingPage();
            }
            if (dbug) {
              print("SURVEYSTATE(notNULL) = $surveyState");
              print("TASKMAP(notNULL) = $taskMap");
            }
          }

          assert(surveyState != null);
          assert(taskMap != null);
          if (dbug) print("CONSENT = $consentGiven");

          revTaskMap = taskMap.map((key, value) => MapEntry(value, key));

          oldImpTaskStringBenign = revTaskMap[OTB];
          bool oldImpTaskStringBenignActive =
              activateButton(oldImpTaskStringBenign, surveyState);
          oldImpTaskStringAttack = revTaskMap[OTA];
          bool oldImpTaskStringAttackActive =
              activateButton(oldImpTaskStringAttack, surveyState);
          oldImpTaskStringReality = revTaskMap[OTR];
          bool oldImpTaskStringRealityActive =
              activateButton(oldImpTaskStringReality, surveyState);

          newImpTaskStringBenign = revTaskMap[NTB];
          bool newImpTaskStringBenignActive =
              activateButton(newImpTaskStringBenign, surveyState);
          newImpTaskStringAttack = revTaskMap[NTA];
          bool newImpTaskStringAttackActive =
              activateButton(newImpTaskStringAttack, surveyState);
          newImpTaskStringReality = revTaskMap[NTR];
          bool newImpTaskStringRealityActive =
              activateButton(newImpTaskStringReality, surveyState);

          bool oldPTQActive = activateButton(revTaskMap[OTPTQ], surveyState);
          bool newPTQActive = activateButton(revTaskMap[NTPTQ], surveyState);
          bool demQActive = activateButton(revTaskMap[DEMQ], surveyState);

          var giveConsentButton = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  displayConsentText(context, consentPrompt, setState);
                },
                child: Text(
                  "Consent",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.blue[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.blue[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );

          var oldImplementationButtonBenign = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: oldImpTaskStringBenignActive
                    ? () {
                        Navigator.pushNamed(context, '/wifinetworklist',
                            arguments: {
                              'NEW_IMPLEMENTATION': false,
                              'TASK_IDENTIFIER': '$oldImpTaskStringBenign',
                              'TOFU_AVAILABLE': taskMap['TofuMode'] == 'True',
                              'ACTUAL_TASK_ID': OTB,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  oldImpTaskStringBenign)
                            });
                      }
                    : null,
                child: Text(
                  "$oldImpTaskStringBenign",
                  style: TextStyle(
                      color: oldImpTaskStringBenignActive
                          ? Colors.white
                          : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.purple[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.purple[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );

          var oldImplementationButtonAttack = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: oldImpTaskStringAttackActive
                    ? () {
                        Navigator.pushNamed(context, '/wifinetworklist',
                            arguments: {
                              'NEW_IMPLEMENTATION': false,
                              'TASK_IDENTIFIER': '$oldImpTaskStringAttack',
                              'TOFU_AVAILABLE': taskMap['TofuMode'] == 'True',
                              'ACTUAL_TASK_ID': OTA,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  oldImpTaskStringAttack)
                            });
                      }
                    : null,
                child: Text(
                  "$oldImpTaskStringAttack",
                  style: TextStyle(
                      color: oldImpTaskStringAttackActive
                          ? Colors.white
                          : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.purple[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.purple[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );

          var oldImplementationButtonReality = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: oldImpTaskStringRealityActive
                    ? () {
                        Navigator.pushNamed(context, '/wifinetworklist',
                            arguments: {
                              'NEW_IMPLEMENTATION': false,
                              'TASK_IDENTIFIER': '$oldImpTaskStringReality',
                              'TOFU_AVAILABLE': taskMap['TofuMode'] == 'True',
                              'ACTUAL_TASK_ID': OTR,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  oldImpTaskStringReality)
                            });
                      }
                    : null,
                child: Text(
                  "$oldImpTaskStringReality",
                  style: TextStyle(
                      color: oldImpTaskStringRealityActive
                          ? Colors.white
                          : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.purple[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.purple[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );

          var newImplementationButtonBenign = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: newImpTaskStringBenignActive
                    ? () {
                        Navigator.pushNamed(context, '/wifinetworklist',
                            arguments: {
                              'NEW_IMPLEMENTATION': true,
                              'TASK_IDENTIFIER': '$newImpTaskStringBenign',
                              'TOFU_AVAILABLE': false,
                              'ACTUAL_TASK_ID': NTB,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  newImpTaskStringBenign)
                            });
                      }
                    : null,
                child: Text(
                  "$newImpTaskStringBenign",
                  style: TextStyle(
                      color: newImpTaskStringBenignActive
                          ? Colors.white
                          : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.lightGreen[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.lightGreen[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );

          var newImplementationButtonAttack = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: newImpTaskStringAttackActive
                    ? () {
                        Navigator.pushNamed(context, '/wifinetworklist',
                            arguments: {
                              'NEW_IMPLEMENTATION': true,
                              'TASK_IDENTIFIER': '$newImpTaskStringAttack',
                              'TOFU_AVAILABLE': false,
                              'ACTUAL_TASK_ID': NTA,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  newImpTaskStringAttack)
                            });
                      }
                    : null,
                child: Text(
                  "$newImpTaskStringAttack",
                  style: TextStyle(
                      color: newImpTaskStringAttackActive
                          ? Colors.white
                          : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.lightGreen[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.lightGreen[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );
          var newImplementationButtonReality = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: newImpTaskStringRealityActive
                    ? () {
                        Navigator.pushNamed(context, '/wifinetworklist',
                            arguments: {
                              'NEW_IMPLEMENTATION': true,
                              'TASK_IDENTIFIER': '$newImpTaskStringReality',
                              'TOFU_AVAILABLE': false,
                              'ACTUAL_TASK_ID': NTR,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  newImpTaskStringReality)
                            });
                      }
                    : null,
                child: Text(
                  "$newImpTaskStringReality",
                  style: TextStyle(
                      color: newImpTaskStringRealityActive
                          ? Colors.white
                          : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.lightGreen[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.lightGreen[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );

          var oldTaskPTQ = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: oldPTQActive
                    ? () {
                        Navigator.pushNamed(context, '/questionnaire',
                            arguments: {
                              'PostTask': true,
                              'TaskId': OTPTQ,
                              'newImplementation': false,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  revTaskMap[OTPTQ]),
                              'TOFU_AVAILABLE': false
                            });
                      }
                    : null,
                child: Text(
                  revTaskMap[OTPTQ],
                  style: TextStyle(
                      color: oldPTQActive ? Colors.white : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.purple[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.purple[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );
          var newTaskPTQ = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: newPTQActive
                    ? () {
                        Navigator.pushNamed(context, '/questionnaire',
                            arguments: {
                              'PostTask': true,
                              'TaskId': NTPTQ,
                              'newImplementation': true,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  revTaskMap[NTPTQ]),
                              'TOFU_AVAILABLE': false
                            });
                      }
                    : null,
                child: Text(
                  revTaskMap[NTPTQ],
                  style: TextStyle(
                      color: newPTQActive ? Colors.white : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.lightGreen[900]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.lightGreen[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );
          var demQButton = SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: demQActive
                    ? () {
                        Navigator.pushNamed(context, '/questionnaire',
                            arguments: {
                              'PostTask': false,
                              'TaskId': DEMQ,
                              'TASK_STATE': getTaskStateFromTaskIdentifier(
                                  revTaskMap[DEMQ])
                            });
                      }
                    : null,
                child: Text(
                  revTaskMap[DEMQ],
                  style: TextStyle(
                      color: demQActive ? Colors.white : Colors.grey,
                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                      letterSpacing: 1.5),
                ),
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.teal[800]),
                    foregroundColor:
                        MaterialStateProperty.all(Colors.teal[200]),
                    elevation: MaterialStateProperty.all(0.0)),
              ),
            ),
          );

          List<Widget> rootPageButtons = [
            Visibility(
              visible: !currentUserInfo.isAnonymous,
              child: SizedBox(
                width: buttonWidth,
                height: buttonHeight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      _displaySummaryInformation(context);
                      // BotToast.showText(
                      //         text:
                      //             "TODO!",
                      //         duration: Duration(seconds: 3),
                      //         contentColor: Colors.blue[300],
                      //         textStyle: TextStyle(
                      //             color: Colors.white,
                      //             fontSize: Configuration.TOAST_SIZE));
                    },
                    child: Text(
                      "Summary",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: Configuration.BUTTON_TEXT_SIZE,
                          letterSpacing: 1.5),
                    ),
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.grey[800]),
                        foregroundColor:
                            MaterialStateProperty.all(Colors.grey[500]),
                        elevation: MaterialStateProperty.all(0.0)),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: !currentUserInfo.isAnonymous,
              child: SizedBox(
                width: buttonWidth,
                height: buttonHeight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      AddOrEditElements(context, "RNGLIST");
                      // BotToast.showText(
                      //         text:
                      //             "TODO!",
                      //         duration: Duration(seconds: 3),
                      //         contentColor: Colors.blue[300],
                      //         textStyle: TextStyle(
                      //             color: Colors.white,
                      //             fontSize: Configuration.TOAST_SIZE));
                    },
                    child: Text(
                      "RNGs",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: Configuration.BUTTON_TEXT_SIZE,
                          letterSpacing: 1.5),
                    ),
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.grey[800]),
                        foregroundColor:
                            MaterialStateProperty.all(Colors.grey[500]),
                        elevation: MaterialStateProperty.all(0.0)),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: !currentUserInfo.isAnonymous,
              child: SizedBox(
                width: buttonWidth,
                height: buttonHeight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      AddOrEditElements(context, "BLACKLIST");
                      // BotToast.showText(
                      //         text:
                      //             "TODO!",
                      //         duration: Duration(seconds: 3),
                      //         contentColor: Colors.blue[300],
                      //         textStyle: TextStyle(
                      //             color: Colors.white,
                      //             fontSize: Configuration.TOAST_SIZE));
                    },
                    child: Text(
                      "Blacklist",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: Configuration.BUTTON_TEXT_SIZE,
                          letterSpacing: 1.5),
                    ),
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.grey[800]),
                        foregroundColor:
                            MaterialStateProperty.all(Colors.grey[500]),
                        elevation: MaterialStateProperty.all(0.0)),
                  ),
                ),
              ),
            ),
          ];

          var taskList = taskMap.keys.toList();
          taskList.sort();

          for (int i = 0; i < taskList.length; i++) {
            String taskName = taskMap[taskList[i]];
            // print("Task-${i+1} => ${taskMap["Task-${i+1}"]}");
            if (taskName == OTB) {
              rootPageButtons.insert(i, oldImplementationButtonBenign);
            } else if (taskName == OTA) {
              rootPageButtons.insert(i, oldImplementationButtonAttack);
            } else if (taskName == OTR) {
              rootPageButtons.insert(i, oldImplementationButtonReality);
            } else if (taskName == OTPTQ) {
              rootPageButtons.insert(i, oldTaskPTQ);
            } else if (taskName == NTB) {
              rootPageButtons.insert(i, newImplementationButtonBenign);
            } else if (taskName == NTA) {
              rootPageButtons.insert(i, newImplementationButtonAttack);
            } else if (taskName == NTR) {
              rootPageButtons.insert(i, newImplementationButtonReality);
            } else if (taskName == NTPTQ) {
              rootPageButtons.insert(i, newTaskPTQ);
            } else if (taskName == DEMQ) {
              rootPageButtons.insert(i, demQButton);
            }
          }

          rootPageButtons.insert(0, giveConsentButton);

          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                "Wifi QR Tester",
                style: TextStyle(fontSize: Configuration.TEXT_SIZE),
              ),
              centerTitle: true,
              backgroundColor: Colors.grey[800],
              actions: [
                Visibility(
                  visible: !currentUserInfo.isAnonymous,
                  child: TextButton(
                      onPressed: () {
                        setState(() {
                          userModeForAdmin = !userModeForAdmin;
                        });
                      },
                      child: Text("UserMode: ${userModeForAdmin}",
                          style: TextStyle(
                              fontSize: Configuration.BUTTON_TEXT_SIZE))),
                ),
                TextButton.icon(
                  onPressed: () async {
                    setState(() {
                      surveyState = null;
                      taskMap = null;
                      consentPrompt = null;
                      newImpTaskStringBenign = null;
                      oldImpTaskStringBenign = null;
                      newImplHtmlPrompt = null;
                      oldImplHtmlPrompt = null;
                      questionHtmlPrompt = null;
                      showLoading = true;
                    });
                  },
                  icon: Icon(Icons.replay_outlined),
                  label: Text("Reload",
                      style:
                          TextStyle(fontSize: Configuration.BUTTON_TEXT_SIZE)),
                  style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all(Colors.red)),
                ),
                TextButton(
                  onPressed: () async {
                    await authService.signOut();
                  },
                  child: Text("Log Out",
                      style:
                          TextStyle(fontSize: Configuration.BUTTON_TEXT_SIZE)),
                  style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all(Colors.red)),
                )
              ],
            ),
            body: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    currentUserInfo.isAnonymous
                        ? Text(
                            "Logged In As: USER",
                            style: TextStyle(
                                fontSize: Configuration.TEXT_SIZE,
                                fontWeight: FontWeight.bold),
                          )
                        : Text(
                            "Logged In As: ADMIN",
                            style: TextStyle(
                                fontSize: Configuration.TEXT_SIZE,
                                fontWeight: FontWeight.bold),
                          ),
                    Container(
                      height: 60,
                    ),
                    currentUserInfo.isAnonymous
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SelectableText(
                              "AMT WorkerID: ${currentUserInfo.workerId}",
                              style: TextStyle(
                                  fontSize: Configuration.TEXT_SIZE,
                                  fontWeight: FontWeight.bold),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SelectableText(
                                "Email: ${currentUserInfo.email}",
                                style: TextStyle(
                                    fontSize: Configuration.TEXT_SIZE,
                                    fontWeight: FontWeight.bold)),
                          ),
                    Visibility(
                      visible: !currentUserInfo.isAnonymous,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SelectableText(
                            "AppUser ID: ${currentUserInfo.uid}",
                            style: TextStyle(
                                fontSize: Configuration.TEXT_SIZE,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Visibility(
                      visible: showAMTCode,
                      child: Container(
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SelectableText(
                                  "Please submit the following code to your mechanical turk portal as proof of survey completion.",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SelectableText(
                                  "MTurk Code (without the quotes):   '$AMTCode'",
                                  style: TextStyle(
                                      fontSize: Configuration.TEXT_SIZE,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 50,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: rootPageButtons,
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Future<void> _displaySummaryInformation(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Center(
                child: Text(
              'Current Summary',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: Configuration.TEXT_SIZE,
                  fontWeight: FontWeight.bold),
            )),
            content: Container(
                width: 600,
                height: 300,
                child: Center(
                    child: Column(
                  children: [
                    Text(
                      "RNG-1 Count: ${si.rngCounter.left}",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    ),
                    Text(
                      "RNG-2 Count: ${si.rngCounter.right}",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    ),
                    Text(
                      "Total MechTurk Code generated: ${si.totalAMTCodeGenerated}",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    ),
                    Text(
                      "Total ConventionalUI Responses: ${si.totalTask1ResponseCount}",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    ),
                    Text(
                      "Total QrCodeUI Responses: ${si.totalTask2ResponseCount}",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    ),
                    Text(
                      "Total QuestionnaireResponses: ${si.totalQuestionnaireResponseCount}",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    ),
                    Text(
                      "Total Logged WorkerIDs: ${si.totalWorkerCount}",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    ),
                  ],
                ))),
            actions: <Widget>[
              Container(
                height: Configuration.DIALOG_BUTTON_HEIGHT,
                child: TextButton(
                  style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.lightGreen)),
                  child: Text(
                    'OK',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.BUTTON_TEXT_SIZE),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              )
            ],
          );
        });
  }

  Future<void> displayConsentText(
      BuildContext context, String html, Function parentSetState) async {
    consentTextController.text = html;
    localConsentHtml = html;
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Center(
                  child: currentUserInfo.isAnonymous
                      ? (consentGiven
                          ? Text(
                              "You Consented To The Following",
                              style:
                                  TextStyle(fontSize: Configuration.TEXT_SIZE),
                            )
                          : Text('Give Consent To The Following',
                              style:
                                  TextStyle(fontSize: Configuration.TEXT_SIZE)))
                      : Text("Edit Consent Text",
                          style: TextStyle(fontSize: Configuration.TEXT_SIZE))),
              content: SingleChildScrollView(
                child: Container(
                  width: 900,
                  child: currentUserInfo.isAnonymous
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: HtmlWidget(localConsentHtml,
                              textStyle:
                                  TextStyle(decoration: TextDecoration.none),
                              buildAsync: false,
                              enableCaching: true,
                              renderMode: RenderMode.column,
                              isSelectable: true),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: HtmlWidget(
                                localConsentHtml,
                                textStyle:
                                    TextStyle(decoration: TextDecoration.none),
                                buildAsync: false,
                                isSelectable: true,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: consentTextController,
                                decoration: InputDecoration(
                                  hintText: "Add consent text here",
                                  border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Colors.green, width: 5.0),
                                      borderRadius: BorderRadius.circular(10)),
                                  labelText: "Consent Text HTML",
                                ),
                                minLines: 5,
                                maxLines: 10,
                                style: TextStyle(
                                    fontSize: Configuration.TEXT_SIZE),
                                readOnly: currentUserInfo.isAnonymous,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              actions: <Widget>[
                if (!consentGiven || !currentUserInfo.isAnonymous)
                  Container(
                    height: Configuration.DIALOG_BUTTON_HEIGHT,
                    child: TextButton(
                      style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Colors.lightGreen)),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: Configuration.BUTTON_TEXT_SIZE),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                Container(
                  height: Configuration.DIALOG_BUTTON_HEIGHT,
                  child: TextButton(
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.lightBlue)),
                    child: currentUserInfo.isAnonymous
                        ? (consentGiven
                            ? Text(
                                "Ok",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: Configuration.BUTTON_TEXT_SIZE),
                              )
                            : Text(
                                'Give consent',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: Configuration.BUTTON_TEXT_SIZE),
                              ))
                        : Text(
                            "Update",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: Configuration.BUTTON_TEXT_SIZE),
                          ),
                    onPressed: () async {
                      if (!currentUserInfo.isAnonymous) {
                        //update consent prompt in DB
                        consentPrompt = consentTextController.text;
                        await rtdbService.updatePromptsOrConsentText(
                            rtdbService.consentPromptRef,
                            consentTextController.text);
                      } else if (!consentGiven) {
                        await rtdbService.addOrGetConsentStateInDB(true);
                        parentSetState(() {
                          consentGiven = true;
                          surveyState =
                              null; // force to reload the survey states
                        });
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
                if (!currentUserInfo.isAnonymous)
                  Container(
                    height: Configuration.DIALOG_BUTTON_HEIGHT,
                    child: TextButton(
                      style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(
                              Colors.deepOrange[400])),
                      child: Text(
                        'Preview',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: Configuration.BUTTON_TEXT_SIZE),
                      ),
                      onPressed: () {
                        setState((() {
                          localConsentHtml = consentTextController.text;
                        }));
                      },
                    ),
                  ),
              ],
            );
          });
        });
  }

  Future<void> AddOrEditElements(BuildContext context, String what) async {
    if (what == "BLACKLIST") {
      editTextController.text = blackList;
    } else if (what == "RNGLIST") {
      editTextController.text = rng1List + "\n;\n" + rng2List;
    }
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Center(
                child: Text(
              'Add or update: ${what}',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: Configuration.TEXT_SIZE,
                  fontWeight: FontWeight.bold),
            )),
            content: Container(
                width: 800,
                height: 500,
                child: Center(
                    child: Column(
                  children: [
                    TextFormField(
                      controller: editTextController,
                      minLines: 25,
                      maxLines: 25,
                    )
                  ],
                ))),
            actions: <Widget>[
              Container(
                height: Configuration.DIALOG_BUTTON_HEIGHT,
                child: TextButton(
                  style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.lightGreen)),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.BUTTON_TEXT_SIZE),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              Container(
                height: Configuration.DIALOG_BUTTON_HEIGHT,
                child: TextButton(
                  style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.blueAccent)),
                  child: Text(
                    'Update',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.BUTTON_TEXT_SIZE),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    BuildContext dialogContext;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        dialogContext = context;
                        return Dialog(
                          child: Container(
                            height: 50,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SpinKitPouringHourGlassRefined(
                                    color: Colors.blue),
                                Text(
                                  "Saving...please wait",
                                  style: TextStyle(
                                      fontSize:
                                          Configuration.QUESTIONNAIRE_FONT_SIZE,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );

                    if (what == "BLACKLIST") {
                      await rtdbService
                          .updateBlackList(editTextController.text);
                      blackList = editTextController.text;
                      editTextController.clear();
                    } else if (what == "RNGLIST") {
                      await rtdbService.updateRNG(editTextController.text);
                      var splitted = editTextController.text
                          .split(rtdbService.listStringdelim);
                      rng1List = splitted[0].trim();
                      rng2List = splitted[1].trim();
                      editTextController.clear();
                    }

                    Navigator.pop(dialogContext);
                  },
                ),
              )
            ],
          );
        });
  }

  Future<void> reloadWorkerId() async {
    if ((currentUserInfo.workerId == null ||
            currentUserInfo.workerId.isEmpty) &&
        currentUserInfo.isAnonymous) {
      await rtdbService.getWorkerIdFromUid(currentUserInfo.uid);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String wid = prefs.getString(AMT_WORKER_ID);
      assert(wid == currentUserInfo.workerId);
      if (dbug) print("WID = ${wid}");
    }
  }

  Future<void> getTaskMap() async {
    taskMap = await rtdbService.getTaskMap();
    if (taskMap == null) {
      taskMap = new Map();

      if (dbug) print("TASK MAP IS NULL!!");
      Pair<int> randomInts = await rtdbService.getRandomInts();
      implementationList.shuffle();
      List<String> sListOld = allOldLists[randomInts.left % 6];
      if (implementationList[0] == "OLD_IMPLEMENTATION") {
        taskMap["Task-1"] = sListOld[0];
        taskMap["Task-2"] = sListOld[1];
        taskMap["Task-3"] = sListOld[2];
        taskMap["Task-4"] = OTPTQ;
      } else if (implementationList[1] == "OLD_IMPLEMENTATION") {
        taskMap["Task-5"] = sListOld[0];
        taskMap["Task-6"] = sListOld[1];
        taskMap["Task-7"] = sListOld[2];
        taskMap["Task-8"] = OTPTQ;
      }

      List<String> sListNew = allNewLists[randomInts.left % 6];

      if (implementationList[0] == "NEW_IMPLEMENTATION") {
        taskMap["Task-1"] = sListNew[0];
        taskMap["Task-2"] = sListNew[1];
        taskMap["Task-3"] = sListNew[2];
        taskMap["Task-4"] = NTPTQ;
      } else if (implementationList[1] == "NEW_IMPLEMENTATION") {
        taskMap["Task-5"] = sListNew[0];
        taskMap["Task-6"] = sListNew[1];
        taskMap["Task-7"] = sListNew[2];
        taskMap["Task-8"] = NTPTQ;
      }
      taskMap["Task-9"] = DEMQ;

      taskMap["TofuMode"] = (randomInts.left % 2 == 0) ? "True" : "False";

      await rtdbService.addTaskMap(taskMap);
    }
  }

  Future<void>
      readAndSetSurveyStateAndUpdateWorkerIDAndUpdateTaskMapAndSetupInstructionMapAndGetConsentFromDB() async {
    if (currentUserInfo == null) print("RootPage: This is an impossible case");
    //get consent in db first
    consentGiven = await rtdbService.addOrGetConsentStateInDB(consentGiven);

    // 2. get the latest survey state from db
    String currentSurveyStateInDB = await rtdbService.getLatestSurveyState();
    if (dbug) print("CURRENT SURVEY STATE IN DB: ${currentSurveyStateInDB}");

    // 2.1 if surveyState in DB is null, this is the first time this user logged in, so add state in db accordingly
    if (currentSurveyStateInDB == null)
      currentSurveyStateInDB =
          await rtdbService.addSurveyStateInDB(null, null); // addition

    // 3. update surveyState for the UI
    surveyState = currentSurveyStateInDB;

    // 3.1 Get the taskMap from database if not admin

    if (taskMap == null) {
      blackList = await rtdbService
          .getBlackList(); // blacklist is a must for both cases
      if (surveyState == AMT_SURVEY_STATE_ADMIN_MODE) {
        rng1List = await rtdbService.getRNG1();
        rng2List = await rtdbService.getRNG2();
        si.rngCounter = await rtdbService.countRandomInts();
        si.totalWorkerCount = await rtdbService.getTotalUserCount();
        si.totalAMTCodeGenerated = await rtdbService.getTotalAMTCodeCount();
        si.totalTask1ResponseCount =
            await rtdbService.getTotalTask1ResponseCount();
        si.totalTask2ResponseCount =
            await rtdbService.getTotalTask2ResponseCount();
        si.totalQuestionnaireResponseCount =
            await rtdbService.getTotalQuestionnaireResponseCount();
        taskMap = ADMIN_TASK_MAP;
      } else {
        if (blackList
            .toUpperCase()
            .contains(currentUserInfo.workerId.toUpperCase())) {
          authService.signOut();
          Navigator.pushNamedAndRemoveUntil(
            context,
            "/thankyou",
            (Route<dynamic> route) => false,
          );
          return;
        } else {
          await getTaskMap();
        }
      }
    }

    // 3.2 Get or setup instructionMap in database
    if (dbug) print("POPULATING INSTRUCTIONS.....");
    await rtdbService.getInstructions(taskMap["TofuMode"] == "True");
    if (dbug) print("POPULATING INSTRUCTIONS.....FINISHED");

    if (dbug) print("LOADING HTML PROMPTS.....");
    await rtdbService.loadPromptsAndConsent();
    if (dbug) print("LOADING HTML PROMPTS.....FINISHED");

    // 4. if survey state is AMT_SURVEY_STATE_TASK3_FINISHED, generate and show the MTurk Code
    if (surveyState == AMT_SURVEY_STATE_TASK9_FINISHED) {
      AMTCode = await rtdbService.createOrGetAMTCode();
      showAMTCode = true;
    } else {
      AMTCode = "No Code Generated";
    }

    setState(() {
      showLoading = false;
    }); // update the UI based on the surveyState
  }

  String getTaskStateFromTaskIdentifier(String taskId) {
    if (taskId == "Task-1") return AMT_SURVEY_STATE_TASK1_FINISHED;
    if (taskId == "Task-2") return AMT_SURVEY_STATE_TASK2_FINISHED;
    if (taskId == "Task-3") return AMT_SURVEY_STATE_TASK3_FINISHED;
    if (taskId == "Task-4") return AMT_SURVEY_STATE_TASK4_FINISHED;
    if (taskId == "Task-5") return AMT_SURVEY_STATE_TASK5_FINISHED;
    if (taskId == "Task-6") return AMT_SURVEY_STATE_TASK6_FINISHED;
    if (taskId == "Task-7") return AMT_SURVEY_STATE_TASK7_FINISHED;
    if (taskId == "Task-8") return AMT_SURVEY_STATE_TASK8_FINISHED;
    if (taskId == "Task-9") return AMT_SURVEY_STATE_TASK9_FINISHED;

    return AMT_SURVEY_STATE_NO_TASK_FINISHED;
  }

  bool activateButton(String taskNumber, String surveyState) {
    if (newDbug) print("DBUG: ${taskNumber}, ${surveyState}, ${consentGiven}");

    if (surveyState == AMT_SURVEY_STATE_ADMIN_MODE)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_NO_TASK_FINISHED &&
        taskNumber == "Task-1" &&
        consentGiven)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_TASK1_FINISHED &&
        taskNumber == "Task-2" &&
        consentGiven)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_TASK2_FINISHED &&
        taskNumber == "Task-3" &&
        consentGiven)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_TASK3_FINISHED &&
        taskNumber == "Task-4" &&
        consentGiven)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_TASK4_FINISHED &&
        taskNumber == "Task-5" &&
        consentGiven)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_TASK5_FINISHED &&
        taskNumber == "Task-6" &&
        consentGiven)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_TASK6_FINISHED &&
        taskNumber == "Task-7" &&
        consentGiven)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_TASK7_FINISHED &&
        taskNumber == "Task-8" &&
        consentGiven)
      return true;
    else if (surveyState == AMT_SURVEY_STATE_TASK8_FINISHED &&
        taskNumber == "Task-9" &&
        consentGiven) return true;

    return false;
  }
}

// FixedData.wifiList.forEach((element) {
//   if (SecurityType.EAPLIST.contains(element.security.securityType) &&
//       !element.twin &&
//       element.security.enterpriseCACertificate != null) {
//     if (element.qrCodePath != null && element.wifiSSID != null) {
//       FixedData.qrCodeWifiSSID[element.qrCodePath] = element.wifiSSID;
//       FixedData.qrCodeValues[element.qrCodePath] =
//           element.security.enterpriseCACertificate;
//       if (!FixedData.domainNames
//           .contains(element.security.enterpriseDomainName))
//         FixedData.domainNames.add(element.security.enterpriseDomainName);
//     } else
//       Toast.show("ERROR IN WIFILIST DATA! PLEASE CHECK!", context,
//           textColor: Colors.white,
//           backgroundColor: Colors.red,
//           duration: 10);
//   }
// });



// SizedBox(
//         width: 300,
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: ElevatedButton(
//             onPressed: () {
//               Navigator.pushNamed(context, '/installcacertificate',
//                   arguments: {});
//             },
//             child: Text(
//               "Install CA Certificates",
//               style: TextStyle(
//                   color: Colors.white, fontSize: 15.0, letterSpacing: 1.5),
//             ),
//             style: ButtonStyle(
//                 backgroundColor: MaterialStateProperty.all(Colors.grey[800]),
//                 foregroundColor: MaterialStateProperty.all(Colors.grey[500]),
//                 elevation: MaterialStateProperty.all(0.0)),
//           ),
//         ),
//       ),