class Profile {
  String? schoolGrade;
  String subSchoolClass = "";
  List<String> subjects = [];
  Map<String, String> calendarUrls = {};

  Map<String, dynamic> getJsonData() {
    final jsonData = <String, dynamic>{
      "schoolGrade": schoolGrade,
      "subSchoolClass": subSchoolClass,
      "subjects": subjects,
      "calendarUrls": calendarUrls
    };
    return jsonData;
  }

  @override
  String toString() {
    return "$schoolGrade$subSchoolClass";
  }

  // ignore: prefer_constructors_over_static_methods
  static Profile fromJsonData(Map<String, dynamic> jsonData) {
    final newProfile = Profile();
    newProfile.schoolGrade = jsonData["schoolGrade"]?.toString();
    newProfile.subSchoolClass = jsonData["subSchoolClass"]?.toString() ?? "";

    final subjectsList = jsonData["subjects"] as List<dynamic>? ?? [];
    for (final subject in subjectsList) {
      newProfile.subjects.add(subject.toString());
    }

    final calendarUrlsMap = jsonData["calendarUrls"] as Map<String, dynamic>?;
    if (calendarUrlsMap != null) {
      newProfile.calendarUrls = {};
      for (final entry in calendarUrlsMap.entries) {
        newProfile.calendarUrls[entry.key] = entry.value.toString();
      }
    }

    return newProfile;
  }
}
