/// Offline localization catalogue.
///
/// 13 languages are declared. English and Hindi translations ship in the first
/// build; the remaining languages fall back to English until reviewed strings
/// are added. No network lookup is performed at any point.
library;

enum AppLanguage {
  en('en', 'English'),
  hi('hi', 'हिन्दी'),
  bn('bn', 'বাংলা'),
  ta('ta', 'தமிழ்'),
  te('te', 'తెలుగు'),
  mr('mr', 'मराठी'),
  gu('gu', 'ગુજરાતી'),
  kn('kn', 'ಕನ್ನಡ'),
  ml('ml', 'മലയാളം'),
  pa('pa', 'ਪੰਜਾਬੀ'),
  or('or', 'ଓଡ଼ିଆ'),
  as('as', 'অসমীয়া'),
  ur('ur', 'اردو');

  const AppLanguage(this.code, this.nativeName);

  final String code;
  final String nativeName;

  static AppLanguage fromCode(String code) => AppLanguage.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.en,
      );
}

class AppStrings {
  AppStrings(this.language);

  final AppLanguage language;

  static const _en = <String, String>{
    'app_name': 'AI Gym Trainer',
    'nav_home': 'Home',
    'nav_library': 'Exercises',
    'nav_progress': 'Progress',
    'nav_settings': 'Settings',
    'welcome': 'Train smarter, stay safe',
    'subtitle': 'Real-time form guidance, fully offline',
    'start_workout': 'Start Workout',
    'view_demo': 'View Demo',
    'squat': 'Squat',
    'pushup': 'Push-up',
    'bicep_curl': 'Bicep Curl',
    'lunge': 'Lunge',
    'shoulder_press': 'Shoulder Press',
    'plank': 'Plank',
    'in_development': 'In development',
    'reps': 'Reps',
    'sets': 'Sets',
    'duration': 'Duration',
    'calibration': 'Camera Calibration',
    'calibration_hint': 'Step back until your full body is visible',
    'ready': 'Ready',
    'start': 'Start',
    'cancel': 'Cancel',
    'pause': 'Pause',
    'resume': 'Resume',
    'finish': 'Finish',
    'summary': 'Workout Summary',
    'no_sessions': 'No workouts yet. Your history stays on this device.',
    'language': 'Language',
    'voice': 'Voice guidance',
    'privacy': 'Privacy',
    'offline_badge': 'Offline',
    'permission_camera': 'Camera access is required for body tracking',
    'grant_permission': 'Grant permission',
    'low_visibility': 'Move back so your full body is visible',
    'knees_collapsing_inward': 'Keep your knees aligned with your toes',
    'hip_sag': 'Keep your hips up — body in one straight line',
    'insufficient_depth': 'Go a little deeper with control',
    'trunk_lean': 'Keep your chest lifted',
    'slow_movement': 'Control the movement',
    'incorrect_body_alignment': 'Align your body horizontally',
    'pain_stop': 'Stop if you feel pain',
    'good_rep': 'Good repetition',
    'excellent': 'Excellent work',
    'set_complete': 'Set complete — take a short rest',
    'show_demo': 'Watch the demonstration',
    'demo_slow_motion': 'Slow motion',
    'ghost_trainer': 'Ghost trainer',
    'model_missing': 'Pose model is missing. Run scripts/download_models.py',
    'workout_active': 'Workout active',
    'confidence': 'Tracking',
    'delete_all': 'Delete all workout data',
    'export_data': 'Export my data',
  };

  static const _hi = <String, String>{
    'app_name': 'एआई जिम ट्रेनर',
    'nav_home': 'होम',
    'nav_library': 'व्यायाम',
    'nav_progress': 'प्रगति',
    'nav_settings': 'सेटिंग्स',
    'welcome': 'बेहतर प्रशिक्षण, सुरक्षित रहें',
    'subtitle': 'वास्तविक समय में फ़ॉर्म मार्गदर्शन, पूरी तरह ऑफ़लाइन',
    'start_workout': 'वर्कआउट शुरू करें',
    'view_demo': 'डेमो देखें',
    'squat': 'स्क्वैट',
    'pushup': 'पुश-अप',
    'bicep_curl': 'बाइसेप्स कर्ल',
    'lunge': 'लंज',
    'shoulder_press': 'शोल्डर प्रेस',
    'plank': 'प्लैंक',
    'in_development': 'विकास में',
    'reps': 'दोहराव',
    'sets': 'सेट',
    'duration': 'अवधि',
    'calibration': 'कैमरा कैलिब्रेशन',
    'calibration_hint': 'पीछे जाएँ ताकि पूरा शरीर दिखे',
    'ready': 'तैयार',
    'start': 'शुरू',
    'cancel': 'रद्द करें',
    'pause': 'रोकें',
    'resume': 'जारी रखें',
    'finish': 'समाप्त',
    'summary': 'वर्कआउट सारांश',
    'no_sessions': 'अभी कोई वर्कआउट नहीं। आपका इतिहास इसी डिवाइस पर रहता है।',
    'language': 'भाषा',
    'voice': 'आवाज़ मार्गदर्शन',
    'privacy': 'गोपनीयता',
    'offline_badge': 'ऑफ़लाइन',
    'permission_camera': 'बॉडी ट्रैकिंग के लिए कैमरा एक्सेस ज़रूरी है',
    'grant_permission': 'अनुमति दें',
    'low_visibility': 'पीछे जाएँ ताकि पूरा शरीर दिखे',
    'knees_collapsing_inward': 'घुटने पैर की उंगलियों के अनुसार रखें',
    'hip_sag': 'कूल्हे ऊपर रखें — शरीर सीधी रेखा में',
    'insufficient_depth': 'नियंत्रण के साथ थोड़ा और नीचे जाएँ',
    'trunk_lean': 'छाती ऊपर रखें',
    'slow_movement': 'गति को नियंत्रित करें',
    'incorrect_body_alignment': 'शरीर को क्षैतिज रखें',
    'pain_stop': 'दर्द हो तो रोकें',
    'good_rep': 'अच्छा दोहराव',
    'excellent': 'बहुत बढ़िया',
    'set_complete': 'सेट पूरा — थोड़ा आराम करें',
    'show_demo': 'प्रदर्शन देखें',
    'demo_slow_motion': 'धीरी गति',
    'ghost_trainer': 'घोस्ट ट्रेनर',
    'model_missing': 'पोज़ मॉडल नहीं मिला। scripts/download_models.py चलाएँ',
    'workout_active': 'वर्कआउट चल रहा है',
    'confidence': 'ट्रैकिंग',
    'delete_all': 'सभी वर्कआउट डेटा हटाएँ',
    'export_data': 'मेरा डेटा निर्यात करें',
  };

  String get(String key) {
    if (language == AppLanguage.hi) {
      return _hi[key] ?? _en[key] ?? key;
    }
    return _en[key] ?? key;
  }

  /// Text for a form error code emitted by the deterministic engine.
  String formError(String wireName) => get(wireName);
}
