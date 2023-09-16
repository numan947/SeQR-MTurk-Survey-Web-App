import 'dart:async';
import 'dart:js';
import 'dart:math';
import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_strategy/url_strategy.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:wifi_qr_survey_app/Configuration.dart';
import 'package:wifi_qr_survey_app/LandingPage.dart';
import 'package:wifi_qr_survey_app/InstallCACertificatePage.dart';
import 'package:wifi_qr_survey_app/QuestionnairePage.dart';
import 'package:wifi_qr_survey_app/WifiNetworkListPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ThankYou.dart';
import 'models/Comments.dart';
import 'models/QuestionnaireRelatedClasses.dart';


final bool dbug = false;
final bool newDbug = false;
bool userModeForAdmin = false;
const String AMT_WORKER_ID = "AMT_WORKER_ID";
const String AMT_SURVEY_COMPLETION_STATE = "AMT_SURVEY_COMPLETION_STATE";
const String OTB = "oldImplBen";
const String OTA = "oldImplAtk";
const String OTR = "oldImplRel";
const String NTB = "newImplBen";
const String NTA = "newImplAtk";
const String NTR = "newImplRel";
const String OTPTQ = "oldImplPTQ";
const String NTPTQ = "newImplPTQ";
const String DEMQ  = "demQ";
const Map<String, String> ADMIN_TASK_MAP = {
          "Task-1": OTB,
          "Task-2": OTA,
          "Task-3": OTR,
          "Task-4": OTPTQ,
          "Task-5": NTB,
          "Task-6": NTA,
          "Task-7": NTR,
          "Task-8": NTPTQ,
          "Task-9": DEMQ,
          "TofuMode": "True"
        };
const String AMT_SURVEY_STATE_NO_TASK_FINISHED =
    "AMT_SURVEY_STATE_NO_TASK_FINISHED";
const String AMT_SURVEY_STATE_TASK1_FINISHED =
    "AMT_SURVEY_STATE_TASK1_FINISHED";
const String AMT_SURVEY_STATE_TASK2_FINISHED =
    "AMT_SURVEY_STATE_TASK2_FINISHED";
const String AMT_SURVEY_STATE_TASK3_FINISHED =
    "AMT_SURVEY_STATE_TASK3_FINISHED";
const String AMT_SURVEY_STATE_TASK4_FINISHED =
    "AMT_SURVEY_STATE_TASK4_FINISHED";
const String AMT_SURVEY_STATE_TASK5_FINISHED =
    "AMT_SURVEY_STATE_TASK5_FINISHED";
const String AMT_SURVEY_STATE_TASK6_FINISHED =
    "AMT_SURVEY_STATE_TASK6_FINISHED";
const String AMT_SURVEY_STATE_TASK7_FINISHED =
    "AMT_SURVEY_STATE_TASK7_FINISHED";
const String AMT_SURVEY_STATE_TASK8_FINISHED =
    "AMT_SURVEY_STATE_TASK8_FINISHED";
const String AMT_SURVEY_STATE_TASK9_FINISHED =
    "AMT_SURVEY_STATE_TASK9_FINISHED";
const String AMT_SURVEY_STATE_CONSENT_REQUIRED =
    "AMT_SURVEY_STATE_CONSENT_REQUIRED";
const String AMT_SURVEY_STATE_ADMIN_MODE = "AMT_SURVEY_STATE_ADMIN_MODE";

class Pair<T> {
  Pair(this.left, this.right);

  T left;
  T right;

  @override
  String toString() => 'Pair[$left, $right]';
}

class FirebaseAuthService {
  FirebaseAuth auth;
  UserCredential credential;
  User user;

  FirebaseAuthService() {
    if (auth == null) this.auth = FirebaseAuth.instance;

    FirebaseAuth.instance.authStateChanges().listen((User user) {
      if (user == null) {
        if (dbug) print('User is currently signed out!');
        this.user = null;
      } else {
        this.user = user;
        if (dbug) print('User is signed in!');
      }
    });
  }

  bool hasAdminAccess() {
    return isSignedIn() && !this.user.isAnonymous;
  }

  User getUser() {
    return this.user;
  }

  FirebaseAuth getAuth() {
    return auth;
  }

  UserCredential getCredentials() {
    return credential;
  }

  Future<bool> signIn(String email, String password) async {
    if (dbug) print(email);
    if (dbug) print(password);

    try {
      credential = await auth.signInWithEmailAndPassword(
          email: email, password: password);
      this.user = credential.user;
      return true;
    } on FirebaseAuthException catch (e) {
      if (dbug) print("Authentication failed!");
      this.credential = null;
      this.user = null;
      return false;
    }
  }

  Future<bool> signInAnonymous(BuildContext buildContext) async {
    assert(currentUserInfo.workerId != null);
    try {
      credential = await auth.signInAnonymously();
      this.user = credential.user;
      await rtdbService.addWorkerID(currentUserInfo.workerId, this.user.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      this.credential = null;
      this.user = null;
      return false;
    }
  }

  Future<void> signOut() async {
    // cancel all subscritpion
    if (!currentUserInfo.isAnonymous) {
      rtdbService.removeCommentListener();
      for (StreamSubscription s in rtdbService.dbChangeListeners)
        if (s != null) s.cancel();
      rtdbService.dbChangeListeners.clear();
    }

    if (isSignedIn() && this.user.isAnonymous) {
      await prefs.remove(AMT_WORKER_ID);
      await prefs.remove(AMT_SURVEY_COMPLETION_STATE);
      await rtdbService.removeFromTempUidWorkerIdMap(this.user.uid);
    }
    await auth.signOut();
  }

  bool isSignedIn() {
    if (this.user != null) {
      currentUserInfo.setUserInfo(this.user);
      if (currentUserInfo.workerId == null && this.user.isAnonymous) {
        rtdbService.getWorkerIdFromUid(this.user.uid);
      }
      return true;
    } else {
      currentUserInfo = new CurrentUserInfo();
      return false;
    }
  }
}

class FirebaseStorageService {
  final String oldInstructionsFolder = "old_instructions/";
  final String newInstructionsFolder = "new_instructions/";
  final String tofuInstructionsFolder = "tofu_instructions/";

  FirebaseStorage storage;
  FirebaseStorageService() {
    if (storage == null) storage = FirebaseStorage.instance;
  }

