import 'dart:async';
import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:bubble_tab_indicator/bubble_tab_indicator.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:wifi_qr_survey_app/LoadingPage.dart';
import 'package:wifi_qr_survey_app/QrCodeWidget.dart';
import 'package:wifi_qr_survey_app/models/FixedData.dart';
import 'package:wifi_qr_survey_app/models/QuestionnaireRelatedClasses.dart';
import 'package:wifi_qr_survey_app/models/SecurityModel.dart';
import 'package:wifi_qr_survey_app/models/WifiModel.dart';
import 'package:wifi_qr_survey_app/MainApp.dart';

import 'Configuration.dart';

/*
* Main WifiList Class for showing the available wifi-networks
* */

class WifiNetworkList extends StatefulWidget {
  const WifiNetworkList({
    Key key,
  }) : super(key: key);

  @override
  _WifiNetworkListState createState() => _WifiNetworkListState();
}

class _WifiNetworkListState extends State<WifiNetworkList>
    with
        AutomaticKeepAliveClientMixin<WifiNetworkList>,
        TickerProviderStateMixin {
  // to keep track of the connection state of the page
  bool hasConnection = false; // currently connected to any wifi-network?
  bool showAvailableWifiNetworks =
      true; // show currently available wifi-networks at the beginning?
  bool newImplementation = false; // is this list part of the newImplementation?
  bool tofuAvailable = false; // is this going to be a tofu?
  String
      actualTaskIdentifier; //["oldImplBen", "oldImplAtk", "oldImplRel", "newImplBen", "newImplAtk", "newImplRel","oldImplPTQ", "newImplPTQ","demQ"]
  bool checkedValue = false; // show wifi passwords?

  String taskState;
  String designatedWiFiAP;
  String designatedPassword;
  String designatedUsername;
  String certificateVerificationFailedPage = "1";
  int connectButtonClickCountForEnterpriseWifi;
  final int minTryThreshold = 3;

  // list of wifi-networks to be tested in the implementation
  List<WifiEntry> wifiList;

  Map<String, String> qrCodeValues = FixedData.qrCodeValues;
  Map<String, String> qrCodeWifiSSID = FixedData.qrCodeWifiSSID;

  Map<String, bool> isSavedNetwork;
  Map<String, bool> isInstalledCertificate;
  Stopwatch certInstallTimer;

  Timer t1, t2, t3;

  SharedPreferences prefs;
  bool showLoading = false;
  TabController tabController;

  static final double enabledOpacity = 0.99;
  static final double disabledOpacity = 0.2;
  bool qrCodeSectionEnabled = false;
  bool wifiSectionEnabled = false;
  double qrCodeSectionOpacity;
  double wifiSectionOpacity;

  SecurityInputInformation currentSII;
  WifiEntry currentWifiEntry;
  int currentIndex;

  String taskId;

  List<String> qrCodePathList;

  List<UserInteractionsRecord> interactionRecords;
  UserInteractionsRecord currentRecord;

  List<UserInteractionTimers> interactionTimers;
  UserInteractionTimers currentTimer;

  String failReason;

  bool isConnecting = false;
  bool atLeastOnceConnectedToWpa2Enterprise = false;
  bool qrCodeFirstMode = false;
  String qrCodeFirstModeQrCodeString;
  bool showInformationPage = true;
  bool showWifiUIPage = false;
  bool showSetupGuide = false;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  double pdfViewerZoomLevel;
  final TextEditingController editHtmlController = TextEditingController(
      text: "<center><h1 style='color:red'>Add HTML </h1></center>");

  List<String> eapMethodList = ["PEAP", "TTLS", "TLS"];

  Map<String, List<String>> phase2MethodMap = {
    "PEAP": ["MSCHAPV2", "GTC"],
    "TTLS": ["PAP", "MSCHAPV2", "MSCHAP", "GTC"],
    "TLS": ["MSCHAPV2", "GTC", "SIM", "AKA"]
  };
  final GlobalTimers globalTimers = GlobalTimers();
  int successCount = 0;
  int failureCount = 0;
  String selectedEapMethod = "PEAP";
  List<String> phase2MethodList = [
    "MSCHAPV2",
    "GTC"
  ]; // just a placeholder, dynamically updated from pahse2MethodMap
  String selectedPhase2Method = "MSCHAPV2";
  List<String> caCertificateList = [PLS_SLT_STR, USE_SYS_CRT, DNT_VALIDAT];

  List<String> userCertificateList = [PLS_SLT_STR, DNT_PROVIDE];

  List<String> folderNames = [
    "Alarms",
    "Android",
    "DCIM",
    "Documents",
    "Download",
    "Movies",
    "Music",
    "Notifications",
    "Pictures",
    "Podcasts",
    "Ringtones"
  ];
  bool topDocTree = true;
  String selectedFolder;
  List<WifiEntry> enterpriseWifiList;
  TextEditingController certNameController = TextEditingController();
  String certInstallDropDownValue = FixedData.certModeVpn;
  Map<String, String> certNameToCertDomainNameMap;
  static final useWifiToolTipKey = GlobalKey();
  static final userManualToolTipKey = GlobalKey();
  final useWifiTab = Tooltip(
    message: "To Use Wifi Click Here!",
    triggerMode: TooltipTriggerMode.manual,
    key: useWifiToolTipKey,
    padding: EdgeInsets.all(10),
    showDuration: Duration(hours: 3),
    decoration: ShapeDecoration(
      color: Colors.purple[300],
      shape: TooltipShapeBorder(arrowArc: 0.05),
      shadows: [
        BoxShadow(color: Colors.black26, blurRadius: 4.0, offset: Offset(2, 2))
      ],
    ),
    textStyle:
        TextStyle(fontSize: Configuration.TOOLTIP_SIZE, color: Colors.white),
    height: 10.0,
    verticalOffset: 40.0,
    child: Tab(
      child: Text(
        "Use Wifi",
        style: TextStyle(fontSize: Configuration.BUTTON_TEXT_SIZE - 7),
      ),
      icon: Icon(Icons.wifi),
    ),
  );

  final userManualTab = Tooltip(
    message: "To Read Setup Guide Click Here!",
    triggerMode: TooltipTriggerMode.manual,
    key: userManualToolTipKey,
    padding: EdgeInsets.all(10),
    showDuration: Duration(hours: 3),
    decoration: ShapeDecoration(
      color: Colors.purple[300],
      shape: TooltipShapeBorder(arrowArc: 0.05),
      shadows: [
        BoxShadow(color: Colors.black26, blurRadius: 4.0, offset: Offset(2, 2))
      ],
    ),
    textStyle:
        TextStyle(fontSize: Configuration.TOOLTIP_SIZE, color: Colors.white),
    height: 10.0,
    verticalOffset: 40.0,
    child: Tab(
      child: Text(
        "Show Setup Guide",
        style: TextStyle(fontSize: Configuration.BUTTON_TEXT_SIZE - 7),
      ),
      icon: Icon(Icons.notes),
    ),
  );

  Future<void> showCertInstallDialog(int index) async {
    certInstallDropDownValue = FixedData.certModeVpn;
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Name the certificate',
            style: TextStyle(fontSize: Configuration.TEXT_SIZE),
          ),
          content: StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Certificate name:',
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE - 2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: certNameController,
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE - 2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Credential use:",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE - 2.0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        items: <String>[
                          FixedData.certModeVpn,
                          FixedData.certModeWifi
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                  fontSize: Configuration.TEXT_SIZE - 3.0),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            certInstallDropDownValue = v;
                          });
                        },
                        value: certInstallDropDownValue,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Note: The issuer of this certificate may inspect all traffic to and from the device.",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: Configuration.TEXT_SIZE - 7.0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "The package contains:",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: Configuration.TEXT_SIZE - 7.0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "one CA certificate",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: Configuration.TEXT_SIZE - 7.0),
                    ),
                  )
                ],
              ),
            );
          }),
          actions: <Widget>[
            Container(
              height: Configuration.DIALOG_BUTTON_HEIGHT,
              child: TextButton(
                child: const Text(
                  'CANCEL',
                  style: TextStyle(fontSize: Configuration.BUTTON_TEXT_SIZE),
                ),
                onPressed: () {
                  certInstallTimer.stop();
                  Navigator.of(context).pop();
                  certNameController.clear();
                },
              ),
            ),
            Container(
              height: Configuration.DIALOG_BUTTON_HEIGHT,
              child: TextButton(
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: Configuration.BUTTON_TEXT_SIZE),
                ),
                onPressed: () async {
                  certInstallTimer.stop();
                  Navigator.of(context).pop();
                  // only save the correct form of cert installation
                  if (certNameController.text.isEmpty) {
                    BotToast.showText(
                        text: "Certificate name cannot be empty!",
                        contentColor: Colors.redAccent[400],
                        textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: Configuration.TOAST_SIZE),
                        duration: Duration(seconds: 3));
                  } else if (certInstallDropDownValue ==
                      FixedData.certModeWifi) {
                    await prefs.setString(
                        actualTaskIdentifier +
                            "_" +
                            FixedData.domainNames[index],
                        FixedData.certStateInstalled);
                    prefs.setString(
                        actualTaskIdentifier +
                            "_" +
                            FixedData.domainNames[index] +
                            "_NAME",
                        certNameController.text);
                    prefs.setString(
                        actualTaskIdentifier +
                            "_" +
                            FixedData.domainNames[index] +
                            "_MODE",
                        certInstallDropDownValue);
                    populateInstallationMap();
                  }
                  certNameController.clear();
                  BotToast.showText(
                      text:
                          "Certificate Installed for $certInstallDropDownValue",
                      contentColor: Colors.blueAccent[400],
                      textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: Configuration.TOAST_SIZE));
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void setupGlobalTimersAndCount() {
    globalTimers.taskLevelTimer.reset();
    globalTimers.setupGuideTimer.reset();
    globalTimers.wifiUITimer.reset();
    globalTimers.instructionPageTimer.reset();
    if (dbug) {
      print("All global timers reset");
      globalTimers.printAll();
    }

    globalTimers.taskLevelTimer.start();
    updateGlobalTimersStates();

    successCount = failureCount = 0;
  }

  void updateGlobalTimersStates() {
    if (showInformationPage) {
      globalTimers.instructionPageTimer.start();
    } else {
      globalTimers.instructionPageTimer.stop();
    }

    if (showWifiUIPage) {
      // WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      //   showCredentialsOverlay();
      // });
      globalTimers.wifiUITimer.start();
    } else {
      globalTimers.wifiUITimer.stop();
      // WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      //   // hideCredentialsOverlay();
      // });
    }

    if (showSetupGuide) {
      globalTimers.setupGuideTimer.start();
    } else {
      globalTimers.setupGuideTimer.stop();
    }

    if (dbug) globalTimers.printAll();
  }

  WifiEntry goodSSID = WifiEntry(
      wifiSSID: "UE-Secure",
      security: SecurityEntry(
          securityType: SecurityType.EAP2,
          enterpriseCACertificate:
              "382644ED105257F63A8DBEC51AA02DF46A2937A4E73DB2155A183F4096D1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0FF0F068F099795C3B9", //syne.cs.syr.edu-CA-Certificate
          usedSystemCertificate: "dot1x.ue.edu;ue.edu;edu",
          enterpriseDomainName: "dot1x.ue.edu;ue.edu;edu",
          enterpriseUserDatabase: {
            // "s31415@ue.edu": "passwordforwifi",
            "username@ue.edu": "passwordforwifi",
            if (kDebugMode) "A": "A"
            // "user3": "secretpassword3456"
          },
          certIssuerName: "USERTrust RSA Certification Authority",
          certServerName: "USERTrust RSA Certification Authority",
          certOrganization: "The USERTRUST Network",
          certSignature: "b493c0dd035f0429"),
      signalStrength: 2,
      qrCodePath: "qr-codes/seqr-01/1.png",
      twin: false);

  WifiEntry twinSSID = WifiEntry(
      wifiSSID: "UE-Secure",
      security: SecurityEntry(
          securityType: SecurityType.EAP2,
          enterpriseCACertificate:
              "382644ED105257F63A8DBECCCBB0FGFHGA2937A4E73DB2155A183FasdfgD1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0FF0F068F099795C3B9", //syne.cs.syr.edu-CA-Certificate
          usedSystemCertificate: "sot1x.ue.edu;se.eddu;sdu",
          enterpriseDomainName: "sot1x.ue.edu;de.edu;fdu",
          enterpriseUserDatabase: {
            // "s31415@ue.edu": "passwordforwifi",
            "username@ue.edu": "passwordforwifi",
            if (kDebugMode) "A": "A"
            // "user3": "secretpassword3456"
          },
          certIssuerName: "USERTrust RSA Certification Authority",
          certServerName: "USERTrust RSA Certification Authority",
          certOrganization: "The USERTRUST Network",
          certSignature: "c537475efdb22adc"),
      signalStrength: 2,
      qrCodePath: "qr-codes/seqr-01/1.png",
      twin: true);

  @override
  void initState() {
    super.initState();
    if (dbug) print("INIT STATE CALLED");
  }

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    Map args = ModalRoute.of(context).settings.arguments;
    actualTaskIdentifier = args["ACTUAL_TASK_ID"];
    wifiList = List.from(FixedData.wifiList);
    setupGlobalTimersAndCount();
    connectButtonClickCountForEnterpriseWifi = 0; // reset counter here
    tabController = new TabController(length: 2, vsync: this);
    tabController.addListener(() {
      if (tabController.index == 0) {
        if (dbug) print("TAB CONTROLLER INDEX 0");
        showWifiUIPage = true;
        showInformationPage = false;
        showSetupGuide = false;
        updateGlobalTimersStates();
      } else {
        if (dbug) print("TAB CONTROLLER INDEX 1");
        showWifiUIPage = false;
        showInformationPage = false;
        showSetupGuide = true;
        updateGlobalTimersStates();
      }
      setState(() {
        showAppropriateToolTip();
      });
    });

    currentSII = null;
    currentWifiEntry = null;
    currentIndex = -1;

    qrCodeSectionEnabled = false;
    wifiSectionEnabled = true;
    qrCodeSectionOpacity = disabledOpacity;
    wifiSectionOpacity = enabledOpacity;

    isSavedNetwork = new Map();
    isInstalledCertificate = new Map();
    certNameToCertDomainNameMap = new Map();

    if (actualTaskIdentifier == NTA || actualTaskIdentifier == OTA) {
      wifiList.add(twinSSID);
    } else if (actualTaskIdentifier == NTB || actualTaskIdentifier == OTB) {
      wifiList.add(goodSSID);
    } else if (actualTaskIdentifier == NTR || actualTaskIdentifier == OTR) {
      wifiList.add(goodSSID);
      wifiList.add(twinSSID);
    }

    wifiList.sort((a, b) => a.wifiSSID.compareTo(b.wifiSSID));
    wifiList.shuffle();
    wifiList.map((e) {
      isSavedNetwork[e.wifiSSID] = false;
    });

    populateInstallationMap();

    interactionRecords = [];
    interactionTimers =
        new List.filled(wifiList.length + 1, new UserInteractionTimers());
    currentTimer = null;
    currentRecord = null;

    // clear Wifi States
    for (int i = 0; i < wifiList.length; i++) {
      disconnectConnection(i);
      forgetConnection(i);
    }

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    cancelAllConnectionAnimationTimer();
    tabController.dispose();
    editHtmlController.dispose();
    certNameController.dispose();
    globalTimers.wifiUITimer.stop();
    globalTimers.taskLevelTimer.stop();
    globalTimers.setupGuideTimer.stop();
    globalTimers.instructionPageTimer.stop();
    // hideCredentialsOverlay();

    if (dbug) {
      print("DISPOSE CALLED");
      print("FailureCount = $failureCount");
      print("SuccessCount = $successCount");
      globalTimers.printAll();
    }

    super.dispose();
  }

  showLoaderDialog(BuildContext context) {
    AlertDialog alert = AlertDialog(
      content: Container(
        height: 50,
        child: new Row(
          children: [
            SpinKitPouringHourGlassRefined(color: Colors.blue),
            Text(
              "Saving...please wait",
              style: TextStyle(
                  fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return alert;
        });
  }

  void populateInstallationMap() async {
    prefs = await SharedPreferences.getInstance();
    caCertificateList = [PLS_SLT_STR, USE_SYS_CRT, DNT_VALIDAT];
    for (int i = 0; i < FixedData.domainNames.length; i++) {
      String certState = prefs.getString(
              actualTaskIdentifier + "_" + FixedData.domainNames[i]) ??
          FixedData.certStateNotDownloaded;
      String certMode = prefs.getString(actualTaskIdentifier +
              "_" +
              FixedData.domainNames[i] +
              "_MODE") ??
          "N/A";
      isInstalledCertificate[FixedData.domainNames[i]] =
          (certState == FixedData.certStateInstalled &&
              certMode == FixedData.certModeWifi);
      String certSaveName = prefs.getString(actualTaskIdentifier +
              "_" +
              FixedData.domainNames[i] +
              "_NAME") ??
          "EMPTY_NAME"; // empty name shouldn't be possible for installed certificates
      if (isInstalledCertificate[FixedData.domainNames[i]]) {
        caCertificateList.add(certSaveName);
        certNameToCertDomainNameMap[certSaveName] = FixedData.domainNames[i];
      }
    }
    setState(() {});
    if (dbug)
      print("CURRENT POPULATION MAP: ${isInstalledCertificate.toString()}");
  }

  Future<void> initQrCodeList(String path) async {
    // >> To get paths you need these 2 lines
    final manifestContent = await rootBundle.loadString('AssetManifest.json');

    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    // >> To get paths you need these 2 lines

    qrCodePathList =
        manifestMap.keys.where((String key) => key.contains(path)).toList();
    if (dbug) {
      print(path);
      print(qrCodePathList);
    }
    setState(() {});
  }

  // Main body of the list is being built inside this function
  @override
  Widget build(BuildContext context) {
    super.build(context);
    Map data =
        ModalRoute.of(context).settings.arguments; // data passing between pages
    if (data == null) {
      newImplementation = prefs?.get("NEW_IMPLEMENTATION") ?? false;
      taskId = prefs?.get("TASK_IDENTIFIER") ?? "";
      tofuAvailable = prefs?.get("TOFU_AVAILABLE") ?? false;
      actualTaskIdentifier = prefs?.get("ACTUAL_TASK_ID") ?? null;
      taskState = prefs?.get('TASK_STATE');
    } else {
      newImplementation = data["NEW_IMPLEMENTATION"];
      taskId = data["TASK_IDENTIFIER"];
      tofuAvailable = data['TOFU_AVAILABLE'];
      actualTaskIdentifier = data["ACTUAL_TASK_ID"];
      taskState = data['TASK_STATE'];

      prefs?.setString("ACTUAL_TASK_ID", actualTaskIdentifier);
      prefs?.setString('TASK_STATE', taskState);
      prefs?.setBool("NEW_IMPLEMENTATION", newImplementation);
      prefs?.setString("TASK_IDENTIFIER", taskId);
      prefs?.setBool("TOFU_AVAILABLE", tofuAvailable);
    }

    if (newDbug) print("ACTUAL TASK ID => ${actualTaskIdentifier}");

    if (tofuAvailable &
        !caCertificateList.contains(TOFU_STRING) &
        caCertificateList.contains(DNT_VALIDAT)) {
      caCertificateList.remove(DNT_VALIDAT);
      caCertificateList.add(TOFU_STRING);
    }

    designatedWiFiAP = "UE-Secure";
    designatedPassword = "passwordforwifi";
    designatedUsername = "username@ue.edu";

    if (newImplementation == null)
      newImplementation = prefs?.get("NEW_IMPLEMENTATION") ?? false;
    if (taskId == null) taskId = prefs?.get("TASK_IDENTIFIER") ?? "";

    if (dbug) {
      print("NEW IMPLEMENTATION: $newImplementation");
      print("TASK ID => ${taskId}");
    }
    showAppropriateToolTip();
    return StreamBuilder<Object>(
        stream: authService.auth.authStateChanges(),
        builder: (context, snapshot) {
          if (dbug) {
            print("Inside WifiNetworkListPage.dart");
            print("snapshot.connectionState = ${snapshot.connectionState}");
            print("snapshot.hasData = ${snapshot.hasData}");
          }

          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting)
            return LoadingPage();

          if (!snapshot.hasData) {
            // redirect to SignInPage => user is not signed in
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              Navigator.pushNamedAndRemoveUntil(
                  context, "/", (Route<dynamic> route) => false);
            });
            if (dbug) print("Redirecting to / from WifiNetworkListPage.dart");
            return LoadingPage();
          }

          if (dbug) print(oldAndNewInstructionsPath.right);

          String tmp1 = oldAndNewInstructionsPath.right.split("%2F")[1];
          String tmp2 = tmp1.substring(0, tmp1.indexOf("."));

          FixedData.qrCodeValues
              .removeWhere((key, value) => !key.contains(tmp2));
          FixedData.qrCodeWifiSSID
              .removeWhere((key, value) => !key.contains(tmp2));

          User u = snapshot.data;
          currentUserInfo.setUserInfo(u);

          double width = MediaQuery.of(context).size.width;
          double height = MediaQuery.of(context).size.height;
          double cWidth = 0.45 * width;
          double lWidth = width - cWidth - 16;
          double dWidth = 1;

          enterpriseWifiList = wifiList
              .where((element) =>
                  element.security.securityType == SecurityType.EAP2)
              .toList();
          if (newImplHtmlPrompt == null || oldImplHtmlPrompt == null) {
            rtdbService.loadPromptsAndConsent(setState);
            return LoadingPage();
          }
          if (showInformationPage) {
            return Scaffold(
              appBar: AppBar(
                  title: Text(
                    "Information Regarding This Task",
                    style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                  ),
                  centerTitle: true,
                  backgroundColor: Colors.grey[800],
                  actions: [
                    TextButton.icon(
                      icon: const Icon(
                        Icons.replay_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        "Reload Page",
                        style: TextStyle(
                            fontSize: Configuration.BUTTON_TEXT_SIZE,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          newImplHtmlPrompt = null;
                          oldImplHtmlPrompt = null;
                          showInformationPage = true;
                          showSetupGuide = false;
                          showWifiUIPage = false;
                          setupGlobalTimersAndCount();
                        });
                      },
                    )
                  ]),
              body: SingleChildScrollView(
                child: Center(
                    child: Container(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HtmlWidget(
                          newImplementation
                              ? "$newImplHtmlPrompt"
                              : "$oldImplHtmlPrompt",
                          isSelectable: true,
                          textStyle: TextStyle(decoration: TextDecoration.none),
                        ),
                        Divider(
                          height: 100,
                          thickness: 5,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            height: Configuration.DIALOG_BUTTON_HEIGHT,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  showInformationPage = false;
                                  if (tabController?.index == 0) {
                                    showWifiUIPage = true;
                                    showInformationPage = false;
                                    showSetupGuide = false;
                                    updateGlobalTimersStates();
                                  } else {
                                    showWifiUIPage = false;
                                    showInformationPage = false;
                                    showSetupGuide = true;
                                    updateGlobalTimersStates();
                                  }
                                });
                              },
                              child: Text(
                                "START",
                                style: TextStyle(
                                    fontSize: Configuration.BUTTON_TEXT_SIZE),
                              ),
                              style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.all(
                                      Colors.blue[400])),
                            ),
                          ),
                        ),
                      ]),
                )),
              ),
              floatingActionButton: Visibility(
                visible: !currentUserInfo.isAnonymous,
                child: FloatingActionButton(
                  onPressed: () {
                    _displayEditHtml(
                        context,
                        newImplementation
                            ? newImplHtmlPrompt
                            : oldImplHtmlPrompt);
                  },
                  child: Icon(Icons.edit),
                  tooltip: "Edit Prompt",
                ),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
            );
          }

          return Scaffold(
            floatingActionButton: Visibility(
              child: FloatingActionButton.extended(
                heroTag: 'SUBMIT-BUTTON',
                onPressed: submitLogic()
                    ? () async {
                        if (certInstallTimer != null) certInstallTimer.stop();

                        // print("SuccessCount => ${successCount}, FailureCount => ${failureCount}");

                        bool reallySubmit = true;

                        if (!currentUserInfo.isAnonymous) {
                          // admin mode
                          showLoaderDialog(context);
                          await saveResponse();
                          Navigator.of(context).pop();
                          Navigator.pushNamedAndRemoveUntil(
                              context, "/", (Route<dynamic> route) => false);

                          return;
                        } else if (successCount == 0 && failureCount == 0) {
                          /*BotToast.showText(
                              text:
                                  "You need to try to connect to the designated Wi-Fi access point before you can submit!",
                              contentColor: Colors.redAccent[400],
                              textStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: Configuration.TOAST_SIZE),
                              duration: Duration(seconds: 4));
                          */
                          reallySubmit =
                              await showNoInteractionSubmitDialog(context);
                        }
                        /*else if (!atLeastOnceConnectedToWpa2Enterprise &&
                            connectButtonClickCountForEnterpriseWifi >=
                                minTryThreshold) {
                          await _displayIncompleteSubmissionText(context);
                        } */

                        if (reallySubmit) {
                          bool finalSubmit = false;
                          finalSubmit = await showSubmitNowDialog(context);
                          if (finalSubmit) {
                            showLoaderDialog(context);
                            await saveResponse();
                            Navigator.of(context).pop();
                            Navigator.pushNamedAndRemoveUntil(
                                context, "/", (Route<dynamic> route) => false);
                            return;
                          }
                        }
                      }
                    : null,
                label: const Text(
                  "Submit Task",
                  style: TextStyle(fontSize: Configuration.BUTTON_TEXT_SIZE),
                ),
                backgroundColor:
                    submitLogic() ? Colors.blueAccent : Colors.grey[500],
                icon: const Icon(Icons.upload),
              ),
              visible: tabController.index == 0,
            ),
            bottomNavigationBar: TabBar(
              controller: tabController,
              tabs: [
                Container(height: 57, child: useWifiTab),
                Container(height: 57, child: userManualTab)
              ],
              unselectedLabelColor: Colors.grey[600],
              labelColor: Colors.white,
              unselectedLabelStyle:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              labelStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic),
              indicatorWeight: 2,
              indicatorColor: Colors.blue[100],
              indicator: BubbleTabIndicator(
                indicatorHeight: 57,
                indicatorRadius: 100,
                indicatorColor: Colors.blue,
                // tabBarIndicatorSize: TabBarIndicatorSize.tab,
                // padding: EdgeInsets.all(10)
              ),
            ),
            appBar: AppBar(
              title: tabController.index == 0
                  ? Text(
                      "Use Wi-Fi (${taskId})",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    )
                  : Text(
                      "Read Setup Guide",
                      style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                    ),
              centerTitle: true,
              backgroundColor: Colors.grey[800],
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  label: Text(
                    "Show Instructions",
                    style: TextStyle(
                        fontSize: Configuration.BUTTON_TEXT_SIZE,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    setState(() {
                      showInformationPage = true;
                      showWifiUIPage = false;
                      showSetupGuide = false;
                      updateGlobalTimersStates();
                    });
                  },
                ),
                TextButton.icon(
                  icon: const Icon(
                    Icons.replay_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    "Reload Page",
                    style: TextStyle(
                        fontSize: Configuration.BUTTON_TEXT_SIZE,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    setState(() {
                      newImplHtmlPrompt = null;
                      oldImplHtmlPrompt = null;
                    });
                  },
                )
              ],
            ),
            // (tabController.index == 0 && wifiSectionEnabled)
            //     ? [
            //         Padding(
            //           padding: EdgeInsets.fromLTRB(0, 0, 30, 0),
            //           child: Switch(
            //               value: showAvailableWifiNetworks,
            //               onChanged: (newval) {
            //                 setState(() {
            //                   showAvailableWifiNetworks = newval;
            //                 });
            //               }),
            //         ),
            //       ]
            //     : [],
            body: TabBarView(controller: tabController, children: [
              Row(
                children: [
                  // qrCodeListView
                  newImplementation
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              Card(
                                elevation: 5,
                                borderOnForeground: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(8.0),
                                  ),
                                ),
                                color: Color.fromARGB(255, 134, 7, 53),
                                shadowColor: Colors.purple[100],
                                child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Color.fromARGB(
                                                255, 255, 255, 255),
                                            width: 2)),
                                    height: 200,
                                    width: 400,
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "CREDENTIALS",
                                                style: TextStyle(
                                                    fontSize: 25,
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Your Username: ",
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.white),
                                              ),
                                              SelectableText(
                                                "username@ue.edu",
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.white),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Your Password: ",
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.white),
                                              ),
                                              SelectableText(
                                                "passwordforwifi",
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.white),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 5, left: 5),
                                            child: Text(
                                              "IMPORTANT NOTE: Please make sure you are typing the credentials correctly. You will not be rewarded if you type wrong credentials.",
                                              style: TextStyle(
                                                  color: Color.fromARGB(
                                                      255, 255, 255, 255),
                                                  fontSize: 15),
                                            ),
                                          )
                                        ]),
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: dWidth,
                              ),
                              ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                    Colors.black
                                        .withOpacity(qrCodeSectionOpacity),
                                    BlendMode.dstIn),
                                child: AbsorbPointer(
                                  absorbing: !qrCodeSectionEnabled,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 15.0),
                                    child: Container(
                                        width: cWidth,
                                        child: QrCodeWidgetList(
                                          qrCodeValues: qrCodeValues,
                                          qrCodeWifiSSID: qrCodeWifiSSID,
                                          notifyParent: scanResult,
                                        )),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          width: cWidth,
                          child: Padding(
                            padding: const EdgeInsets.all(30.0),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Card(
                                    child: Column(children: [
                                      Card(
                                        elevation: 5,
                                        borderOnForeground: true,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(8.0),
                                          ),
                                        ),
                                        color: Color.fromARGB(255, 134, 7, 53),
                                        shadowColor: Colors.purple[100],
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Color.fromARGB(
                                                        255, 255, 255, 255),
                                                    width: 2)),
                                            height: 200,
                                            width: 400,
                                            child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        "CREDENTIALS",
                                                        style: TextStyle(
                                                            fontSize: 25,
                                                            decoration:
                                                                TextDecoration
                                                                    .none,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        "Your Username: ",
                                                        style: TextStyle(
                                                            fontSize: 20,
                                                            decoration:
                                                                TextDecoration
                                                                    .none,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                      SelectableText(
                                                        "username@ue.edu",
                                                        style: TextStyle(
                                                            fontSize: 20,
                                                            decoration:
                                                                TextDecoration
                                                                    .none,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        "Your Password: ",
                                                        style: TextStyle(
                                                            fontSize: 20,
                                                            decoration:
                                                                TextDecoration
                                                                    .none,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                      SelectableText(
                                                        "passwordforwifi",
                                                        style: TextStyle(
                                                            fontSize: 20,
                                                            decoration:
                                                                TextDecoration
                                                                    .none,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                    ],
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 5, left: 5),
                                                    child: Text(
                                                      "IMPORTANT NOTE: Please make sure you are typing the credentials correctly. You will not be rewarded if you type wrong credentials.",
                                                      style: TextStyle(
                                                          color: Color.fromARGB(
                                                              255,
                                                              255,
                                                              255,
                                                              255),
                                                          fontSize: 15),
                                                    ),
                                                  )
                                                ]),
                                          ),
                                        ),
                                      ),
                                      Divider(
                                        thickness: dWidth,
                                      ),
                                      ListTile(
                                        title: Center(
                                            child: Text(
                                          selectedFolder == null
                                              ? 'Files'
                                              : selectedFolder,
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        )),
                                        leading: Visibility(
                                          child: TextButton.icon(
                                              onPressed: () {
                                                selectedFolder = null;
                                                topDocTree = true;
                                                setState(() {});
                                              },
                                              icon: Icon(Icons.arrow_back),
                                              label: Text("Go back")),
                                          visible: !topDocTree,
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                                Expanded(
                                  child: topDocTree
                                      ? ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            return Card(
                                              child: ListTile(
                                                  onTap: () {
                                                    selectedFolder =
                                                        folderNames[index];
                                                    topDocTree = false;
                                                    setState(() {});
                                                  },
                                                  title: Text(
                                                    folderNames[index],
                                                    style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  leading: Icon(Icons.folder)),
                                            );
                                          },
                                          itemCount: folderNames.length,
                                        )
                                      : (selectedFolder == "Download"
                                          ? ListView.builder(
                                              itemBuilder:
                                                  (BuildContext context,
                                                      int index) {
                                                return Card(
                                                  child: ListTile(
                                                      onTap: () {
                                                        if (!isInstalledCertificate[
                                                            FixedData
                                                                    .domainNames[
                                                                index]]) {
                                                          if ("CSE-SEC-A" ==
                                                              FixedData
                                                                      .domainNames[
                                                                  index])
                                                            certInstallTimer =
                                                                globalTimers
                                                                    .certInstallTimer_CSE_A;
                                                          else if ("CSE-SEC-B" ==
                                                              FixedData
                                                                      .domainNames[
                                                                  index])
                                                            certInstallTimer =
                                                                globalTimers
                                                                    .certInstallTimer_CSE_B;
                                                          else
                                                            certInstallTimer =
                                                                globalTimers
                                                                    .certInstallTimer_ue_secure;

                                                          // certInstallTimer.reset();
                                                          certInstallTimer
                                                              .start();
                                                          showCertInstallDialog(
                                                              index);
                                                        } else {
                                                          BotToast.showText(
                                                              text:
                                                                  "Certificate already installed for Wifi",
                                                              contentColor:
                                                                  Colors.redAccent[
                                                                      400],
                                                              textStyle: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      Configuration
                                                                          .TOAST_SIZE),
                                                              duration:
                                                                  Duration(
                                                                      seconds:
                                                                          4));
                                                        }
                                                      },
                                                      title: Text(
                                                        "${FixedData.domainNames[index]}.crt",
                                                        style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                      leading: Icon(
                                                          Icons.file_copy)),
                                                );
                                              },
                                              itemCount:
                                                  FixedData.domainNames.length,
                                            )
                                          : Container()),
                                ),
                              ],
                            ),
                          )),

                  Visibility(child: VerticalDivider(thickness: dWidth)),

                  // wifiListView
                  Stack(alignment: Alignment.center, children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(wifiSectionOpacity),
                          BlendMode.dstIn),
                      child: AbsorbPointer(
                        absorbing: !wifiSectionEnabled,
                        child: Container(
                          width: lWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30.0, vertical: 2.0),
                            child: showAvailableWifiNetworks
                                ? ListView.builder(
                                    primary: false,
                                    itemCount: wifiList.length + 1,
                                    itemBuilder:
                                        wifiItemBuilder // building the wifi-items listview here // TODO: maybe add some animation here later??
                                    )
                                : Center(
                                    child: Row(
                                      children: <Widget>[
                                        Icon(Icons.info_outline),
                                        SizedBox(
                                          width: 10,
                                        ),
                                        Text(
                                            "To see available networks, turn Wi-Fi on.") // This option is not available anymore, didn't remove because of lazy removing
                                      ],
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                      child: Center(
                        child: Container(
                          height: Configuration.DIALOG_BUTTON_HEIGHT,
                          child: ElevatedButton(
                            onPressed: () {
                              cancelCurrentScan();
                            },
                            child: Text(
                              "Cancel Scan",
                              style: TextStyle(
                                  fontSize: Configuration.BUTTON_TEXT_SIZE),
                            ),
                            style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all(Colors.red[300])),
                          ),
                        ),
                      ),
                      visible: !wifiSectionEnabled,
                    )
                  ]),
                ],
              ),

              //Show Instructions Page
              Center(
                child: Scaffold(
                  body: Container(
                      child: SfPdfViewer.network(
                    newImplementation
                        ? oldAndNewInstructionsPath.right
                        : oldAndNewInstructionsPath.left,
                    controller: _pdfViewerController,
                    initialZoomLevel: 2.0,
                  )),
                  floatingActionButton:
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: FloatingActionButton(
                        onPressed: () {
                          double currentZoomLevel =
                              _pdfViewerController.zoomLevel;
                          if (currentZoomLevel < 3.0)
                            _pdfViewerController.zoomLevel =
                                currentZoomLevel + 0.25;
                          pdfViewerZoomLevel = _pdfViewerController.zoomLevel;
                        },
                        tooltip: "Zoom In",
                        child: Icon(Icons.zoom_in),
                        heroTag: 'ZOOM-IN',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: FloatingActionButton(
                        onPressed: () {
                          double currentZoomLevel =
                              _pdfViewerController.zoomLevel;
                          if (currentZoomLevel > 1.0)
                            _pdfViewerController.zoomLevel =
                                currentZoomLevel - 0.25;
                          pdfViewerZoomLevel = _pdfViewerController.zoomLevel;
                        },
                        child: Icon(Icons.zoom_out),
                        tooltip: "Zoom Out",
                        heroTag: 'ZOOM-OUT',
                      ),
                    ),
                  ]),
                ),
              )
            ]),
          );
        });
  }

  // function for populating each item of the wifi listview
  Widget wifiItemBuilder(BuildContext context, int index) {
    if (index == wifiList.length) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 1.0, horizontal: 4.0),
        child: ListTile(
            onTap: () {
              if (!newImplementation) {
                BotToast.showText(
                    text: "Not Implemented!",
                    contentColor: Colors.redAccent[400],
                    textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.TOAST_SIZE),
                    duration: Duration(seconds: 4));
              } else {
                currentRecord = new UserInteractionsRecord();
                currentTimer = interactionTimers[wifiList.length];
                currentTimer.resetAll();
                currentTimer.totalTimeTimer.start();
                if (dbug) {
                  currentTimer.printRunningTimers();
                }
                currentRecord.clickedAddNetworkViaQrCode = true;
                currentRecord.addInteraction("Click: Add network via QrCode",
                    DateTime.now().millisecondsSinceEpoch);
                currentRecord.qrCodeFirstMode = true;
                qrCodeFirstMode = true;
                toggleWifiAndQrCodeSection(false);
              }
              // if (wifiList[index].connectionState ==
              //     WifiConnectionState.DISCONNECTED) {
              //   if (wifiList[index].saved) {
              //     print("$index -- > ${wifiList[index].wifiSSID}");
              //     establishConnection(index);
              //   } else if (wifiList[index]
              //       .security
              //       .securityType
              //       .toLowerCase()
              //       .contains("none"))
              //     establishConnection(index);
              //   else
              //     onWifiItemTapped(context,
              //         index); // TODO: fix it? currently tracking only enabled for new connection with some form of security, not saved or no security networks
              // }
            },
            title: Text("Add Network"),
            leading: Icon(Icons.add),
            trailing: Icon(Icons.qr_code)),
      );
    }
    // 1. Divider
    // return the divider if currently there's a connection
    // if(wifiList[index].wifiSSID == "NONE") // if placeholder wifi entry's SSID is "NONE", it's a placeholder for the blue border
    //   return

    // 2. Trailing icon context menu
    // Context menu for the trailing icon for the connected element
    List<String> popUpMenuItems = ["Disconnect", "Forget"];
    List<PopupMenuItem> pp = [];
    for (int i = 0; i < popUpMenuItems.length; i++)
      pp.add(PopupMenuItem(value: i, child: Text('${popUpMenuItems[i]}')));

    // Context menu for each item long press
    List<String> popUpMenuItems1 = ["Forget"];
    List<PopupMenuItem> pp1 = [];
    for (int i = 0; i < popUpMenuItems1.length; i++)
      pp1.add(PopupMenuItem(value: i, child: Text('${popUpMenuItems1[i]}')));

    dynamic trailingButton;
    if (wifiList[index].connectionState != WifiConnectionState.DISCONNECTED)
      trailingButton = PopupMenuButton(
        child: Icon(Icons.settings),
        itemBuilder: (context) => pp,
        onSelected: (idx) {
          switch (popUpMenuItems[idx]) {
            case "Disconnect":
              disconnectConnection(index);
              break;
            case "Forget":
              forgetConnection(index);
              break;
            default:
              if (dbug) print("Unknown option");
              break;
          }
        },
        onCanceled: () {
          if (dbug) print("cancelled");
        },
      ); // wifi item is at least in connecting state
    else if (wifiList[index].saved)
      trailingButton = PopupMenuButton(
        child: Icon(
          Icons.save,
          color: Colors.grey,
        ),
        itemBuilder: (context) => pp1,
        onSelected: (idx) {
          switch (popUpMenuItems1[idx]) {
            case "Forget":
              if (dbug) print("FFF --> $index");
              forgetConnection(index);
              break;
            default:
              if (dbug) print("Unknown option");
              break;
          }
        },
        onCanceled: () {
          if (dbug) print("cancelled");
        },
      );

    // 4. Subtitle
    // subtitle based on connection state
    String wifiSubTitle = wifiList[index].security.securityType;
    if (wifiList[index].connectionState != WifiConnectionState.DISCONNECTED)
      wifiSubTitle += "                                        Status: " +
          wifiList[index].connectionState;

    List<Widget> widgets = [
      Card(
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 1.0, horizontal: 4.0),
        child: ListTile(
            onTap: () {
              if (wifiList[index].connectionState ==
                  WifiConnectionState.DISCONNECTED) {
                if (wifiList[index].saved) {
                  currentRecord.addInteraction(
                      "Click: Clicked connect to saved network: ${wifiList[index].wifiSSID}",
                      DateTime.now().millisecondsSinceEpoch);
                  establishConnection(index);
                } else if (wifiList[index]
                    .security
                    .securityType
                    .toLowerCase()
                    .contains("none")) {
                  establishConnection(index);
                  currentRecord.addInteraction(
                      "Click: Clicked connect to 'NONE' security network: ${wifiList[index].wifiSSID}",
                      DateTime.now().millisecondsSinceEpoch);
                } else {
                  onWifiItemTapped(context, index);
                }
              }
            },
            title: Text(wifiList[index].wifiSSID),
            subtitle: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.security_outlined,
                  color: Colors.grey,
                  size: 15.0,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3.0),
                  child: Text(wifiSubTitle),
                )
              ],
            ),
            leading: Icon(
              wifiList[index]
                      .security
                      .securityType
                      .toLowerCase()
                      .contains("none")
                  ? Icons.network_wifi
                  : Icons.wifi_lock,
            ),
            trailing: trailingButton),
      ),
    ];

    if (index == 0 && hasConnection)
      widgets.add(Divider(
        height: 1,
        color: Colors.grey,
      ));

    // 5. Wifi tile card
    return Column(
      children: widgets,
    );
  }

  Future<void> _displayEditHtml(BuildContext context, String html) async {
    editHtmlController.text = html;
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Edit HTML',
              style: TextStyle(fontSize: Configuration.TEXT_SIZE),
            ),
            content: TextFormField(
              style: TextStyle(fontSize: Configuration.TEXT_SIZE - 1.5),
              controller: editHtmlController,
              decoration: InputDecoration(hintText: "Add HTML"),
              minLines: 5,
              maxLines: 40,
            ),
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
                    setState(() {
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              Container(
                height: Configuration.DIALOG_BUTTON_HEIGHT,
                child: TextButton(
                  style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.lightBlue)),
                  child: Text(
                    'Update',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.BUTTON_TEXT_SIZE),
                  ),
                  onPressed: () {
                    setState(() {
                      if (newImplementation) {
                        newImplHtmlPrompt = editHtmlController.text;
                        rtdbService.updatePromptsOrConsentText(
                            rtdbService.newImplHtmlPromptRef,
                            newImplHtmlPrompt);
                      } else {
                        oldImplHtmlPrompt = editHtmlController.text;
                        rtdbService.updatePromptsOrConsentText(
                            rtdbService.oldImplHtmlPromptRef,
                            oldImplHtmlPrompt);
                      }
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
            ],
          );
        });
  }

  Future<void> _displayIncompleteSubmissionText(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Center(
                child: Text(
              'Warning: Incomplete Submission!!',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: Configuration.TEXT_SIZE,
                  fontWeight: FontWeight.bold),
            )),
            content: Container(
                width: 600,
                height: 300,
                child: Center(
                  child: Text(
                    "You didn't successfully connect to any enterprise network yet!\nDo you really want to submit?\nYou will not get the full compensation for incomplete submission.",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                        fontWeight: FontWeight.bold),
                  ),
                )),
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
                    setState(() {
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              Container(
                height: Configuration.DIALOG_BUTTON_HEIGHT,
                child: TextButton(
                  style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.redAccent[400])),
                  child: Text(
                    'Submit Anyway',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.BUTTON_TEXT_SIZE),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await saveResponse();
                  },
                ),
              ),
            ],
          );
        });
  }

  // shows the alert dialog for connection information based on connection type
  Future<void> onWifiItemTapped(BuildContext context, int index) {
    // set and start the current timer
    if (!qrCodeFirstMode) {
      this.currentTimer = interactionTimers[index];
      currentTimer.resetAll();
      this.currentRecord = new UserInteractionsRecord();
      this.currentRecord.qrCodeFirstMode = qrCodeFirstMode;
      currentTimer.totalTimeTimer.start();
      if (dbug) {
        currentTimer.printRunningTimers();
      }
    }
    //save the SSID
    this.currentRecord.selectedSSID = this.wifiList[index].wifiSSID;
    this.currentRecord.securityTypeOfSelectedSSID =
        this.wifiList[index].security.securityType;
    this.currentRecord.selectedSSIDIsET = this.wifiList[index].twin ?? false;

    if (newImplementation)
      currentRecord.iType = "NEW_IMPLEMENTATION";
    else
      currentRecord.iType = "OLD_IMPLEMENTATION";

    return showDialog<Pair<dynamic>>(
      context: context,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) =>
          buildWifiConnectionDialog(context, index),
    ).then((closeMode) {
      if (closeMode == null) {
        currentRecord.addInteraction(
            "Click: Barrier dismissed", DateTime.now().millisecondsSinceEpoch);
        stopAllTimersAndRecordInteraction();
        currentRecord.barrierDismissed = true;
        if (isConnecting)
          setState(() {
            isConnecting = false;
          });
      } else if (closeMode.left == 'Cancel') {
        if (isConnecting)
          setState(() {
            isConnecting = false;
          });
      }
      // Here we are stopping some timers that may be left running during submission of the dialog
      currentTimer.advanceOptTimer.stop();
      if (dbug) {
        currentTimer.printRunningTimers();
      }
    });
  }

  AlertDialog buildWifiConnectionDialog(BuildContext context, int index) {
    SecurityInputInformation sii = SecurityInputInformation();

    WifiEntry entry = wifiList[index];
    checkedValue = false;

    sii.wifiSSID = entry.wifiSSID;
    sii.securityType = entry.security.securityType;
    String selectedCACertificate = PLS_SLT_STR;
    String selectedUserCertificate = PLS_SLT_STR;
    sii.enterpriseSelectedCACertificate = selectedCACertificate;
    if (newImplementation) caCertificateList.add("Scan QR code");

    currentRecord.inputEapMethod = selectedEapMethod;
    currentRecord.inputPhase2Method = selectedPhase2Method;
    currentRecord.inputCACertificate = selectedCACertificate;

    return AlertDialog(
        title: Text('${entry.wifiSSID}'),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          // for psk only now
          if (SecurityType.PSKLIST.contains(entry.security.securityType)) {
            return Container(
              width: 500,
              child: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          currentRecord.addInteraction("Input: Password: BEGIN",
                              DateTime.now().millisecondsSinceEpoch);
                          currentTimer.passwordTimer.start();
                          if (dbug) {
                            currentTimer.printRunningTimers();
                          }
                        } else {
                          currentTimer.passwordTimer.stop();
                          if (dbug) {
                            currentTimer.printRunningTimers();
                          }
                          currentRecord.addInteraction("Input: Password: END",
                              DateTime.now().millisecondsSinceEpoch);
                        }
                      },
                      child: TextField(
                        autofocus: true,
                        obscureText: !checkedValue,
                        onChanged: (value) {
                          currentRecord.inputPassword = value;
                          setState(() {
                            sii.pskPassword = value;
                          });
                        },
                        decoration: InputDecoration(
                            border: UnderlineInputBorder(),
                            labelText: 'Password',
                            suffix: IconButton(
                              icon:
                                  Icon(Icons.qr_code, color: Colors.green[300]),
                              onPressed: () {
                                BotToast.showText(
                                    text: "Not Implemented!",
                                    contentColor: Colors.redAccent[400],
                                    textStyle: TextStyle(
                                        color: Colors.white,
                                        fontSize: Configuration.TOAST_SIZE),
                                    duration: Duration(seconds: 4));
                              },
                            )),
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.all(0.0),
                      title: Text("Show password"),
                      value: checkedValue,
                      onChanged: (newValue) {
                        currentRecord.addInteraction("Click: Show password",
                            DateTime.now().millisecondsSinceEpoch);
                        currentTimer.showPasswordTimer.start();
                        if (dbug) {
                          currentTimer.printRunningTimers();
                        }
                        setState(() {
                          checkedValue = newValue;
                        });
                        currentTimer.showPasswordTimer.stop();
                        if (dbug) {
                          currentTimer.printRunningTimers();
                        }
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CustomExpansionTile(
                      currentTimer: currentTimer,
                      currentRecord: currentRecord,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 5),
                          child: TextButton(
                              onPressed: () {
                                currentRecord.addInteraction(
                                    'Click: Cancel clicked',
                                    DateTime.now().millisecondsSinceEpoch);
                                currentRecord.clickedCancel = true;
                                stopAllTimersAndRecordInteraction();
                                Navigator.of(context).pop(Pair(
                                    'Click: Cancel clicked', 1234)); // not used
                              },
                              child: Text("Cancel")),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 5),
                          child: TextButton(
                            child: Text('Connect'),
                            onPressed: (sii.pskPassword == null ||
                                    sii.pskPassword.isEmpty)
                                ? null
                                : () {
                                    currentRecord.addInteraction(
                                        'Click: Connect clicked',
                                        DateTime.now().millisecondsSinceEpoch);
                                    Navigator.of(context).pop(Pair(
                                        'Click: Connect clicked',
                                        1234)); // not used
                                    currentRecord.clickedConnect = true;
                                    if (hasConnection) disconnectConnection(0);
                                    validateAndConnect(entry, sii, index);
                                  },
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          } else {
            if (SecurityType.EAPLIST.contains(entry.security.securityType)) {
              return Container(
                width: 500,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Visibility(
                        visible: !newImplementation,
                        child: Text(
                          "EAP method",
                          style: TextStyle(fontSize: 12.0, color: Colors.grey),
                        ),
                      ),
                      Visibility(
                        visible: !newImplementation,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            onTap: (() {
                              currentTimer.eapTimer.start();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            }),
                            onMenuClose: () {
                              currentTimer.eapTimer.stop();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            },
                            value: selectedEapMethod,
                            icon: Icon(Icons.arrow_downward),
                            iconSize: 24,
                            isExpanded: true,
                            dropdownElevation: 16,
                            underline: null,
                            style: TextStyle(color: Colors.deepPurple),
                            onChanged: (String newValue) {
                              setState(() {
                                selectedEapMethod = newValue;
                                currentRecord.inputEapMethod =
                                    selectedEapMethod;
                                if (newValue == "PEAP")
                                  selectedPhase2Method = "MSCHAPV2";
                                else if (newValue == "TTLS")
                                  selectedPhase2Method = "PAP";

                                phase2MethodList = phase2MethodMap[newValue];
                                selectedPhase2Method = phase2MethodList[0];

                                sii.enterpriseEAPMethod = selectedEapMethod;
                                currentRecord.inputPhase2Method =
                                    selectedPhase2Method;
                              });
                            },
                            items: eapMethodList
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Visibility(
                        visible:
                            !newImplementation && selectedEapMethod != "TLS",
                        child: Text(
                          "Phase 2 authentication",
                          style: TextStyle(fontSize: 12.0, color: Colors.grey),
                        ),
                      ),
                      Visibility(
                        visible:
                            !newImplementation && selectedEapMethod != "TLS",
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            onTap: () {
                              currentTimer.phase2Timer.start();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            },
                            onMenuClose: () {
                              currentTimer.phase2Timer.stop();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            },
                            value: selectedPhase2Method,
                            icon: Icon(Icons.arrow_downward),
                            iconSize: 24,
                            isExpanded: true,
                            dropdownElevation: 16,
                            underline: null,
                            style: TextStyle(color: Colors.deepPurple),
                            onChanged: (String newValue) {
                              setState(() {
                                selectedPhase2Method = newValue;
                                sii.enterprisePhase2AuthMethod =
                                    selectedPhase2Method;
                                currentRecord.inputPhase2Method =
                                    selectedPhase2Method;
                              });
                            },
                            items: phase2MethodList
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: !newImplementation,
                        child: Text(
                          "CA certificate",
                          style: TextStyle(fontSize: 12.0, color: Colors.grey),
                        ),
                      ),
                      Visibility(
                        visible: !newImplementation,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            onTap: () {
                              currentTimer.cacertTimer.start();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            },
                            onMenuClose: () {
                              currentTimer.cacertTimer.stop();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            },
                            value: selectedCACertificate,
                            icon: Icon(Icons.arrow_downward),
                            iconSize: 24,
                            isExpanded: true,
                            dropdownElevation: 16,
                            underline: null,
                            style: TextStyle(color: Colors.deepPurple),
                            onChanged: (String newValue) {
                              setState(() {
                                selectedCACertificate = newValue;
                                sii.enterpriseSelectedCACertificate =
                                    selectedCACertificate;
                                currentRecord.inputCACertificate =
                                    selectedCACertificate;
                                if (certNameToCertDomainNameMap
                                    .containsKey(selectedCACertificate)) {
                                  sii.selectedCustomCertificate =
                                      certNameToCertDomainNameMap[
                                          selectedCACertificate];
                                  currentRecord.selectedCustomCertificate =
                                      sii.selectedCustomCertificate;
                                }
                                if (dbug)
                                  print(sii.enterpriseSelectedCACertificate);
                              });
                            },
                            items: caCertificateList
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Visibility(
                        visible:
                            !newImplementation && selectedEapMethod == "TLS",
                        child: Text(
                          "User certificate",
                          style: TextStyle(fontSize: 12.0, color: Colors.grey),
                        ),
                      ),
                      Visibility(
                        visible:
                            !newImplementation && selectedEapMethod == "TLS",
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            onTap: () {
                              currentTimer.cacertTimer.start();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            },
                            onMenuClose: () {
                              currentTimer.cacertTimer.stop();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            },
                            value: selectedUserCertificate,
                            icon: Icon(Icons.arrow_downward),
                            iconSize: 24,
                            isExpanded: true,
                            dropdownElevation: 16,
                            underline: null,
                            style: TextStyle(color: Colors.deepPurple),
                            onChanged: (String newValue) {
                              setState(() {
                                selectedUserCertificate = newValue;
                                sii.enterpriseSelectedUserCertificate =
                                    selectedUserCertificate;
                                currentRecord.inputUserCertificate =
                                    selectedUserCertificate;
                                if (dbug)
                                  print(sii.enterpriseSelectedUserCertificate);
                              });
                            },
                            items: userCertificateList
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Visibility(
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              currentRecord.addInteraction(
                                  "Input: DomainName: BEGIN",
                                  DateTime.now().millisecondsSinceEpoch);
                              currentTimer.domainNameTimer.start();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            } else {
                              currentTimer.domainNameTimer.stop();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                              currentRecord.addInteraction(
                                  "Input: DomainName: END",
                                  DateTime.now().millisecondsSinceEpoch);
                            }
                          },
                          child: TextField(
                            autofocus: true,
                            onChanged: (value) {
                              setState(() {
                                sii.enterpriseDomainName = value;
                                currentRecord.inputDomainName = value;
                              });
                            },
                            decoration: InputDecoration(
                              border: UnderlineInputBorder(),
                              labelText: 'Domain',
                            ),
                          ),
                        ),
                        visible: selectedCACertificate != DNT_VALIDAT &&
                            selectedCACertificate != PLS_SLT_STR &&
                            selectedCACertificate != TOFU_STRING,
                      ),
                      Visibility(
                        visible: selectedCACertificate == USE_SYS_CRT,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                          child: Text(
                            "Must specify a domain",
                            style: TextStyle(fontSize: 10.0, color: Colors.red),
                          ),
                        ),
                      ),
                      Visibility(
                        visible:
                            selectedCACertificate == DNT_VALIDAT ? true : false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
                          child: Text(
                            "No certificate specified. Your connection will not be private.",
                            style: TextStyle(fontSize: 10.0, color: Colors.red),
                          ),
                        ),
                      ),
                      Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            currentRecord.addInteraction(
                                "Input: Identity: BEGIN",
                                DateTime.now().millisecondsSinceEpoch);
                            currentTimer.identityTimer.start();
                            if (dbug) {
                              currentTimer.printRunningTimers();
                            }
                          } else {
                            currentTimer.identityTimer.stop();
                            if (dbug) {
                              currentTimer.printRunningTimers();
                            }
                            currentRecord.addInteraction("Input: Identity: END",
                                DateTime.now().millisecondsSinceEpoch);
                          }
                        },
                        child: TextField(
                          autofocus: true,
                          onChanged: (value) {
                            setState(() {
                              sii.enterpriseUsername = value;
                              currentRecord.inputIdentity = value;
                            });
                          },
                          decoration: InputDecoration(
                            border: UnderlineInputBorder(),
                            labelText: 'Identity',
                          ),
                        ),
                      ),
                      Visibility(
                        visible: !newImplementation,
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              currentRecord.addInteraction(
                                  "Input: Anonymous Identity: BEGIN",
                                  DateTime.now().millisecondsSinceEpoch);
                              currentTimer.anonIdentityTimer.start();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            } else {
                              currentTimer.anonIdentityTimer.stop();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                              currentRecord.addInteraction(
                                  "Input: Anonymous Identity: END",
                                  DateTime.now().millisecondsSinceEpoch);
                            }
                          },
                          child: TextField(
                            autofocus: true,
                            onChanged: (value) {
                              sii.enterpriseAnonymousIdentity =
                                  value; // ultimately this is useless for our usecase
                              currentRecord.inputAnonymousIdentity = value;
                            },
                            decoration: InputDecoration(
                              border: UnderlineInputBorder(),
                              labelText: 'Anonymous identity',
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: selectedEapMethod != "TLS",
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              currentRecord.addInteraction(
                                  "Input: Password: BEGIN",
                                  DateTime.now().millisecondsSinceEpoch);
                              currentTimer.passwordTimer.start();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                            } else {
                              currentTimer.passwordTimer.stop();
                              if (dbug) {
                                currentTimer.printRunningTimers();
                              }
                              currentRecord.addInteraction(
                                  "Input: Password: END",
                                  DateTime.now().millisecondsSinceEpoch);
                            }
                          },
                          child: TextField(
                            autofocus: true,
                            obscureText: !checkedValue,
                            onChanged: (value) {
                              setState(() {
                                sii.enterprisePassword = value;
                                currentRecord.inputPassword = value;
                              });
                            },
                            decoration: InputDecoration(
                              border: UnderlineInputBorder(),
                              labelText: 'Password',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.all(0.0),
                        title: Text("Show password"),
                        value: checkedValue,
                        onChanged: (newValue) {
                          currentRecord.addInteraction("Click: Show password",
                              DateTime.now().millisecondsSinceEpoch);
                          currentTimer.showPasswordTimer.start();
                          if (dbug) {
                            currentTimer.printRunningTimers();
                          }
                          setState(() {
                            checkedValue = newValue;
                            currentRecord.showPasswordChecked = true;
                          });

                          currentTimer.showPasswordTimer.stop();
                          if (dbug) {
                            currentTimer.printRunningTimers();
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CustomExpansionTile(
                        currentTimer: currentTimer,
                        currentRecord: currentRecord,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 5),
                            child: TextButton(
                                onPressed: () {
                                  currentRecord.addInteraction(
                                      'Click: Cancel clicked',
                                      DateTime.now().millisecondsSinceEpoch);
                                  currentRecord.clickedCancel = true;
                                  stopAllTimersAndRecordInteraction();
                                  Navigator.of(context)
                                      .pop(Pair('Cancel', 1234)); // not used
                                },
                                child: Text("Cancel")),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 5),
                            child: TextButton(
                                child: Text(newImplementation &&
                                        !qrCodeFirstMode //sii.enterpriseSelectedCACertificate =="Scan QR code"
                                    ? "Scan QR code and connect"
                                    : 'Connect'),
                                onPressed: (sii.enterpriseUsername == null ||
                                        sii.enterpriseUsername.isEmpty ||
                                        (sii.enterpriseEAPMethod != "TLS" &&
                                            (sii.enterprisePassword == null ||
                                                sii.enterprisePassword
                                                    .isEmpty)) ||
                                        (sii.enterpriseSelectedCACertificate ==
                                                USE_SYS_CRT &&
                                            (sii.enterpriseDomainName == null ||
                                                sii.enterpriseDomainName
                                                    .isEmpty)) ||
                                        // (sii.enterpriseSelectedCACertificate == "Scan QR code" && (sii.enterpriseCACertificate == null || sii.enterpriseCACertificate.isEmpty)) ||
                                        (sii.enterpriseSelectedCACertificate ==
                                                PLS_SLT_STR &&
                                            !newImplementation))
                                    ? null
                                    : () {
                                        connectButtonClickCountForEnterpriseWifi++;

                                        if (dbug)
                                          print(
                                              "Connect Clicked For EAP: $connectButtonClickCountForEnterpriseWifi");

                                        currentRecord.addInteraction(
                                            newImplementation &&
                                                    !qrCodeFirstMode
                                                ? 'Click: Scan Qr code and connect clicked'
                                                : 'Click: Connect clicked',
                                            DateTime.now()
                                                .millisecondsSinceEpoch);
                                        currentRecord.clickedConnect = true;
                                        Navigator.of(context).pop(Pair(
                                            'Click: Connect clicked',
                                            1234)); // not used
                                        // print(sii.securityType);
                                        // sii.enterpriseSelectedCACertificate == "Scan QR code"
                                        if (newImplementation &&
                                            qrCodeFirstMode) {
                                          currentSII = sii;
                                          validateAndConnectQrCodeFirstMode();
                                        } else if (newImplementation) {
                                          toggleWifiAndQrCodeSection(
                                              false); // show QRCode Section for scanning
                                          currentSII = sii;
                                          currentWifiEntry = entry;
                                          currentIndex = index;
                                        } else if (sii
                                                .enterpriseSelectedCACertificate ==
                                            USE_SYS_CRT) {
                                          // bool inputDomainValid =
                                          //     (sii.enterpriseDomainName ==
                                          //         entry.security
                                          //             .usedSystemCertificate);
                                          // if (inputDomainValid)
                                          validateAndConnect(entry, sii, index);
                                          // else
                                          //   BotToast.showText(
                                          //       text:
                                          //           "No matching certificate found",
                                          //       contentColor:
                                          //           Colors.redAccent[400],
                                          //       textStyle: TextStyle(
                                          //           color: Colors.white,
                                          //           fontSize: Configuration
                                          //               .TOAST_SIZE),
                                          //       duration: Duration(seconds: 4));
                                        } else
                                          validateAndConnect(entry, sii, index);
                                      }),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            }
          }

          return Container(
            child: Text("This is an error!!"),
          );
        }));
  }

  void cancelCurrentScan() {
    currentIndex = -1;
    currentSII = null;
    currentWifiEntry = null;
    qrCodeFirstMode = false;
    qrCodeFirstModeQrCodeString = null;
    currentRecord.addInteraction(
        "Click: QrCode Scan cancelled", DateTime.now().millisecondsSinceEpoch);
    currentRecord.clickedCancel = true;
    toggleWifiAndQrCodeSection(true);
    stopAllTimersAndRecordInteraction();
    BotToast.showText(
        text: "Scan Cancelled!",
        contentColor: Colors.redAccent[400],
        textStyle:
            TextStyle(color: Colors.white, fontSize: Configuration.TOAST_SIZE),
        duration: Duration(seconds: 2));
    setState(() {
      isConnecting = false;
    });
  }

  WifiEntry getWifiEntryFromSSID(String ssid) {
    int i = 0;
    for (WifiEntry e in wifiList) {
      if (e.wifiSSID == ssid) {
        currentIndex = i;
        return e;
      }
      i++;
    }
    currentIndex = -1;
    return null;
  }

  void validateAndConnectQrCodeFirstMode() {
    print(currentWifiEntry);
    print(currentIndex);
    if (qrCodeFirstMode && qrCodeFirstModeQrCodeString != null) {
      currentSII.enterpriseCACertificate = qrCodeFirstModeQrCodeString;
      currentRecord.scannedQrCode = qrCodeFirstModeQrCodeString;
      if (currentSII.enterpriseCACertificate !=
          currentWifiEntry.security.enterpriseCACertificate) {
        // validate via qr code
        certificateVerificationFailedPage = "1";
        showCertificateVerificationFailedError().then((connectAnyway) {
          if (connectAnyway) {
            validateAndConnect(currentWifiEntry, currentSII, currentIndex);
          } else {
            setState(() {
              isConnecting = false;
            });
          }
        });
      } else
        validateAndConnect(currentWifiEntry, currentSII, currentIndex);
    }
  }

  void scanResult(String wifiSSID, String qrCodeString) {
    BotToast.showText(
        text: "Scan finished!",
        contentColor: Colors.blueAccent[400],
        textStyle:
            TextStyle(color: Colors.white, fontSize: Configuration.TOAST_SIZE),
        duration: Duration(seconds: 2));

    if (qrCodeFirstMode) {
      toggleWifiAndQrCodeSection(true);
      qrCodeFirstModeQrCodeString = qrCodeString;

      if (dbug) print("HELLO FROM QRCODE FIRST! : $wifiSSID");
      currentWifiEntry = getWifiEntryFromSSID(wifiSSID);
      if (currentWifiEntry == null) {
        BotToast.showText(
            text: "Scanned Network Not Found!",
            contentColor: Colors.redAccent[400],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE),
            duration: Duration(seconds: 4));
      } else {
        if (dbug) print(currentWifiEntry.connectionState);
        onWifiItemTapped(context, currentIndex);
      }

      return;
    }

    currentRecord.addInteraction(
        "Click: QrCode Scan finished", DateTime.now().millisecondsSinceEpoch);
    toggleWifiAndQrCodeSection(true);
    if (qrCodeString != null) {
      currentSII.enterpriseCACertificate = qrCodeString;
      currentRecord.scannedQrCode = qrCodeString;
      if (currentSII.enterpriseCACertificate !=
          currentWifiEntry.security.enterpriseCACertificate) {
        // validate via qr code
        certificateVerificationFailedPage = "1";
        showCertificateVerificationFailedError().then((connectAnyway) {
          if (connectAnyway)
            validateAndConnect(currentWifiEntry, currentSII, currentIndex);
          else {
            setState(() {
              isConnecting = false;
            });
          }
        });
      } else
        validateAndConnect(currentWifiEntry, currentSII, currentIndex);
    }
  }

  void toggleWifiAndQrCodeSection(bool showWifiSection) {
    wifiSectionEnabled = showWifiSection;
    qrCodeSectionEnabled = !showWifiSection;

    if (wifiSectionEnabled) {
      currentTimer.qrCodeScanTimer.stop();
      if (dbug) {
        currentTimer.printRunningTimers();
      }
      currentRecord.addInteraction(
          "Input: QrCode Scan: END", DateTime.now().millisecondsSinceEpoch);
      wifiSectionOpacity = enabledOpacity;
      qrCodeSectionOpacity = disabledOpacity;
      // isConnecting = false;
    } else {
      // this means we are scanning something
      wifiSectionOpacity = disabledOpacity;
      qrCodeSectionOpacity = enabledOpacity;
      currentRecord.addInteraction(
          "Input: QrCode Scan: START", DateTime.now().millisecondsSinceEpoch);
      currentTimer.qrCodeScanTimer.start();
      if (dbug) {
        currentTimer.printRunningTimers();
      }
      isConnecting = true;
    }
    setState(() {}); // refresh UI
  }

  Future<bool> showTofuDialog(context, WifiEntry wifiEntry) {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            title: Text('Is this network trusted?'),
            content: Container(
              height: 450,
              width: 350,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
                    child: Text(
                        'Only allow this network to connect if the information below looks correct.',
                        style: TextStyle(color: Colors.black, fontSize: 20)),
                  ),
                  Text('Server Name:',
                      style: TextStyle(color: Colors.black, fontSize: 20)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                    child: Text('${wifiEntry.security.certServerName}',
                        style: TextStyle(color: Colors.black, fontSize: 20)),
                  ),
                  Text('Issuer Name:',
                      style: TextStyle(color: Colors.black, fontSize: 20)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                    child: Text('${wifiEntry.security.certIssuerName}',
                        style: TextStyle(color: Colors.black, fontSize: 20)),
                  ),
                  Text('Organization:',
                      style: TextStyle(color: Colors.black, fontSize: 20)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                    child: Text('${wifiEntry.security.certOrganization}',
                        style: TextStyle(color: Colors.black, fontSize: 20)),
                  ),
                  Text('Fingerprint:',
                      style: TextStyle(color: Colors.black, fontSize: 20)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                    child: Text('${wifiEntry.security.certSignature}',
                        style: TextStyle(color: Colors.black, fontSize: 20)),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: OutlinedButton(
                  // style: ButtonStyle(
                  //     backgroundColor:
                  //         MaterialStateProperty.all(Color.fromARGB(255, 154, 94, 106))),
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    )),
                    side: MaterialStateProperty.all(
                        BorderSide(width: 1.0, color: Colors.tealAccent[400])),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'No, don\'t connect',
                      style: TextStyle(
                          color: Colors.teal[900],
                          fontSize: Configuration.BUTTON_TEXT_SIZE),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context, false);
                  },
                ),
              ),
              SizedBox(
                width: 50,
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: OutlinedButton(
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    )),
                    side: MaterialStateProperty.all(
                        BorderSide(width: 1.0, color: Colors.tealAccent[400])),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Yes, connect',
                      style: TextStyle(
                          color: Colors.teal[900],
                          fontSize: Configuration.BUTTON_TEXT_SIZE),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context, true);
                  },
                ),
              ),
            ],
          );
        });
  }

  Future<bool> showSubmitNowDialog(context) {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            title: Text(
              'Submit the task now?',
              style: TextStyle(color: Colors.blue[700], fontSize: 40),
            ),
            content: Container(
              height: 150,
              width: 300,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
                    child: Text(
                        'Your interactions will be saved and you will be able to access the next task.',
                        style: TextStyle(
                            color: Color.fromARGB(255, 7, 70, 152),
                            fontSize: 20)),
                  ),
                  Text(
                      'Please note that you cannot acess this task once you submit.',
                      style: TextStyle(
                          color: Color.fromARGB(255, 208, 30, 30),
                          fontSize: 20)),
                ],
              ),
            ),
            actions: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 250,
                    child: OutlinedButton(
                      // style: ButtonStyle(
                      //     backgroundColor:
                      //         MaterialStateProperty.all(Color.fromARGB(255, 154, 94, 106))),
                      style: ButtonStyle(
                          shape:
                              MaterialStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          )),
                          backgroundColor: MaterialStateProperty.all(
                              Color.fromARGB(255, 46, 38, 199))),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'No, don\'t submit',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: Configuration.BUTTON_TEXT_SIZE),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context, false);
                      },
                    ),
                  ),
                  Container(
                    width: 250,
                    child: OutlinedButton(
                      style: ButtonStyle(
                        shape: MaterialStateProperty.all(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        )),
                        backgroundColor: MaterialStateProperty.all(
                            Color.fromARGB(255, 13, 124, 91)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Yes, submit',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: Configuration.BUTTON_TEXT_SIZE),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              )
            ],
          );
        });
  }

  Future<bool> showNoInteractionSubmitDialog(context) {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            title: Text(
              'Do you really want to submit?',
              style: TextStyle(color: Colors.red[700], fontSize: 40),
            ),
            content: Container(
              height: 150,
              width: 300,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
                    child: Text(
                        'Our record shows that you have not interacted with the designated Wi-Fi access point.',
                        style:
                            TextStyle(color: Colors.purple[800], fontSize: 20)),
                  ),
                  Text(
                      'Please note that you will not get compensated if you do not interact with the designated Wi-Fi access point.',
                      style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 250,
                    child: OutlinedButton(
                      // style: ButtonStyle(
                      //     backgroundColor:
                      //         MaterialStateProperty.all(Color.fromARGB(255, 154, 94, 106))),
                      style: ButtonStyle(
                          shape:
                              MaterialStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          )),
                          backgroundColor: MaterialStateProperty.all(
                              Color.fromARGB(255, 60, 115, 244))),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'No, don\'t submit',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: Configuration.BUTTON_TEXT_SIZE),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context, false);
                      },
                    ),
                  ),
                  Container(
                    width: 250,
                    child: OutlinedButton(
                      style: ButtonStyle(
                        shape: MaterialStateProperty.all(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        )),
                        backgroundColor: MaterialStateProperty.all(
                            Color.fromARGB(255, 214, 35, 35)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Yes, submit',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: Configuration.BUTTON_TEXT_SIZE),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              )
            ],
          );
        });
  }

  // for validating => showing connection animation | error animation
  Future<void> validateAndConnect(
      WifiEntry entry, SecurityInputInformation sii, int index) async {
    setState(() {
      isConnecting = true;
    });

    failReason = "NONE";
    if (dbug) print("INSIDE VALIDATE & CONNECT --> ${sii.enterpriseEAPMethod}");
    if (sii.enterpriseEAPMethod == "TLS") {
      currentRecord.connectionSuccessful = false;
      failReason = "SELECTED_TLS_IN_EAP";
      currentRecord.failReason = failReason;
      showError(index);
      stopAllTimersAndRecordInteraction();
      return;
    }

    bool trustClicked = true; // only valid if it's TOFU, otherwise ignore

    if (tofuAvailable && sii.enterpriseSelectedCACertificate == TOFU_STRING) {
      globalTimers.tofuPromptTimer.start();
      trustClicked = await showTofuDialog(context, entry);
      globalTimers.tofuPromptTimer.stop();
      if (trustClicked == false) {
        if (entry.wifiSSID == designatedWiFiAP) {
          failureCount += 1; // failure due to user being aware of ET
          failReason = "TOFU_DO_NOT_CONNECT";
          if (sii.enterprisePassword != designatedPassword) {
            failReason += ";WRONG_ENTERPRISE_PASSWORD";
          }
          if (sii.enterpriseUsername != designatedUsername) {
            failReason += ";WRONG_ENTERPRISE_USERNAME";
          }
          currentRecord.failReason = failReason;
        }
        setState(() {
          isConnecting = false;
        });
      }
    }
    if (kDebugMode) {
      print("TOFU ACCEPT => ${trustClicked}");
    }

    // print(entry.security.enterpriseDomainName);

    if (trustClicked) {
      if (entry.validate(sii) && trustClicked) {
        // print("TOFU ACCEPT => Validation Successful");
        currentRecord.connectionSuccessful = true;
        // print(entry);
        // print(entry.wifiSSID);
        // print(designatedWiFiAP);
        // print(index);
        if (SecurityType.EAPLIST.contains(entry.security.securityType) &&
            entry.wifiSSID == designatedWiFiAP) {
          atLeastOnceConnectedToWpa2Enterprise = true;
        }
        currentRecord.failReason = failReason;
        establishConnection(index);
      } else {
        currentRecord.connectionSuccessful = false;
        if (SecurityType.EAPLIST.contains(entry.security.securityType) &&
            entry.wifiSSID == designatedWiFiAP) {
          failureCount += 1;
          failReason = "";
          if (sii.enterprisePassword != designatedPassword) {
            failReason += "WRONG_ENTERPRISE_PASSWORD";
          }
          if (sii.enterpriseUsername != designatedUsername) {
            failReason += ";WRONG_ENTERPRISE_USERNAME";
          }

          if (failReason == "") failReason = "NONE";

          currentRecord.failReason = failReason;
        }
        showError(index);
      }
    }

    // setState(() {
    //   isConnecting = false;
    // });

    stopAllTimersAndRecordInteraction();
  }

  void stopAllTimersAndRecordInteraction() {
    assert(currentRecord != null);
    assert(currentTimer != null);

    qrCodeFirstMode = false;
    qrCodeFirstModeQrCodeString = null;
    currentWifiEntry = null;
    currentIndex = -1;
    currentSII = null;

    currentTimer.totalTimeTimer.stop();
    currentTimer.stopAll();

    currentRecord.updateUserInteractionTimes(currentTimer);

    // save the current interaction
    interactionRecords.add(currentRecord);

    if (dbug) currentTimer.printAllElapsed();
    if (dbug) currentRecord.printInteraction();
  }

  // Error handling when QRCode's hash doesn't match with server's certificate hash
  Future<bool> showCertificateVerificationFailedError() {
    return showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: null,
              content: Container(
                width: 500,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    // Error page number 1
                    if (certificateVerificationFailedPage == "1") {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Center(
                              child: Icon(Icons.error_outline_outlined,
                                  color: Colors.red, size: 50)),
                          SizedBox(
                            height: 10,
                          ),
                          Center(
                            child: Text(
                              "Certificate verification failed!",
                              style: TextStyle(fontSize: 25, color: Colors.red),
                            ),
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          Visibility(
                            visible: false,
                            child: TextButton(
                                child: Text(
                                  "Connect anyway",
                                  style: TextStyle(
                                      color: Colors.redAccent, fontSize: 15),
                                ),
                                onPressed: () {
                                  setState(() {
                                    certificateVerificationFailedPage = "3";
                                  });
                                }),
                          ),
                          TextButton(
                            child: Text(
                              "Terminate connection",
                              style: TextStyle(
                                  color: Colors.greenAccent, fontSize: 15),
                            ),
                            onPressed: () {
                              currentRecord.addInteraction(
                                  "Click: Terminate connection",
                                  DateTime.now().millisecondsSinceEpoch);
                              currentRecord.connectionSuccessful = false;
                              if (kDebugMode) {
                                print("HELLOM WORLD 1");
                                print(currentWifiEntry.wifiSSID);
                                print(designatedWiFiAP);
                                print(currentIndex);
                              }
                              if (currentWifiEntry.wifiSSID ==
                                  designatedWiFiAP) {
                                failureCount += 1;
                                failReason = "";
                                if (currentSII.enterprisePassword !=
                                    designatedPassword) {
                                  failReason += "WRONG_ENTERPRISE_PASSWORD";
                                }
                                if (currentSII.enterpriseUsername !=
                                    designatedUsername) {
                                  failReason += ";WRONG_ENTERPRISE_USERNAME";
                                }

                                if (failReason == "") failReason = "NONE";

                                currentRecord.failReason = failReason;
                              }

                              stopAllTimersAndRecordInteraction();
                              Future.delayed(Duration.zero, () {
                                Navigator.of(context).pop(false);
                                certificateVerificationFailedPage = "1";
                              });
                            },
                          ),
                          TextButton(
                            child: Text(
                              "Show details",
                              style: TextStyle(
                                  color: Colors.blueAccent, fontSize: 15),
                            ),
                            onPressed: () {
                              currentRecord.addInteraction(
                                  "Click: Show details",
                                  DateTime.now().millisecondsSinceEpoch);
                              setState(() {
                                certificateVerificationFailedPage = "2";
                              });
                            },
                          ),
                        ],
                      );
                    }

                    // Error page number 2
                    else if (certificateVerificationFailedPage == "2") {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Center(
                              child: Icon(Icons.info_outline,
                                  color: Colors.blue, size: 50)),
                          SizedBox(
                            height: 10,
                          ),
                          Center(
                            child: Container(
                                width: 500,
                                child: Text(
                                  "Selected enterprise wifi network's radius server certificate hash doesn't match with hash scanned from qr code.\nYou are interacting with a potentially malicious Wi-Fi access point. Connecting to this Wi-Fi access point may result in your user name and password being stolen.",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 20),
                                )),
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          TextButton(
                              child: Text("Return",
                                  style: TextStyle(
                                      color: Colors.blueAccent, fontSize: 15)),
                              onPressed: () {
                                setState(() {
                                  certificateVerificationFailedPage = "1";
                                });
                              }),
                          TextButton(
                              child: Text("Terminate connection",
                                  style: TextStyle(color: Colors.green)),
                              onPressed: () {
                                certificateVerificationFailedPage = "1";
                                currentRecord.addInteraction(
                                    "Click: Terminate connection",
                                    DateTime.now().millisecondsSinceEpoch);
                                currentRecord.connectionSuccessful = false;
                                if (kDebugMode) {
                                  print("HELLOM WORLD 1");
                                  print(currentWifiEntry.wifiSSID);
                                  print(designatedWiFiAP);
                                  print(currentIndex);
                                }
                                if (currentWifiEntry.wifiSSID ==
                                    designatedWiFiAP) {
                                  failureCount += 1;
                                  failReason = "";
                                  if (currentSII.enterprisePassword !=
                                      designatedPassword) {
                                    failReason += "WRONG_ENTERPRISE_PASSWORD";
                                  }
                                  if (currentSII.enterpriseUsername !=
                                      designatedUsername) {
                                    failReason += ";WRONG_ENTERPRISE_USERNAME";
                                  }

                                  if (failReason == "") failReason = "NONE";

                                  currentRecord.failReason = failReason;
                                }

                                stopAllTimersAndRecordInteraction();
                                Future.delayed(Duration.zero, () {
                                  Navigator.of(context).pop(false);
                                });
                              }),
                        ],
                      );
                    }

                    // Error page number 3
                    else if (certificateVerificationFailedPage == "3") {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Center(
                              child: Icon(
                            Icons.lock_open_outlined,
                            color: Colors.redAccent,
                            size: 50,
                          )),
                          SizedBox(
                            height: 10,
                          ),
                          Center(
                            child: Text(
                              "Are you sure?",
                              style: TextStyle(
                                fontSize: 30,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          // SizedBox(
                          //   height: 5,
                          // ),
                          // Center(
                          //   child: Text(
                          //     "Your connection may not be private",
                          //     style: TextStyle(
                          //       fontSize: 25,
                          //       color: Colors.grey,
                          //     ),
                          //   ),
                          // ),
                          SizedBox(
                            height: 5,
                          ),
                          Center(
                            child: Container(
                                width: 500,
                                child: Text(
                                  /*"Attackers might be trying to steal your information by attacking the selected network (for example, passwords, messages, or credit-card credentials)"*/ "You are interacting with a potentially malicious Wi-Fi access point. Connecting to this Wi-Fi access point may result in your user name and password being stolen.",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 21),
                                )),
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          TextButton(
                              child: Text("Connect",
                                  style: TextStyle(
                                      color: Colors.redAccent, fontSize: 15)),
                              onPressed: () {
                                certificateVerificationFailedPage = "1";
                                currentRecord.connectAnyway = true;
                                Future.delayed(Duration.zero, () {
                                  Navigator.of(context).pop(true);
                                });
                              }),
                          TextButton(
                              child: Text("Terminate connection",
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 15)),
                              onPressed: () {
                                certificateVerificationFailedPage = "1";
                                currentRecord.addInteraction(
                                    "Click: Terminate connection",
                                    DateTime.now().millisecondsSinceEpoch);
                                currentRecord.connectionSuccessful = false;
                                if (kDebugMode) {
                                  print("HELLOM WORLD 2");
                                  print(currentWifiEntry.wifiSSID);
                                  print(designatedWiFiAP);
                                  print(currentIndex);
                                }
                                if (currentWifiEntry.wifiSSID ==
                                    designatedWiFiAP) {
                                  failureCount += 1;
                                  failReason = "";
                                  if (currentSII.enterprisePassword !=
                                      designatedPassword) {
                                    failReason += "WRONG_ENTERPRISE_PASSWORD";
                                  }
                                  if (currentSII.enterpriseUsername !=
                                      designatedUsername) {
                                    failReason += ";WRONG_ENTERPRISE_USERNAME";
                                  }

                                  if (failReason == "") failReason = "NONE";

                                  currentRecord.failReason = failReason;
                                }
                                stopAllTimersAndRecordInteraction();
                                Future.delayed(Duration.zero, () {
                                  Navigator.of(context).pop(false);
                                });
                              }),
                        ],
                      );
                    }
                    return Container(
                      height: 400,
                      width: 400,
                      child: Text("THIS SHOULD NEVER BE SEEN"),
                    );
                  },
                ),
              ));
        });
  }

