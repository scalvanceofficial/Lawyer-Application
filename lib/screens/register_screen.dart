import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_role.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../repositories/legal_taxonomy_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_form_fields.dart';
import '../widgets/auth_background.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/register_fields.dart';
import '../widgets/terms_check.dart';
import '../widgets/multi_select_form_field.dart';
import 'client_dashboard.dart';
import 'lawyer_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Set<String> _availableDays = {};
  bool _acceptedTerms = false;
  String? _gender;
  final Set<String> _expertise = {};
  final LegalTaxonomyRepository _taxonomy = LegalTaxonomyRepository();
  final Set<String> _courts = {};
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _barCouncilIdController = TextEditingController();
  final _experienceController = TextEditingController();
  final _officeAddressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  String? _verifiedPhoneNumber;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  Uint8List? _profileImageBytes;

  bool get _isPhoneVerified =>
      _verifiedPhoneNumber != null &&
      _verifiedPhoneNumber == _normalizedPhoneNumber;

  String get _normalizedPhoneNumber {
    final raw = _phoneController.text.trim();
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.startsWith('+')) return '+$digits';
    if (digits.startsWith('91') && digits.length == 12) return '+$digits';
    return '+91$digits';
  }

  bool get _isLawyer => widget.role == UserRole.lawyer;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all required details and accept terms',
          ),
        ),
      );
      return;
    }
    if (!_isPhoneVerified || AuthService.currentUser?.phoneNumber == null) {
      _showMessage('Please verify your phone number with the OTP first.');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage('Passwords do not match.');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }
    if (_isLawyer && _availableDays.isEmpty) {
      _showMessage('Please select at least one available day.');
      return;
    }
    if (_isLawyer && _courts.isEmpty) {
      _showMessage('Please select your court of practice.');
      return;
    }
    if (_profileImageBytes == null) {
      _showMessage('Please add a profile photo to continue.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.register(
        email: _emailController.text,
        password: _passwordController.text,
        role: widget.role,
        profile: {
          'name': _nameController.text.trim(),
          'dateOfBirth': _dateOfBirthController.text.trim(),
          'gender': _gender,
          'phone': _normalizedPhoneNumber,
          'term': _acceptedTerms,
          'verified': false,
          if (_isLawyer) ...{
            'bio': _bioController.text.trim(),
            'barCouncilId': _barCouncilIdController.text.trim(),
            'barid': _barCouncilIdController.text.trim(),
            'expertise': _expertise.toList(growable: false),
            'aoe': _expertise.toList(growable: false),
            'experienceYears': _experienceController.text.trim(),
            'experience': _experienceController.text.trim(),
            'officeAddress': _officeAddressController.text.trim(),
            'location': _officeAddressController.text.trim(),
            'availability': _availableDays.toList(),
            'court': _courts.toList(growable: false),
            'courtType': _courts.toList(growable: false),
          } else
            'address': _addressController.text.trim(),
          'dob': _dateOfBirthController.text.trim(),
        },
        profileImageBytes: _profileImageBytes!,
      );
      await AppPreferences.completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              _isLawyer ? const LawyerDashboard() : const ClientDashboard(),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_firebaseMessage(error));
    } on AuthAccountException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Registration failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    final digits = _normalizedPhoneNumber.replaceFirst('+91', '');
    if (digits.length != 10) {
      _showMessage('Enter a valid 10-digit Indian phone number.');
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _normalizedPhoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            setState(() {
              _verifiedPhoneNumber = _normalizedPhoneNumber;
              _isSendingOtp = false;
            });
            _showMessage('Phone number verified successfully.');
          } on FirebaseAuthException catch (error) {
            if (mounted) setState(() => _isSendingOtp = false);
            _showMessage(_phoneAuthMessage(error));
          }
        },
        verificationFailed: (error) {
          if (mounted) setState(() => _isSendingOtp = false);
          _showMessage(_phoneAuthMessage(error));
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isSendingOtp = false;
            _otpController.clear();
          });
          _showMessage('OTP sent to $_normalizedPhoneNumber.');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isSendingOtp = false;
          });
        },
        timeout: const Duration(seconds: 60),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _isSendingOtp = false);
      _showMessage(_phoneAuthMessage(error));
    } catch (_) {
      if (mounted) setState(() => _isSendingOtp = false);
      _showMessage('Unable to send OTP. Please try again.');
    }
  }

  Future<void> _verifyOtp() async {
    final verificationId = _verificationId;
    final otp = _otpController.text.trim();
    if (verificationId == null) {
      _showMessage('Please request an OTP first.');
      return;
    }
    if (otp.length != 6) {
      _showMessage('Enter the 6-digit OTP.');
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      setState(() => _verifiedPhoneNumber = _normalizedPhoneNumber);
      _showMessage('Phone number verified successfully.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_phoneAuthMessage(error));
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _phoneNumberChanged(String value) {
    if (_verifiedPhoneNumber == _normalizedPhoneNumber) return;
    setState(() {
      _verifiedPhoneNumber = null;
      _verificationId = null;
      _otpController.clear();
    });
  }

  Future<void> _pickProfileImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _showMessage('Please choose a profile photo smaller than 5 MB.');
        return;
      }
      if (mounted) setState(() => _profileImageBytes = bytes);
    } catch (_) {
      _showMessage('Unable to open your photos. Please check permission.');
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial =
        _parseDateOfBirth(_dateOfBirthController.text) ??
        DateTime(now.year - 18, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select date of birth',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dateOfBirthController.text =
          '${selected.month.toString().padLeft(2, '0')}/'
          '${selected.day.toString().padLeft(2, '0')}/'
          '${selected.year}';
    });
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _positiveNumberValidator(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return 'Enter a valid number';
    return null;
  }

  String? _nameValidator(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Required';
    if (name.length < 2) return 'Enter your full name';
    return null;
  }

  String? _dateOfBirthValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final date = _parseDateOfBirth(value);
    if (date == null) return 'Select a valid date';
    if (!date.isBefore(DateTime.now())) return 'Date must be in the past';
    return null;
  }

  DateTime? _parseDateOfBirth(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String? _addressValidator(String? value) {
    final address = value?.trim() ?? '';
    if (address.isEmpty) return 'Required';
    if (address.length < 3) return 'Enter a complete address';
    return null;
  }

  String _phoneAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid.';
      case 'invalid-verification-code':
        return 'The OTP is incorrect. Please try again.';
      case 'session-expired':
        return 'The OTP expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many OTP attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota has been exceeded. Please try again later.';
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'Phone verification is still being activated. Please wait a few minutes and try again.';
      default:
        return error.message ?? 'Phone verification failed.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _firebaseMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'provider-already-linked':
        return 'This phone account already has login credentials.';
      case 'credential-already-in-use':
        return 'This phone number is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return error.message ?? 'Registration failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dateOfBirthController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _barCouncilIdController.dispose();
    _experienceController.dispose();
    _officeAddressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _showAvailabilityDialog() async {
    final Set<String> temp = {..._availableDays};
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text('Enter Your Availability'),
            contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final day in const [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: temp.contains(day),
                              onChanged: (value) {
                                setDialogState(() {
                                  value ? temp.add(day) : temp.remove(day);
                                });
                              },
                              title: Text(
                                day,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Time Range:',
                                  style: TextStyle(fontSize: 18),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'From',
                                      style: TextStyle(
                                        color: kBrown,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text('21:05'),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'To',
                                      style: TextStyle(
                                        color: kBrown,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text('21:05'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _availableDays
                      ..clear()
                      ..addAll(temp);
                  });
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 54, 14, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AuthGlassPanel(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                    child: Theme(
                      data: authFormTheme(context),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProfileAvatar(
                              imageBytes: _profileImageBytes,
                              onTap: _pickProfileImage,
                              isRequired: true,
                              compact: true,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _isLawyer
                                  ? 'Create advocate account'
                                  : 'Create user account',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _isLawyer
                                  ? 'Add your professional details to get started'
                                  : 'Enter your details to access legal services',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFEADFD8),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              hint: 'Full name',
                              controller: _nameController,
                              validator: _nameValidator,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              hint: 'Email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: _emailValidator,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              hint: 'Date of Birth',
                              controller: _dateOfBirthController,
                              keyboardType: TextInputType.datetime,
                              validator: _dateOfBirthValidator,
                              readOnly: true,
                              onTap: _pickDateOfBirth,
                            ),
                            const SizedBox(height: 8),
                            AppDropdownField(
                              hint: 'Select Gender',
                              value: _gender,
                              options: const ['Male', 'Female', 'Other'],
                              onChanged: (value) =>
                                  setState(() => _gender = value),
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              hint: _isLawyer
                                  ? 'Phone number with country code (+91)'
                                  : 'Phone',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              onChanged: _phoneNumberChanged,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isPhoneVerified)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.verified, color: Colors.green),
                                    SizedBox(width: 10),
                                    Text(
                                      'Phone number verified',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              _RegisterActionButton(
                                label: _isSendingOtp
                                    ? 'Sending OTP...'
                                    : _verificationId == null
                                    ? 'Get OTP'
                                    : 'Resend OTP',
                                onPressed: _isSendingOtp ? () {} : _sendOtp,
                              ),
                              if (_verificationId != null) ...[
                                const SizedBox(height: 8),
                                AppTextField(
                                  hint: 'Enter 6-digit OTP',
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 8),
                                _RegisterActionButton(
                                  label: _isVerifyingOtp
                                      ? 'Verifying OTP...'
                                      : 'Verify OTP',
                                  onPressed: _isVerifyingOtp
                                      ? () {}
                                      : _verifyOtp,
                                ),
                              ],
                            ],
                            const SizedBox(height: 8),
                            if (!_isLawyer) ...[
                              AppTextField(
                                hint: 'Address',
                                controller: _addressController,
                                validator: _addressValidator,
                                maxLines: 2,
                                autofillHints: const [
                                  AutofillHints.fullStreetAddress,
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_isLawyer) ...[
                              AppTextField(
                                hint: 'Enter your bio',
                                controller: _bioController,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              AppTextField(
                                hint: 'Bar Council ID',
                                controller: _barCouncilIdController,
                              ),
                              const SizedBox(height: 8),
                              StreamBuilder<List<String>>(
                                stream: _taxonomy.watchAreasOfExpertise(),
                                builder: (context, snapshot) =>
                                    MultiSelectFormField(
                                      label: 'Areas of expertise',
                                      options: snapshot.data ?? const [],
                                      selected: _expertise,
                                      loading:
                                          snapshot.connectionState ==
                                              ConnectionState.waiting &&
                                          !snapshot.hasData,
                                      errorText: snapshot.hasError
                                          ? 'Unable to load live expertise values'
                                          : snapshot.hasData &&
                                                snapshot.data!.isEmpty
                                          ? 'No expertise values are configured'
                                          : null,
                                      onChanged: (values) => setState(() {
                                        _expertise
                                          ..clear()
                                          ..addAll(values);
                                      }),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              AppTextField(
                                hint: 'Experience in years',
                                controller: _experienceController,
                                keyboardType: TextInputType.number,
                                validator: _positiveNumberValidator,
                              ),
                              const SizedBox(height: 8),
                              AppTextField(
                                hint: 'Enter Office Address',
                                controller: _officeAddressController,
                              ),
                              const SizedBox(height: 8),
                              AvailabilityField(
                                days: _availableDays,
                                onTap: _showAvailabilityDialog,
                              ),
                              const SizedBox(height: 8),
                              CourtField(
                                value: _courts,
                                onChanged: (value) => setState(() {
                                  _courts
                                    ..clear()
                                    ..addAll(value);
                                }),
                              ),
                              const SizedBox(height: 8),
                            ],
                            AppTextField(
                              hint: 'Password',
                              controller: _passwordController,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              hint: 'Confirm Password',
                              controller: _confirmPasswordController,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TermsCheck(
                                value: _acceptedTerms,
                                onChanged: (value) => setState(
                                  () => _acceptedTerms = value ?? false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _RegisterActionButton(
                              label: _isLoading
                                  ? 'Creating account...'
                                  : 'Create Account',
                              onPressed: _isLoading ? () {} : _register,
                            ),
                            const SizedBox(height: 8),
                            if (_isLawyer)
                              _RegisterActionButton(
                                label: 'Already have an account? Login',
                                outlined: true,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterActionButton extends StatelessWidget {
  const _RegisterActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: outlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: kBrown,
                side: const BorderSide(color: kBrown),
                shape: shape,
              ),
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kBrown,
                shape: shape,
              ),
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}
