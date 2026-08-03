import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService {
  static const _sessionTokenKey = 'dumpit_session_token';
  static const _uidKey = 'dumpit_uid';

  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// 发送手机验证码，返回 verificationId 供 [confirmCode] 使用
  static Future<String> sendCode(String phoneNumber) async {
    final completer = Completer<String>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(e.message ?? '验证码发送失败'));
        }
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  /// 用验证码登录，登录成功后向后端换取 session token 并本地持久化
  static Future<void> confirmCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final idToken = await userCredential.user!.getIdToken();

    final decoded = await ApiService.verifyFirebaseIdToken(idToken!);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, decoded['session_token'] as String);
    await prefs.setString(_uidKey, decoded['uid'] as String);
  }

  /// 读取本地持久化的 session token；未登录时返回 null
  static Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionTokenKey);
  }

  static Future<bool> isLoggedIn() async {
    return await getSessionToken() != null;
  }

  static Future<void> signOut() async {
    await _firebaseAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_uidKey);
  }
}
