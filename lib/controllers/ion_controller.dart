import 'package:flutter_ion/flutter_ion.dart';
import 'package:uuid/uuid.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:device_info/device_info.dart';

import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';



class IonController extends GetxController {
  SharedPreferences? _prefs;
  late String _sid;
  late String _name;
  //final String _uid = Uuid().v4();
  late String _uid;

  Connector? _connector;

  RTC? _rtc;
  var dataChannel_stick;
  String get sid => _sid;

  String get uid => _uid;

  String get name => _name;
  RTC? get rtc => _rtc;

  @override
  void onInit() async {
    super.onInit();
    print('IonController::onInit');
  }

  Future<SharedPreferences> prefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    return _prefs!;
  }

  Future<String> getPhoneIdentifer() async {
    String id='';
    bool kIsWeb = GetPlatform.isWeb;
    try {
      //如果是网页
      if(kIsWeb ){
        id='webTest122';//Random().nextInt(10).toString();
      }else {
        if (GetPlatform.isAndroid) {
          final DeviceInfoPlugin deviceInfoPlugin = new DeviceInfoPlugin();
          var build = await deviceInfoPlugin.androidInfo;
          id = build.androidId;
          //UUID for Android
        } else if (GetPlatform.isIOS) {
          final DeviceInfoPlugin deviceInfoPlugin = new DeviceInfoPlugin();
          var data = await deviceInfoPlugin.iosInfo;
          id = data.identifierForVendor;
        } else {
          id = Random().nextInt(10).toString();
        }
      }
    } on PlatformException {
      print('Failed to get platform version');
    }
    return id;
  }

  setup(
      {required String host,
      required String sid,
      required String name}) async {
    print('IonController setup');
    _connector = new Connector(host);
    _rtc = new RTC(_connector!);
    _sid = sid;
    _name = name;
    print('IonController setup ok');
  }

  connect() async {

    await _rtc!.connect();
    print('IonController connect()');

    joinRTC();

    print('joinRtc()');
  }

  dataChannelSend(String msg){
    if(dataChannel_stick.state == RTCDataChannelState.RTCDataChannelOpen) {
      dataChannel_stick.send(RTCDataChannelMessage(msg));
    }else
      print("dataChannelSend fail,state:${dataChannel_stick.state}");
  }
  joinRTC() async {
    _uid=await getPhoneIdentifer();
   await _rtc!.join(_sid, _uid, JoinConfig());
     dataChannel_stick =await _rtc!.createDataChannel("stick");
     dataChannel_stick.onDataChannelState=( RTCDataChannelState state) =>{
             if(state == RTCDataChannelState.RTCDataChannelOpen)
                 dataChannel_stick.send(RTCDataChannelMessage("wuayxiongnnnnb"))
     };
  }

  close() async {

  }

  subscribe(List<Subscription> infos) {
    _rtc!.subscribe(infos);
  }
}