//Navigator.of(context).pop(true);
  Future<String> scanQRCode() {
    List<String> qrCodes = qrCodeValues.keys.toList();
    return showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Center(child: Text("Scan QR Code")),
              content: Container(
                width: 500,
                height: 700,
                child: ListView.builder(
                  itemCount: qrCodes.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "QR code for Wifi SSID: " +
                                qrCodeWifiSSID[qrCodes[index]],
                            style: TextStyle(
                                color: Colors.white,
                                backgroundColor: Colors.grey,
                                fontSize: 16),
                          ),
                          Tooltip(
                            message: "Scan this qr code",
                            preferBelow: true,
                            child: InkWell(
                              child: Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.rectangle,
                                      border: Border.all(
                                        width: 1,
                                      )),
                                  child: Image.asset(
                                    qrCodes[index],
                                    height: 300,
                                  )),
                              onTap: () {
                                Future.delayed(Duration.zero, () {
                                  Navigator.of(context)
                                      .pop(qrCodeValues[qrCodes[index]]);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ));
        });
  }

  // Establishing connection after everything is verified + textual animation setup
  void establishConnection(int index) {
    if (wifiList[index].wifiSSID == designatedWiFiAP) successCount += 1;

    if (dbug) print('$index -->${wifiList[index].wifiSSID}');
    if (hasConnection) disconnectConnection(0);

    for (int i = 0; i < wifiList.length; i++)
      wifiList[i].connectionState = WifiConnectionState.DISCONNECTED;

    // Updating the position of the selected item
    setState(() {
      WifiEntry tmp = wifiList.removeAt(index);
      if (dbug) print('$index -->${tmp.wifiSSID}');
      tmp.connectionState = WifiConnectionState.CONNECTING;
      wifiList.insert(0, tmp);

      isSavedNetwork[wifiList[0].wifiSSID] = true;
      wifiList[0].saved = true;

      hasConnection = true;
    });

    t1 = new Timer(Duration(milliseconds: 500), () {
      setState(() {
        wifiList[0].connectionState = WifiConnectionState.VERIFYING;
      });
    });

    // Animation Schedule
    t2 = new Timer(Duration(milliseconds: 1200), () {
      setState(() {
        wifiList[0].connectionState = WifiConnectionState.OBTAININGIP;
      });
    });

    t3 = new Timer(Duration(milliseconds: 1700), () {
      setState(() {
        wifiList[0].connectionState = WifiConnectionState.CONNECTED;
        isConnecting = false;
      });
    });
  }

  // disconnect connection
  void disconnectConnection(int index) {
    cancelAllConnectionAnimationTimer();
    for (int i = 0; i < wifiList.length; i++)
      wifiList[i].connectionState = WifiConnectionState.DISCONNECTED;
    setState(() {
      hasConnection = false;
    });
  }

  void forgetConnection(int index) {
    if (index == 0 && hasConnection) disconnectConnection(index);
    setState(() {
      wifiList[index].saved = false;
    });
    isSavedNetwork[wifiList[index].wifiSSID] = false;
  }

  // show error when there's credential mismatch
  void showError(int index) {
    if (hasConnection) disconnectConnection(0);

    for (int i = 0; i < wifiList.length; i++)
      wifiList[i].connectionState = WifiConnectionState.DISCONNECTED;

    // Updating the position of the selected item
    setState(() {
      WifiEntry tmp = wifiList.removeAt(index);
      tmp.connectionState = WifiConnectionState.CONNECTING;
      wifiList.insert(0, tmp);
      hasConnection = true;
    });

    // Animation Schedule
    t1 = new Timer(Duration(milliseconds: 300), () {
      setState(() {
        wifiList[0].connectionState = WifiConnectionState.VERIFYING;
      });
    });
    t2 = new Timer(Duration(milliseconds: 1000), () {
      setState(() {
        disconnectConnection(0);
        isConnecting = false;
        BotToast.showText(
            text: (failReason.contains("WRONG_ENTERPRISE_PASSWORD") ||
                    failReason.contains("WRONG_ENTERPRISE_USERNAME") || actualTaskIdentifier.contains('Ben'))
                ? "Verification failed! Try again!"
                : "Verification failed!", // try again!",
            contentColor: Colors.redAccent[400],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE),
            duration: Duration(seconds: 4));
      });
    });
  }

  void cancelAllConnectionAnimationTimer() {
    if (t1 != null) {
      if (dbug) print("Cancel t1");
      t1.cancel();
    }
    if (t2 != null) {
      if (dbug) print("Cancel t2");
      t2.cancel();
    }
    if (t3 != null) {
      if (dbug) print("Cancel t3");
      t3.cancel();
    }
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> saveResponse() async {
    globalTimers.setupGuideTimer.stop();
    globalTimers.taskLevelTimer.stop();
    globalTimers.wifiUITimer.stop();
    globalTimers.instructionPageTimer.stop();
    if (dbug) globalTimers.printAll();

    await rtdbService.saveInteractionResponse(
        interactionRecords,
        globalTimers,
        failureCount,
        successCount,
        actualTaskIdentifier,
        taskId,
        tofuAvailable);

    String checkRef = "";

    if (currentUserInfo.isAnonymous) {
      // No need to do this for the admins
      if (actualTaskIdentifier.contains("old"))
        checkRef = rtdbService.oldImplResponseRef +
            "/" +
            currentUserInfo.workerId +
            "/" +
            actualTaskIdentifier;
      else if (actualTaskIdentifier.contains("new"))
        checkRef = rtdbService.newImplResponseRef +
            "/" +
            currentUserInfo.workerId +
            "/" +
            actualTaskIdentifier;
    }

    // print("UPDATING TASK STATE TO=> ${taskState}");
    await rtdbService.addSurveyStateInDB(taskState, checkRef);
    // if (taskId == 'Task-1') {
    //   String checkRef = "";
    //   if (newImplementation) {
    //     await rtdbService.addNewImplResponse(interactionRecords, globalTimers, failureCount, successCount);
    //     checkRef = rtdbService.newImplResponseRef;
    //   } else {
    //     await rtdbService.addOldImplResponse(interactionRecords, globalTimers, failureCount, successCount);
    //     checkRef = rtdbService.oldImplResponseRef;
    //   }
    //   await rtdbService.addSurveyStateInDB(AMT_SURVEY_STATE_TASK1_FINISHED, checkRef);
    // } else if (taskId == 'Task-2') {
    //   String checkRef = "";
    //   if (newImplementation) {
    //     await rtdbService.addNewImplResponse(interactionRecords, globalTimers, failureCount, successCount);
    //     checkRef = rtdbService.newImplResponseRef;
    //   } else {
    //     await rtdbService.addOldImplResponse(
    //         interactionRecords, globalTimers, failureCount, successCount);
    //     checkRef = rtdbService.oldImplResponseRef;
    //   }
    //   await rtdbService.addSurveyStateInDB(AMT_SURVEY_STATE_TASK2_FINISHED, checkRef);
    // }
    // else{
    //   BotToast.showText(
    //       text: "Unknown Task!!",
    //       contentColor: Colors.redAccent[400],
    //       textStyle: TextStyle(
    //       color: Colors.white, fontSize: Configuration.TOAST_SIZE),
    //       duration: Duration(seconds: 4)
    //     );
    //   }

    // Go back to rootpage and reload
/*    if (!currentUserInfo.isAnonymous)
      Navigator.pushNamed(context, "/questionnaire", arguments: {
        'PostTask': true,
        'TaskId': taskId,
        'newImplementation': newImplementation,
        'InteractionRecords': interactionRecords,
        'GlobalTimers': globalTimers,
        'FailureCount': failureCount,
        'SuccessCount': successCount
      });
    else
      Navigator.pushNamedAndRemoveUntil(
          context, "/questionnaire", (Route<dynamic> route) => false,
          arguments: {
            'PostTask': true,
            'TaskId': taskId,
            'newImplementation': newImplementation,
            'InteractionRecords': interactionRecords,
            'GlobalTimers': globalTimers,
            'FailureCount': failureCount,
            'SuccessCount': successCount
          });
  */
  }

  void showAppropriateToolTip() {
    if (tabController.index == 0) {
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        (userManualToolTipKey.currentState as dynamic)?.ensureTooltipVisible();
      });
    } else {
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        (useWifiToolTipKey.currentState as dynamic)?.ensureTooltipVisible();
      });
    }
  }

  OverlayEntry entry;
  OverlayState overlayState;
  Offset offset = Offset(60, 300);
  void showCredentialsOverlay() {
    offset = Offset(MediaQuery.of(context).size.width / 1.9,
        MediaQuery.of(context).size.height / 1.7);
    if (entry != null) {
      entry.remove();
      entry = null;
    }

    entry = OverlayEntry(
        builder: (context) => Positioned(
            left: offset.dx,
            top: offset.dy,
            child: GestureDetector(
                onPanUpdate: (details) {
                  offset += details.delta;
                  // print(offset);
                  if (entry != null) entry.markNeedsBuild();
                },
                child: Card(
                  elevation: 50,
                  borderOnForeground: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(8.0),
                    ),
                  ),
                  color: Color.fromARGB(255, 163, 94, 175),
                  shadowColor: Colors.purple[100],
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Container(
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: Color.fromARGB(255, 255, 255, 255),
                              width: 2)),
                      height: 140,
                      width: 320,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "CREDENTIALS",
                                  style: TextStyle(
                                      fontSize: 15,
                                      decoration: TextDecoration.none,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Username: ",
                                  style: TextStyle(
                                      fontSize: 15,
                                      decoration: TextDecoration.none,
                                      color: Colors.white),
                                ),
                                SelectableText(
                                  "username@ue.edu",
                                  style: TextStyle(
                                      fontSize: 15,
                                      decoration: TextDecoration.none,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Password: ",
                                  style: TextStyle(
                                      fontSize: 15,
                                      decoration: TextDecoration.none,
                                      color: Colors.white),
                                ),
                                SelectableText(
                                  "passwordforwifi",
                                  style: TextStyle(
                                      fontSize: 15,
                                      decoration: TextDecoration.none,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                "NOTE: Please make sure you are typing the credentials correctly. ",
                                style: TextStyle(
                                    color: Color.fromARGB(255, 255, 255, 255),
                                    fontSize: 10),
                              ),
                            ),
                            Text(
                              "You will not be rewarded if you type wrong credentials.",
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 10,
                              ),
                            ),
                          ]),
                    ),
                  ),
                ))));

    overlayState = Overlay.of(context);
    overlayState.insert(entry);
  }

  void hideCredentialsOverlay() {
    if (entry != null) entry.remove();
    entry = null;
  }

  bool submitLogic() {
    if (isConnecting) return false;
    if (successCount > 0) return true;
    if(actualTaskIdentifier.contains('Ben') && successCount == 0)
      return false;
    if (failureCount > 0 &&
        !failReason.contains("WRONG_ENTERPRISE_PASSWORD") &&
        !failReason.contains('WRONG_ENTERPRISE_USERNAME')) return true;

    return false;
  }
}