  Future<Pair<String>> getRandomInstructionFile(bool tofu) async {
    try {
      
      String oldUIFolder = oldInstructionsFolder;
      if(tofu)
        oldUIFolder = tofuInstructionsFolder;

      final oldStorageRef = storage.ref(oldUIFolder);
      final oldInstList = await oldStorageRef.listAll();
      final newStorageRef = storage.ref(newInstructionsFolder);
      final newInstList = await newStorageRef.listAll();

      //randomize
      Pair<int> randomInts = await rtdbService.getRandomInts();
      if (randomInts == null) {
        return null;
      }

      int c1 = randomInts.left % oldInstList.items.length;
      int c2 = randomInts.right % newInstList.items.length;
      return Pair(oldInstList.items[c1].name, newInstList.items[c2].name);
    } on FirebaseException catch (e) {
      if (dbug)
        print("LIST FILE FAILED DURING GETTING RANDOM INSTRUCTION FILE...");
      return null;
    }
  }

  Future<Pair<String>> getDownloadUrl(
      Pair<String> oldAndNewInstructions, bool tofu) async {
    try {

      String oldUIFolder = oldInstructionsFolder;
      if(tofu)
        oldUIFolder = tofuInstructionsFolder;
        
      final oldUrl = await storage
          .ref(oldUIFolder)
          .child(oldAndNewInstructions.left)
          .getDownloadURL();
      final newUrl = await storage
          .ref(newInstructionsFolder)
          .child(oldAndNewInstructions.right)
          .getDownloadURL();
      return Pair<String>(oldUrl, newUrl);
    } on FirebaseException catch (e) {
      if (dbug) print("FILE NOT FOUND IN STORAGE! REPOPULATING....");
      return null;
    }
  }
}

class FirebaseRTDBService {
  final String blackListedWorkerIdsRef = "/blacklist";
  final String workerIdsRef = "/worker_ids";
  final String tempUidWorkerIdMap = "/temp_uid_worker_id_map";

  final String questionsRef = "/questions";
  final String questionIdsRef = "/question_ids";
  final String questionChangedref = "/questions_changed";

  final String oldImplResponseRef = '/responses/old_impl_responses';
  final String newImplResponseRef = '/responses/new_impl_responses';
  final String questResponseRef = '/responses/question_responses';

  final String surveyStatesRef = "/survey_states";
  final String surveyState0 = "/survey_states/survey_state_0";
  final String surveyState1 = "/survey_states/survey_state_1";
  final String surveyState2 = "/survey_states/survey_state_2";
  final String surveyState3 = "/survey_states/survey_state_3";
  final String surveyState4 = "/survey_states/survey_state_4";
  final String surveyState5 = "/survey_states/survey_state_5";
  final String surveyState6 = "/survey_states/survey_state_6";
  final String surveyState7 = "/survey_states/survey_state_7";
  final String surveyState8 = "/survey_states/survey_state_8";
  final String surveyState9 = "/survey_states/survey_state_9";
  final String surveyStateAdmin = "/survey_states/survey_state_admin";

  final String amtCodesRef = "/amt_codes";
  final String consentRef = "/consent_given";

  final String taskMapRef = "/task_map";
  final String instructionMapRef = "/instruction_map";

  final String oldImplHtmlPromptRef = "/prompts/old_impl_prompt";
  final String newImplHtmlPromptRef = "/prompts/new_impl_prompt";
  final String questionHtmlPromptRef = "/prompts/question_impl_prompt";
  final String consentPromptRef = "/prompts/consent_prompt";

  final String commentsRef = "/comments";
  final String lastCommentedRef = "/last_commented";

  final String RNGRef = "/RNG";

  final String listStringdelim = ";";
  StreamSubscription commentSubscription;
  List<StreamSubscription> dbChangeListeners = [];

  FirebaseDatabase rtdb;

  FirebaseRTDBService() {
    if (rtdb == null) rtdb = FirebaseDatabase.instance;
  }

  FirebaseDatabase getRTDB() {
    return rtdb;
  }

  void addCommentListener(String qId, Function callBack) {
    //remove the last subscription, ideally this should be automatically done by clients
    removeCommentListener();
    commentSubscription = rtdb
        .ref(commentsRef + "/" + qId)
        .limitToLast(1)
        .onChildAdded
        .listen((event) {
      var mp = Map<String, String>.from(event.snapshot.value);
      var key = event.snapshot.key;

      Comment c = Comment(
          uid: mp["uid"],
          comment: mp["comment"],
          date: DateTime.parse(mp["date"]).toLocal(),
          email: mp["email"]);
      c.commentId = key;
      callBack(c);
    });
  }

  void removeCommentListener() {
    if (commentSubscription != null) {
      if (dbug) print("Subscription cancelled!");
      commentSubscription.cancel();
      commentSubscription = null;
    }
  }

  Future<List<Comment>> getComments(String qId) async {
    assert(!currentUserInfo.isAnonymous);

    DataSnapshot data = await rtdb.ref(commentsRef + "/" + qId).get();
    if (data.value == null) return [];
    var mapOfMaps = Map<String, dynamic>.from(data.value);
    List<Comment> lst = [];

    for (var key in mapOfMaps.keys) {
      var mp = mapOfMaps[key];

      Comment c = Comment(
          uid: mp["uid"],
          comment: mp["comment"],
          date: DateTime.parse(mp["date"]).toLocal(),
          email: mp["email"]);
      c.commentId = key;
      lst.add(c);
    }

    return lst;
  }

  Future<void> addComment(
      String qId, Comment c, String qBody, String qType) async {
    assert(!currentUserInfo.isAnonymous);
    DatabaseReference tmpRef = rtdb.ref(commentsRef + "/" + qId).push();
    await tmpRef.set({
      "uid": c.uid,
      "email": c.email,
      "date": c.date.toUtc().toString(),
      "comment": c.comment,
      "qBody": qBody,
      "qType": qType
    });
    c.commentId = tmpRef.key;

    await rtdb.ref(lastCommentedRef + "/" + qId).set({
      "uid": c.uid,
      "email": c.email,
      "date": c.date.toUtc().toString(),
    });
  }

