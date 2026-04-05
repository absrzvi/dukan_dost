// All user-facing strings in Urdu and Roman Urdu
// Design principle: Urdu script is primary, Roman Urdu is the toggle option

class AppStrings {
  // Auth
  static const String enterPhone = 'فون نمبر درج کریں';
  static const String enterPhoneRoman = 'Phone number darj karein';
  static const String enterOtp = 'کوڈ درج کریں';
  static const String enterOtpRoman = 'Code darj karein';
  static const String verify = 'تصدیق کریں';
  static const String verifyRoman = 'Tasdeeq karein';
  static const String sendOtp = 'کوڈ بھیجیں';
  static const String sendOtpRoman = 'Code bhejein';
  static const String resendOtp = 'دوبارہ بھیجیں';
  static const String resendOtpRoman = 'Dobara bhejein';

  // Onboarding
  static const String shopName = 'دکان کا نام';
  static const String shopNameRoman = 'Dukaan ka naam';
  static const String locality = 'علاقہ';
  static const String localityRoman = 'Ilaqa';
  static const String importContacts = 'رابطے درآمد کریں';
  static const String importContactsRoman = 'Contacts import karein';
  static const String skip = 'چھوڑیں';
  static const String skipRoman = 'Chhorein';
  static const String skipImport = 'چھوڑیں';
  static const String skipImportRoman = 'Chhorein';
  static const String next = 'اگلا';
  static const String nextRoman = 'Agla';
  static const String done = 'مکمل';
  static const String doneRoman = 'Mukammal';
  static const String searchContacts = 'رابطے تلاش کریں';
  static const String searchContactsRoman = 'Contacts talaash karein';
  static const String continueText = 'جاری رکھیں';
  static const String continueTextRoman = 'Jaari rakhein';
  static const String shopSetupSubtitle = 'اپنی دکان کی تفصیل درج کریں';
  static const String shopNameRequired = 'دکان کا نام ضروری ہے';
  static const String contactsLoadError = 'رابطے نہیں مل سکے';
  static const String contactImportRationale =
      'اپنے موبائل کے رابطے گاہکوں میں شامل کریں تاکہ آسانی سے ڈھونڈ سکیں';
  static const String noContactsFound = 'کوئی رابطہ نہیں ملا';
  static const String unknownContact = 'نامعلوم';
  static const String optional = '(اختیاری)';

  // Onboarding walkthrough
  static const String walkthroughStep1Title = 'اپنا گاہک چنیں';
  static const String walkthroughStep1Subtitle = 'فہرست سے گاہک منتخب کریں یا نیا شامل کریں';
  static const String walkthroughStep2Title = 'ادھار لکھیں';
  static const String walkthroughStep2Subtitle = 'گاہک کا ادھار آسانی سے درج کریں';
  static const String walkthroughStep3Title = 'ادائیگی لکھیں';
  static const String walkthroughStep3Subtitle = 'ادائیگی ملنے پر فوری درج کریں';

  // Home
  static const String totalOwedToMe = 'مجھے ملنا ہے';
  static const String totalOwedToMeRoman = 'Mujhe milna hai';
  static const String totalIOwe = 'مجھے دینا ہے';
  static const String totalIOweRoman = 'Mujhe dena hai';
  static const String netPosition = 'کل پوزیشن';
  static const String netPositionRoman = 'Kul position';

  // Transactions
  static const String udhaar = 'ادھار';
  static const String udhaarRoman = 'Udhaar';
  static const String wapsi = 'واپسی';
  static const String wapsiRoman = 'Wapsi';
  static const String amount = 'رقم';
  static const String amountRoman = 'Raqam';
  static const String save = 'محفوظ کریں';
  static const String saveRoman = 'Mehfooz karein';
  static const String hisaabSaaf = 'حساب صاف';
  static const String hisaabSaafRoman = 'Hisaab saaf';
  static const String hisaabSaafMessage = 'اس گاہک کا حساب صاف ہو گیا';
  static const String hisaabSaafMessageRoman = 'Is grahak ka hisaab saaf ho gaya';

  // Customers
  static const String customers = 'گاہک';
  static const String customersRoman = 'Grahak';
  static const String addCustomer = 'گاہک شامل کریں';
  static const String addCustomerRoman = 'Grahak shamil karein';
  static const String noPhone = 'فون نہیں';
  static const String noPhoneRoman = 'Phone nahin';

  // Reminders
  static const String sendReminder = 'یاد دلائیں';
  static const String sendReminderRoman = 'Yaad dilayein';
  static const String daysOverdue = 'دن باقی';
  static const String daysOverdueRoman = 'din baqi';
  static const String lastReminderSent = 'آخری یاد دہانی';
  static const String lastReminderSentRoman = 'Aakhri yaad dahaani';

  // WhatsApp templates
  static const String reminderGentle =
      'السلام علیکم {name} بھائی، امید ہے خیریت سے ہوں گے۔ {shopName} کا PKR {amount} باقی ہے۔ تھوڑا وقت ملے تو ادا کر دیں۔ شکریہ۔';
  static const String reminderFirm =
      'السلام علیکم {name} بھائی، {shopName} کا PKR {amount} کافی دنوں سے باقی ہے۔ گزارش ہے جلدی ادا کر دیں۔ شکریہ۔';
  static const String reminderFinal =
      'السلام علیکم {name} بھائی، {shopName} کا PKR {amount} بہت دن سے باقی ہے۔ آج ہی ادا کر دیں تو مہربانی ہوگی۔ شکریہ۔';

  // Suppliers
  static const String suppliers = 'سپلائر';
  static const String suppliersRoman = 'Supplier';
  static const String dueDate = 'آخری تاریخ';
  static const String dueDateRoman = 'Aakhri taareekh';
  static const String markPaid = 'ادا ہو گیا';
  static const String markPaidRoman = 'Ada ho gaya';

  // Sync / Offline
  static const String offline = 'آف لائن';
  static const String offlineRoman = 'Offline';
  static const String syncing = 'ہم آہنگی';
  static const String syncingRoman = 'Sync ho raha hai';
  static const String syncComplete = 'ہم آہنگ';
  static const String syncCompleteRoman = 'Sync complete';

  // History / Dispute
  static const String historyShare = 'تاریخ شیئر کریں';
  static const String historyShareRoman = 'History share karein';
  static const String baaki = 'باقی';
  static const String baakiRoman = 'Baaki';
}
