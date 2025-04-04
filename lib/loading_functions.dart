// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stundenplan/constants.dart';
import 'package:stundenplan/helper_functions.dart';
import 'package:stundenplan/pages/intro/class_selection.dart';
import 'package:stundenplan/parsing/parse.dart';
import 'package:stundenplan/shared_state.dart';
import 'package:stundenplan/update_notify.dart';

Future<void> openSetupPageAndCheckForFile(
    SharedState sharedState, BuildContext context) async {
  try {
    // Only load from file when file permissions are granted
    if (await checkForFilePermissionsAndShowDialog(context)) {
      await tryMoveFile(
          Constants.saveDataFileLocationOld, Constants.saveDataFileLocation);
      await loadProfileManagerAndThemeFromFile(
        sharedState,
      );
    }
  } catch (e) {
    log("Error in openSetupPageAndCheckForFile", name: "setup", error: e);
  } finally {
    // Making sure the Frame has been completely drawn and everything has loaded before navigating to new Page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ClassSelectionPage(
                  sharedState,
                )),
      );
    });
  }
}

Future<bool> checkForFilePermissionsAndShowDialog(BuildContext context) async {
  // This function uses root-level file access, which is only available on android
  if (!Platform.isAndroid) return false;

  // Check if we have the storage Permission
  if (await Permission.manageExternalStorage.isDenied) {
    // We don't have Permission -> Show a small dialog to explain why we need it
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Einstellungen Speichern"),
        content: const Text(
            "Diese App benötigt zugriff auf den Speicher deines Gerätes um Fächer und Themes verlässlich zu speichern."),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ok'),
          ),
        ],
      ),
    );

    if (result != true) return false;

    // Request Permission -> If Permission denied -> return false
    final status = await requestStorage();
    if (status.isDenied) return false;
  }
  return true;
}

Future<void> loadProfileManagerAndThemeFromFile(
  SharedState sharedState,
) async {
  try {
    final String data = await loadFromFile(Constants.saveDataFileLocation);
    // Parse the json
    final Map<String, dynamic> jsonData =
        jsonDecode(data) as Map<String, dynamic>;

    // Validate required fields
    if (!jsonData.containsKey("theme") ||
        !jsonData.containsKey("jsonProfileManagerData")) {
      throw const FormatException("Missing required fields in save data");
    }

    // Load data from json
    sharedState.loadThemeProfileManagerFromJson(
        jsonData["theme"] as Map<String, dynamic>,
        jsonData["jsonProfileManagerData"] as Map<String, dynamic>);

    if (jsonData.containsKey("sendNotifications")) {
      sharedState.sendNotifications = jsonData["sendNotifications"] as bool;
    }
  } catch (e) {
    log("Error while loading save data from file", name: "file", error: e);
    rethrow; // Re-throw to allow caller to handle the error
  }
}

Future<bool> checkForUpdateAndLoadTimetable(UpdateNotifier updateNotifier,
    SharedState sharedState, BuildContext context) async {
  try {
    // Check for updates on non-Windows platforms
    if (!Platform.isWindows) {
      await updateNotifier.init();
      await updateNotifier.checkForNewestVersionAndShowDialog(
        context,
        sharedState,
      );
    }

    // Parse the Timetable
    await parsePlans(
      sharedState,
    );
    log("State was set to: ${sharedState.content}", name: "state");

    // Cache the Timetable
    sharedState.saveCache();
    return true;
  } on TimeoutException catch (e) {
    log("Timeout! Can't read timetable from Network",
        name: "network", error: e);
    sharedState.loadCache();
    return false;
  } on SocketException catch (e) {
    log("Network error! Can't reach page", name: "network", error: e);
    sharedState.loadCache();
    return false;
  } catch (e) {
    log("Unexpected error while checking for update and loading timetable",
        name: "update", error: e);
    sharedState.loadCache();
    return false;
  }
}
