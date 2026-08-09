import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import 'api_service.dart';

class AuthService {
  static const _sessionTokenKey = 'dumpit_session_token';
  static const _uidKey = 'dumpit_uid';

  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// 发送手机验证码，返回 verificationId 供 [confirmCode] 使用
  static Future<String> sendCode(String phoneNumber) async {
    final completer = Completer<String>();

    // 仅在 Firebase 未初始化时才初始化，避免重复初始化阻塞 UI
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } on Exception {
        // fallback: already initialized or default config
        try {
          await Firebase.initializeApp();
        } on Exception {
          // ignore
        }
      }
    }

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('自动验证完成，请在登录页直接确认登录'),
          );
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(e.message ?? '验证码发送失败'),
          );
        }
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('验证码已过期，请重新发送'),
          );
        }
      },
    );

    // 超时保护：30 秒没回调就报错，避免 UI 永远卡在发送中
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('请求超时，请检查网络后重试'),
    );
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
