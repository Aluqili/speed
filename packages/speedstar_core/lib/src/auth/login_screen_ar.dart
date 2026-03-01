import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreenArabic extends StatefulWidget {
  const LoginScreenArabic({
    super.key,
    this.allowRegister = true,
    this.allowGoogleSignIn = true,
    this.allowPhoneSignIn = true,
    this.allowGuestSignIn = true,
  });

  final bool allowRegister;
  final bool allowGoogleSignIn;
  final bool allowPhoneSignIn;
  final bool allowGuestSignIn;

  @override
  State<LoginScreenArabic> createState() => _LoginScreenArabicState();
}

class _LoginScreenArabicState extends State<LoginScreenArabic> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _smsCode = TextEditingController();

  bool _loading = false;
  bool _codeSent = false;

  String? _verificationId;
  int? _resendToken;
  String _defaultDialCode = '+249';
  bool _obscurePassword = true;

  // Toggles via Remote Config
  bool _allowGuest = false; // افتراضي: موقوف
  bool _allowGoogle = true; // افتراضي: مفعّل
  bool _allowPhone = true; // افتراضي: مفعّل

  @override
  void initState() {
    super.initState();
    _loadRemoteConfig();
  }

  Future<void> _loadRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      final all = rc.getAll();
      if (!mounted) return;
      setState(() {
        _allowGuest =
            all.containsKey('allow_guest') ? rc.getBool('allow_guest') : false;
        _allowGoogle =
            all.containsKey('allow_google') ? rc.getBool('allow_google') : true;
        _allowPhone =
            all.containsKey('allow_phone') ? rc.getBool('allow_phone') : true;
        if (all.containsKey('default_country_code')) {
          final v = rc.getString('default_country_code').trim();
          if (v.isNotEmpty) {
            _defaultDialCode = v.startsWith('+')
                ? v
                : (v.startsWith('00') ? '+${v.substring(2)}' : '+$v');
          }
        }
      });
    } catch (_) {
      // احتفظ بالقيم الافتراضية المحددة أعلاه
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('تسجيل الدخول'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE85D2A),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أهلاً بك في SpeedStar',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 6),
                          Text('أدخل بريدك وكلمة المرور للمتابعة بأمان.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        hintText: 'name@example.com',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_loading) _signIn();
                      },
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _loading ? null : _signIn,
                          icon: const Icon(Icons.login),
                          label: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('تسجيل الدخول'),
                        ),
                        if (widget.allowRegister)
                          OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => _RegisterScreenArabic(
                                          defaultDialCode: _defaultDialCode,
                                        ),
                                      ),
                                    );
                                  },
                            child: const Text('إنشاء حساب'),
                          ),
                        if (_allowGoogle && widget.allowGoogleSignIn)
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _signInWithGoogle,
                            icon: const Icon(Icons.login),
                            label: const Text('تسجيل بحساب جوجل'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (_allowGuest && widget.allowGuestSignIn)
                          TextButton(
                            onPressed: _loading ? null : _continueAsGuest,
                            child: const Text('تابع كضيف'),
                          ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          _ForgotPasswordScreenArabic(
                                        initialEmail: _email.text.trim(),
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_allowPhone && widget.allowPhoneSignIn) ...[
                      const Text('أو الدخول برقم الهاتف'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          hintText:
                              'مثال: +9665XXXXXXXX أو اكتب رقمك المحلي وسيُضاف رمز $_defaultDialCode',
                          prefixText: '$_defaultDialCode ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton(
                            onPressed: _loading
                                ? null
                                : () => _sendSmsCode(resend: false),
                            child: const Text('إرسال الرمز'),
                          ),
                        ],
                      ),
                      if (_codeSent) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _smsCode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'رمز التحقق',
                            hintText: '123456',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton(
                              onPressed: _loading ? null : _verifySmsCode,
                              child: const Text('تأكيد الرمز'),
                            ),
                            OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : () => _sendSmsCode(resend: true),
                              child: const Text('إعادة الإرسال'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _closeIfPresentedAsRoute() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    }
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'missing-email':
        return 'الرجاء إدخال البريد الإلكتروني';
      case 'user-not-found':
        return 'لم يتم العثور على مستخدم';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'البريد مستخدم بالفعل';
      case 'weak-password':
        return 'الكلمة ضعيفة؛ استخدم 6 أحرف فأكثر';
      case 'network-request-failed':
        return 'تعذّر الاتصال بالشبكة؛ تحقق من الإنترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة؛ حاول لاحقًا';
      case 'operation-not-allowed':
        return 'طريقة الدخول غير مفعّلة في Firebase (لوحة التحكم)';
      case 'user-disabled':
        return 'هذا الحساب موقوف';
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      default:
        return 'تعذّر إتمام العملية ($code)';
    }
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      final pass = _password.text;
      if (email.isEmpty) {
        _showError('الرجاء إدخال البريد الإلكتروني');
        return;
      }
      if (pass.isEmpty) {
        _showError('الرجاء إدخال كلمة المرور');
        return;
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      _closeIfPresentedAsRoute();
    } on FirebaseAuthException catch (e) {
      _showError(_messageForCode(e.code));
    } catch (e) {
      _showError('حدث خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizePhone(String input) {
    var p = input.trim().replaceAll(' ', '');
    if (p.isEmpty) return p;
    if (p.startsWith('+')) return p;
    if (p.startsWith('00')) return '+${p.substring(2)}';
    while (p.startsWith('0')) {
      p = p.substring(1);
    }
    return '$_defaultDialCode$p';
  }

  Future<void> _sendSmsCode({bool resend = false}) async {
    setState(() => _loading = true);
    try {
      final phone = _normalizePhone(_phone.text);
      if (phone.isEmpty) {
        _showError('الرجاء إدخال رقم الهاتف');
        return;
      }
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          _closeIfPresentedAsRoute();
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          final em = e.message ?? '';
          _showError(
              '${_messageForCode(e.code)}${em.isNotEmpty ? ' - $em' : ''}');
        },
        forceResendingToken: resend ? _resendToken : null,
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _showError('تم إرسال الرمز إلى $phone، تحقق من الرسائل');
          setState(() {});
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          _verificationId = verificationId;
          _showError(
              'انتهت مهلة الاسترجاع الآلي، يمكنك إدخال الرمز يدويًا أو إعادة الإرسال');
        },
      );
    } catch (e) {
      _showError('تعذّر إرسال الرمز');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifySmsCode() async {
    setState(() => _loading = true);
    try {
      final code = _smsCode.text.trim();
      if (code.isEmpty || _verificationId == null) {
        _showError('أدخل الرمز أولًا');
        return;
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      _closeIfPresentedAsRoute();
    } on FirebaseAuthException catch (e) {
      _showError(_messageForCode(e.code));
    } catch (e) {
      _showError('تعذّر تأكيد الرمز');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      _closeIfPresentedAsRoute();
    } on FirebaseAuthException catch (e) {
      _showError(_messageForCode(e.code));
    } catch (e) {
      _showError('حدث خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) {
        _showError('تم إلغاء عملية تسجيل جوجل');
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      _closeIfPresentedAsRoute();
    } on FirebaseAuthException catch (e) {
      _showError(_messageForCode(e.code));
    } catch (e) {
      _showError('تعذّر تسجيل الدخول عبر جوجل');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _RegisterScreenArabic extends StatefulWidget {
  const _RegisterScreenArabic({required this.defaultDialCode});

  final String defaultDialCode;

  @override
  State<_RegisterScreenArabic> createState() => _RegisterScreenArabicState();
}

class _RegisterScreenArabicState extends State<_RegisterScreenArabic> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'email-already-in-use':
        return 'البريد مستخدم بالفعل';
      case 'weak-password':
        return 'الكلمة ضعيفة؛ استخدم 6 أحرف فأكثر';
      default:
        return 'تعذّر إتمام العملية ($code)';
    }
  }

  String _normalizePhone(String input) {
    var p = input.trim().replaceAll(' ', '');
    if (p.isEmpty) return p;
    if (p.startsWith('+')) return p;
    if (p.startsWith('00')) return '+${p.substring(2)}';
    while (p.startsWith('0')) {
      p = p.substring(1);
    }
    return '${widget.defaultDialCode}$p';
  }

  Future<void> _upsertClientProfile({
    required User user,
    required String name,
    required String phone,
    required String email,
  }) async {
    final docRef =
        FirebaseFirestore.instance.collection('clients').doc(user.uid);
    final existing = await docRef.get();

    final payload = <String, dynamic>{
      'name': name,
      'fullName': name,
      'displayName': name,
      'phone': phone,
      'phoneNumber': phone,
      'email': email,
      'ownerUid': user.uid,
      'uid': user.uid,
      'userId': user.uid,
      'userType': 'client',
      'role': 'client',
      'isActive': true,
      'isApproved': true,
      'approvalStatus': 'approved',
      'stateId': existing.data()?['stateId'] ?? '',
      'region': existing.data()?['region'] ?? '',
      'defaultAddressId': existing.data()?['defaultAddressId'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final name = _name.text.trim();
      final phone = _normalizePhone(_phone.text);
      final email = _email.text.trim();
      final pass = _password.text;

      if (name.isEmpty) {
        _showError('الرجاء إدخال الاسم');
        return;
      }
      if (phone.isEmpty) {
        _showError('الرجاء إدخال رقم الهاتف');
        return;
      }
      if (email.isEmpty) {
        _showError('الرجاء إدخال البريد الإلكتروني');
        return;
      }
      if (pass.length < 6) {
        _showError('الحد الأدنى لطول كلمة المرور هو 6 أحرف');
        return;
      }

      UserCredential credential;
      try {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;

        try {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: pass,
          );
        } on FirebaseAuthException catch (signInError) {
          if (signInError.code == 'wrong-password' ||
              signInError.code == 'invalid-credential') {
            _showError(
                'هذا البريد مسجل بالفعل. أدخل نفس كلمة مرور الحساب الحالي لربطه كعميل.');
            return;
          }
          if (signInError.code == 'user-disabled') {
            _showError('هذا الحساب موقوف.');
            return;
          }
          _showError(_messageForCode(signInError.code));
          return;
        }
      }

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await _upsertClientProfile(
          user: user,
          name: name,
          phone: phone,
          email: email,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showError(_messageForCode(e.code));
    } catch (_) {
      _showError('حدث خطأ غير متوقع أثناء إنشاء الحساب');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('إنشاء حساب عميل'), centerTitle: true),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حساب عميل جديد',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 6),
                        Text(
                            'يمكنك استخدام نفس البريد الموجود في المتجر/المندوب وربطه بدور العميل.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      filled: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText:
                          'مثال: +2499XXXXXXX أو اكتب رقمك المحلي وسيُضاف رمز ${widget.defaultDialCode}',
                      prefixText: '${widget.defaultDialCode} ',
                      filled: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      hintText: 'name@example.com',
                      filled: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      filled: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _loading ? null : _register,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('إنشاء الحساب'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordScreenArabic extends StatefulWidget {
  const _ForgotPasswordScreenArabic({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordScreenArabic> createState() =>
      _ForgotPasswordScreenArabicState();
}

class _ForgotPasswordScreenArabicState
    extends State<_ForgotPasswordScreenArabic> {
  late final TextEditingController _email;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد';
      default:
        return 'تعذّر إتمام العملية ($code)';
    }
  }

  Future<void> _sendResetEmail() async {
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      if (email.isEmpty) {
        _showError('الرجاء إدخال البريد الإلكتروني');
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك'),
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showError(_messageForCode(e.code));
    } catch (_) {
      _showError('تعذّر إرسال رابط الاستعادة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('نسيت كلمة المرور')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                      'أدخل بريدك وسنرسل لك رابط إعادة تعيين كلمة المرور.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      hintText: 'name@example.com',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _sendResetEmail,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('إرسال رابط إعادة التعيين'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
