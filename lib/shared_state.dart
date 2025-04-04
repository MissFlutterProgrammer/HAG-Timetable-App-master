import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stundenplan/calendar_data.dart';
import 'package:stundenplan/constants.dart';
import 'package:stundenplan/content.dart';
import 'package:stundenplan/helper_functions.dart';
import 'package:stundenplan/holiday_calculator.dart';
import 'package:stundenplan/integration.dart';
import 'package:stundenplan/parsing/parse_subsitution_plan.dart';
import 'package:stundenplan/profile_manager.dart';
import 'package:stundenplan/theme.dart';

class SharedState {
  final SharedPreferences preferences;
  late Content content;
  Theme theme = darkTheme;
  int height = Constants.defaultHeight;
  bool sendNotifications = false;
  ProfileManager profileManager = ProfileManager();
  String? schulmanagerClassName;
  List<int> holidayWeekdays = getHolidayWeekDays();
  CalendarData calendarData = CalendarData();
  // Internal flags
  bool hasChangedCourses = true;
  bool processSpecialAGClass = true;
  bool processSpecialCourseClass = true;

  SharedState(this.preferences, Content initialContent) {
    content = initialContent;
  }

  void saveState() {
    final saveFileData = <String, dynamic>{};

    // Theme
    final themeData = theme.getJsonData();
    saveFileData["theme"] = themeData;
    preferences.setString("theme", jsonEncode(themeData));

    // Profiles
    profileManager.renameAllProfiles();
    final jsonProfileManagerData = profileManager.getJsonData();
    saveFileData["jsonProfileManagerData"] = jsonProfileManagerData;
    preferences.setString(
        "jsonProfileManagerData", jsonEncode(jsonProfileManagerData));

    // Notifications
    preferences.setBool("sendNotifications", sendNotifications);
    saveFileData["sendNotifications"] = sendNotifications;

    // Save theme and profiles to file
    saveToFile(jsonEncode(saveFileData), Constants.saveDataFileLocation);

    // Internal flags
    saveInternalFlags();

    preferences.setInt("height", height);
  }

  Theme themeFromJsonData(Map<String, dynamic> jsonThemeData) {
    return Theme.fromJsonData(jsonThemeData);
  }

  bool loadStateAndCheckIfFirstTime({bool fromBackgroundTask = false}) {
    final themeDataString = preferences.getString("theme") ?? "dark";
    height = preferences.getInt("height") ?? Constants.defaultHeight;

    // If first time using app
    if (height == Constants.defaultHeight &&
        !preferences.containsKey("height")) {
      return true;
    }

    // Load User flags
    sendNotifications = preferences.getBool("sendNotifications") ?? false;
    // Load Internal flags
    loadInternalFlags();
    // Register integrations
    Integrations.instance
        .registerIntegration(IServUnitsSubstitutionIntegration(this));
    Integrations.instance
        .registerIntegration(SchulmanagerIntegration.Schulmanager(this));

    loadSchulmangerClassName(fromBackgroundTask: fromBackgroundTask);

    final profileManagerData = preferences.getString("jsonProfileManagerData");
    if (profileManagerData != null) {
      loadThemeProfileManagerFromJson(
          jsonDecode(themeDataString) as Map<String, dynamic>,
          jsonDecode(profileManagerData) as Map<String, dynamic>);
    }
    return false;
  }

  void loadSchulmangerClassName({bool fromBackgroundTask = false}) {
    final now = DateTime.now();
    final lastOpened =
        DateTime.tryParse(preferences.getString("appLastOpened") ?? "");
    if (lastOpened != null &&
        !fromBackgroundTask &&
        now.difference(lastOpened) >
            Constants.refreshSchulmanagerClassNameDuration) {
      preferences.remove("schulmanagerClassName");
      schulmanagerClassName = null;
      preferences.setString("appLastOpened", now.toIso8601String());
      return;
    }
    if (!fromBackgroundTask) {
      preferences.setString("appLastOpened", now.toIso8601String());
    }
    schulmanagerClassName = preferences.getString("schulmanagerClassName");
  }

