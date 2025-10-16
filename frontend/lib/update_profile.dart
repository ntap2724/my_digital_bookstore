import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/app_form_field.dart';
import 'package:my_flutter_app/widgets/app_small_field.dart';
import 'package:my_flutter_app/widgets/primary_button.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Profile fields
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  bool _avName = false, _avPhone = false, _avDob = false, _avGender = false;
  DateTime? _dob;
  String? _gender; // 'male' | 'female' | 'other'

  // Password change fields removed (handled on separate ChangePassword page)

  // Snapshot to detect unsaved changes
  String _initName = '';
  String _initPhone = '';
  DateTime? _initDob;
  String? _initGender;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) setState(() => _avName = true);
    });
    _phoneFocus.addListener(() {
      if (!_phoneFocus.hasFocus) setState(() => _avPhone = true);
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await AuthService.instance.me();
      if (me != null) {
        _nameCtrl.text = me['name']?.toString() ?? '';
        _emailCtrl.text = me['email']?.toString() ?? '';
        _phoneCtrl.text = me['phone']?.toString() ?? '';
        final dobStr = me['dob']?.toString();
        if (dobStr != null && dobStr.isNotEmpty) {
          final d = DateTime.tryParse(dobStr);
          if (d != null) {
            _dob = d;
            _dobCtrl.text = _formatDate(d);
          }
        }
        // Map server gender to internal keys
        final g = me['gender']?.toString();
        if (g != null && g.isNotEmpty) {
          _gender = switch (g) {
            'Nam' => 'male',
            'Ná»¯' => 'female',
            'Nu' => 'female',
            'KhÃ¡c' => 'other',
            _ => 'other',
          };
        }
        // Normalize gender defensively to english keys
        final g2 = me['gender']?.toString().trim().toLowerCase();
        if (g2 != null && g2.isNotEmpty) {
          if (g2 == 'male' || g2.startsWith('nam')) {
            _gender = 'male';
          } else if (g2 == 'female' ||
              g2 == 'nu' ||
              g2 == 'ná»¯' ||
              g2 == 'nÆ°Ìƒ') {
            _gender = 'female';
          } else if (g2 == 'other' ||
              g2.startsWith('khac') ||
              g2.startsWith('khÃ¡c')) {
            _gender = 'other';
          }
        }
        // Save snapshot
        _initName = _nameCtrl.text;
        _initPhone = _phoneCtrl.text;
        _initDob = _dob;
        _initGender = _gender;
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final init = _dob ?? DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 120);
    final last = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = _formatDate(picked);
      });
    }
  }

  // ignore: unused_element
  Widget _passwordChecklist(String v, AppLocalizations t) {
    final hasLen = v.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasLower = RegExp(r'[a-z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    final hasSpecial = RegExp(
      r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/;+=]',
    ).hasMatch(v);

    Widget item(bool ok, String text) => Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: ok ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item(hasLen, t.passwordRuleLen),
        item(hasUpper, t.passwordRuleUpper),
        item(hasLower, t.passwordRuleLower),
        item(hasDigit, t.passwordRuleDigit),
        item(hasSpecial, t.passwordRuleSpecial),
      ],
    );
  }

  // ignore: unused_element
  Future<void> _submitPassword() async {
    // no-op: password change handled on dedicated page
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final t = context.l10n;
    // Always send english keys for gender
    String? g = _gender;
    final res = await AuthService.instance.updateProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      dob: _dob,
      gender: g,
    );
    if (!mounted) return;
    if (res.success) {
      // Refresh local caches so other screens (e.g., Home) see updated info without manual refresh
      try {
        await AuthService.instance.refreshLocalProfileCache();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.profileUpdated)));
      // Refresh snapshot so back button does not warn
      _initName = _nameCtrl.text;
      _initPhone = _phoneCtrl.text;
      _initDob = _dob;
      _initGender = _gender;
    } else {
      // Refresh snapshot so back button does not warn
      _initName = _nameCtrl.text;
      _initPhone = _phoneCtrl.text;
      _initDob = _dob;
      _initGender = _gender;
      final msg = res.message ?? t.errorPrefix('');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.changeInfoTitle),
        leading: BackButton(
          onPressed: () async {
            final ok = await _onWillPopConfirm();
            if (!context.mounted) return;
            if (ok) Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile section
                    AppFormField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      autovalidateMode: _avName
                          ? AutovalidateMode.always
                          : AutovalidateMode.disabled,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t.fullName,
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return t.fullNameRequired;
                        if (s.length < 2) return t.fullNameTooShort;
                        return null;
                      },
                    ),
                    const SizedBox(height: 0),
                    AppFormField(
                      controller: _emailCtrl,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: t.email,
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 0),
                    AppFormField(
                      controller: _phoneCtrl,
                      focusNode: _phoneFocus,
                      autovalidateMode: _avPhone
                          ? AutovalidateMode.always
                          : AutovalidateMode.disabled,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t.phone,
                        hintText: t.phoneHint,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        final s = (v ?? '').replaceAll(RegExp(r'\s+'), '');
                        if (s.isEmpty) return t.phoneRequired;
                        if (!RegExp(r'^(0|\+84)(\d{9})$').hasMatch(s)) {
                          return t.phoneInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 0),
                    Row(
                      children: [
                        Expanded(
                          child: AppSmallTextField(
                            controller: _dobCtrl,
                            readOnly: true,
                            onTap: () {
                              _pickDob();
                              setState(() => _avDob = true);
                            },
                            autovalidateMode: _avDob
                                ? AutovalidateMode.always
                                : AutovalidateMode.disabled,
                            decoration: InputDecoration(
                              labelText: t.dateOfBirth,
                              prefixIcon: const Icon(Icons.cake_outlined),
                              suffixIcon: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: IconButton(
                                    tooltip: t.selectDate,
                                    onPressed: () {
                                      _pickDob();
                                      setState(() => _avDob = true);
                                    },
                                    splashRadius: 20,
                                    icon: const Icon(Icons.event_outlined),
                                  ),
                                ),
                              ),
                            ),
                            validator: (_) {
                              if (_dob == null) return t.dobRequired;
                              final now = DateTime.now();
                              var age = now.year - _dob!.year;
                              if (now.month < _dob!.month ||
                                  (now.month == _dob!.month &&
                                      now.day < _dob!.day)) {
                                age--;
                              }
                              if (age < 13) return t.ageRequirement;
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppSmallDropdown<String>(
                            key: ValueKey(_gender),
                            initialValue:
                                (_gender == 'male' ||
                                    _gender == 'female' ||
                                    _gender == 'other')
                                ? _gender
                                : null,
                            autovalidateMode: _avGender
                                ? AutovalidateMode.always
                                : AutovalidateMode.disabled,
                            decoration: InputDecoration(
                              labelText: t.gender,
                              prefixIcon: const Icon(Icons.wc_outlined),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'male',
                                child: Text(t.male),
                              ),
                              DropdownMenuItem(
                                value: 'female',
                                child: Text(t.female),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text(t.other),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _gender = v;
                              _avGender = true;
                            }),
                            validator: (v) => (v == null || v.isEmpty)
                                ? t.genderRequired
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(t.saveChanges),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasUnsavedChanges {
    final profileChanged =
        _nameCtrl.text.trim() != _initName.trim() ||
        _phoneCtrl.text.trim() != _initPhone.trim() ||
        (_dob?.toIso8601String() ?? '') !=
            (_initDob?.toIso8601String() ?? '') ||
        (_gender ?? '') != (_initGender ?? '');
    return profileChanged;
  }

  Future<bool> _onWillPopConfirm() async {
    if (!_hasUnsavedChanges) return true;
    final t = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.unsavedChangesTitle),
        content: Text(t.unsavedChangesMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.discard),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.stay),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
