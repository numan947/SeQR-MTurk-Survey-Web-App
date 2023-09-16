import 'dart:async';

import 'package:wifi_qr_survey_app/MainApp.dart';
import 'package:wifi_qr_survey_app/models/Comments.dart';

class Question {
  //these are the supported question types
  static final String TFQ = "TFQ"; // True false questions
  static final String MCQ = "MCQ"; // Multiple choice questions
  static final String MAQ = "MAQ"; // Multiple answer questions
  static final String SAQ = "SAQ"; // Short answer questions
  static final String SCQ = "SCQ"; // double scale questions
  static final String SCQ_SINGLE = "SCQ_SINGLE"; // single scale questions
  static final String DCR = "DECOR"; // decorations
  static final String DDM = "DDM"; // dropdown menu
  String qRef;
  String qId;
  String qBody;
  String qType;
  bool postTask;
  int qOrder;
  List<String> qOptions;
  Pair<int> qScale;
  Pair<String> qScalePrompts;

  CommentNotification lastCommented; // set inside question fetch from db, not added or updated otherwise
  StreamSubscription lastCommentedSub;

  void cancelSub(){
    if(lastCommentedSub != null)
      lastCommentedSub.cancel();
  }

  Question({this.qId, this.qBody, this.qType, this.qOptions, this.qScale, this.qScalePrompts, this.qOrder, this.postTask});

  void update(Question q) {
    this.qId = q.qId;
    this.qBody = q.qBody;
    this.qType = q.qType;
    this.qOrder = q.qOrder;

    this.qOptions = q.qOptions;
    this.qScale = q.qScale;
    this.qScalePrompts = q.qScalePrompts;
    this.postTask = q.postTask;

    if (this.qOptions == null) this.qOptions = [];
    if (this.qScale == null) this.qScale = Pair<int>(0, 1);
    if (this.qScalePrompts == null) this.qScalePrompts = Pair<String>("", "");
  }

  Pair<dynamic> sanityCheck() {
    if (this.qId == null || this.qBody == null || this.qType == null || this.qOrder == null || this.qOrder < 0 || this.postTask == null) {
      return Pair<dynamic>(false, "Sanity check failed!");
    }
    if (this.qId.isEmpty || this.qBody.isEmpty || this.qType.isEmpty) {
      return Pair<dynamic>(false, "Sanity check failed!");
    }
    if (this.qType != SAQ && this.qType != SCQ && this.qType != SCQ_SINGLE) {
      if (this.qOptions == null || this.qOptions.length <= 0)
        return Pair<dynamic>(false, "Sanity check failed!");
    } 
    else if (this.qType == SCQ || this.qType == SCQ_SINGLE) {
      if (this.qScale == null)
        return Pair<dynamic>(false, "Sanity check failed!");
      else{
        int left = this.qScale.left;
        int right = this.qScale.right;
        if(left>=right)
          return Pair<dynamic>(false, "Sanity check failed!");
      }
      
      if (this.qScalePrompts == null ||
          this.qScalePrompts.left == null ||
          this.qScalePrompts.right == null)
        return Pair<dynamic>(false, "Sanity check failed!");
      String s1 = this.qScalePrompts.left;
      String s2 = this.qScalePrompts.right;
      if (s1.isEmpty || s2.isEmpty) return Pair<dynamic>(false, "Sanity check failed!");
    }

    return Pair<dynamic>(true, "Sanity check passed!");
  }

  Question.clone(Question q) {
    if (q != null) {
      this.qId = q.qId;
      this.postTask = q.postTask;
      this.qBody = q.qBody;
      this.qType = q.qType;
      this.qOptions = q.qOptions;
      this.qScale = q.qScale;
      this.qScalePrompts = q.qScalePrompts;
      this.qOrder = q.qOrder;
      this.qRef = q.qRef;
      if(q.lastCommented!=null)
        this.lastCommented = q.lastCommented;
      if(q.lastCommentedSub != null)
        this.lastCommentedSub = q.lastCommentedSub;
    }
    if (this.qOptions == null) this.qOptions = [];
    if (this.qScale == null) this.qScale = Pair<int>(0, 1);
    if (this.qScalePrompts == null) this.qScalePrompts = Pair<String>("", "");
    if(this.postTask == null)
      this.postTask = false;
  }