  void loadInternalFlags() {
    hasChangedCourses = preferences.getBool("hasChangedCourses") ?? true;
    processSpecialAGClass =
        preferences.getBool("processSpecialAGClass") ?? true;
    processSpecialCourseClass =
        preferences.getBool("processSpecialCourseClass") ?? true;
    // Randomly activate hasChangedCourses to force update the special classes.
    if (math.Random().nextDouble() <
            Constants.randomUpdateSpecialClassesChance &&
        (!processSpecialAGClass || !processSpecialCourseClass)) {
      hasChangedCourses = true;
    }
  }

  void loadThemeProfileManagerFromJson(Map<String, dynamic> themeData,
      Map<String, dynamic> jsonProfileManagerData) {
    theme = Theme.fromJsonData(themeData);
    profileManager = ProfileManager.fromJsonData(jsonProfileManagerData);
  }

  void saveCache() {
    // Save calendar data
    preferences.setString("calendarData", jsonEncode(calendarData.toJson()));
    // Save integrations
    preferences.setString("integrationsValues",
        jsonEncode(Integrations.instance.saveIntegrationValuesToJson()));
    // Save content
    content.updateLastUpdated();
    log("[SAVED] lastUpdated: ${content.lastUpdated}", name: "cache");
    final encodedContent = jsonEncode(content.toJsonData());
    preferences.setString("cachedContent", encodedContent);
    // Save internal flags
    saveInternalFlags();
  }

  Future<void> saveSchulmanagerClassName() async {
    if (schulmanagerClassName != null) {
      await preferences.setString(
          "schulmanagerClassName", schulmanagerClassName!);
    } else {
      await preferences.remove("schulmanagerClassName");
    }
  }

  void saveInternalFlags() {
    preferences.setBool("hasChangedCourses", hasChangedCourses);
    preferences.setBool("processSpecialAGClass", processSpecialAGClass);
    preferences.setBool("processSpecialCourseClass", processSpecialCourseClass);
  }

  void loadCache() {
    // Load calendar data
    final calendarDataJsonString = preferences.getString("calendarData");
    if (calendarDataJsonString != null && calendarDataJsonString.isNotEmpty) {
      calendarData = CalendarData.fromJson(
          jsonDecode(calendarDataJsonString) as List<dynamic>);
    }

    // Load integrations
    final integrationsValuesString =
        preferences.getString("integrationsValues");
    if (integrationsValuesString != null) {
      Integrations.instance.loadIntegrationValuesFromJson(
          jsonDecode(integrationsValuesString) as Map<String, dynamic>);
    }

    // Load content
    final contentJsonString = preferences.getString("cachedContent");
    if (contentJsonString == null || contentJsonString.isEmpty) return;

    final decodedJson = jsonDecode(contentJsonString) as List<dynamic>;
    content = Content.fromJsonData(decodedJson);
    log("[LOADED] lastUpdated: ${content.lastUpdated}", name: "cache");
  }

  void setThemeFromThemeName(String themeName) {
    theme = Theme.getThemeFromThemeName(themeName);
  }

  List<String> get defaultSubjects {
    final schoolGrade = profileManager.schoolGrade;
    if (schoolGrade == null) return Constants.alwaysDefaultSubjects;

    for (final schoolGradeList in Constants.defaultSubjectsMap.keys) {
      if (schoolGradeList.contains(schoolGrade)) {
        final defaultSubjects =
            List<String>.from(Constants.defaultSubjectsMap[schoolGradeList]!);
        defaultSubjects.addAll(Constants.alwaysDefaultSubjects);
        return defaultSubjects;
      }
    }
    return Constants.alwaysDefaultSubjects;
  }

  List<String> get allCurrentSubjects {
    final allSubjects = profileManager.subjects.toList();
    allSubjects.addAll(defaultSubjects);
    return allSubjects;
  }

  Future<void> saveSnapshot() async {
    final snapshotData = <String, dynamic>{
      "integrations": Integrations.instance.saveIntegrationValuesToJson(),
      "content": content.toJsonData()
    };
    final now = DateTime.now();
    final timeStampString = DateFormat("dd_MM_yyy-HH_mm_ss").format(now);
    final saveFilePath =
        "${Constants.saveSnapshotFileLocation}/stundenplan_snapshot_$timeStampString.snapshot";
    await saveToFileArchived(jsonEncode(snapshotData), saveFilePath);
  }
}
