import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:otp_text_field/otp_text_field.dart';
class User {
  User({@required this.uid,this.photoUrl,this.displayName});
  final String uid;
  final String displayName;
  final String photoUrl;
}

abstract class AuthBase {
  Stream<User> get onAuthChanged;
  Future<User> createUserWithEmailAndPassword(String email,String password);
  Future<User> signInWithEmailAndPassword(String email,String password);
  Future<User> currentUser();
  Future<String> updateUser(String name);
  Future<void> signOut();
  Future<User> signInGoogle();
  Future<User> signInWithFacebok();
  Future<User> verifyPhone(BuildContext context,String phone);
}

class Auth implements AuthBase {
  String phoneNo, smssent, verificationId, sms, errorMessage;
  final _firebaseAuth = FirebaseAuth.instance;

  User _userFromFirebase(FirebaseUser user) {
    if (user == null) {
      return null;
    }
    return User(uid: user.uid,photoUrl: user.photoUrl,displayName: user.displayName);
  }

  @override
  Stream<User> get onAuthChanged {
    return _firebaseAuth.onAuthStateChanged.map(_userFromFirebase);
  }
  @override
  Future<String> updateUser(String name) async {
    final user = await _firebaseAuth.currentUser();
    var userUpdateInfo = UserUpdateInfo();
    userUpdateInfo.displayName=name;
    await user.updateProfile(userUpdateInfo);
    await user.reload();
    return user.uid;
  }
  @override
  Future<User> currentUser() async {
    final user = await _firebaseAuth.currentUser();
    return _userFromFirebase(user);
  }

  @override
  Future<User> createUserWithEmailAndPassword(String email,String password) async{
    final authResult=await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    return _userFromFirebase(authResult.user);
  }
  @override
  Future<User> signInWithEmailAndPassword(String email,String password) async{
    final authResult=await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    return _userFromFirebase(authResult.user);
  }


  //Google

  Future<User> signInGoogle()async{
    final googleSIgnIn = GoogleSignIn();
    final account = await googleSIgnIn.signIn();
    if(account !=null){
      GoogleSignInAuthentication googleAuth= await account.authentication;
      if(googleAuth.accessToken !=null && googleAuth.idToken !=null){
        final result =await _firebaseAuth.signInWithCredential(
          GoogleAuthProvider.getCredential(idToken: googleAuth.idToken, accessToken: googleAuth.accessToken),
        );
        return _userFromFirebase(result.user);
      }
    }
  }
//Facebook
  @override
  Future<User> signInWithFacebok() async{
    final facebookLogin = FacebookLogin();
    final result = await facebookLogin.logIn(['public_profile'],);
    if(result.accessToken != null){
      final authResult= await _firebaseAuth.signInWithCredential(
          FacebookAuthProvider.getCredential(
              accessToken: result.accessToken.token
          )
      );
      return await _userFromFirebase(authResult.user);
    }else{
     print('No access token found');
    }
  }

                                                //________________Phone_______________________//
  Future<User> verifyPhone(BuildContext context,String phone)async{
    final PhoneVerificationCompleted verified=
        (AuthCredential authResult){
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      BotToast.showText(text: 'Auto Completed verification',duration: Duration(seconds: 2),align: Alignment.center);
      return _userFromFirebase(signIn(authResult));

    };
    final PhoneVerificationFailed verificationfailed =
        (AuthException authException) {
      print('${authException.message}');
      BotToast.showText(
        text: '${authException.message}',
        textStyle: TextStyle(color: Colors.white, fontSize: 16),
        borderRadius: BorderRadius.all(Radius.circular(8)),
        duration: Duration(seconds: 15),
        animationDuration: Duration(seconds: 2),
        clickClose: true,
      );
    };
    final PhoneCodeSent smsSent = (String verId, [int forceResend]) {
      this.verificationId = verId;
      smsCodeDialoge(context);
    };
    final PhoneCodeAutoRetrievalTimeout autoTimeout = (String verId) {
      this.verificationId = verId;
    };
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: verified,
      verificationFailed: verificationfailed,
      codeSent: smsSent,
      codeAutoRetrievalTimeout: autoTimeout,);
  }
  signIn(AuthCredential authCreds) async{
    try{
      await _firebaseAuth.signInWithCredential(authCreds);
    }catch (e){
      print(e);
      BotToast.showText(
        text: '${e.message}',
        textStyle: TextStyle(color: Colors.white, fontSize: 16),
        borderRadius: BorderRadius.all(Radius.circular(8)),
        duration: Duration(seconds: 15),
        animationDuration: Duration(seconds: 2),
        clickClose: true,
      );
    }
  }
  signInWithOTP( smsCode, verId) {
    AuthCredential authCreds = PhoneAuthProvider.getCredential(
        verificationId: verId, smsCode: smsCode);
    return signIn(authCreds);
  }
  Future<bool> smsCodeDialoge(BuildContext context) {

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return new AlertDialog(
          title: Text('Validate with OTP'),
          content:OTPTextField(
            length: 6,
            width: MediaQuery.of(context).size.width,
            style: TextStyle(

                fontSize: 17
            ),
            onCompleted: (pin) {
              this.sms=pin;
            },
          ),
          contentPadding: EdgeInsets.all(10.0),
          actions: <Widget>[
            new FlatButton(
                onPressed: () {
                  FirebaseAuth.instance.currentUser().then((user){
                    signInWithOTP(sms, verificationId);
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                  });
                },
                child: Text(
                  'Done',
                  style: TextStyle(color: Colors.orangeAccent),
                ))
          ],
        );
      },
    );
  }

  @override
  Future<void> signOut() async {
    final gsignin= GoogleSignIn();
    await gsignin.signOut();
    final facebookLogin= FacebookLogin();
    await facebookLogin.logOut();
    await _firebaseAuth.signOut();
  }
}