  bool isEqual(Question q){
    assert(q!=null);
    return this.postTask == q.postTask && this.qId == q.qId && this.qBody == q.qBody && this.qType == q.qType && 
           this.qOptions == q.qOptions && this.qScale == q.qScale && this.qScalePrompts == q.qScalePrompts && this.qOrder == q.qOrder && this.qRef == q.qRef;
  }
}

class QuestionResponse {
  int radioListState = -1;
  List<bool> checkListState;
  String qId;
  String qType;
  List<String> qOptions;
  Pair<int> scaleResponse;
  int singleScaleResponse;
  String briefResponse;
  String dropDownResponse;
  String dropDownOtherResponse;

  bool hasResponse = false;

  QuestionResponse({this.qId, this.qType, this.qOptions, Pair<int> qScale}) {
    if (qType == Question.MCQ || qType == Question.TFQ) radioListState = -1;
    if (qType == Question.MAQ)
      checkListState = List.filled(qOptions.length, false);
    if (qType == Question.SAQ) briefResponse = "";
    if (qType == Question.SCQ){
      int tl = qScale.left;
      int tr = qScale.right;
      int md = (tl+tr)~/2;
      scaleResponse = Pair<int>(md, md);
     } // first scale and second scale
    if(qType == Question.SCQ_SINGLE){
      singleScaleResponse = (qScale.left + qScale.right)~/2;
    }
    if(qType == Question.DDM)
      dropDownOtherResponse = "";

  }

  void update(Question q) {
    this.qId = q.qId;
    this.qType = q.qType;
    this.qOptions = q.qOptions;

    if (q.qType == Question.MCQ || q.qType == Question.TFQ) radioListState = -1;
    if (q.qType == Question.MAQ)
      checkListState = List.filled(q.qOptions.length, false);
    if (q.qType == Question.SAQ) briefResponse = "";
    if (q.qType == Question.SCQ) {
      int tl = q.qScale.left;
      int tr = q.qScale.right;
      int md = (tl+tr)~/2;
      scaleResponse = Pair<int>(md, md);
    }
    if(qType == Question.SCQ_SINGLE){
      singleScaleResponse = (q.qScale.left + q.qScale.right)~/2;
    }
    
    if(qType == Question.DDM)
      dropDownOtherResponse = "";
  }

  void addResponse(String response) {
    qOptions.add(response);
  }

  int getRadioState() {
    return radioListState;
  }

  void setRadioState(int state) {
    this.radioListState = state;
  }

  bool getCheckListState(int i) {
    if (i >= checkListState.length) return false;

    return checkListState[i];
  }

  void setCheckListState(int i, bool b) {
    if (i >= checkListState.length) return;
    checkListState[i] = b;
  }

