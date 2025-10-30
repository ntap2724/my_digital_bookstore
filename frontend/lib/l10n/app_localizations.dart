import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  final Map<String, String> _strings;
  final Map<String, String> _fallback;

  AppLocalizations._(this.locale, this._strings, this._fallback);

  static const supportedLocales = [Locale('en'), Locale('vi')];

  static Future<AppLocalizations> load(Locale locale) async {
    final lang = locale.languageCode.toLowerCase();
    final primaryPath = 'assets/l10n/$lang.json';
    final fallbackPath = 'assets/l10n/en.json';

    Map<String, String> decode(String src) {
      final map = (jsonDecode(src) as Map).cast<String, dynamic>();
      return map.map((k, v) => MapEntry(k, v.toString()));
    }

    // Load primary; if missing, fallback to en
    Map<String, String> primary;
    try {
      final s = await rootBundle.loadString(primaryPath, cache: false);
      primary = decode(s);
    } catch (_) {
      final s = await rootBundle.loadString(fallbackPath, cache: false);
      primary = decode(s);
    }

    // Load fallback EN for missing keys
    Map<String, String> fb;
    try {
      final s = await rootBundle.loadString(fallbackPath, cache: false);
      fb = decode(s);
    } catch (_) {
      fb = const {};
    }

    return AppLocalizations._(locale, primary, fb);
  }

  static AppLocalizations of(BuildContext context) {
    final t = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(t != null, 'AppLocalizations not found in widget tree.');
    return t!;
  }

  String _t(String key) => _strings[key] ?? _fallback[key] ?? key;

  String _fmt(String key, Map<String, String> params) {
    var s = _t(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  // ---- App / Common ----
  String get appName => _t('appName');
  String get settings => _t('settings');
  String get view => _t('view');
  String get welcome => _t('welcome');
  String get initializing => _t('initializing');
  String get home => _t('home');
  String get refresh => _t('refresh');
  String get retry => _t('retry');
  String get noUserData => _t('noUserData');
  String get rawData => _t('rawData');
  String get drawerSettings => _t('drawerSettings');
  String get drawerLogout => _t('drawerLogout');

  // ---- Dynamic helpers ----
  String errorPrefix(String message) =>
      _fmt('errorPrefix', {'message': message});
  String helloUser(String name) => _fmt('helloUser', {'name': name});
  String emailLabel(String email) => _fmt('emailLabel', {'email': email});
  String linkSentTo(String email) => _fmt('linkSentTo', {'email': email});
  String confirmRemoveMessage(String email) =>
      _fmt('confirmRemoveMessage', {'email': email});

  // ---- Auth / Login / Register ----
  String get login => _t('login');
  String get register => _t('register');
  String get loginSuccess => _t('loginSuccess');
  String get loginFailed => _t('loginFailed');
  String get invalidCredentials => _t('invalidCredentials');
  String get emailNotFound => _t('emailNotFound');
  String get signInWithAnotherEmail => _t('signInWithAnotherEmail');
  String get continueAction => _t('continueAction');
  String get forgotPassword => _t('forgotPassword');
  String get sending => _t('sending');
  String get sendLink => _t('sendLink');
  String get forgotInstruction => _t('forgotInstruction');
  String get verifyEmail => _t('verifyEmail');
  String get resetPassword => _t('resetPassword');
  String get forgotInstructionStep2 => _t('forgotInstructionStep2');
  String get haveAccount => _t('haveAccount');
  String get noAccount => _t('noAccount');
  String get loggingIn => _t('loggingIn');

  // ---- Fields / Validation ----
  String get email => _t('email');
  String get emailRequired => _t('emailRequired');
  String get emailInvalid => _t('emailInvalid');
  String get password => _t('password');
  String get passwordRequired => _t('passwordRequired');
  String get showPassword => _t('showPassword');
  String get hidePassword => _t('hidePassword');
  String get fullName => _t('fullName');
  String get fullNameHint => _t('fullNameHint');
  String get fullNameRequired => _t('fullNameRequired');
  String get fullNameTooShort => _t('fullNameTooShort');
  String get phone => _t('phone');
  String get phoneHint => _t('phoneHint');
  String get phoneRequired => _t('phoneRequired');
  String get phoneInvalid => _t('phoneInvalid');
  String get dateOfBirth => _t('dateOfBirth');
  String get selectDate => _t('selectDate');
  String get gender => _t('gender');
  String get male => _t('male');
  String get female => _t('female');
  String get other => _t('other');
  String get genderRequired => _t('genderRequired');
  String get confirmPassword => _t('confirmPassword');
  String get confirmPasswordRequired => _t('confirmPasswordRequired');
  String get confirmPasswordMismatch => _t('confirmPasswordMismatch');
  String get confirmPasswordMatch => _t('confirmPasswordMatch');
  String get passwordNotStrong => _t('passwordNotStrong');
  String get passwordRuleLen => _t('passwordRuleLen');
  String get passwordRuleUpper => _t('passwordRuleUpper');
  String get passwordRuleLower => _t('passwordRuleLower');
  String get passwordRuleDigit => _t('passwordRuleDigit');
  String get passwordRuleSpecial => _t('passwordRuleSpecial');
  String get passwordOk => _t('passwordOk');
  String get dobRequired => _t('dobRequired');
  String get ageRequirement => _t('ageRequirement');

  // ---- Settings ----
  String get language => _t('language');
  String get vietnamese => _t('vietnamese');
  String get english => _t('english');
  String get darkMode => _t('darkMode');
  String get color => _t('color');
  String get fontSize => _t('fontSize');
  String get fontSmall => _t('fontSmall');
  String get fontNormal => _t('fontNormal');
  String get fontLarge => _t('fontLarge');
  String get changeInfoTitle => _t('changeInfoTitle');
  String get changePassword => _t('changePassword');
  String get tosPrivacy => _t('tosPrivacy');
  String get tosShort => _t('tosShort');
  String get privacyShort => _t('privacyShort');
  String get agreePrefix => _t('agreePrefix');
  String get and => _t('and');
  String get registerSuccess => _t('registerSuccess');
  String get registerFailed => _t('registerFailed');
  String get deleteAccount => _t('deleteAccount');
  String get deleteAccountWarning => _t('deleteAccountWarning');
  String get emailAlreadyTaken => _t('emailAlreadyTaken');
  String get registerTitle => _t('registerTitle');
  String get registerSubtitle => _t('registerSubtitle');

  // ---- Change password ----
  String get changePasswordTitle => _t('changePasswordTitle');
  String get currentPassword => _t('currentPassword');
  String get newPassword => _t('newPassword');
  String get confirmNewPassword => _t('confirmNewPassword');
  String get passwordMustDiffer => _t('passwordMustDiffer');
  String get passwordChanged => _t('passwordChanged');

  // ---- Accounts ----
  String get manageAccounts => _t('manageAccounts');
  String get noAccounts => _t('noAccounts');
  String get active => _t('active');
  String get remove => _t('remove');
  String get cancel => _t('cancel');
  String get addAccount => _t('addAccount');
  String get confirmRemoveTitle => _t('confirmRemoveTitle');
  String get confirmLogoutMessage => _t('confirmLogoutMessage');
  String get switchAccount => _t('switchAccount');
  String switchAccountSuccess(String email) =>
      _fmt('switchAccountSuccess', {'email': email});

  // ---- Dangerous actions ----
  String get deleteAccountSuccess => _t('deleteAccountSuccess');
  String get deleteAccountFailed => _t('deleteAccountFailed');

  // ---- Update profile ----
  String get saveChanges => _t('saveChanges');
  String get unsavedChangesTitle => _t('unsavedChangesTitle');
  String get unsavedChangesMessage => _t('unsavedChangesMessage');
  String get discard => _t('discard');
  String get stay => _t('stay');
  String get profileUpdated => _t('profileUpdated');

  // ---- Catalog & Books ----
  String get catalog => _t('catalog');
  String get catalogSubtitle => _t('catalogSubtitle');
  String get bookExplorerTitle => _t('bookExplorerTitle');
  String get searchBooksHint => _t('searchBooksHint');
  String get categories => _t('categories');
  String get authors => _t('authors');
  String get books => _t('books');
  String get viewAll => _t('viewAll');
  String get catalogEmpty => _t('catalogEmpty');
  String bookPrice(String credit) => _fmt('bookPrice', {'credit': credit});
  String bookAvailableCopies(String count) =>
      _fmt('bookAvailableCopies', {'count': count});
  String get bookOutOfStock => _t('bookOutOfStock');
  String get bookNoDescription => _t('bookNoDescription');
  String get bookAlreadyOwned => _t('bookAlreadyOwned');
  String get bookAuthors => _t('bookAuthors');
  String get bookCategory => _t('bookCategory');
  String get bookCategoryAll => _t('bookCategoryAll');
  String get bookCategoryLabel => _t('bookCategoryLabel');
  String get bookStatusDraft => _t('bookStatusDraft');
  String get bookStatusPublished => _t('bookStatusPublished');
  String get bookStatusArchived => _t('bookStatusArchived');
  String get bookAdd => _t('bookAdd');
  String get bookColumnIndex => _t('bookColumnIndex');
  String get bookColumnTitle => _t('bookColumnTitle');
  String get bookColumnPrice => _t('bookColumnPrice');
  String get bookColumnCopies => _t('bookColumnCopies');
  String get bookColumnStatus => _t('bookColumnStatus');
  String get bookColumnCategory => _t('bookColumnCategory');
  String get bookColumnActions => _t('bookColumnActions');
  String get bookListEmpty => _t('bookListEmpty');
  String get bookNoResults => _t('bookNoResults');
  String get bookSearchLabel => _t('bookSearchLabel');
  String get bookSearchHint => _t('bookSearchHint');
  String get bookStatusFilter => _t('bookStatusFilter');
  String get bookStatusAll => _t('bookStatusAll');
  String get bookCategoryUnassigned => _t('bookCategoryUnassigned');
  String get bookCreateSuccess => _t('bookCreateSuccess');
  String get bookUpdateSuccess => _t('bookUpdateSuccess');
  String get bookEdit => _t('bookEdit');
  String get bookDelete => _t('bookDelete');
  String get bookDeleteTitle => _t('bookDeleteTitle');
  String bookDeleteMessage(String title) =>
      _fmt('bookDeleteMessage', {'title': title});
  String get bookDeleteAction => _t('bookDeleteAction');
  String get bookDeleteSuccess => _t('bookDeleteSuccess');
  String get bookDeleteInProgress => _t('bookDeleteInProgress');
  String get bookTitleLabel => _t('bookTitleLabel');
  String get bookTitleRequired => _t('bookTitleRequired');
  String get bookSlugLabel => _t('bookSlugLabel');
  String get bookSubtitleLabel => _t('bookSubtitleLabel');
  String get bookDescriptionLabel => _t('bookDescriptionLabel');
  String get bookCreditPriceLabel => _t('bookCreditPriceLabel');
  String get bookCreditPriceRequired => _t('bookCreditPriceRequired');
  String get bookCreditPriceInvalid => _t('bookCreditPriceInvalid');
  String get bookAvailableCopiesLabel => _t('bookAvailableCopiesLabel');
  String get bookAvailableCopiesRequired => _t('bookAvailableCopiesRequired');
  String get bookAvailableCopiesInvalid => _t('bookAvailableCopiesInvalid');
  String get bookStatusLabel => _t('bookStatusLabel');
  String get bookCategoryNone => _t('bookCategoryNone');
  String get bookAuthorsEmpty => _t('bookAuthorsEmpty');
  String get bookIsbnLabel => _t('bookIsbnLabel');
  String get bookLanguageLabel => _t('bookLanguageLabel');
  String get bookCoverUrlLabel => _t('bookCoverUrlLabel');
  String get bookFileUrlLabel => _t('bookFileUrlLabel');
  String get bookPublishedAtLabel => _t('bookPublishedAtLabel');
  String get bookFormUnexpectedError => _t('bookFormUnexpectedError');
  String get bookFormCreateTitle => _t('bookFormCreateTitle');
  String bookFormEditTitle(String title) =>
      _fmt('bookFormEditTitle', {'title': title});
  String get bookFormCreateAction => _t('bookFormCreateAction');
  String get bookFormUpdateAction => _t('bookFormUpdateAction');
  String get bookSortLabel => _t('bookSortLabel');
  String get bookSortRecommended => _t('bookSortRecommended');
  String get bookSortNameAZ => _t('bookSortNameAZ');
  String get bookSortNameZA => _t('bookSortNameZA');
  String get bookSortPriceLowHigh => _t('bookSortPriceLowHigh');
  String get bookSortPriceHighLow => _t('bookSortPriceHighLow');
  String get bookSortRatingHighLow => _t('bookSortRatingHighLow');
  String get bookSortRatingLowHigh => _t('bookSortRatingLowHigh');
  String get bookOwnedTag => _t('bookOwnedTag');
  String get bookOwnedInfo => _t('bookOwnedInfo');
  String get walletTopUp => _t('walletTopUp');
  String get walletTopUpRequest => _t('walletTopUpRequest');
  String get walletTopUpAmountLabel => _t('walletTopUpAmountLabel');
  String get walletTopUpAmountInvalid => _t('walletTopUpAmountInvalid');
  String get walletTopUpNoteLabel => _t('walletTopUpNoteLabel');
  String get walletTopUpSubmit => _t('walletTopUpSubmit');
  String get walletTopUpSuccess => _t('walletTopUpSuccess');
  String get walletTopUpRequests => _t('walletTopUpRequests');
  String get walletTopUpStatusPending => _t('walletTopUpStatusPending');
  String get walletTopUpStatusApproved => _t('walletTopUpStatusApproved');
  String get walletTopUpStatusRejected => _t('walletTopUpStatusRejected');
  String get walletTopUpNoRequests => _t('walletTopUpNoRequests');
  String get walletTopUpDecisionNote => _t('walletTopUpDecisionNote');
  String get walletTopUpApprove => _t('walletTopUpApprove');
  String get walletTopUpReject => _t('walletTopUpReject');
  String get walletTopUpApproveSuccess => _t('walletTopUpApproveSuccess');
  String get walletTopUpRejectSuccess => _t('walletTopUpRejectSuccess');
  String get bookRatingSummary => _t('bookRatingSummary');
  String bookRatingCount(int count) =>
      _fmt('bookRatingCount', {'count': count.toString()});
  String get bookReviewsTitle => _t('bookReviewsTitle');
  String get bookNoReviews => _t('bookNoReviews');
  String get bookReviewAnonymous => _t('bookReviewAnonymous');
  String get bookReviewComposerTitle => _t('bookReviewComposerTitle');
  String get bookReviewComposerUpdateTitle => _t('bookReviewComposerUpdateTitle');
  String get bookReviewTitleLabel => _t('bookReviewTitleLabel');
  String get bookReviewTitleHint => _t('bookReviewTitleHint');
  String get bookReviewContentRequired => _t('bookReviewContentRequired');
  String get bookReviewRatingLabel => _t('bookReviewRatingLabel');
  String get bookReviewRatingRequired => _t('bookReviewRatingRequired');
  String get bookReviewCommentLabel => _t('bookReviewCommentLabel');
  String get bookReviewCommentHint => _t('bookReviewCommentHint');
  String get bookReviewSubmitButton => _t('bookReviewSubmitButton');
  String get bookReviewUpdateButton => _t('bookReviewUpdateButton');
  String get bookReviewSubmitSuccess => _t('bookReviewSubmitSuccess');
  String get bookReviewLoginRequired => _t('bookReviewLoginRequired');

  // ---- Users ----
  String get users => _t('users');
  String get userSearchLabel => _t('userSearchLabel');
  String get userSearchHint => _t('userSearchHint');
  String get userRoleFilter => _t('userRoleFilter');
  String get userRoleAll => _t('userRoleAll');
  String get userRoleAdmin => _t('userRoleAdmin');
  String get userRoleUser => _t('userRoleUser');
  String userRoleLabel(String role) => _fmt('userRoleLabel', {'role': role});
  String userCreatedAt(String date) => _fmt('userCreatedAt', {'date': date});
  String get usersEmpty => _t('usersEmpty');
  String get userColumnIndex => _t('userColumnIndex');
  String get userColumnEmail => _t('userColumnEmail');
  String get userColumnName => _t('userColumnName');
  String get userColumnRole => _t('userColumnRole');
  String get userColumnDob => _t('userColumnDob');
  String get userColumnBalance => _t('userColumnBalance');
  String get userColumnActions => _t('userColumnActions');
  String get userWalletMissing => _t('userWalletMissing');
  String get userWalletLoad => _t('userWalletLoad');
  String get userWalletManage => _t('userWalletManage');
  String get userWalletRefresh => _t('userWalletRefresh');
  String get userDeleteTitle => _t('userDeleteTitle');
  String userDeleteMessage(String email) =>
      _fmt('userDeleteMessage', {'email': email});
  String get userDeleteConfirm => _t('userDeleteConfirm');
  String get userDeleteAction => _t('userDeleteAction');
  String get userDeleteInProgress => _t('userDeleteInProgress');
  String get userDeleteSuccess => _t('userDeleteSuccess');
  String get userDeleteFailure => _t('userDeleteFailure');
  String get userDeleteDisabled => _t('userDeleteDisabled');

  // ---- Wallet ----
  String get wallet => _t('wallet');
  String walletBalance(String credit) =>
      _fmt('walletBalance', {'credit': credit});
  String get walletTransactions => _t('walletTransactions');
  String get walletNoTransactions => _t('walletNoTransactions');
  String get walletsEmpty => _t('walletsEmpty');
  String walletUpdatedAt(String date) =>
      _fmt('walletUpdatedAt', {'date': date});
  String creditUnit(String value) => _fmt('creditUnit', {'value': value});
  String get walletAdjust => _t('walletAdjust');
  String get walletAdjustAmount => _t('walletAdjustAmount');
  String get walletAdjustType => _t('walletAdjustType');
  String get walletAdjustNote => _t('walletAdjustNote');
  String get walletAdjustSuccess => _t('walletAdjustSuccess');
  String get walletAdjustFailed => _t('walletAdjustFailed');
  String get transactionTypeCredit => _t('transactionTypeCredit');
  String get transactionTypeDebit => _t('transactionTypeDebit');
  String get transactionTypeAdjustment => _t('transactionTypeAdjustment');

  // ---- Orders ----
  String get orders => _t('orders');
  String get orderHistory => _t('orderHistory');
  String orderId(int id) => _fmt('orderId', {'id': id.toString()});
  String get orderStatusPending => _t('orderStatusPending');
  String get orderStatusCompleted => _t('orderStatusCompleted');
  String get orderStatusCancelled => _t('orderStatusCancelled');
  String orderTotal(String credit) => _fmt('orderTotal', {'credit': credit});
  String orderPlacedAt(String date) => _fmt('orderPlacedAt', {'date': date});
  String orderItemLine(String title, String qty, String credits) =>
      _fmt('orderItemLine', {'title': title, 'qty': qty, 'credits': credits});
  String get orderNoItems => _t('orderNoItems');
  String get orderEmpty => _t('orderEmpty');

  // ---- Cart ----
  String get cart => _t('cart');
  String get cartEmpty => _t('cartEmpty');
  String get cartCheckout => _t('cartCheckout');
  String get cartCheckoutSuccess => _t('cartCheckoutSuccess');
  String get cartCheckoutFailed => _t('cartCheckoutFailed');
  String get cartUpdateFailed => _t('cartUpdateFailed');
  String get cartAlreadyContains => _t('cartAlreadyContains');
  String get addToCart => _t('addToCart');
  String get addedToCart => _t('addedToCart');
  String get viewCart => _t('viewCart');
  String get quantity => _t('quantity');

  // ---- Extract Text ----
  String get extractText => _t('extractText');
  String get extractTextDescription => _t('extractTextDescription');
  String get extractTextLoading => _t('extractTextLoading');
  String get extractTextError => _t('extractTextError');
  String get extractTextNoContent => _t('extractTextNoContent');
  String get extractTextDownload => _t('extractTextDownload');
  String get extractTextCopy => _t('extractTextCopy');
  String get extractTextCopied => _t('extractTextCopied');
  String get extractTextSave => _t('extractTextSave');
  String get extractTextShare => _t('extractTextShare');
  String get extractTextTitle => _t('extractTextTitle');
  String get extractTextPreview => _t('extractTextPreview');
  String get extractTextOwnedOnly => _t('extractTextOwnedOnly');
  String extractTextSaved(String path) => _fmt('extractTextSaved', {'path': path});
  String extractTextPages(int count) =>
      _fmt('extractTextPages', {'count': count.toString()});

  // ---- Library ----
  String get myBooks => _t('myBooks');
  String get myBooksSubtitle => _t('myBooksSubtitle');
  String get myBooksEmpty => _t('myBooksEmpty');
  String myBooksLastPurchased(String date) =>
      _fmt('myBooksLastPurchased', {'date': date});
  String myBooksLastOpened(String date) =>
      _fmt('myBooksLastOpened', {'date': date});
  String get openBook => _t('openBook');
  String get bookReviewHelpful => _t('bookReviewHelpful');
  String get bookReviewYes => _t('bookReviewYes');
  String get bookReviewNo => _t('bookReviewNo');
  String get bookReviewReport => _t('bookReviewReport');
  String get bookReviewNoTitle => _t('bookReviewNoTitle');
  String get bookReviewSortBy => _t('bookReviewSortBy');
  String get bookReviewSortMostHelpful => _t('bookReviewSortMostHelpful');
  String get bookReviewSortMostRecent => _t('bookReviewSortMostRecent');
  String get bookReviewSortHighestRating => _t('bookReviewSortHighestRating');
  String get bookReviewSortLowestRating => _t('bookReviewSortLowestRating');

  // ---- Actions / Misc ----
  String get purchase => _t('purchase');
  String get purchaseWithCredits => _t('purchaseWithCredits');
  String get notEnoughCredits => _t('notEnoughCredits');
  String get loading => _t('loading');
  String get tryAgain => _t('tryAgain');
  String get adminPanel => _t('adminPanel');
  String get adminTabUsers => _t('adminTabUsers');
  String get adminTabBooks => _t('adminTabBooks');
  String get adminTabAuthors => _t('adminTabAuthors');

  // ---- Authors ----
  String get authorSearchLabel => _t('authorSearchLabel');
  String get authorSearchHint => _t('authorSearchHint');
  String get authorColumnIndex => _t('authorColumnIndex');
  String get authorColumnName => _t('authorColumnName');
  String get authorColumnSlug => _t('authorColumnSlug');
  String get authorColumnBooksCount => _t('authorColumnBooksCount');
  String get authorColumnActions => _t('authorColumnActions');
  String get authorAdd => _t('authorAdd');
  String get authorEdit => _t('authorEdit');
  String get authorDelete => _t('authorDelete');
  String get authorDeleteTitle => _t('authorDeleteTitle');
  String authorDeleteMessage(String name) =>
      _fmt('authorDeleteMessage', {'name': name});
  String get authorDeleteAction => _t('authorDeleteAction');
  String get authorDeleteSuccess => _t('authorDeleteSuccess');
  String get authorDeleteInProgress => _t('authorDeleteInProgress');
  String get authorListEmpty => _t('authorListEmpty');
  String get authorCreateSuccess => _t('authorCreateSuccess');
  String get authorUpdateSuccess => _t('authorUpdateSuccess');
  String get authorFormCreateTitle => _t('authorFormCreateTitle');
  String authorFormEditTitle(String name) =>
      _fmt('authorFormEditTitle', {'name': name});
  String get authorNameLabel => _t('authorNameLabel');
  String get authorNameRequired => _t('authorNameRequired');
  String get authorSlugLabel => _t('authorSlugLabel');
  String get authorBioLabel => _t('authorBioLabel');
  String get authorFormCreateAction => _t('authorFormCreateAction');
  String get authorFormUpdateAction => _t('authorFormUpdateAction');

  String get confirm => _t('confirm');
  String get close => _t('close');
  String get details => _t('details');
  String get filter => _t('filter');
  String get clear => _t('clear');
  String lastUpdated(String date) => _fmt('lastUpdated', {'date': date});
  
  // ---- Book Explorer / Search / Filter ----
  String get searchBooksPlaceholder => _t('searchBooksPlaceholder');
  String get sortByLabel => _t('sortByLabel');
  String get sortTitleAsc => _t('sortTitleAsc');
  String get sortTitleDesc => _t('sortTitleDesc');
  String get sortPriceAsc => _t('sortPriceAsc');
  String get sortPriceDesc => _t('sortPriceDesc');
  String get sortRatingDesc => _t('sortRatingDesc');
  String get sortRatingAsc => _t('sortRatingAsc');
  String get filterByCategoryLabel => _t('filterByCategoryLabel');
  String get filterByAuthorLabel => _t('filterByAuthorLabel');
  String get allCategories => _t('allCategories');
  String get allAuthors => _t('allAuthors');
  String get showingBooksCount => _t('showingBooksCount');
  String get showingBooksCountPlural => _t('showingBooksCountPlural');
  String get suggestionsCategories => _t('suggestionsCategories');
  String get suggestionsTitles => _t('suggestionsTitles');
  String get suggestionsAuthors => _t('suggestionsAuthors');
  String get filterByThisCategory => _t('filterByThisCategory');
  String get filterByThisAuthor => _t('filterByThisAuthor');
  String get noBooksByAuthor => _t('noBooksByAuthor');
  String get checkBackLater => _t('checkBackLater');
  String get tryAdjustingFilters => _t('tryAdjustingFilters');
  String get clearFilters => _t('clearFilters');
  String get showFilters => _t('showFilters');
  String get hideFilters => _t('hideFilters');
  String get filtersButton => _t('filtersButton');
  String filtersActive(String count) => _t('filtersActive').replaceAll('{count}', count);
  String showMoreFilters(String count) => _t('showMoreFilters').replaceAll('{count}', count);
  String get showLessFilters => _t('showLessFilters');
  String get applyFilters => _t('applyFilters');
  String get clearAllFilters => _t('clearAllFilters');
  String get activeFiltersLabel => _t('activeFiltersLabel');
  String categoriesCount(String count) => _t('categoriesCount').replaceAll('{count}', count);
  String authorsCount(String count) => _t('authorsCount').replaceAll('{count}', count);
  String categoriesSelected(String count) => _t('categoriesSelected').replaceAll('{count}', count);
  String authorsSelected(String count) => _t('authorsSelected').replaceAll('{count}', count);
  String get noFiltersActive => _t('noFiltersActive');
  String get noBooksFound => _t('noBooksFound');
  
  // ---- Auth / Registration ----
  String get createAccount => _t('createAccount');
  String get createAccountSubtitle => _t('createAccountSubtitle');
  String get personalInformation => _t('personalInformation');
  String get accountSecurity => _t('accountSecurity');
  String get fullNameLabel => _t('fullNameLabel');
  String get phoneLabel => _t('phoneLabel');
  String get passwordLabel => _t('passwordLabel');
  String get confirmPasswordLabel => _t('confirmPasswordLabel');
  String get dobLabel => _t('dobLabel');
  String get dobHint => _t('dobHint');
  String get genderLabel => _t('genderLabel');
  String get genderMale => _t('genderMale');
  String get genderFemale => _t('genderFemale');
  String get genderOther => _t('genderOther');
  String get genderHint => _t('genderHint');
  String get agreeToTermsPrefix => _t('agreeToTermsPrefix');
  String get termsOfService => _t('termsOfService');
  String get andText => _t('andText');
  String get privacyPolicy => _t('privacyPolicy');
  String get registerButton => _t('registerButton');
  String get registerButtonDisabledHint => _t('registerButtonDisabledHint');
  String get alreadyHaveAccount => _t('alreadyHaveAccount');
  String get loginLink => _t('loginLink');
  String get rememberPassword => _t('rememberPassword');
  String get emailConfirmedTooltip => _t('emailConfirmedTooltip');
  String get processingText => _t('processingText');
  String get passwordWeak => _t('passwordWeak');
  String get passwordMedium => _t('passwordMedium');
  String get passwordStrong => _t('passwordStrong');
  String get passwordStrengthLabel => _t('passwordStrengthLabel');
  
  // ---- PDF Viewer ----
  String get readBook => _t('readBook');
  String get seeDetails => _t('seeDetails');
  String get downloadingPdf => _t('downloadingPdf');
  String get pdfNotAvailable => _t('pdfNotAvailable');
  String get pdfDownloadFailed => _t('pdfDownloadFailed');
  String get askBookTitle => _t('askBookTitle');
  String get askBookPromptLabel => _t('askBookPromptLabel');
  String get askBookPlaceholder => _t('askBookPlaceholder');
  String get askBookSubmit => _t('askBookSubmit');
  String get askBookGenerating => _t('askBookGenerating');
  String get askBookAnswerHeading => _t('askBookAnswerHeading');
  String get askBookErrorGeneric => _t('askBookErrorGeneric');
  
  // ---- Error texts ----
  String get errorLoadingInfo => _t('errorLoadingInfo');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    return lang == 'en' || lang == 'vi';
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Use SynchronousFuture if you cache results; here we load assets per locale.
    return AppLocalizations.load(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