  void addCommentNotificationListenerToQuestion(
      Question q, Function stateSetter) {
    if (dbug) print(q.qId);
    q.lastCommentedSub =
        rtdb.ref(lastCommentedRef + "/" + q.qId).onValue.listen((event) {
      if (dbug) print(lastCommentedRef + "/" + q.qId);
      if (event.snapshot.exists && event.snapshot.value != null) {
        Map<String, String> mp = Map.from(event.snapshot.value);
        CommentNotification newNotif = CommentNotification(
            qID: q.qId,
            lastCommentedUID: mp["uid"],
            lastCommentedDate: DateTime.parse(mp["date"]).toLocal().toString(),
            lastCommentedEmail: mp["email"]);
        if (q.lastCommented == null ||
            q.lastCommented.lastCommentedUID != newNotif.lastCommentedUID ||
            q.lastCommented.lastCommentedDate != newNotif.lastCommentedDate) {
          stateSetter(() {
            q.lastCommented = newNotif;
          });
        }
      }
    });
    dbChangeListeners.add(q.lastCommentedSub);
  }

  Future<Question> getQuestion(String qId) async {
    final snapshot =
        await rtdbService.getRTDB().ref().child(questionsRef + "/" + qId).get();
    if (snapshot.exists) {
      var mapOfMaps = Map<String, dynamic>.from(snapshot.value);

      String qBody = mapOfMaps["qBody"];
      String qType = mapOfMaps["qType"];
      String qOptionsString = mapOfMaps["qOptions"];
      String qScaleString = mapOfMaps["qScale"];
      String qScalePromptsString = mapOfMaps["qScalePrompts"];
      int qOrder = mapOfMaps["qOrder"];
      bool postTask = mapOfMaps['postTask'];

      if (postTask == null) postTask = false;
      if (qOrder == null)
        qOrder = -1; // using this we will basically renumber everything

      List<String> qOptions = [];
      if (qOptionsString != null) {
        qOptions = qOptionsString.split(listStringdelim);
      }

      List<String> temp = [];

      Pair<int> qScale = Pair<int>(0, 0);
      if (qScaleString != null) {
        temp = qScaleString.split(listStringdelim);
        qScale.left = int.parse(temp[0]);
        qScale.right = int.parse(temp[1]);
      }

      Pair<String> qScalePrompts = Pair<String>("", "");
      if (qScalePromptsString != null) {
        temp = qScalePromptsString.split(listStringdelim);
        qScalePrompts.left = temp[0];
        qScalePrompts.right = temp[1];
      }

      // if(qType!=Question.SAQ)
      //   print(List.from(mapOfMaps["qOptions"]));
      // print(qId);
      // print(mapOfMaps["qOptions"]);
      // print("$qId => qOrder is $qOrder");

      if (dbug) print("-----------------$qId------------------------");
      CommentNotification lastCommented;
      if (!currentUserInfo.isAnonymous) {
        DataSnapshot lc = await rtdb.ref(lastCommentedRef + "/" + qId).get();
        if (lc.exists) {
          Map<String, String> mp = Map.from(lc.value);
          lastCommented = CommentNotification(
              qID: qId,
              lastCommentedUID: mp["uid"],
              lastCommentedDate:
                  DateTime.parse(mp["date"]).toLocal().toString(),
              lastCommentedEmail: mp["email"]);
        } else {
          if (dbug) print("LC IS NULL");
        }
      }

      if (dbug) print("--------------------$qId--------------------");

      Question newQ = Question(
          qId: qId,
          qBody: qBody,
          qType: qType,
          qOptions: qOptions,
          qScale: qScale,
          qScalePrompts: qScalePrompts,
          qOrder: qOrder,
          postTask: postTask);

      newQ.lastCommented = lastCommented;
      newQ.lastCommentedSub = null;
      return newQ;
    } else
      return null;
  }

  Future<List<String>> getQuestionIds() async {
    final snapshot =
        await rtdbService.getRTDB().ref().child(questionIdsRef).get();
    List<String> tmp = [];
    if (snapshot.exists) {
      var myMap = Map<String, dynamic>.from(snapshot.value);
      for (var v in myMap.values) {
        if (dbug) print("Getting: ID=" + v);
        tmp.add(v as String);
      }
    }
    return tmp;
  }

  Future<Pair<dynamic>> getQuestions(bool postTaskFilter, bool getAll) async {
    final snapshot =
        await rtdbService.getRTDB().ref().child(questionIdsRef).get();
    List<Question> allQuestions = [];
    bool reOrderAndSave = false;

    if (snapshot.exists) {
      var myMap = Map<String, dynamic>.from(snapshot.value);
      final ids = Set();
      for (var v in myMap.keys) {
        String qRef = v;
        String qId = myMap[v];
        Question q = await getQuestion(qId);

        if (getAll) {
          q.qRef = qRef;
          if (q.qOrder == -1) reOrderAndSave = true;
          allQuestions.add(q);
          ids.add(q.qOrder);
          if (dbug) print(q.qOrder);
        } else if (postTaskFilter == q.postTask) {
          q.qRef = qRef;
          if (q.qOrder == -1) reOrderAndSave = true;
          allQuestions.add(q);
          ids.add(q.qOrder);
          if (dbug) print(q.qOrder);
        }
      }

      if (ids.length != allQuestions.length) {
        // this can happen if someone deletes weirdly
        if (dbug) {
          print("HELLO WORLD");
          print(ids.length);
          print(allQuestions.length);
        }
        reOrderAndSave = true;
      }
    }
    return Pair<dynamic>(reOrderAndSave, allQuestions);
  }

  Future<void> addQuestion(Question q) async {
    DatabaseReference tmpRef = rtdb.ref(questionIdsRef + "/").push();
    await tmpRef.set(q.qId);
    q.qRef = tmpRef.key;

    await rtdb.ref(questionsRef + "/" + q.qId).set({
      "qBody": q.qBody,
      "qType": q.qType,
      "qOptions":
          q.qType == Question.SAQ ? null : q.qOptions.join(listStringdelim),
      "qScale": "${q.qScale.left};${q.qScale.right}",
      "qScalePrompts":
          "${q.qScalePrompts.left}$listStringdelim${q.qScalePrompts.right}",
      "uid": currentUserInfo.uid,
      "qOrder": q.qOrder,
      "postTask": q.postTask
    });
  }

