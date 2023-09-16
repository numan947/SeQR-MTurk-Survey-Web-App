import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:wifi_qr_survey_app/Configuration.dart';
import 'package:wifi_qr_survey_app/LoadingPage.dart';
import 'package:wifi_qr_survey_app/MainApp.dart';
import 'package:wifi_qr_survey_app/models/Comments.dart';
import 'package:wifi_qr_survey_app/models/QuestionnaireRelatedClasses.dart';

class Questionnaire extends StatefulWidget {
  const Questionnaire({Key key}) : super(key: key);

  @override
  _QuestionnaireState createState() => _QuestionnaireState();
}

class _QuestionnaireState extends State<Questionnaire> {
  List<Question> questions;
  List<Question> clonedQuestions;
  List<QuestionResponse> responses;
  bool hasAdminAccess = false;
  bool showLoading = false;
  bool showEmptyResponses = false;
  String taskState;
  String actualTaskId;
  bool tofu;
  bool newImplementation;
  final TextEditingController editHtmlController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final ScrollController commentScrollController = ScrollController();

  Map<String, TextEditingController> responseControllers = Map();
  bool showInformationPage = true;
  bool reloadPage = true;
  bool showSaveOrderButton = false;
  bool dialogLoading = false;
  bool postTaskQuestionnaire = false;
  Map passedFromLastPage = null;

  List<String> questionTypeList = <String>[
    Question.MAQ,
    Question.MCQ,
    Question.SAQ,
    Question.TFQ,
    Question.SCQ,
    Question.SCQ_SINGLE,
    Question.DCR,
    Question.DDM
  ];
  List<Comment> comments;
  Map<String, String> taskMap;
  final Map<String, String> taskMapToName = {
    "OLD_IMPLEMENTATION": "Conventional approach",
    "NEW_IMPLEMENTATION": "QR-code based approach"
  };