  Future<String> getResponseJson() async {
    if (!hasResponse) return null;
    if (qType == Question.SCQ) {
      String currentSurveyState = await rtdbService.getLatestSurveyState();
      Map<String, String>taskMap;
      
      if(currentSurveyState == AMT_SURVEY_STATE_ADMIN_MODE)
        taskMap = {
          "Task-1": OTB,
          "Task-2": OTA,
          "Task-3": OTR,
          "Task-4": OTPTQ,
          "Task-5": NTB,
          "Task-6": NTA,
          "Task-7": NTR,
          "Task-8": NTPTQ,
          "Task-9": DEMQ
        };
      else
        taskMap = await rtdbService.getTaskMap();
      
      // Map<String, String>revTaskMap = taskMap.map((key, value) => MapEntry(value, key));
      
      String leftKey = taskMap["Task-1"]+"_"+taskMap["Task-2"]+"_"+taskMap["Task-3"];
      String rightKey = taskMap["Task-5"]+"_"+taskMap["Task-6"]+"_"+taskMap["Task-7"];
      return "$leftKey=${scaleResponse.left};$rightKey=${scaleResponse.right}";
    }
    if (qType == Question.SCQ_SINGLE) {
      String currentSurveyState = await rtdbService.getLatestSurveyState();
      Map<String, String>taskMap;
      
      if(currentSurveyState == AMT_SURVEY_STATE_ADMIN_MODE)
        taskMap = {
          "Task-1": OTB,
          "Task-2": OTA,
          "Task-3": OTR,
          "Task-4": OTPTQ,
          "Task-5": NTB,
          "Task-6": NTA,
          "Task-7": NTR,
          "Task-8": NTPTQ,
          "Task-9": DEMQ
        };
      else
        taskMap = await rtdbService.getTaskMap();
      
      return "$singleScaleResponse";
    }
    if (qType == Question.SAQ) return this.briefResponse;
    if (qType == Question.MCQ || qType == Question.TFQ)
      return qOptions[getRadioState()];
    if (qType == Question.MAQ) {
      List<String> tmp = [];
      for (int i = 0; i < checkListState.length; i++) {
        if (checkListState[i]) tmp.add(qOptions[i]);
      }
      return tmp.join(";");
    }

    if(qType == Question.DDM){
      if(this.dropDownOtherResponse.isEmpty)
        return this.dropDownResponse;
      else
        return this.dropDownOtherResponse;
    }
    return null;
  }
}

class UserResponse {
  String workerId;
  String email;
  String uid;
  String metadata;
  List<QuestionResponse> questionResponses;

  UserResponse() {
    this.workerId = "";
    this.email = "";
    this.uid = "";
    this.metadata = "";
    this.questionResponses = [];
  }

  void updateUserInfo(CurrentUserInfo u) {
    this.workerId = u.workerId;
    this.email = u.email;
    this.uid = u.uid;
    this.metadata = u.metadata.toString();
  }

  void addQuestionResponse(QuestionResponse response) {
    this.questionResponses.add(response);
  }

  void clearQuestionResponse() {
    this.questionResponses.clear();
  }

  Future<void> printObject() async {
    print("workerId = ${this.workerId}");
    print("email = ${this.email}");
    print("uid = ${this.uid}");
    print("metadata = ${this.metadata}");
    print("Question Responses: ");
    for (QuestionResponse qr in this.questionResponses) {
      print("${qr.qId} Response null => ${qr == null}");
      print(qr.qId + "-->" + await qr.getResponseJson());
    }
  }
}

// capture in milliseconds
class UserInteractionsRecord{
  String iType; // "newImplementation" or "oldImplementation"
  
  int totalTimeFromStartToEnd;
  int timeForEapMethod;
  int timeForPhase2AuthMethod;
  int timeForCACertSelect;
  int timeForDomainName;
  int timeForIdentity;
  int timeForAnonymousIdentity;
  int timeForPassword;
  int timeForShowPassword;
  int timeForAdvancedOptions;
  int timeForScanningQrCode;
  int timeForInstallingCertificate;

  String selectedSSID;
  String securityTypeOfSelectedSSID;
  bool selectedSSIDIsET;
  String failReason;
  
  String inputEapMethod;
  String inputPhase2Method;
  String inputCACertificate;
  String inputUserCertificate;
  String inputDomainName;
  String inputIdentity;
  String inputAnonymousIdentity;
  String inputPassword;
  String selectedCustomCertificate;
  String scannedQrCode;
  bool showPasswordChecked;
  bool advancedOptionsChecked;

  bool connectionSuccessful;
  bool clickedConnect;
  bool clickedCancel;
  bool connectAnyway;
  bool clickedAddNetworkViaQrCode;
  bool qrCodeFirstMode;
  bool barrierDismissed;

  List<Pair<dynamic>>userInteractionTrace; // Pair => first is String: description of the interaction, second is int: timestamp in milliseconds
  