  Future<void> updateQuestion(Question q) async {
    await rtdb.ref(questionsRef + "/" + q.qId).update({
      "qBody": q.qBody,
      "qType": q.qType,
      "qOptions":
          q.qType == Question.SAQ ? null : q.qOptions.join(listStringdelim),
      "qScale": "${q.qScale.left};${q.qScale.right}",
      "qScalePrompts":
          "${q.qScalePrompts.left}$listStringdelim${q.qScalePrompts.right}",
      "uid": currentUserInfo.uid,
      "qOrder": q.qOrder,
      "postTask": q.postTask
    });
  }

  Future<void> deleteQuestion(Question q) async {
    await rtdb.ref(questionIdsRef + "/" + q.qRef).remove();
    await rtdb.ref(questionsRef + "/" + q.qId).remove();
    if (q.lastCommentedSub != null) q.lastCommentedSub.cancel();
  }

  Future<void> saveInteractionResponse(
      List<UserInteractionsRecord> interactionRecords,
      GlobalTimers globalTimers,
      int failureCount,
      int successCount,
      String actualTaskId,
      String fakeTaskId, bool tofuAvailable) async {
    String key = await getDbStateKey();
    if (newDbug) print("Push for: $key");
    
    String selectedRef = (actualTaskId.contains('new')?newImplResponseRef:oldImplResponseRef);
    
    
    DatabaseReference tmpRef =
        rtdb.ref(selectedRef + "/" + key + "/" + actualTaskId);
    if (newDbug) print(tmpRef.path);

    Map<String, dynamic> mp = new Map();
    for (int i = 0; i < interactionRecords.length; i++) {
      UserInteractionsRecord u = interactionRecords[i];
      mp["$i"] = u.getUserInteractionRecordJson();
    }

    await tmpRef.set({
      "workerId": currentUserInfo.workerId,
      "email": currentUserInfo.email,
      "uid": currentUserInfo.uid,
      "metadata": currentUserInfo.metadata.toString(),
      "isAdmin": !currentUserInfo.isAnonymous,
      "interactionRecords": mp,
      "taskLevelTimerTime": globalTimers.taskLevelTimer.elapsedMicroseconds,
      "wifiUITimerTime": globalTimers.wifiUITimer.elapsedMicroseconds,
      "setupGuideTimerTime": globalTimers.setupGuideTimer.elapsedMicroseconds,
      "instructionPageTimerTime":
          globalTimers.instructionPageTimer.elapsedMicroseconds,
      "CSE_SEC_A_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_CSE_A.elapsedMicroseconds,
      "CSE_SEC_B_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_CSE_B.elapsedMicroseconds,
      "UE_SECURE_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_ue_secure.elapsedMicroseconds,
      "tofuPromptTimerTime":globalTimers.tofuPromptTimer.elapsedMicroseconds,
      "enterpriseConnectionFailureCount": failureCount,
      "enterpriseConnectionSuccessCount": successCount,
      "fakeTaskId": fakeTaskId,
      "actualTaskId":actualTaskId,
      "tofuMode":tofuAvailable
    });
  }

 Future<void> addQuestionnaireResponse(UserResponse userResponse, String savePath, bool newImplementation, bool tofu) async {
    DatabaseReference tmpRef = rtdb.ref(questResponseRef + "/" + savePath);
    if (newDbug) print(tmpRef.path);

    Map<String, Object> jsonMap = Map();
    for (int i = 0; i < userResponse.questionResponses.length; i++) {
      QuestionResponse qr = userResponse.questionResponses[i];
      jsonMap["qId = ${qr.qId}"] = {
        "qType": qr.qType,
        "qResponse": await qr.getResponseJson()
      };
    }
    await tmpRef.set({
      "workerId": currentUserInfo.workerId,
      "email": currentUserInfo.email,
      "uid": currentUserInfo.uid,
      "metadata": currentUserInfo.metadata.toString(),
      "isAdmin": !currentUserInfo.isAnonymous,
      "scaleResponses": jsonMap,
      "newImplementation":newImplementation,
      "tofuMode":tofu
    });
  }


  Future<void> addOldImplResponse(
      List<UserInteractionsRecord> interactionRecords,
      GlobalTimers globalTimers,
      int failureCount,
      int successCount,
      UserResponse userResponse) async {
    String key = await getDbStateKey();
    if (dbug) print("Task-1 Push for: $key");
    DatabaseReference tmpRef = rtdb.ref(oldImplResponseRef + "/" + key);
    if (dbug) print(tmpRef.path);

    Map<String, dynamic> mp = new Map();
    for (int i = 0; i < interactionRecords.length; i++) {
      UserInteractionsRecord u = interactionRecords[i];
      mp["$i"] = u.getUserInteractionRecordJson();
    }
    Map<String, Object> jsonMap = Map();
    for (int i = 0; i < userResponse.questionResponses.length; i++) {
      QuestionResponse qr = userResponse.questionResponses[i];
      jsonMap["qId = ${qr.qId}"] = {
        "qType": qr.qType,
        "qResponse": await qr.getResponseJson()
      };
    }
    await tmpRef.set({
      "workerId": currentUserInfo.workerId,
      "email": currentUserInfo.email,
      "uid": currentUserInfo.uid,
      "metadata": currentUserInfo.metadata.toString(),
      "isAdmin": !currentUserInfo.isAnonymous,
      "interactionRecords": mp,
      "taskLevelTimerTime": globalTimers.taskLevelTimer.elapsedMicroseconds,
      "wifiUITimerTime": globalTimers.wifiUITimer.elapsedMicroseconds,
      "setupGuideTimerTime": globalTimers.setupGuideTimer.elapsedMicroseconds,
      "instructionPageTimerTime":
          globalTimers.instructionPageTimer.elapsedMicroseconds,
      "CSE_SEC_A_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_CSE_A.elapsedMicroseconds,
      "CSE_SEC_B_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_CSE_B.elapsedMicroseconds,
      "UE_SECURE_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_ue_secure.elapsedMicroseconds,
      "enterpriseConnectionFailureCount": failureCount,
      "enterpriseConnectionSuccessCount": successCount,
      "scaleResponses": jsonMap
    });
  }

