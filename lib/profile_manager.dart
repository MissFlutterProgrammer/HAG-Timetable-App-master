import 'dart:collection';
import 'package:stundenplan/profile.dart';

class ProfileManager {
  String currentProfileName = "11e";
  late LinkedHashMap<String, Profile> profiles;

  ProfileManager() {
    profiles = LinkedHashMap<String, Profile>();
    profiles["11e"] = Profile();
  }

  Map<String, dynamic> getJsonData() {
    final jsonProfileManagerData = <String, dynamic>{};
    final jsonProfilesData = <String, Map<String, dynamic>>{};
    for (final profileName in profiles.keys) {
      final profile = profiles[profileName]!;
      jsonProfilesData[profileName] = profile.getJsonData();
    }
    jsonProfileManagerData["profiles"] = jsonProfilesData;
    jsonProfileManagerData["currentProfileName"] = currentProfileName;
    return jsonProfileManagerData;
  }

  // ignore: prefer_constructors_over_static_methods
  static ProfileManager fromJsonData(
      Map<String, dynamic> jsonProfileManagerData) {
    final profileManager = ProfileManager();
    profileManager.profiles = LinkedHashMap<String, Profile>();
    profileManager.currentProfileName =
        jsonProfileManagerData["currentProfileName"].toString();
    final jsonProfilesData =
        jsonProfileManagerData["profiles"] as Map<String, dynamic>;
    for (final profileName in jsonProfilesData.keys) {
      final jsonProfileData =
          jsonProfilesData[profileName] as Map<String, dynamic>;
      profileManager.profiles[profileName] =
          Profile.fromJsonData(jsonProfileData);
    }
    return profileManager;
  }

  String findNewProfileName(String profileName) {
    var counter = 1;
    var currentProfileName = profileName;
    while (profiles.keys.contains(currentProfileName)) {
      currentProfileName = "$profileName-$counter";
      counter++;
    }
    return currentProfileName;
  }

  void addProfileWithName(String profileName) {
    profiles[profileName] = Profile();
  }

  void renameAllProfiles() {
    for (final profileName in List<String>.from(profiles.keys)) {
      final profile = profiles[profileName]!;
      profiles.remove(profileName);
      final newProfileName =
          findNewProfileName(profile.schoolGrade ?? profileName);
      if (profileName == currentProfileName) {
        currentProfileName = newProfileName;
      }
      profiles[newProfileName] = profile;
    }
  }

  Profile get currentProfile {
    return profiles[currentProfileName]!;
  }

  // Current Profile attributes

  String? get schoolGrade {
    return currentProfile.schoolGrade;
  }

  set schoolGrade(String? schoolGrade) {
    if (schoolGrade != null) {
      currentProfile.schoolGrade = schoolGrade;
    }
  }

  String get subSchoolClass {
    return currentProfile.subSchoolClass;
  }

  set subSchoolClass(String subSchoolClass) {
    currentProfile.subSchoolClass = subSchoolClass;
  }

  String get schoolClassFullName {
    final grade = currentProfile.schoolGrade;
    if (grade == null) {
      return currentProfile.subSchoolClass;
    }
    return grade + currentProfile.subSchoolClass;
  }

  List<String> get subjects {
    return currentProfile.subjects;
  }

  set subjects(List<String> subjects) {
    currentProfile.subjects = subjects;
  }

  Map<String, String> get calendarUrls {
    return Map<String, String>.from(currentProfile.calendarUrls);
  }
}