  Map<String, dynamic> getUserInteractionRecordJson()
  {
    Map<String, dynamic> myMap = new Map();
    
    myMap["iType"] = this.iType;
    myMap["totalTimeFromStartToEnd"] = this.totalTimeFromStartToEnd;
    myMap["timeForEapMethod"] = this.timeForEapMethod;
    myMap["timeForPhase2AuthMethod"] = this.timeForPhase2AuthMethod;
    myMap["timeCACertSelect"] = this.timeForCACertSelect;
    myMap["timeForDomainName"] = this.timeForDomainName;
    myMap["timeForIdentity"] = this.timeForIdentity;
    myMap["timeForAnonymousIdentity"] = this.timeForAnonymousIdentity;
    myMap["timeForPassword"] = this.timeForPassword;
    myMap["timeForShowPassword"] = this.timeForShowPassword;
    myMap["timeForAdvancedOptions"] = this.timeForAdvancedOptions;
    myMap["timeForScanningQrCode"] = this.timeForScanningQrCode;
    myMap["timeForInstallingCertificate"] = this.timeForInstallingCertificate;

    
    myMap["selectedSSID"] = this.selectedSSID;
    myMap["securityTypeOfSelectedSSID"] = this.securityTypeOfSelectedSSID;
    myMap['selectedSSIDIsET'] = this.selectedSSIDIsET;
    myMap["inputEapMethod"] = this.inputEapMethod;
    myMap["inputPhase2Method"] = this.inputPhase2Method;
    myMap["inputCACertificate"] = this.inputCACertificate;
    myMap["inputUserCertificate"] = this.inputUserCertificate;
    myMap["inputDomainName"] = this.inputDomainName;
    myMap["inputIdentity"] = this.inputIdentity;
    myMap["inputAnonymousIdentity"] = this.inputAnonymousIdentity;
    myMap["inputPassword"] = this.inputPassword;
    myMap["scannedQrCode"] = this.scannedQrCode;
    myMap["showPasswordChecked"] = this.showPasswordChecked;
    myMap["advancedOptionsChecked"] = this.advancedOptionsChecked;
    myMap["connectionSuccessful"] = this.connectionSuccessful;
    myMap["clickedConnect"] = this.clickedConnect;
    myMap["clickedCancel"] = this.clickedCancel;
    myMap["connectAnyway"] = this.connectAnyway;
    myMap['clickedAddNetworkViaQrCode'] = this.clickedAddNetworkViaQrCode;
    myMap["barrierDismissed"] = this.barrierDismissed;
    myMap["qrCodeFirstMode"] = this.qrCodeFirstMode;
    myMap["selectedCustomCertificate"] = this.selectedCustomCertificate;
    myMap['failReason'] = this.failReason;

    Map<String, dynamic> traceMap = new Map();

    for(int i=0; i<userInteractionTrace.length; i++){
      Pair<dynamic>tmp = userInteractionTrace[i];

      traceMap["$i"] = {
        "description": tmp.left,
        "timestamp(millisecondsSinceEpoch)":tmp.right
      };
    }
    myMap["UserInteractionsTrace"] = traceMap;

    return myMap;
  }
  
  UserInteractionsRecord(){
    userInteractionTrace = [];
  }

  void updateUserInteractionTimes(UserInteractionTimers t){
    totalTimeFromStartToEnd = t.totalTimeTimer.elapsedMicroseconds;
    timeForEapMethod = t.eapTimer.elapsedMicroseconds;
    timeForPhase2AuthMethod = t.phase2Timer.elapsedMicroseconds;
    timeForCACertSelect = t.cacertTimer.elapsedMicroseconds;
    timeForDomainName = t.domainNameTimer.elapsedMicroseconds;
    timeForIdentity = t.identityTimer.elapsedMicroseconds;
    timeForAnonymousIdentity = t.anonIdentityTimer.elapsedMicroseconds;
    timeForPassword = t.passwordTimer.elapsedMicroseconds;
    timeForShowPassword = t.showPasswordTimer.elapsedMicroseconds;
    timeForAdvancedOptions = t.advanceOptTimer.elapsedMicroseconds;
    timeForScanningQrCode = t.qrCodeScanTimer.elapsedMicroseconds;
    // timeForInstallingCertificate = t.certInstallTimer.elapsedMicroseconds;
  }

