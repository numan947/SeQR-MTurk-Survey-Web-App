import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_qr_survey_app/Configuration.dart';
import 'package:wifi_qr_survey_app/LoadingPage.dart';
import 'package:wifi_qr_survey_app/MainApp.dart';
import 'package:wifi_qr_survey_app/RootPage.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({Key key}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  String blackList;
  final SnackBar errorSnack = SnackBar(
    content: Container(
        height: 40,
        child: Center(
            child: Text(
          "Login Failed!",
          style: TextStyle(fontSize: Configuration.TEXT_SIZE),
        ))),
    backgroundColor: Colors.red[500],
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: 3),
  );

  final TextEditingController workerIdController = TextEditingController();
  String email;
  String password;
  bool showLoading = false;
  SharedPreferences prefs;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> initializeLocalSharedPrefs() async {
    prefs = await SharedPreferences.getInstance();
  }

  @override
  void initState() {
    super.initState();
    initializeLocalSharedPrefs();
    workerIdController.addListener(() {
      currentUserInfo.workerId = workerIdController.text.trim();
    });
    emailController.addListener(() {
      this.email = emailController.text;
    });

    passwordController.addListener(() {
      this.password = passwordController.text;
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    workerIdController.dispose();
    super.dispose();
  }

  Future<void> showAdminLogin() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(
            child: Text(
              'Admin Login',
              style: TextStyle(fontSize: Configuration.TEXT_SIZE),
            ),
          ),
          content: StatefulBuilder(builder: (context, setState) {
            return Container(
              height: 200,
              width: 550,
              child: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: TextField(
                        style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                        decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Email',
                            hintText: 'Please enter your email'),
                        controller: emailController,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: TextField(
                        style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                        obscureText: true,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Password',
                            hintText: 'Please enter your password'),
                        controller: passwordController,
                      ),
                    ),
                  ],
                ),
              ),
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
                    emailController.clear();
                    passwordController.clear();
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
                  child: const Text('Login',
                      style: TextStyle(
                          fontSize: Configuration.BUTTON_TEXT_SIZE,
                          color: Colors.green)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (this.email == null ||
                        this.password == null ||
                        this.email.isEmpty ||
                        this.password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(errorSnack);
                      workerIdController.clear();
                      passwordController.clear();
                      emailController.clear();
                    } else {
                      tryToLoginAsAdmin();
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (blackList == null) {
      loadBlackList();
      return LoadingPage();
    }

    return StreamBuilder<Object>(
        stream: authService.auth.authStateChanges(),
        builder: (context, snapshot) {
          if (showLoading) return LoadingPage();

          if (dbug) {
            print("Inside LandingPage.dart");
            print("snpashot.hasData: ${snapshot.hasData}");
            print(snapshot.connectionState);
          }
          if (snapshot.connectionState == ConnectionState.waiting)
            return LoadingPage();

          if (snapshot.hasData) {
            User u = snapshot.data;
            currentUserInfo.setUserInfo(u);
            return RootPage();
          }

          return Scaffold(
              appBar: AppBar(
                elevation: 15,
                title: Text(
                  "Wifi Phase 2 Survey",
                  style: TextStyle(fontSize: Configuration.TEXT_SIZE),
                ),
                centerTitle: true,
                backgroundColor: Colors.grey[800],
                titleTextStyle: TextStyle(fontSize: 30, color: Colors.white),
                actions: [
                  TextButton(
                      onPressed: () {
                        showAdminLogin();
                      },
                      child: Text(
                        "Admin Login",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: Configuration.BUTTON_TEXT_SIZE),
                      ))
                ],
              ),
              body: Center(
                child: SizedBox(
                  width: 800,
                  child: Card(
                    color: Colors.white,
                    elevation: 5,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: TextField(
                              style:
                                  TextStyle(fontSize: Configuration.TEXT_SIZE),
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Worker ID',
                                  hintText:
                                      'Please enter your Worker ID, e.g., A3XV63UMU77LL2',
                                  errorText: isValidWorkerId()
                                      ? null
                                      : "Invalid Worker Id"),
                              controller: workerIdController,
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            height: 60,
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    showLoading = true;
                                  });
                                  if (currentUserInfo.getWorkerId() == null ||
                                      currentUserInfo.getWorkerId() == "" ||
                                      !isValidWorkerId() ||
                                      workerIdController.text.isEmpty) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(errorSnack);
                                    workerIdController.clear();
                                  } else {
                                    if (blackList.toUpperCase().contains(
                                        workerIdController.text
                                            .toUpperCase())) {
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        "/thankyou",
                                        (Route<dynamic> route) => false,
                                      );
                                      return;
                                    }
                                    bool result = await authService
                                        .signInAnonymous(context);
                                    await prefs.clear(); // clear first
                                    if (result == true) {
                                      await prefs.setString(AMT_WORKER_ID,
                                          currentUserInfo.getWorkerId());
                                      currentUserInfo
                                          .setUserInfo(authService.getUser());
                                      this.workerIdController.clear();
                                    } else {
                                      workerIdController.clear();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(errorSnack);
                                    }
                                  }
                                  setState(() {
                                    showLoading = false;
                                  });
                                },
                                child: Text(
                                  "SUBMIT",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Configuration.BUTTON_TEXT_SIZE,
                                      letterSpacing: 1.5),
                                ),
                                style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all(
                                        Colors.grey[800]),
                                    foregroundColor: MaterialStateProperty.all(
                                        Colors.grey[500]),
                                    elevation: MaterialStateProperty.all(1.0)),
                              ),
                            ),
                          ),
                        ]),
                  ),
                ),
              ));
        });
  }

  bool isValidWorkerId() {
    if (workerIdController.text.characters.contains('.') ||
        workerIdController.text.characters.contains('#') ||
        workerIdController.text.characters.contains('\$') ||
        workerIdController.text.characters.contains(']') ||
        workerIdController.text.characters.contains('[')) return false;
    return true;
  }

  Future<void> tryToLoginAsAdmin() async {
    setState(() {
      showLoading = true;
    });
    bool success = await authService.signIn(email, password);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(errorSnack);
      passwordController.clear();
      emailController.clear();
      workerIdController.clear();
    }

    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      showLoading = false;
    });
    emailController.clear();
    passwordController.clear();
  }

  Future<void> loadBlackList() async {
    blackList = await rtdbService.getBlackList();
    setState(() {});
  }
}