  Future<void> addNewImplResponse(
      List<UserInteractionsRecord> interactionRecords,
      GlobalTimers globalTimers,
      int failureCount,
      int successCount,
      UserResponse userResponse) async {
    String key = await getDbStateKey();
    if (dbug) print("Task-2 Push for: $key");
    DatabaseReference tmpRef = rtdb.ref(newImplResponseRef + "/" + key);
    if (dbug) print(tmpRef.path);

    Map<String, dynamic> mp = new Map();
    for (int i = 0; i < interactionRecords.length; i++) {
      UserInteractionsRecord u = interactionRecords[i];
      mp["$i"] = u.getUserInteractionRecordJson();
    }

    Map<String, Object> jsonMap = Map();
    for (int i = 0; i < userResponse.questionResponses.length; i++) {
      QuestionResponse qr = userResponse.questionResponses[i];
      jsonMap["qId = ${qr.qId}"] = {
        "qType": qr.qType,
        "qResponse": await qr.getResponseJson()
      };
    }
    await tmpRef.set({
      "workerId": currentUserInfo.workerId,
      "email": currentUserInfo.email,
      "uid": currentUserInfo.uid,
      "metadata": currentUserInfo.metadata.toString(),
      "isAdmin": !currentUserInfo.isAnonymous,
      "interactionRecords": mp,
      "taskLevelTimerTime": globalTimers.taskLevelTimer.elapsedMicroseconds,
      "wifiUITimerTime": globalTimers.wifiUITimer.elapsedMicroseconds,
      "setupGuideTimerTime": globalTimers.setupGuideTimer.elapsedMicroseconds,
      "instructionPageTimerTime":
          globalTimers.instructionPageTimer.elapsedMicroseconds,
      "CSE_SEC_A_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_CSE_A.elapsedMicroseconds,
      "CSE_SEC_B_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_CSE_B.elapsedMicroseconds,
      "UE_SECURE_CERT_INSTALL_TIMER":
          globalTimers.certInstallTimer_ue_secure.elapsedMicroseconds,
      "enterpriseConnectionFailureCount": failureCount,
      "enterpriseConnectionSuccessCount": successCount,
      "scaleResponses": jsonMap
    });
  }

  Future<void> addQuestionResponse(UserResponse r, String savePath) async {
    DatabaseReference tmpRef = rtdb.ref(questResponseRef + "/" + savePath);

    Map<String, Object> jsonMap = Map();

    jsonMap["workerId"] = r.workerId;
    jsonMap["email"] = r.email;
    jsonMap["uid"] = r.uid;
    jsonMap["metadata"] = r.metadata;
    jsonMap["isAdmin"] = !currentUserInfo.isAnonymous;

    for (int i = 0; i < r.questionResponses.length; i++) {
      QuestionResponse qr = r.questionResponses[i];
      jsonMap["qId = ${qr.qId}"] = {
        "qType": qr.qType,
        "qResponse": await qr.getResponseJson()
      };
    }
    if (dbug) print(jsonMap.toString());
    await tmpRef.set(jsonMap);
  }

  Future<void> addWorkerID(String workerId, String uid) async {
    await rtdb.ref(workerIdsRef + "/" + workerId).set(uid);
    await rtdb.ref(tempUidWorkerIdMap + "/" + uid).set(workerId);
  }

  Future<void> removeFromTempUidWorkerIdMap(String uid) async {
    await rtdb.ref(tempUidWorkerIdMap + "/" + uid).remove();
  }

  Future<void> getWorkerIdFromUid(String uid) async {
    DataSnapshot tmp = await rtdb.ref(tempUidWorkerIdMap + "/" + uid).get();
    currentUserInfo.workerId =
        tmp.value.toString().trim(); // remove leading and trailing spaces
    if (dbug) print("rtdbService: WorkerID = ${currentUserInfo.workerId}");
  }

  String getUniqueID() {
    return UniqueKey()
        .toString()
        .replaceAll("#", "")
        .replaceAll("[", "")
        .replaceAll("]", "");
  }

  Future<String> getDbStateKey() async {
    String key;
    if (currentUserInfo.isAnonymous) {
      if (currentUserInfo.workerId == null || currentUserInfo.workerId.isEmpty)
        await this.getWorkerIdFromUid(currentUserInfo.uid);
      key = currentUserInfo.workerId;
    } else {
      key = currentUserInfo.uid;
    }
    return key;
  }

  Future<String> getLatestSurveyState() async {
    String key = await getDbStateKey();
    DataSnapshot temp;
    if (!currentUserInfo.isAnonymous) {
      // only read if admin
      temp = await rtdb.ref(surveyStateAdmin + "/" + key).get();
      if (temp.value != null) return temp.value;
    }
    temp = await rtdb.ref(surveyState9 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState8 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState7 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState6 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState5 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState4 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState3 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState2 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState1 + "/" + key).get();
    if (temp.value != null) return temp.value;
    temp = await rtdb.ref(surveyState0 + "/" + key).get();
    if (temp.value != null)
      return temp.value;
    else
      return null;
  }

  Future<bool> addOrGetConsentStateInDB(bool updateState) async {
    // for admins
    if (!currentUserInfo.isAnonymous) {
      DataSnapshot dbs =
          await rtdb.ref(consentRef).child(currentUserInfo.uid).get();
      if (!dbs.exists)
        await rtdb.ref(consentRef).child(currentUserInfo.uid).set(true);
      return true;
    }

    //for everyone else
    if (currentUserInfo.workerId == null || currentUserInfo.workerId.isEmpty) {
      await getWorkerIdFromUid(currentUserInfo.uid);
    }

    DataSnapshot dbs =
        await rtdb.ref(consentRef).child(currentUserInfo.workerId).get();
    if (!dbs.exists) {
      //doesn't exist, so this is the first time adding consent state for the user, add it as false
      await rtdb.ref(consentRef).child(currentUserInfo.workerId).set(false);
      return false;
    } else {
      bool tmp = dbs.value;
      if (tmp == false && updateState == true) {
        // this is the only thing allowed...once
        await rtdb
            .ref(consentRef)
            .child(currentUserInfo.workerId)
            .set(updateState);
      }
      return tmp || updateState;
    }
  }