  void updateGlobalTimes(GlobalTimers t){
    //todo
  }

  void addInteraction(String description, int timeStamp){
    userInteractionTrace.add(Pair<dynamic>(description, timeStamp));
  }

  

  void printInteraction(){
    print("\nPRINTING USER INTERACTION VALUES FOR: $iType\n");
    print("qrCodeFirstMode = $qrCodeFirstMode");
    print("selectedSSID = ${selectedSSID}");
    print("securityTypeOfSelectedSSID = ${securityTypeOfSelectedSSID}");
    print("selectedSSIDIsET = ${selectedSSIDIsET}");
    print("inputEapMethod = ${inputEapMethod}");
    print("inputPhase2Method = ${inputPhase2Method}");
    print("inputCACertificate = ${inputCACertificate}");
    print("inputDomainName = ${inputDomainName}");
    print("inputIdentity = ${inputIdentity}");
    print("inputAnonymousIdentity = ${inputAnonymousIdentity}");
    print("inputPassword = ${inputPassword}");
    print("scannedQrCode = ${scannedQrCode}");
    print("showPasswordChecked = ${showPasswordChecked}");
    print("advancedOptionsChecked = ${advancedOptionsChecked}");
    print("connectionSuccessful = ${connectionSuccessful}");
    print("clickedAddNetworkViaQrCode = $clickedAddNetworkViaQrCode");
    print("clickedConnect = ${clickedConnect}");
    print("clickedCancel = ${clickedCancel}");
    print("barrierDismissed = ${barrierDismissed}");
    print("selectedCustomCertificate - ${selectedCustomCertificate}");


    if(userInteractionTrace.length == 0)
      print("NO TRACE RECORDED");
    else
      print("USER INTERACTION TRACES: ");
    for(int i=0 ;i<userInteractionTrace.length; i++){
      Pair tmp = userInteractionTrace[i];
      print("ACTION: ${tmp.left} => timestamp: ${tmp.right}");
    }
    print("----------------------------------------\n");
  }

}

class GlobalTimers{
  final Stopwatch taskLevelTimer = Stopwatch();
  final Stopwatch wifiUITimer = Stopwatch();
  final Stopwatch setupGuideTimer = Stopwatch();
  final Stopwatch instructionPageTimer = Stopwatch();
  final Stopwatch certInstallTimer_CSE_A = Stopwatch();
  final Stopwatch certInstallTimer_CSE_B = Stopwatch();
  final Stopwatch certInstallTimer_ue_secure = Stopwatch();
  final Stopwatch tofuPromptTimer = Stopwatch();
  
  void printAll(){
    print("\n--------GLOBAL TIMERS DETAILS-----------\n");
    print("taskLevelTimer: ${this.taskLevelTimer.elapsed} | Running: ${this.taskLevelTimer.isRunning}");
    print("wifiUITimer: ${this.wifiUITimer.elapsed} | Running: ${this.wifiUITimer.isRunning}");
    print("setupGuideTimer: ${this.setupGuideTimer.elapsed} | Running: ${this.setupGuideTimer.isRunning}");
    print("InstructionPageTimer: ${this.instructionPageTimer.elapsed} | Running: ${this.instructionPageTimer.isRunning}");
    print("\n----------------------------------------\n");
  }
}

class UserInteractionTimers{
  final Stopwatch totalTimeTimer = Stopwatch();
  final Stopwatch eapTimer = Stopwatch();
  final Stopwatch phase2Timer = Stopwatch();
  final Stopwatch cacertTimer = Stopwatch();
  final Stopwatch identityTimer = Stopwatch();
  final Stopwatch anonIdentityTimer = Stopwatch();
  final Stopwatch passwordTimer = Stopwatch();
  final Stopwatch showPasswordTimer = Stopwatch();
  final Stopwatch advanceOptTimer = Stopwatch();
  final Stopwatch qrCodeScanTimer = Stopwatch();
  final Stopwatch domainNameTimer = Stopwatch();
  // final Stopwatch certInstallTimer = Stopwatch();