  TextStyle questionStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE + 2.0);

  Future<void> getQuestionsFromDatabase(bool postTaskFilter) async {
    Pair<dynamic> temp = await rtdbService.getQuestions(
        postTaskFilter, !currentUserInfo.isAnonymous && !userModeForAdmin);
    // also get the taskMap here
    taskMap = await rtdbService.getTaskMap();

    questions = temp.right;
    bool reorderAndSave = temp.left;
    if (dbug) print("REORDER AND SAVING.....$reorderAndSave");

    if (!reorderAndSave) {
      questions.sort((a, b) => a.qOrder.compareTo(b.qOrder)); // sorting here
    } else {
      await refreshOrderOfAllCurrentQuestions();
      setState(() {
        reloadPage = true;
      });
      return;
    }

    clonedQuestions = [];
    responses = [];
    for (int i = 0; i < questions.length; i++) {
      Question p = questions[i];
      if (!currentUserInfo.isAnonymous) {
        rtdbService.addCommentNotificationListenerToQuestion(p, setState);
        clonedQuestions.add(Question.clone(
            p)); // this is back up; will be used if after reorder we hit discard
      }

      responses.add(QuestionResponse(
          qId: p.qId, qType: p.qType, qOptions: p.qOptions, qScale: p.qScale));
    }

    //dummy scale question
    // Question r = Question(
    //     qId: "TMP_Q",
    //     qBody: "How mentally demanding was the task?",
    //     qType: Question.SCQ);
    // r.qScale = Pair(1, 21);
    // r.qScalePrompts = Pair("Low", "High");
    // questions.add(r);
    // responses.add(
    //     QuestionResponse(qId: r.qId, qType: r.qType, qOptions: r.qOptions, qScale: r.qScale));

    assert(questions.length == responses.length);
    //force reload UI
    setState(() {
      showLoading = false;
      reloadPage = false;
    });
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
              controller: editHtmlController,
              decoration: InputDecoration(hintText: "Add HTML"),
              minLines: 5,
              maxLines: 10,
              style: TextStyle(fontSize: Configuration.TEXT_SIZE),
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
                      questionHtmlPrompt = editHtmlController.text;
                      rtdbService.updatePromptsOrConsentText(
                          rtdbService.questionHtmlPromptRef,
                          questionHtmlPrompt);
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
            ],
          );
        });
  }

  @override
  void initState() {
    super.initState();
    if (!currentUserInfo.isAnonymous) rtdbService.removeCommentListener();
  }

  @override
  void dispose() {
    if (dbug) print("DISPOSE CALLED IN QUESTIONNAIRE PAGE!!");
    editHtmlController.dispose();
    commentController.dispose();
    commentScrollController.dispose();
    if (!currentUserInfo.isAnonymous) rtdbService.removeCommentListener();
    for (StreamSubscription s in rtdbService.dbChangeListeners) s.cancel();
    rtdbService.dbChangeListeners.clear();
    for (TextEditingController v in responseControllers.values) v.dispose();

    super.dispose();
  }

  Widget _myRadioButton(
      {String title, int value, int groupValue, Function onChanged}) {
    return RadioListTile(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(
        title,
        style: TextStyle(fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE),
      ),
    );
  }

  Widget _myCheckbox({String title, bool value, Function onChanged}) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: TextStyle(fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Future<Question> addOrEditQuestionDialog(
      [Question currentQuestion, QuestionResponse currentResponse]) async {
    Question tempQuestion = Question.clone(currentQuestion);

    return showDialog<Question>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: EdgeInsets.zero,
          title: Text(
            currentQuestion == null
                ? ("Add a new questions")
                : "Editing question with ID: " + tempQuestion.qId,
            style: TextStyle(
                fontSize: Configuration.TEXT_SIZE,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent[400]),
          ),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 700,
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        child: ListBody(
                          children: <Widget>[
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Text(
                                      "Post Task",
                                      style: TextStyle(
                                          fontSize: Configuration.TEXT_SIZE,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Spacer(),
                                    Transform.scale(
                                      scale: 1.5,
                                      child: Checkbox(
                                        value: tempQuestion.postTask,
                                        onChanged: (newValue) {
                                          setState(() {
                                            tempQuestion.postTask = newValue;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                )),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                tempQuestion.qType == Question.DCR
                                    ? "Section Title"
                                    : "Question:",
                                style: TextStyle(
                                    fontSize: Configuration.TEXT_SIZE,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                minLines: 1,
                                maxLines: 10,
                                initialValue: currentQuestion == null
                                    ? ""
                                    : tempQuestion.qBody,
                                onChanged: (newValue) {
                                  setState(() {
                                    tempQuestion.qBody = newValue;
                                  });
                                },
                                style: TextStyle(
                                    fontSize: Configuration.TEXT_SIZE - 1.0),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Text(
                                      tempQuestion.qType == Question.DCR
                                          ? "Type: "
                                          : "Type: (Question)",
                                      style: TextStyle(
                                          fontSize: Configuration.TEXT_SIZE,
                                          fontWeight: FontWeight.bold)),
                                  DropdownButton<String>(
                                    items: questionTypeList.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                              fontSize:
                                                  Configuration.TEXT_SIZE),
                                        ),
                                      );
                                    }).toList(),
                                    value: tempQuestion.qType,
                                    onChanged: (newValue) {
                                      setState(() {
                                        tempQuestion.qType = newValue;
                                        if (dbug)
                                          print(
                                              "Selected Question Type: ${tempQuestion.qType}");
                                      });
                                    },
                                  )
                                ],
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                              ),
                            ),
                            Visibility(
                              visible: tempQuestion.qType != Question.SAQ &&
                                  tempQuestion.qType != Question.SCQ &&
                                  tempQuestion.qType != Question.SCQ_SINGLE,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                    tempQuestion.qType == Question.DCR
                                        ? "Section Description"
                                        : "Question Options: Separate each by a ;(semicolon)",
                                    style: TextStyle(
                                        fontSize: Configuration.TEXT_SIZE,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            Visibility(
                              visible: tempQuestion.qType != Question.SAQ &&
                                  tempQuestion.qType != Question.SCQ &&
                                  tempQuestion.qType != Question.SCQ_SINGLE,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextFormField(
                                  initialValue: currentQuestion == null
                                      ? ""
                                      : currentQuestion.qOptions
                                          ?.join(rtdbService.listStringdelim),
                                  minLines: 1,
                                  maxLines: 10,
                                  onChanged: (newValue) {
                                    setState(() {
                                      if (tempQuestion.qType == Question.DCR) {
                                        tempQuestion.qOptions = [newValue];
                                      } else {
                                        tempQuestion.qOptions = newValue
                                            .replaceAll('\n', '')
                                            .split(rtdbService.listStringdelim);
                                      }
                                    });
                                  },
                                  style: TextStyle(
                                      fontSize: Configuration
                                              .QUESTIONNAIRE_FONT_SIZE -
                                          1.0),
                                ),
                              ),
                            ),
                            Visibility(
                              visible: tempQuestion.qType == Question.SCQ ||
                                  tempQuestion.qType == Question.SCQ_SINGLE,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Flexible(
                                      child: Text(
                                    "Min Value",
                                    style: TextStyle(
                                        fontSize: Configuration.TEXT_SIZE),
                                  )),
                                  Flexible(
                                      child: TextFormField(
                                    style: TextStyle(
                                        fontSize: Configuration
                                                .QUESTIONNAIRE_FONT_SIZE -
                                            1.0),
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    keyboardType: TextInputType.number,
                                    initialValue: "${tempQuestion.qScale.left}",
                                    onChanged: (newValue) {
                                      setState(() {
                                        tempQuestion.qScale.left =
                                            int.parse(newValue);
                                      });
                                    },
                                  )),
                                  Flexible(
                                      child: Text(
                                    "Max Value",
                                    style: TextStyle(
                                        fontSize: Configuration.TEXT_SIZE),
                                  )),
                                  Flexible(
                                      child: TextFormField(
                                    style: TextStyle(
                                        fontSize: Configuration
                                                .QUESTIONNAIRE_FONT_SIZE -
                                            1.0),
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    keyboardType: TextInputType.number,
                                    initialValue:
                                        "${tempQuestion.qScale.right}",
                                    onChanged: (newValue) {
                                      setState(() {
                                        tempQuestion.qScale.right =
                                            int.parse(newValue);
                                      });
                                    },
                                  ))
                                ],
                              ),
                            ),
                            Visibility(
                              visible: tempQuestion.qType == Question.SCQ ||
                                  tempQuestion.qType == Question.SCQ_SINGLE,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Flexible(
                                      child: Text(
                                    "Min Text",
                                    style: TextStyle(
                                        fontSize: Configuration.TEXT_SIZE),
                                  )),
                                  Flexible(
                                      child: TextFormField(
                                    style: TextStyle(
                                        fontSize: Configuration
                                                .QUESTIONNAIRE_FONT_SIZE -
                                            1.0),
                                    initialValue:
                                        "${tempQuestion.qScalePrompts.left}",
                                    onChanged: (newValue) {
                                      setState(() {
                                        tempQuestion.qScalePrompts.left =
                                            newValue;
                                      });
                                    },
                                  )),
                                  Flexible(
                                      child: Text(
                                    "Max Text",
                                    style: TextStyle(
                                        fontSize: Configuration.TEXT_SIZE),
                                  )),
                                  Flexible(
                                      child: TextFormField(
                                    style: TextStyle(
                                        fontSize: Configuration
                                                .QUESTIONNAIRE_FONT_SIZE -
                                            1.0),
                                    initialValue:
                                        "${tempQuestion.qScalePrompts.right}",
                                    onChanged: (newValue) {
                                      setState(() {
                                        tempQuestion.qScalePrompts.right =
                                            newValue;
                                      });
                                    },
                                  ))
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          actions: <Widget>[
            SizedBox(
              height: Configuration.DIALOG_BUTTON_HEIGHT,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: Configuration.BUTTON_TEXT_SIZE,
                          color: Colors.blueAccent)),
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                ),
              ),
            ),
            SizedBox(
              height: Configuration.DIALOG_BUTTON_HEIGHT,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  child: const Text('Save',
                      style: TextStyle(
                          fontSize: Configuration.BUTTON_TEXT_SIZE,
                          color: Colors.redAccent)),
                  onPressed: () {
                    showLoading = true;
                    if (currentQuestion != null) {
                      // editing case
                      Pair<dynamic> sanity = tempQuestion.sanityCheck();
                      if (sanity.left) {
                        currentQuestion.update(tempQuestion);
                        currentResponse.update(tempQuestion);
                        updateQuestionHelper(tempQuestion);
                        BotToast.showText(
                            text: "Database Updated!",
                            duration: Duration(seconds: 3),
                            contentColor: Colors.blue[300],
                            textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: Configuration.TOAST_SIZE));
                      } else {
                        BotToast.showText(
                            text: "Sanity Check Failed!",
                            duration: Duration(seconds: 3),
                            contentColor: Colors.red[300],
                            textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: Configuration.TOAST_SIZE));
                      }
                      showLoading = false;

                      if (sanity.left)
                        Navigator.of(context).pop(tempQuestion);
                      else
                        Navigator.of(context).pop(null);
                    } else {
                      // adding case
                      String uniqueID = rtdbService.getUniqueID();
                      tempQuestion.qId = "$uniqueID";
                      tempQuestion.qOrder = questions.length;
                      Pair<dynamic> sanity = tempQuestion.sanityCheck();
                      if (sanity.left) {
                        questions.add(tempQuestion);
                        responses.add(QuestionResponse(
                            qId: tempQuestion.qId,
                            qOptions: tempQuestion.qOptions,
                            qType: tempQuestion.qType,
                            qScale: tempQuestion.qScale));
                        if (dbug) print(tempQuestion.qId);
                        addQuestionHelper(tempQuestion);
                        BotToast.showText(
                            text: "Database Updated!",
                            duration: Duration(seconds: 3),
                            contentColor: Colors.blue[300],
                            textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: Configuration.TOAST_SIZE));
                      } else {
                        BotToast.showText(
                            text: "Sanity Check Failed!",
                            duration: Duration(seconds: 3),
                            contentColor: Colors.red[300],
                            textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: Configuration.TOAST_SIZE));
                      }
                      showLoading = false;

                      if (sanity.left)
                        Navigator.of(context).pop(tempQuestion);
                      else
                        Navigator.of(context).pop(null);
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> addQuestionHelper(Question tempQuestion) async {
    await rtdbService.addQuestion(tempQuestion);
    rtdbService.addCommentNotificationListenerToQuestion(
        tempQuestion, setState);
  }

  Future<void> updateQuestionHelper(Question tempQuestion) async {
    await rtdbService.updateQuestion(tempQuestion);
  }

  Future<void> refreshOrderOfAllCurrentQuestions() async {
    if (dbug) print("INSIDE REFRESH!");
    for (int i = 0; i < questions.length; i++) {
      questions[i].qOrder = i;
      await rtdbService.updateQuestion(questions[i]);
    }
  }

  Future<void> deleteQuestionHelper(Question q) async {
    await rtdbService.deleteQuestion(q);
    // because some order may change after deleting a question
    for (int i = 0; i < questions.length; i++) {
      questions[i].qOrder = i;
      await rtdbService.updateQuestion(questions[i]);
    }
  }

  Future<void> deleteDialog(Question q) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Deleting question with ID: ' + q.qId,
            style: TextStyle(
                color: Colors.redAccent[300],
                fontSize: Configuration.TEXT_SIZE,
                fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Delete this question? This cannot be undone.',
                  style: TextStyle(
                      fontSize: Configuration.TEXT_SIZE - 1.0,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            SizedBox(
              height: Configuration.DIALOG_BUTTON_HEIGHT,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: Configuration.BUTTON_TEXT_SIZE,
                          color: Colors.blueAccent)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            SizedBox(
              height: Configuration.DIALOG_BUTTON_HEIGHT,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  child: const Text('Delete',
                      style: TextStyle(
                          fontSize: Configuration.BUTTON_TEXT_SIZE,
                          color: Colors.redAccent)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      if (q != null) {
                        responses
                            .removeWhere((element) => element.qId == q.qId);
                        questions.remove(q);
                        deleteQuestionHelper(q);
                      }
                    });
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestionFrom(BuildContext context, int index) {
    if (index == questions.length) {
      return SizedBox(
        key: ValueKey("BUTTON_SUBMIT"),
        width: 400,
        height: Configuration.DIALOG_BUTTON_HEIGHT,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ElevatedButton(
            onPressed: () async {
              userResponse.updateUserInfo(currentUserInfo);
              userResponse.clearQuestionResponse();
              for (int i = 0; i < responses.length; i++) {
                if (!responses[i].hasResponse) {
                  BotToast.showText(
                      text: "Incomplete Response!",
                      duration: Duration(seconds: 3),
                      contentColor: Colors.red[300],
                      textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: Configuration.TOAST_SIZE));
                  setState(() {
                    showEmptyResponses = true;
                  });
                  return;
                } else if (responses[i].qType != Question.DCR) {
                  // exclude decoration
                  userResponse.addQuestionResponse(responses[i]);
                }
              }
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
                },
              );

              String savePath = "";
                String checkRef = "";
                if(currentUserInfo.isAnonymous)
                {
                  savePath = currentUserInfo.workerId+"/"+actualTaskId;
                  checkRef = rtdbService.questResponseRef+"/"+currentUserInfo.workerId+"/"+actualTaskId;
                }
                else{
                  savePath = currentUserInfo.uid+"/"+actualTaskId;
                  checkRef = rtdbService.questResponseRef+"/"+currentUserInfo.uid+"/"+actualTaskId;
                }
               if (!postTaskQuestionnaire) {
                // userResponse.printObject();
                await rtdbService.addQuestionResponse(userResponse, savePath);
                await rtdbService.addSurveyStateInDB(taskState,checkRef);
                BotToast.showText(
                    text: "Response Saved!",
                    duration: Duration(seconds: 3),
                    contentColor: Colors.blue[300],
                    textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.TOAST_SIZE));
                Navigator.pop(dialogContext);
              } 
              
              else {
                await rtdbService.addQuestionnaireResponse(userResponse, savePath, newImplementation, tofu);
                await rtdbService.addSurveyStateInDB(taskState, checkRef);
                
                // if (taskId == 'Task-1') {
                //   String checkRef = "";
                //   if (newImplementation) {
                //     await rtdbService.addNewImplResponse(interactionRecords,
                //         globalTimers, failureCount, successCount, userResponse);
                //     checkRef = rtdbService.newImplResponseRef;
                //   } else {
                //     await rtdbService.addOldImplResponse(interactionRecords,
                //         globalTimers, failureCount, successCount, userResponse);
                //     checkRef = rtdbService.oldImplResponseRef;
                //   }
                //   await rtdbService.addSurveyStateInDB(
                //       AMT_SURVEY_STATE_TASK1_FINISHED, checkRef);
                // } 
                
                // else if (taskId == 'Task-2') {
                //   String checkRef = "";
                //   if (newImplementation) {
                //     await rtdbService.addNewImplResponse(interactionRecords,
                //         globalTimers, failureCount, successCount, userResponse);
                //     checkRef = rtdbService.newImplResponseRef;
                //   } else {
                //     await rtdbService.addOldImplResponse(interactionRecords,
                //         globalTimers, failureCount, successCount, userResponse);
                //     checkRef = rtdbService.oldImplResponseRef;
                //   }
                //   await rtdbService.addSurveyStateInDB(
                //       AMT_SURVEY_STATE_TASK2_FINISHED, checkRef);
                // } 
                
                // else {
                //   BotToast.showText(
                //       text: "Unknown Task!!",
                //       contentColor: Colors.redAccent[400],
                //       textStyle: TextStyle(
                //           color: Colors.white,
                //           fontSize: Configuration.TOAST_SIZE),
                //       duration: Duration(seconds: 4));
                // }

                BotToast.showText(
                    text: "Response Saved!",
                    duration: Duration(seconds: 3),
                    contentColor: Colors.blue[300],
                    textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.TOAST_SIZE));
                Navigator.pop(dialogContext);
              }

              /*if (!postTaskQuestionnaire) {
                // userResponse.printObject();

                await rtdbService.addQuestionResponse(userResponse);

                await rtdbService.addSurveyStateInDB(
                  taskState,
                  rtdbService.questResponseRef);
                BotToast.showText(
                    text: "Response Saved!",
                    duration: Duration(seconds: 3),
                    contentColor: Colors.blue[300],
                    textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.TOAST_SIZE));
                Navigator.pop(dialogContext);
              } 
              
              else {
                List<UserInteractionsRecord> interactionRecords =
                    passedFromLastPage['InteractionRecords'];
                String taskId = passedFromLastPage['TaskId'];
                bool newImplementation =
                    passedFromLastPage['newImplementation'];
                GlobalTimers globalTimers = passedFromLastPage['GlobalTimers'];
                int failureCount = passedFromLastPage['failureCount'];
                int successCount = passedFromLastPage['successCount'];

                if (taskId == 'Task-1') {
                  String checkRef = "";
                  if (newImplementation) {
                    await rtdbService.addNewImplResponse(interactionRecords,
                        globalTimers, failureCount, successCount, userResponse);
                    checkRef = rtdbService.newImplResponseRef;
                  } else {
                    await rtdbService.addOldImplResponse(interactionRecords,
                        globalTimers, failureCount, successCount, userResponse);
                    checkRef = rtdbService.oldImplResponseRef;
                  }
                  await rtdbService.addSurveyStateInDB(
                      AMT_SURVEY_STATE_TASK1_FINISHED, checkRef);
                } else if (taskId == 'Task-2') {
                  String checkRef = "";
                  if (newImplementation) {
                    await rtdbService.addNewImplResponse(interactionRecords,
                        globalTimers, failureCount, successCount, userResponse);
                    checkRef = rtdbService.newImplResponseRef;
                  } else {
                    await rtdbService.addOldImplResponse(interactionRecords,
                        globalTimers, failureCount, successCount, userResponse);
                    checkRef = rtdbService.oldImplResponseRef;
                  }
                  await rtdbService.addSurveyStateInDB(
                      AMT_SURVEY_STATE_TASK2_FINISHED, checkRef);
                } else {
                  BotToast.showText(
                      text: "Unknown Task!!",
                      contentColor: Colors.redAccent[400],
                      textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: Configuration.TOAST_SIZE),
                      duration: Duration(seconds: 4));
                }

                BotToast.showText(
                    text: "Response Saved!",
                    duration: Duration(seconds: 3),
                    contentColor: Colors.blue[300],
                    textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: Configuration.TOAST_SIZE));
                Navigator.pop(dialogContext);
              }*/

              Navigator.pushNamedAndRemoveUntil(
                  context, "/", (Route<dynamic> route) => false);
            },
            child: Text(
              "Submit Response",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: Configuration.BUTTON_TEXT_SIZE,
                  letterSpacing: 1.5),
            ),
            style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Colors.blue[400]),
                elevation: MaterialStateProperty.all(1.0)),
          ),
        ),
      );
    }

    Question currentQuestion = questions[index];
    QuestionResponse currentResponse = responses[index];

    String passedTaskId = passedFromLastPage['TaskId'] ?? "both";
    // print(passedTaskId);
    // print(taskMap);

    String sclP1 = "Placeholder 1", sclP2 = "Placeholder 2";

    if (currentQuestion.qType == Question.SCQ ||
        currentQuestion.qType == Question.SCQ_SINGLE) {
      var splitted = currentQuestion.qBody.split(
          rtdbService.listStringdelim); // always 3 parts: separated by ';'
      // print(splitted);

      if (splitted.length >= 2) {
        sclP1 = splitted[0];
        sclP2 = splitted.sublist(1, splitted.length).join(';');
        // print(sclP1);
        // print(sclP2);
      } else if (splitted.length == 1) {
        sclP1 = sclP2 = splitted[0];
      }

      if (taskMap["Task-1"].contains("new")) {
        // print("SWAPPING");
        var tmp = sclP1;
        sclP1 = sclP2;
        sclP2 = tmp;
      } // swap
    }

    List<Widget> firstRow = [];

    if (currentQuestion.qType != Question.DCR)
      firstRow.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: SelectableText(
          "Question ID: " + currentQuestion.qId,
          style: questionStyle,
        ),
      ));
    else {
      firstRow.add(Text(
        currentQuestion.qBody,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE + 12.0,
            color: Colors.teal),
      )); // section title
    }

    if (hasAdminAccess) {
      if (currentQuestion.postTask) firstRow.add(Icon(Icons.task_alt_outlined));

      firstRow.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextButton(
            onPressed: (() {
              addOrEditQuestionDialog(currentQuestion, currentResponse)
                  .then((newQ) {
                if (newQ != null) clonedQuestions[index] = Question.clone(newQ);
              });
            }),
            child: Text(
              "Edit",
              style: TextStyle(
                  fontSize: Configuration.BUTTON_TEXT_SIZE,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[400]),
            )),
      ));

      firstRow.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextButton(
            onPressed: (() {
              deleteDialog(currentQuestion);
            }),
            child: Text(
              "Delete",
              style: TextStyle(
                  fontSize: Configuration.BUTTON_TEXT_SIZE,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent[400]),
            )),
      ));

      if (currentQuestion.qType != Question.DCR) {
        firstRow.add(Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextButton(
              onPressed: currentUserInfo.isAnonymous
                  ? null
                  : () {
                      ShowCommentForQuestion(
                          context, currentQuestion.qId, index);
                    },
              child: Text(
                "Comments",
                style: TextStyle(
                    fontSize: Configuration.BUTTON_TEXT_SIZE,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[400]),
              )),
        ));
        if (currentQuestion.lastCommented != null) {
          firstRow.add(Text(
            "[ Last comment by: ${currentQuestion.lastCommented.lastCommentedEmail} (${currentQuestion.lastCommented.lastCommentedDate}) ]",
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: currentQuestion.postTask
                    ? Colors.purple[700]
                    : Colors.grey[700]),
          ));
        } else {
          firstRow.add(Text(
            "[ No comments so far ]",
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: currentQuestion.postTask
                    ? Colors.purple[700]
                    : Colors.grey[700]),
          ));
        }
      }
    }

    if (currentQuestion.qType == Question.DCR) {
      currentResponse.hasResponse = true;
      List<Widget> decoration = [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: firstRow,
            mainAxisAlignment: MainAxisAlignment.start,
          ),
        )
      ];
      if (currentQuestion.qOptions != null &&
          currentQuestion.qOptions.join(rtdbService.listStringdelim).isNotEmpty)
        decoration.addAll([
          Divider(height: 20, color: Colors.blue),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: HtmlWidget(
              currentQuestion.qOptions.join(rtdbService.listStringdelim),
              textStyle: TextStyle(
                  fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE + 1.0),
              isSelectable: true,
            ),
          ),
          Divider(height: 20, color: Colors.blue)
        ]);

      return Padding(
        key: ValueKey(currentQuestion.qId),
        padding: const EdgeInsets.all(10.0),
        child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0)),
            elevation: 0,
            shadowColor: Colors.blueGrey,
            color: showEmptyResponses && !currentResponse.hasResponse
                ? Color.fromARGB(255, 255, 197, 197)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: decoration,
            )),
      );
    }

    List<Widget> questionBody = [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: firstRow,
          mainAxisAlignment: MainAxisAlignment.start,
        ),
      ),
      Divider(height: 5),
      // Padding(
      //   padding: const EdgeInsets.all(8.0),
      //   child: Text(
      //     "Question: ",
      //     style: questionStyle,
      //   ),
      // )
    ];

    if (currentQuestion.qType == Question.DDM) {
      TextEditingController controller =
          responseControllers[currentQuestion.qId] ?? null;
      if (controller == null) {
        controller = TextEditingController();
        responseControllers[currentQuestion.qId] = controller;
        controller.text = "";
      } else {}
      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: SelectableText(
          currentQuestion.qBody,
          style:
              TextStyle(fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE + 1.0),
        ),
      ));

      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Response: (Select one)",
          style: questionStyle,
        ),
      ));

      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: DropdownButton<String>(
          items: currentQuestion.qOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: TextStyle(fontSize: Configuration.TEXT_SIZE),
              ),
            );
          }).toList(),
          value: currentResponse.dropDownResponse,
          hint: Text(
            "Select Language",
            style: questionStyle,
          ),
          onChanged: (newValue) {
            setState(() {
              currentResponse.dropDownResponse = newValue;
              currentResponse.hasResponse = true;
              currentResponse.dropDownOtherResponse = "";
              if (dbug)
                print(
                    "Selected Question Type: ${currentResponse.dropDownResponse}");
            });
          },
        ),
      ));

      controller.text = currentResponse.dropDownOtherResponse ?? "";
      questionBody.add(Visibility(
        visible: (currentResponse.dropDownResponse != null &&
            currentResponse.dropDownResponse.isNotEmpty &&
            currentResponse.dropDownResponse.toLowerCase().contains("other")),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Focus(
            onFocusChange: (value) {
              if (!value) {
                if (controller.text != null && controller.text.isNotEmpty) {
                  currentResponse?.dropDownOtherResponse = controller.text;
                } else {
                  currentResponse?.dropDownOtherResponse = "";
                }
                if(currentResponse.dropDownResponse.isNotEmpty || currentResponse.dropDownOtherResponse.isNotEmpty)
                  currentResponse.hasResponse = true;
                else
                  currentResponse.hasResponse = false;
              }
            },
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: Configuration.TEXT_SIZE),
              decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Language',
                  hintText: 'Please specify your language'),
            ),
          ),
        ),
      ));
    } else if (currentQuestion.qType == Question.SAQ) {
      TextEditingController controller =
          responseControllers[currentQuestion.qId] ?? null;
      if (controller == null) {
        controller = TextEditingController();
        responseControllers[currentQuestion.qId] = controller;
        controller.text = "";
      } else {}

      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: SelectableText(
          currentQuestion.qBody,
          style:
              TextStyle(fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE + 1.0),
        ),
      ));

      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Response: (briefly describe)",
          style: questionStyle,
        ),
      ));

      controller.text = currentResponse.briefResponse ?? "";
      questionBody.add(Focus(
        onFocusChange: (value) {
          if (!value) {
            if (controller.text != null && controller.text.isNotEmpty) {
              currentResponse?.briefResponse = controller.text;
              currentResponse.hasResponse = true;
            } else {
              currentResponse?.briefResponse = "";
              currentResponse.hasResponse = false;
            }
          }
        },
        child: TextFormField(
          minLines: 3,
          maxLines: 7,
          style:
              TextStyle(fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE - 1.0),
          controller: controller,
        ),
      ));
    } else if (currentResponse.qType == Question.SCQ) {
      questionBody.add(
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: RichText(
            text: TextSpan(
                text: "For (${taskMap["Task-1"].contains("new") ? taskMapToName["NEW_IMPLEMENTATION"]:taskMap["OLD_IMPLEMENTATION"]}): ",
                style: TextStyle(
                    fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                    fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                      text: "${sclP1}",
                      style: TextStyle(
                          fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                          fontWeight: FontWeight.normal)),
                ]),
          ),
        ),
      );

      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Response: (show in scale)",
          style: questionStyle,
        ),
      ));
      questionBody.add(Center(
        child: Container(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: SfSlider(
              min: currentQuestion.qScale.left,
              max: currentQuestion.qScale.right,
              value: currentResponse.scaleResponse.left,
              interval: 1,
              showTicks: true,
              showLabels: true,
              enableTooltip: true,
              minorTicksPerInterval: 1,
              onChanged: (dynamic value) {
                setState(() {
                  currentResponse.scaleResponse.left = value.round();
                  currentResponse.hasResponse = true;
                });
              },
            ),
          ),
        ),
      ));
      questionBody.add(Padding(
        padding: const EdgeInsets.only(left: 10.0, right: 10, bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${currentQuestion.qScalePrompts.left}",
              style: TextStyle(
                  fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              "${currentQuestion.qScalePrompts.right}",
              style: TextStyle(
                  fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
      ));

      questionBody.add(
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: RichText(
            text: TextSpan(
                text: "For (${taskMap["Task-5"].contains("new") ? taskMapToName["NEW_IMPLEMENTATION"]:taskMap["OLD_IMPLEMENTATION"]}): ",
                style: TextStyle(
                    fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                    fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                      text: "${sclP2}",
                      style: TextStyle(
                          fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                          fontWeight: FontWeight.normal)),
                ]),
          ),
        ),
      );

      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Response: (show in scale)",
          style: questionStyle,
        ),
      ));
      questionBody.add(Padding(
        padding: const EdgeInsets.all(10.0),
        child: SfSlider(
          min: currentQuestion.qScale.left,
          max: currentQuestion.qScale.right,
          value: currentResponse.scaleResponse.right,
          interval: 1,
          showTicks: true,
          showLabels: true,
          enableTooltip: true,
          minorTicksPerInterval: 1,
          onChanged: (dynamic value) {
            setState(() {
              currentResponse.scaleResponse.right = value.round();
              currentResponse.hasResponse = true;
            });
          },
        ),
      ));
      questionBody.add(Padding(
        padding: const EdgeInsets.only(left: 10.0, right: 10, bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${currentQuestion.qScalePrompts.left}",
              style: TextStyle(
                  fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              "${currentQuestion.qScalePrompts.right}",
              style: TextStyle(
                  fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
      ));
    } else if (currentResponse.qType == Question.SCQ_SINGLE) {
      questionBody.add(
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: RichText(
            text: TextSpan(
                text: "",
                style: TextStyle(
                    fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                    fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                      text: passedTaskId == "both"
                          ? "${currentQuestion.qBody}"
                          : passedTaskId == 'Task-1'
                              ? "${sclP1}"
                              : "${sclP2}",
                      style: TextStyle(
                          fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                          fontWeight: FontWeight.normal)),
                ]),
          ),
        ),
      );

      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Response: (show in scale)",
          style: questionStyle,
        ),
      ));
      questionBody.add(Center(
        child: Container(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: SfSlider(
              min: currentQuestion.qScale.left,
              max: currentQuestion.qScale.right,
              value: currentResponse.singleScaleResponse,
              interval: 1,
              showTicks: true,
              showLabels: true,
              enableTooltip: true,
              minorTicksPerInterval: 1,
              onChanged: (dynamic value) {
                setState(() {
                  currentResponse.singleScaleResponse = value.round();
                  currentResponse.hasResponse = true;
                });
              },
            ),
          ),
        ),
      ));
      questionBody.add(Padding(
        padding: const EdgeInsets.only(left: 10.0, right: 10, bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${currentQuestion.qScalePrompts.left}",
              style: TextStyle(
                  fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              "${currentQuestion.qScalePrompts.right}",
              style: TextStyle(
                  fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
      ));
    } else {
      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: SelectableText(
          currentQuestion.qBody,
          style:
              TextStyle(fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE + 1.0),
        ),
      ));

      questionBody.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          currentQuestion.qType == Question.MAQ
              ? "Response: (select all that apply)"
              : "Response: (select one)",
          style: questionStyle,
        ),
      ));
      for (int i = 0; i < currentQuestion?.qOptions?.length; i++) {
        if (currentQuestion?.qType == Question.MCQ ||
            currentQuestion?.qType == Question.TFQ) {
          questionBody.add(Padding(
            padding: const EdgeInsets.all(8.0),
            child: _myRadioButton(
                title: currentQuestion.qOptions[i],
                value: i,
                groupValue: currentResponse?.getRadioState(),
                onChanged: (newValue) => setState(() {
                      if (newValue >= 0 &&
                          newValue < currentQuestion.qOptions.length) {
                        currentResponse?.setRadioState(newValue);
                        currentResponse?.hasResponse = true;
                      } else {
                        currentResponse?.hasResponse = false;
                      }
                    })),
          ));
        } else if (currentQuestion.qType == Question.MAQ) {
          questionBody.add(_myCheckbox(
              title: currentQuestion.qOptions[i],
              value: currentResponse?.getCheckListState(i),
              onChanged: (newValue) {
                setState(() {
                  currentResponse?.setCheckListState(i, newValue);
                  currentResponse?.hasResponse =
                      currentResponse?.checkListState?.contains(true);
                });
              }));
        }
      }
    }

    return Padding(
      key: ValueKey(currentQuestion.qId),
      padding: const EdgeInsets.all(10.0),
      child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 3,
          shadowColor: Colors.blueGrey,
          color: showEmptyResponses && !currentResponse.hasResponse
              ? Color.fromARGB(255, 255, 197, 197)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: questionBody,
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map data = ModalRoute.of(context).settings.arguments;
    postTaskQuestionnaire = data['PostTask'] ?? false;
    passedFromLastPage = data;
    taskState = data['TASK_STATE']??null;
    actualTaskId = data['TaskId']??null;
    
    tofu = data['TOFU_AVAILABLE']??false;
    newImplementation = data['newImplementation']??false;
    

    assert (taskState != null);

    // showInformationPage = !postTaskQuestionnaire;
    // print(data);
    return StreamBuilder<Object>(
        stream: authService.auth.authStateChanges(),
        builder: (context, snapshot) {
          if (showLoading) return LoadingPage();
          if (dbug) {
            print("Inside QuetionnairePage.dart");
            print("snapshot.hasData = ${snapshot.hasData}");
            print("snapshot.connectionstate = ${snapshot.connectionState}");
          }
          // snapshot.hasData == false, at the very beginning of the page's life cycle, otherwise it will have data and if we show loading, it'll be jittery
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
            if (dbug) print("Redirecting to / from QuestionnairePage.dart");
            return LoadingPage(); // technically this is not possible to hang on to
          } else {
            User u = snapshot.data;
            currentUserInfo.setUserInfo(u);
            hasAdminAccess = !u.isAnonymous;
          }

          if (questionHtmlPrompt == null) {
            rtdbService.loadPromptsAndConsent(setState);
            return LoadingPage();
          }
          if (reloadPage) {
            getQuestionsFromDatabase(postTaskQuestionnaire);
            return LoadingPage();
          }
          if (showInformationPage && !postTaskQuestionnaire) {
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
                          rtdbService.removeCommentListener();
                          for (StreamSubscription s
                              in rtdbService.dbChangeListeners) s.cancel();
                          rtdbService.dbChangeListeners.clear();
                          questionHtmlPrompt = null;
                          reloadPage = true;
                          showEmptyResponses = false;
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
                          questionHtmlPrompt,
                          textStyle: TextStyle(decoration: TextDecoration.none),
                          isSelectable: true,
                        ),
                        Divider(
                          height: 100,
                          thickness: 5,
                        ),
                        Container(
                          height: Configuration.DIALOG_BUTTON_HEIGHT,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                showInformationPage = false;
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
                      ]),
                )),
              ),
              floatingActionButton: Visibility(
                visible: !currentUserInfo.isAnonymous,
                child: FloatingActionButton(
                  onPressed: () {
                    _displayEditHtml(context, questionHtmlPrompt);
                  },
                  child: Icon(Icons.edit),
                  tooltip: "Edit Prompt",
                ),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
            );
          } else
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  postTaskQuestionnaire
                      ? "Post Task Questionnaire"
                      : "Questionnaire",
                  style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                ),
                centerTitle: true,
                backgroundColor: Colors.grey[800],
                actions: [
                  Visibility(
                    visible: !postTaskQuestionnaire,
                    child: TextButton.icon(
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
                        });
                      },
                    ),
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
                        rtdbService.removeCommentListener();
                        for (StreamSubscription s
                            in rtdbService.dbChangeListeners) s.cancel();
                        rtdbService.dbChangeListeners.clear();
                        reloadPage = true;
                        showEmptyResponses = false;
                      });
                    },
                  )
                ],
              ),
              body: Container(
                padding: EdgeInsets.all(5),
                child: Center(
                  child: SizedBox(
                    width: 1500,
                    child: currentUserInfo.isAnonymous
                        ? ListView.builder(
                            itemBuilder: _buildQuestionFrom,
                            itemCount: questions.length + 1,
                          )
                        : ReorderableListView.builder(
                            itemBuilder: _buildQuestionFrom,
                            itemCount: questions.length + 1,
                            onReorder: (oldIndex, newIndex) {
                              if (dbug) print("$oldIndex ==> $newIndex");
                              if (oldIndex == questions.length ||
                                  newIndex >=
                                      questions
                                          .length) // ignore dragging the button
                                return;
                              final index =
                                  newIndex > oldIndex ? newIndex - 1 : newIndex;
                              final Question q = questions.removeAt(oldIndex);
                              questions.insert(index, q);
                              setState(() {
                                showSaveOrderButton = true;
                              });
                            }),
                  ),
                ),
              ),
              floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Visibility(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FloatingActionButton.extended(
                        heroTag: "DISCARD_ORDER",
                        onPressed: () {
                          // use the cloned copy and just refresh the page
                          questions.clear();
                          for (Question v in clonedQuestions)
                            questions.add(Question.clone(v));

                          setState(() {
                            showSaveOrderButton =
                                false; // should rebuild the whole thing again here
                          });
                        },
                        label: const Text(
                          "Discard",
                          style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                        ),
                        backgroundColor: Colors.green,
                        icon: const Icon(Icons.dangerous_outlined),
                      ),
                    ),
                    visible: showSaveOrderButton,
                  ),
                  Visibility(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FloatingActionButton.extended(
                        heroTag: "SAVE_ORDER",
                        onPressed: () async {
                          setState(() {
                            showLoading = true;
                          });
                          // Save the order in DB and pull everything from DB again, i.e. reloadPage
                          await refreshOrderOfAllCurrentQuestions();
                          setState(() {
                            showLoading = false;
                            reloadPage = true;
                            showSaveOrderButton = false;
                          });
                        },
                        label: const Text(
                          "Save   ",
                          style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                        ),
                        backgroundColor: Colors.redAccent,
                        icon: const Icon(Icons.save_outlined),
                      ),
                    ),
                    visible: showSaveOrderButton,
                  ),
                  Visibility(
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: FloatingActionButton.extended(
                        heroTag: "ADD_QUESTION",
                        onPressed: () {
                          addOrEditQuestionDialog(null).then((newQ) {
                            if (dbug) {
                              print("QSize : ${questions.length}");
                              print("ClonedQSize: ${clonedQuestions.length}");
                            }
                            if (newQ != null)
                              clonedQuestions.add(Question.clone(newQ));
                          });
                        },
                        label: const Text(
                          "Add New",
                          style: TextStyle(
                              fontSize: Configuration.BUTTON_TEXT_SIZE),
                        ),
                        backgroundColor: Colors.blueAccent,
                        icon: const Icon(Icons.add),
                      ),
                    ),
                    visible: hasAdminAccess && !showSaveOrderButton,
                  ),
                ],
              ),
            );
        });
  }

  Future<void> getCommentsFromDB(String qId, Function dialogSetState) async {
    comments = await rtdbService.getComments(qId);
    rtdbService.addCommentListener(qId, (Comment newComment) async {
      if (comments.length == 0 ||
          (comments.last.commentId != newComment.commentId)) {
        // only add if it's the first comment for the question or this is a new comment
        comments.add(newComment);
        dialogSetState(() {});
        if (commentScrollController.hasClients)
          await commentScrollController.animateTo(
              commentScrollController.position.maxScrollExtent * 2,
              curve: Curves.easeOut,
              duration: Duration(milliseconds: 500));
      }
    });

    dialogLoading = false;
    dialogSetState(() {});
  }

  Future<void> ShowCommentForQuestion(
      BuildContext context, String qId, int index) async {
    if (dbug) print("NOW SHOWING COMMENTS FOR: $qId");
    commentController.clear();
    return showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            // get the comments from db here asynchronously
            if (comments == null && !currentUserInfo.isAnonymous) {
              dialogLoading = true;
              getCommentsFromDB(qId, setState);
            }

            return AlertDialog(
              title: Text(
                'Showing comments for Question ID : $qId',
                style: TextStyle(fontSize: Configuration.TEXT_SIZE),
              ),
              content: Container(
                width: 900,
                child: dialogLoading
                    ? SpinKitThreeInOut(color: Colors.blueGrey[400])
                    : Column(children: [
                        Text(
                          "Question: ${questions[index].qBody}",
                          style: TextStyle(
                              fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Type: ${questions[index].qType}",
                          style: TextStyle(
                              fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE,
                              fontWeight: FontWeight.bold),
                        ),
                        (comments.length == 0)
                            ? Expanded(
                                child: Center(
                                    child: Text(
                                  "No Comments",
                                  style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold),
                                )),
                              )
                            : Expanded(
                                child: ListView.builder(
                                itemBuilder: commentBuilder,
                                itemCount: comments.length,
                                controller: commentScrollController,
                              )),
                        TextFormField(
                          style: TextStyle(
                              fontSize:
                                  Configuration.QUESTIONNAIRE_FONT_SIZE - 1.0),
                          controller: commentController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.green, width: 5.0),
                                borderRadius: BorderRadius.circular(10)),
                            labelText: "Add a new comment",
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  height: Configuration.DIALOG_BUTTON_HEIGHT,
                                  child: TextButton(
                                    onPressed: () {
                                      if (commentController.text.isEmpty ||
                                          commentController.text == null)
                                        return; // do nothing
                                      Comment newC = Comment(
                                          comment: commentController.text,
                                          date: DateTime.now(),
                                          email: currentUserInfo.email,
                                          uid: currentUserInfo.uid);
                                      commentController.clear();
                                      rtdbService.addComment(
                                          qId,
                                          newC,
                                          questions[index].qBody,
                                          questions[index].qType);
                                    },
                                    child: Text(
                                      "Add Comment",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize:
                                              Configuration.BUTTON_TEXT_SIZE),
                                    ),
                                    style: ButtonStyle(
                                        backgroundColor:
                                            MaterialStateProperty.all(
                                                Colors.blue)),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  height: Configuration.DIALOG_BUTTON_HEIGHT,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(
                                        () {
                                          commentController.clear();
                                        },
                                      );
                                    },
                                    child: Text(
                                      "Clear",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize:
                                              Configuration.BUTTON_TEXT_SIZE),
                                    ),
                                    style: ButtonStyle(
                                        backgroundColor:
                                            MaterialStateProperty.all(
                                                Colors.green)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      ]),
              ),
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                  child: Center(
                    child: Container(
                      height: Configuration.DIALOG_BUTTON_HEIGHT,
                      child: TextButton(
                        style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.lightBlue)),
                        child: Text(
                          'Close',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: Configuration.BUTTON_TEXT_SIZE),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          comments = null;
                          if (!currentUserInfo.isAnonymous)
                            rtdbService.removeCommentListener();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          });
        });
  }

  Widget commentBuilder(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
          elevation: 1,
          shadowColor: Colors.blueGrey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${comments[index].email} commented: ",
                        style: TextStyle(
                            color:
                                comments[index].email == currentUserInfo.email
                                    ? Colors.blue
                                    : Colors.green,
                            fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE),
                      ),
                      Text(
                        "Date: ${comments[index].date.toString()}",
                        style: TextStyle(
                            fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE),
                      )
                    ]),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText(
                  comments[index].comment,
                  style: TextStyle(
                      fontSize: Configuration.QUESTIONNAIRE_FONT_SIZE - 1.0),
                ),
              )
            ],
          )),
    );
  }
}