  Future<String> addSurveyStateInDB(
      String refSurveyState, String checkRef) async {

    // get the dbStateKeyHere
    String dbStateKey = await getDbStateKey();

    // get the latest survey state for the user
    String currentSurveyState = await getLatestSurveyState();

    // print(checkRef);
    // print(currentSurveyState);
    // print(refSurveyState);
    

    // These are for adding survey states for the very first time
    if (currentSurveyState == null &&
        refSurveyState == null &&
        !currentUserInfo.isAnonymous) {
      // admin mode
      await rtdb
          .ref(surveyStateAdmin + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_ADMIN_MODE);
      return AMT_SURVEY_STATE_ADMIN_MODE;
    } 
    
    else if (currentSurveyState == null &&
        refSurveyState == null &&
        currentUserInfo.isAnonymous) {
      await rtdb
          .ref(surveyState0 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_NO_TASK_FINISHED);
      return AMT_SURVEY_STATE_NO_TASK_FINISHED;
    } 
    
    else if (currentSurveyState == AMT_SURVEY_STATE_ADMIN_MODE) {
      // for admins we don't update their survey states
      return currentSurveyState;
    } 
    
    else if (currentSurveyState == AMT_SURVEY_STATE_NO_TASK_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK1_FINISHED) {
      //check entry for task 1 finished here : check if response entry exists

      DataSnapshot dbs = await rtdb.ref(checkRef).get();

      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      await rtdb
          .ref(surveyState1 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK1_FINISHED);

      return AMT_SURVEY_STATE_TASK1_FINISHED;
    } 
    
    else if (currentSurveyState == AMT_SURVEY_STATE_TASK1_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK2_FINISHED) {
      //check entry for task 2 finished here : check if response entry exists

      DataSnapshot dbs = await rtdb.ref(checkRef).get();
  
      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      await rtdb
          .ref(surveyState2 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK2_FINISHED);

      return AMT_SURVEY_STATE_TASK2_FINISHED;
    } 
    
    else if (currentSurveyState == AMT_SURVEY_STATE_TASK2_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK3_FINISHED) {
      //check entry for task 3 finished here : check if response entry exists
      // print("D1");
      DataSnapshot dbs = await rtdb.ref(checkRef ).get();
      // print("D2");
      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      // print("D3");
      await rtdb
          .ref(surveyState3 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK3_FINISHED);
      // print("D4");
      return AMT_SURVEY_STATE_TASK3_FINISHED;
    } 
    
    else if (currentSurveyState == AMT_SURVEY_STATE_TASK3_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK4_FINISHED) {
      //check entry for task 3 finished here : check if response entry exists
      DataSnapshot dbs = await rtdb.ref(checkRef ).get();
      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      await rtdb
          .ref(surveyState4 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK4_FINISHED);
      return AMT_SURVEY_STATE_TASK4_FINISHED;
    } else if (currentSurveyState == AMT_SURVEY_STATE_TASK4_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK5_FINISHED) {
      //check entry for task 3 finished here : check if response entry exists
      DataSnapshot dbs = await rtdb.ref(checkRef ).get();
      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      await rtdb
          .ref(surveyState5 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK5_FINISHED);
      return AMT_SURVEY_STATE_TASK5_FINISHED;
    } else if (currentSurveyState == AMT_SURVEY_STATE_TASK5_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK6_FINISHED) {
      //check entry for task 3 finished here : check if response entry exists
      DataSnapshot dbs = await rtdb.ref(checkRef).get();
      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      await rtdb
          .ref(surveyState6 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK6_FINISHED);
      return AMT_SURVEY_STATE_TASK6_FINISHED;
    } else if (currentSurveyState == AMT_SURVEY_STATE_TASK6_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK7_FINISHED) {
      //check entry for task 3 finished here : check if response entry exists
      DataSnapshot dbs = await rtdb.ref(checkRef ).get();
      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      await rtdb
          .ref(surveyState7 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK7_FINISHED);
      return AMT_SURVEY_STATE_TASK7_FINISHED;
    } else if (currentSurveyState == AMT_SURVEY_STATE_TASK7_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK8_FINISHED) {
      //check entry for task 3 finished here : check if response entry exists
      DataSnapshot dbs = await rtdb.ref(checkRef ).get();
      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      await rtdb
          .ref(surveyState8 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK8_FINISHED);
      return AMT_SURVEY_STATE_TASK8_FINISHED;
    } else if (currentSurveyState == AMT_SURVEY_STATE_TASK8_FINISHED &&
        refSurveyState == AMT_SURVEY_STATE_TASK9_FINISHED) {
      //check entry for task 3 finished here : check if response entry exists
      DataSnapshot dbs = await rtdb.ref(checkRef ).get();
      if (!dbs.exists) {
        BotToast.showText(
            text: "Save response failed!",
            duration: Duration(seconds: 3),
            contentColor: Colors.red[200],
            textStyle: TextStyle(
                color: Colors.white, fontSize: Configuration.TOAST_SIZE));
        return currentSurveyState; // do not change the survey state in db
      }
      await rtdb
          .ref(surveyState9 + "/" + dbStateKey)
          .set(AMT_SURVEY_STATE_TASK9_FINISHED);
      return AMT_SURVEY_STATE_TASK9_FINISHED;
    } else {
      if (dbug)
        print("addOrGetSurveyStateInDB: Inconsistent update of states!");
      return currentSurveyState;
    }
  }

  Future<String> createOrGetAMTCode() async {
    if (dbug) print("Inside createOrGetAMTCode");
    String dbStateKey = await getDbStateKey();
    DataSnapshot tmp = await rtdb.ref(amtCodesRef + "/" + dbStateKey).get();
    if (tmp.value == null) {
      // code generation for AMTURK // this can only be done once per user unless we delete the user by hand
      String code = rtdb.ref(amtCodesRef + "/" + dbStateKey).push().key;
      await rtdb.ref(amtCodesRef + "/" + dbStateKey).set(code);
      return code;
    } else {
      return tmp.value;
    }
  }

  Future<void> addTaskMap(Map<String, String> taskMap) async {
    if (currentUserInfo.isAnonymous &&
        (currentUserInfo.workerId == null || currentUserInfo.workerId.isEmpty))
      await getWorkerIdFromUid(currentUserInfo.uid);

    // it'll be successful exactly once per user
    await rtdb.ref(taskMapRef + "/" + currentUserInfo.workerId).set(taskMap);
  }