// Custom expansion tile for holding the placeholder items inside "Advanced options"
class CustomExpansionTile extends StatefulWidget {
  final UserInteractionTimers currentTimer;
  final UserInteractionsRecord currentRecord;
  const CustomExpansionTile(
      {Key key, @required this.currentTimer, @required this.currentRecord})
      : super(key: key);
  @override
  _CustomExpansionTileState createState() => _CustomExpansionTileState();
}

class _CustomExpansionTileState extends State<CustomExpansionTile> {
  String metered = "Detect automatically";

  List<String> meteredList = [
    "Detect automatically",
    "Treat as metered",
    "Treat as unmetered"
  ];

  String proxy = "None";

  List<String> proxyList = ["None", "Manual", "Proxy Auto-Config"];

  String ipSettings = "DHCP";

  List<String> ipSettingsList = ["DHCP", "Static"];

  String privacy = "Use randomized MAC (default)";

  List<String> privacyList = ["Use randomized MAC (default)", "Use device MAC"];

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      onExpansionChanged: (expanded) {
        if (expanded) {
          widget.currentRecord.advancedOptionsChecked = true;
          widget.currentRecord.addInteraction(
              "Click: Advanced options expanded",
              DateTime.now().millisecondsSinceEpoch);
          widget.currentTimer.advanceOptTimer.start();
        } else {
          widget.currentTimer.advanceOptTimer.stop();
          widget.currentRecord.addInteraction("Click: Advanced options closed",
              DateTime.now().millisecondsSinceEpoch);
        }
      },
      tilePadding: EdgeInsets.all(0.0),
      title: Text("Advanced options"),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      expandedAlignment: Alignment.topLeft,
      childrenPadding: EdgeInsets.only(top: 2, bottom: 2),
      children: [
        Text(
          "Metered",
          textAlign: TextAlign.start,
          style: TextStyle(fontSize: 12.0, color: Colors.grey),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            value: metered,
            icon: Icon(Icons.arrow_downward),
            iconSize: 24,
            isExpanded: true,
            dropdownElevation: 16,
            underline: null,
            style: TextStyle(color: Colors.deepPurple),
            onChanged: (String newValue) {
              setState(() {
                metered = newValue;
              });
            },
            items: meteredList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
        Text(
          "Proxy",
          textAlign: TextAlign.start,
          style: TextStyle(fontSize: 12.0, color: Colors.grey),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            value: proxy,
            icon: Icon(Icons.arrow_downward),
            iconSize: 24,
            isExpanded: true,
            dropdownElevation: 16,
            underline: null,
            style: TextStyle(color: Colors.deepPurple),
            onChanged: (String newValue) {
              setState(() {
                proxy = newValue;
              });
            },
            items: proxyList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
        Text(
          "IP settings",
          textAlign: TextAlign.start,
          style: TextStyle(fontSize: 12.0, color: Colors.grey),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            value: ipSettings,
            icon: Icon(Icons.arrow_downward),
            iconSize: 24,
            isExpanded: true,
            dropdownElevation: 16,
            underline: null,
            style: TextStyle(color: Colors.deepPurple),
            onChanged: (String newValue) {
              setState(() {
                ipSettings = newValue;
              });
            },
            items: ipSettingsList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
        Text(
          "Privacy",
          textAlign: TextAlign.start,
          style: TextStyle(fontSize: 12.0, color: Colors.grey),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            value: privacy,
            icon: Icon(Icons.arrow_downward),
            iconSize: 24,
            isExpanded: true,
            dropdownElevation: 16,
            underline: null,
            style: TextStyle(color: Colors.deepPurple),
            onChanged: (String newValue) {
              setState(() {
                privacy = newValue;
              });
            },
            items: privacyList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

//https://stackoverflow.com/questions/58352828/flutter-design-instagram-like-balloons-tooltip-widget
class TooltipShapeBorder extends ShapeBorder {
  final double arrowWidth;
  final double arrowHeight;
  final double arrowArc;
  final double radius;

  TooltipShapeBorder({
    this.radius = 16.0,
    this.arrowWidth = 20.0,
    this.arrowHeight = 10.0,
    this.arrowArc = 0.0,
  }) : assert(arrowArc <= 1.0 && arrowArc >= 0.0);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: arrowHeight);

  @override
  Path getInnerPath(Rect rect, {TextDirection textDirection}) => null;

  @override
  Path getOuterPath(Rect rect, {TextDirection textDirection}) {
    rect = Rect.fromPoints(
        rect.topLeft, rect.bottomRight - Offset(0, arrowHeight));
    double x = arrowWidth, y = arrowHeight, r = 1 - arrowArc;
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)))
      ..moveTo(rect.bottomCenter.dx + x / 2, rect.bottomCenter.dy)
      ..relativeLineTo(-x / 2 * r, y * r)
      ..relativeQuadraticBezierTo(
          -x / 2 * (1 - r), y * (1 - r), -x * (1 - r), 0)
      ..relativeLineTo(-x / 2 * r, -y * r);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