// Padding(
//         padding: const EdgeInsets.all(40.0),
//         child: Center(
//           child: Card(
//             elevation: 20,
//             child: Column(
//               children: <Widget>[
//                 Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Row(
//                     children: <Widget>[
//                       Expanded(flex: 1 ,child: Text("Hello World")),
//                       Expanded(flex: 3,child: TextField())
//                     ],
//                   )
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.only(top: 30),
//                   child: Text("//TODO: ADD PERSONAL INFORMATION FOR FEEDBACK HERE!"),
//                 )
//               ],
//             ),
//           )
//         ),
//       )

// questions = [
//   Question(
//       qId: "id_1",
//       qBody: "Why do I do this?",
//       qType: Question.TFQ,
//       qOptions: ["True", "False"]),
//   Question(
//       qId: "id_2",
//       qBody: "Why do I do this?",
//       qType: Question.TFQ,
//       qOptions: ["True", "False"]),
//   Question(
//       qId: "id_3",
//       qBody: "Why do I do this?",
//       qType: Question.TFQ,
//       qOptions: ["True", "False"]),
//   Question(
//       qId: "id_4",
//       qBody: "Why do I do this?",
//       qType: Question.MCQ,
//       qOptions: ["Fatman", "Batman", "Catman", "Madman"]),
//   Question(
//       qId: "id_5",
//       qBody: "Why do I do this?",
//       qType: Question.TFQ,
//       qOptions: ["True", "False"]),
//   Question(
//       qId: "id_6",
//       qBody: "Another Question Example?",
//       qType: Question.MAQ,
//       qOptions: [
//         "The way of kings",
//         "Words of radiance",
//         "Oathbringer",
//         "Rhythm of war"
//       ]),
//   Question(qId: "id_7", qBody: "Judge Me", qType: "SAQ", qOptions: null),
// ];

// responses = [
//   QuestionResponse(
//       qId: "id_1", qType: Question.TFQ, qOptions: ["True", "False"]),
//   QuestionResponse(
//       qId: "id_2", qType: Question.TFQ, qOptions: ["True", "False"]),
//   QuestionResponse(
//       qId: "id_3", qType: Question.TFQ, qOptions: ["True", "False"]),
//   QuestionResponse(
//       qId: "id_4",
//       qType: Question.MCQ,
//       qOptions: ["Fatman", "Batman", "Catman", "Madman"]),
//   QuestionResponse(
//       qId: "id_5", qType: Question.TFQ, qOptions: ["True", "False"]),
//   QuestionResponse(qId: "id_6", qType: Question.MAQ, qOptions: [
//     "The way of kings",
//     "Words of radiance",
//     "Oathbringer",
//     "Rhythm of war"
//   ]),
//   QuestionResponse(qId: "id_7", qType: Question.SAQ, qOptions: null)
// ];