  Future<Map<String, String>> getTaskMap() async {
    if (!currentUserInfo.isAnonymous) { // this is for the admins
      return ADMIN_TASK_MAP;
    }
    if (currentUserInfo.isAnonymous &&
        (currentUserInfo.workerId == null || currentUserInfo.workerId.isEmpty))
      await getWorkerIdFromUid(currentUserInfo.uid);

    DataSnapshot tmp =
        await rtdb.ref(taskMapRef + "/" + currentUserInfo.workerId).get();
    if (tmp.value == null) // doesn't exist
      return null;

    Map<String, String> mp = Map<String, String>.from(tmp.value);
    return mp;
  }

  Future<Pair<String>> generateInstructionMap(bool tofu) async {
    if (currentUserInfo.isAnonymous &&
        (currentUserInfo.workerId == null || currentUserInfo.workerId.isEmpty))
      await getWorkerIdFromUid(currentUserInfo.uid);

    String key = currentUserInfo.isAnonymous
        ? currentUserInfo.workerId
        : currentUserInfo.uid;
    Pair<String> oldAndNewInstructions =
        await storageService.getRandomInstructionFile(tofu);

    if (oldAndNewInstructions == null) {
      BotToast.showText(
          text: "Failed to get random instruction file! Contact admin!",
          duration: Duration(seconds: 3),
          contentColor: Colors.red[200],
          textStyle: TextStyle(
              color: Colors.white, fontSize: Configuration.TOAST_SIZE));
      return null;
    }

    await rtdb.ref(instructionMapRef + "/" + key).set({
      "OLD_INSTRUCTION": oldAndNewInstructions.left,
      "NEW_INSTRUCTION": oldAndNewInstructions.right
    });

    return oldAndNewInstructions;
  }

  Future<void> getInstructions(bool tofu) async {
    if (dbug) print("TAG947: DEBUG: GETINSTRUCTIONS()");
    if (currentUserInfo.isAnonymous &&
        (currentUserInfo.workerId == null || currentUserInfo.workerId.isEmpty))
      await getWorkerIdFromUid(currentUserInfo.uid);

    String key = currentUserInfo.isAnonymous
        ? currentUserInfo.workerId
        : currentUserInfo.uid;
    Pair<String> oldAndNewInstructionUrls;

    DataSnapshot tmp = await rtdb.ref(instructionMapRef + "/" + key).get();

    if (tmp.value == null) {
      // doesn't exist in db at all
      Pair<String> newGenerateInstructionMap = await generateInstructionMap(tofu);
      oldAndNewInstructionUrls =
          await storageService.getDownloadUrl(newGenerateInstructionMap, tofu);
    } else {
      Map<String, String> mp = Map<String, String>.from(tmp.value);
      Pair<String> oldAndNewInstructions =
          new Pair<String>(mp["OLD_INSTRUCTION"], mp["NEW_INSTRUCTION"]);
      oldAndNewInstructionUrls =
          await storageService.getDownloadUrl(oldAndNewInstructions, tofu);

      if (oldAndNewInstructionUrls == null) {
        // file was deleted for some reason, repopulate
        Pair<String> newGenerateInstructionMap = await generateInstructionMap(tofu);
        oldAndNewInstructionUrls =
            await storageService.getDownloadUrl(newGenerateInstructionMap, tofu);
      }
    }
    oldAndNewInstructionsPath = oldAndNewInstructionUrls;
  }

  Future<void> loadPromptsAndConsent([Function stateUpdater]) async {
    if (oldImplHtmlPrompt == null) {
      DataSnapshot dt = await rtdb.ref(oldImplHtmlPromptRef).get();
      if (dt.exists && dt.value != null)
        oldImplHtmlPrompt = dt.value.toString();
      else
        oldImplHtmlPrompt =
            "<center><h1>Not Available! Please Add!</h1></center>";
    }
    if (newImplHtmlPrompt == null) {
      DataSnapshot dt = await rtdb.ref(newImplHtmlPromptRef).get();
      if (dt.exists && dt.value != null)
        newImplHtmlPrompt = dt.value.toString();
      else
        newImplHtmlPrompt =
            "<center><h1>Not Available! Please Add!</h1></center>";
    }
    if (questionHtmlPrompt == null) {
      DataSnapshot dt = await rtdb.ref(questionHtmlPromptRef).get();
      if (dt.exists && dt.value != null)
        questionHtmlPrompt = dt.value.toString();
      else
        questionHtmlPrompt =
            "<center><h1>Not Available! Please Add!</h1></center>";
    }

    if (consentPrompt == null) {
      DataSnapshot dt = await rtdb.ref(consentPromptRef).get();
      if (dt.exists && dt.value != null) {
        consentPrompt = dt.value.toString();
      } else
        consentPrompt = "<center><h1>This is a dummy prompt</h1></center>";
    }
    if (stateUpdater != null) {
      stateUpdater(() {});
    }
  }

  Future<void> updatePromptsOrConsentText(String ref, String newPrompt) async {
    if (newPrompt == null || ref == null) {
      print("NOT UPDATING......=> ref: $ref, newPrompt: $newPrompt");
    }

    await rtdb.ref(ref).set(newPrompt);
  }

  Future<Pair<int>> getRandomInts() async {
    if (!currentUserInfo.isAnonymous) // not used for admins
      return Pair(0, 0);

    DataSnapshot snap1 = await rtdb.ref(RNGRef + "/RNG1").get();
    String rngString1 = snap1.value.toString();
    List<String> rngStrings1 = rngString1.split(",");

    DataSnapshot snap2 = await rtdb.ref(RNGRef + "/RNG2").get();
    String rngString2 = snap2.value.toString();
    List<String> rngStrings2 = rngString2.split(",");
    try {
      Pair<int> ret = Pair(int.parse(rngStrings1.removeLast()),
          int.parse(rngStrings2.removeLast()));

      Future.delayed(Duration(milliseconds: Random.secure().nextInt(500)), () {
        rtdb.ref(RNGRef).update(
            {"RNG1": rngStrings1.join(','), "RNG2": rngStrings2.join(',')});
      });

      // await rtdb.ref(RNGRef + "/RNG1").set(rngStrings1.join(","));
      // await rtdb.ref(RNGRef + "/RNG2").set(rngStrings2.join(","));
      return ret;
    } catch (e) {
      return null;
    }
  }

