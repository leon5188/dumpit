import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _isSending = false;
  bool _isConfirming = false;
  String? _errorMsg;

  Future<void> _sendCode() async {
    setState(() {
      _isSending = true;
      _errorMsg = null;
    });
    try {
      final raw = _phoneController.text.trim();
      if (raw.isEmpty) {
        throw Exception('请输入手机号');
      }
      // 归一化为 E.164：带 + 则直接用，否则默认补 +1（美国）
      var phone = raw.replaceAll(RegExp(r'[^\d+]'), '');
      if (!phone.startsWith('+')) {
        phone = '+1$phone';
      }
      // 前端位数校验：E.164 有效长度为 8-15 位数字，避免 Firebase 报 too short
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 8 || digits.length > 15) {
        throw Exception('手机号位数不正确（需 8–15 位），请检查后重试');
      }
      final verificationId = await AuthService.sendCode(phone);
      if (!mounted) return;
      setState(() {
        _verificationId = verificationId;
      });
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMsg = msg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _confirmCode() async {
    if (_verificationId == null) return;
    setState(() {
      _isConfirming = true;
      _errorMsg = null;
    });
    try {
      await AuthService.confirmCode(_verificationId!, _codeController.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMsg = msg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(title: const Text('登录以启用云同步')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              enabled: _verificationId == null,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                labelText: '手机号（如 186****4567，自动补 +1）',
                hintText: '输入本地号码即可，自动加 +1',
                labelStyle: TextStyle(color: Colors.grey),
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            if (_verificationId == null)
              ElevatedButton(
                onPressed: _isSending ? null : _sendCode,
                child: Text(_isSending ? '发送中...' : '发送验证码'),
              )
            else ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isConfirming ? null : _confirmCode,
                child: Text(_isConfirming ? '登录中...' : '确认登录'),
              ),
            ],
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}