  void printRunningTimers(){
    print("\n-------CURRENT LOCAL TIMERS-------------\n");
    if(totalTimeTimer.isRunning)
      print("totalTimeTimer: ${this.totalTimeTimer.elapsed}");
    if(eapTimer.isRunning)
      print("eapTimer: ${this.eapTimer.elapsed}");
    if(phase2Timer.isRunning)
      print("phase2Timer: ${this.phase2Timer.elapsed}");
    if(cacertTimer.isRunning)
      print("cacertTimer: ${this.cacertTimer.elapsed}");
    if(identityTimer.isRunning)
      print("identityTimer: ${this.identityTimer.elapsed}");
    if(anonIdentityTimer.isRunning)
      print("anonIdentityTimer: ${this.anonIdentityTimer.elapsed}");
    if(passwordTimer.isRunning)
      print("passwordTimer: ${this.passwordTimer.elapsed}");
    if(showPasswordTimer.isRunning)
      print("showPasswordTimer: ${this.showPasswordTimer.elapsed}");
    if(advanceOptTimer.isRunning)
      print("advanceOptTimer: ${this.advanceOptTimer.elapsed}");
    if(qrCodeScanTimer.isRunning)
      print("qrCodeScanTimer: ${this.qrCodeScanTimer.elapsed}");
    if(domainNameTimer.isRunning)
      print("domainNameTimer: ${this.domainNameTimer.elapsed}");
    // if(certInstallTimer.isRunning)
    //   print("certInstallTimer: ${this.certInstallTimer.elapsed}");

    
    print("\n---------------------------------------\n");
  }

  void resetAll(){
    totalTimeTimer.reset();
    eapTimer.reset();
    phase2Timer.reset();
    cacertTimer.reset();
    identityTimer.reset();
    anonIdentityTimer.reset();
    passwordTimer.reset();
    showPasswordTimer.reset();
    advanceOptTimer.reset();
    qrCodeScanTimer.reset();
    domainNameTimer.reset();
    // certInstallTimer.reset();

  }

   void stopAll(){
    totalTimeTimer.stop();
    eapTimer.stop();
    phase2Timer.stop();
    cacertTimer.stop();
    identityTimer.stop();
    anonIdentityTimer.stop();
    passwordTimer.stop();
    showPasswordTimer.stop();
    advanceOptTimer.stop();
    qrCodeScanTimer.stop();
    domainNameTimer.stop();
    // certInstallTimer.stop();
  }


  void printAllElapsed(){
    print("\nPRINTING ALL TIMER VALUES IN MICROSECONDS");
    print("totalTimeTimer: ${this.totalTimeTimer.elapsedMicroseconds} microseconds");
    print("eapTImer: ${this.eapTimer.elapsedMicroseconds} microseconds");
    print("phase2Timer: ${this.phase2Timer.elapsedMicroseconds} microseconds");
    print("cacertTimer: ${this.cacertTimer.elapsedMicroseconds} microseconds");
    print("identityTimer: ${this.identityTimer.elapsedMicroseconds} microseconds");
    print("anonIdentityTimer: ${this.anonIdentityTimer.elapsedMicroseconds} microseconds");
    print("passwordTimer: ${this.passwordTimer.elapsedMicroseconds} microseconds");
    print("showPasswordTimer: ${this.showPasswordTimer.elapsedMicroseconds} microseconds");
    print("advanceOptTimer: ${this.advanceOptTimer.elapsedMicroseconds} microseconds");
    print("qrCodeScanTimer: ${this.qrCodeScanTimer.elapsedMicroseconds} microseconds");
    print("domainNameTimer: ${this.domainNameTimer.elapsedMicroseconds} microseconds");
    // print("certInstallTimer: ${this.certInstallTimer.elapsedMicroseconds} microseconds");
    print("------------------------------------\n");
  }

}