  Future<Pair<int>> countRandomInts() async {
    if (currentUserInfo.isAnonymous) return Pair(-1, -1);

    DataSnapshot snap1 = await rtdb.ref(RNGRef + "/RNG1").get();
    String rngString1 = snap1.value.toString();
    List<String> rngStrings1 = rngString1.split(",");

    DataSnapshot snap2 = await rtdb.ref(RNGRef + "/RNG2").get();
    String rngString2 = snap2.value.toString();
    List<String> rngStrings2 = rngString2.split(",");

    return Pair(rngStrings1.length, rngStrings2.length);
  }

  Future<String> getRNG1() async {
    if (currentUserInfo.isAnonymous) return "";
    DataSnapshot snap1 = await rtdb.ref(RNGRef + "/RNG1").get();
    return snap1.value.toString();
  }

  Future<String> getRNG2() async {
    if (currentUserInfo.isAnonymous) return "";
    DataSnapshot snap1 = await rtdb.ref(RNGRef + "/RNG2").get();
    return snap1.value.toString();
  }

  Future<String> getBlackList() async {
    DataSnapshot snap1 = await rtdb.ref(blackListedWorkerIdsRef).get();
    if (snap1 == null || !snap1.exists) return "";

    return snap1.value.toString();
  }

  Future<int> getTotalAMTCodeCount() async {
    if (currentUserInfo.isAnonymous) return -1;

    DataSnapshot data = await rtdb.ref(amtCodesRef).get();
    if (!data.exists || data.value == null) return 0;
    var mapOfMaps = Map<String, dynamic>.from(data.value);
    if (dbug) print(mapOfMaps.length);

    return mapOfMaps.length;
  }

  Future<int> getTotalTask1ResponseCount() async {
    if (currentUserInfo.isAnonymous) return -1;

    DataSnapshot data = await rtdb.ref(oldImplResponseRef).get();
    if (!data.exists || data.value == null) return 0;
    var mapOfMaps = Map<String, dynamic>.from(data.value);
    if (dbug) print(mapOfMaps.length);

    return mapOfMaps.length;
  }

  Future<int> getTotalTask2ResponseCount() async {
    if (currentUserInfo.isAnonymous) return -1;
    DataSnapshot data = await rtdb.ref(newImplResponseRef).get();
    if (!data.exists || data.value == null) return 0;
    var mapOfMaps = Map<String, dynamic>.from(data.value);
    if (dbug) print(mapOfMaps.length);

    return mapOfMaps.length;
  }

  Future<int> getTotalQuestionnaireResponseCount() async {
    if (currentUserInfo.isAnonymous) return -1;
    DataSnapshot data = await rtdb.ref(questResponseRef).get();
    if (!data.exists || data.value == null) return 0;
    var mapOfMaps = Map<String, dynamic>.from(data.value);
    if (dbug) print(mapOfMaps.length);

    return mapOfMaps.length;
  }

  Future<int> getTotalUserCount() async {
    if (currentUserInfo.isAnonymous) return -1;

    DataSnapshot data = await rtdb.ref(workerIdsRef).get();
    if (!data.exists || data.value == null) return 0;
    var mapOfMaps = Map<String, dynamic>.from(data.value);
    if (dbug) print(mapOfMaps.length);

    return mapOfMaps.length;
  }

  Future<void> updateBlackList(String blackList) async {
    if (currentUserInfo.isAnonymous) return;
    await rtdb.ref(blackListedWorkerIdsRef).set(blackList);
  }

  Future<void> updateRNG(String text) async {
    if (currentUserInfo.isAnonymous) return;
    List<String> splitted = text.split(listStringdelim);
    rtdb
        .ref(RNGRef)
        .update({"RNG1": splitted[0].trim(), "RNG2": splitted[1].trim()});
  }
}

class CurrentUserInfo {
  String workerId;
  UserMetadata metadata;
  String email;
  bool isAnonymous;
  String uid;

  Future<void> setUserInfo(User u) async {
    this.metadata = u.metadata;
    this.uid = u.uid;
    this.isAnonymous = u.isAnonymous;
    this.email = u.email;
    // if(u.isAnonymous && workerId==null)
    //   await rtdbService.getWorkerIdFromUid(u.uid);
  }

  void setWorkerId(String workerId) {
    this.workerId = workerId;
  }

  String getWorkerId() {
    return this.workerId;
  }
}

FirebaseAuthService authService;
FirebaseRTDBService rtdbService;
FirebaseStorageService storageService;
CurrentUserInfo currentUserInfo; // populated during each page load
UserResponse userResponse;
SharedPreferences prefs;
Pair<String> oldAndNewInstructionsPath; // populated in root page
String questionsChanged;

String oldImplHtmlPrompt;
String newImplHtmlPrompt;
String questionHtmlPrompt;
String consentPrompt;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: FirebaseOptions(
        // TODO: ADD API KEY HERE.
      )
      );

  authService = new FirebaseAuthService();
  rtdbService = new FirebaseRTDBService();
  storageService = new FirebaseStorageService();
  await authService.getAuth().setPersistence(Persistence.NONE);

  // await FixedData.populateNetworkStaticLists();

  currentUserInfo = new CurrentUserInfo();
  userResponse = new UserResponse();
  prefs = await SharedPreferences.getInstance();

  html.window.onUnload.listen((event) async {
    authService.signOut();
  });

  setPathUrlStrategy();

  MaterialApp mainApp = MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: BotToastInit(),
    navigatorObservers: [BotToastNavigatorObserver()],
    routes: {
      '/': (context) => LandingPage(),
      '/wifinetworklist': (context) => WifiNetworkList(),
      '/installcacertificate': (context) => InstallCACertificate(),
      '/questionnaire': (context) => Questionnaire(),
      "/thankyou": (context) => ThankYouPage()
    },
  );

  runApp(mainApp);
}

// theme: ThemeData(
//       tabBarTheme: TabBarTheme(
//                labelColor: Colors.pink[800],
//         labelStyle: TextStyle(color: Colors.green), // color for text
//         indicator: UnderlineTabIndicator( // color for indicator (underline)
//         borderSide: BorderSide(color: Colors.white))),
//         primaryColor: Colors.pink[800], // outdated and has no effect to Tabbar
//         accentColor: Colors.cyan[600] // deprecated,
//       )
