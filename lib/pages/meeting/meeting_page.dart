import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_ion/flutter_ion.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ion/controllers/ion_controller.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'control_stick.dart';
import 'slider_speed.dart';
import 'dart:convert';
import 'dart:math';
class MeetingBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MeetingController>(() => MeetingController());
    Get.lazyPut<SliderSpeedControl>(() => SliderSpeedControl());
  }
}

class VideoRendererAdapter {
  String mid;
  bool local;
  RTCVideoRenderer? renderer;
  MediaStream stream;
  RTCVideoViewObjectFit _objectFit =
      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
  VideoRendererAdapter._internal(this.mid, this.stream, this.local);
  static Future<VideoRendererAdapter> create(
      String mid, MediaStream stream, bool local) async {
    var renderer = VideoRendererAdapter._internal(mid, stream, local);
    await renderer.setupSrcObject();
    return renderer;
  }

  setupSrcObject() async {
    if (renderer == null) {
      renderer = new RTCVideoRenderer();
      await renderer?.initialize();
    }
    renderer?.srcObject = stream;
    if (local) {
      _objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    }
  }

  switchObjFit() {
    _objectFit =
        (_objectFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
            ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
            : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
  }

  RTCVideoViewObjectFit get objFit => _objectFit;

  set objectFit(RTCVideoViewObjectFit objectFit) {
    _objectFit = objectFit;
  }

  dispose() async {
    if (renderer != null) {
      print('dispose for texture id ' + renderer!.textureId.toString());
      renderer?.srcObject = null;
      await renderer?.dispose();
      renderer = null;
    }
  }
}
class MeetingController extends GetxController {
  final _ionController = Get.find<IonController>();
  late SharedPreferences prefs;
  final videoRenderers = Rx<List<VideoRendererAdapter>>([]);
  LocalStream? _localStream;

  RTC? get rtc => _ionController.rtc;

  var _cameraOff = false.obs;
  var _microphoneOff = false.obs;
  var _speakerOn = true.obs;
  GlobalKey<ScaffoldState>? _scaffoldkey;
  var name = ''.obs;
  var sid = ''.obs;
  var _value02 = 0.0.obs;
  var _simulcast = false.obs;
  Map<String,int> dataChannelDataStick={};

  int oldStickDx=0;
  int oldStickDy=0;
  TrackEvent? trackEvent = null;

  @override
  @mustCallSuper
  void onInit() async {
    super.onInit();
    //全屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    //横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft
    ]);

    if ( rtc == null) {
      print(":::ROOM or SFU is not initialized!:::");
      print("Goback to /login");
      SchedulerBinding.instance!.addPostFrameCallback((_) {
        Get.offNamed('/login');
        _cleanUp();
      });
      return;
    }
  }

  connect() async {
    _scaffoldkey = GlobalKey();

    prefs = await _ionController.prefs();

    //if this client is hosted as a website, using https, the ion-backend has to be
    //reached via wss. So the address should be for example:
    //https://your-backend-address.com
    var host = prefs.getString('server') ?? '120.78.200.246';
    host = 'http://' + host + ':5551';
    //join room
    name.value = prefs.getString('display_name') ?? 'Guest';
    sid.value = prefs.getString('sid') ?? 'ion';

    //init sfu and biz clients
    _ionController.setup(host: host, name: name.value, sid: sid.value);

    rtc!.ontrack = (MediaStreamTrack track, RemoteStream stream) async {
      if (track.kind == 'video') {
        _addAdapter(
            await VideoRendererAdapter.create(stream.id, stream.stream, false));
      }
    };

    rtc?.ontrackevent = (TrackEvent event) async {
      print("ontrackevent event.uid=${event.uid}");
      for (var track in event.tracks) {
        print(
            "ontrackevent track.id=${track.id} track.kind=${track.kind} track.layer=${track.layer}");
      }
      switch (event.state) {
        case TrackState.ADD:
          if (event.tracks.isNotEmpty) {
            var id = event.tracks[0].id;
            this._showSnackBar(":::track-add [$id]:::");
          }

          if (trackEvent == null) {
            print("trackEvent == null");
            trackEvent = event;
          }

          break;
        case TrackState.REMOVE:
          if (event.tracks.isNotEmpty) {
            var mid = event.tracks[0].stream_id;
            this._showSnackBar(":::track-remove [$mid]:::");
            _removeAdapter(mid);
          }
          break;
        case TrackState.UPDATE:
          if (event.tracks.isNotEmpty) {
            var id = event.tracks[0].id;
            this._showSnackBar(":::track-update [$id]:::");
          }
          break;
      }
    };

    //connect to room and SFU
    await _ionController.connect();
  }

  _removeAdapter(String mid) {
    videoRenderers.value.removeWhere((element) => element.mid == mid);
    videoRenderers.update((val) {});
  }

  _addAdapter(VideoRendererAdapter adapter) {
    videoRenderers.value.add(adapter);
    videoRenderers.update((val) {});
  }

  _swapAdapter(adapter) {
    var index = videoRenderers.value
        .indexWhere((element) => element.mid == adapter.mid);
    if (index != -1) {
      var temp = videoRenderers.value.elementAt(index);
      videoRenderers.value[0] = videoRenderers.value[index];
      videoRenderers.value[index] = temp;
    }
  }
  _stickOnChange( Offset delta){
   // print(delta);
    int newStickDx=delta.dx.round();
    int newStickDy= - delta.dy.round();
    if(newStickDy == -0.0)
      newStickDy=0;
    if(newStickDy == 0 || newStickDx ==0){
      return;
    }
    //if(newStickDy != oldStickDy || newStickDx !=oldStickDx)
      //{
        dataChannelDataStick={
          "type":1,
          "x":newStickDx,
          "y":newStickDy
        };
        //String s=jsonEncode(dataChannelData);
        //print(s);
        _ionController.dataChannelSend(jsonEncode(dataChannelDataStick));
        oldStickDx=newStickDx;
        oldStickDy=newStickDy;
     // }else{
      //oldStickDx=newStickDx;
      //oldStickDy=newStickDy;
   // }
  }

  //Switch speaker/earpiece
  _switchSpeaker() {
    if (_localVideo != null) {
      _speakerOn.value = !_speakerOn.value;
      MediaStreamTrack audioTrack = _localVideo!.stream.getAudioTracks()[0];
      audioTrack.enableSpeakerphone(_speakerOn.value);
      _showSnackBar(":::Switch to " +
          (_speakerOn.value ? "speaker" : "earpiece") +
          ":::");
    }
  }

  VideoRendererAdapter? get _localVideo {
    VideoRendererAdapter? renderrer;
    videoRenderers.value.forEach((element) {
      if (element.local) {
        renderrer = element;
        return;
      }
    });
    return renderrer;
  }

  List<VideoRendererAdapter> get _remoteVideos {
    List<VideoRendererAdapter> renderers = ([]);
    videoRenderers.value.forEach((element) {
      if (!element.local) {
        renderers.add(element);
      }
    });
    return renderers;
  }

  //Switch local camera
  _switchCamera() {
    if (_localVideo != null &&
        _localVideo!.stream.getVideoTracks().length > 0) {
      _localVideo?.stream.getVideoTracks()[0].switchCamera();
    } else {
      _showSnackBar(":::Unable to switch the camera:::");
    }
  }

  //Open or close local video
  _turnCamera() {
    if (_localVideo != null &&
        _localVideo!.stream.getVideoTracks().length > 0) {
      var muted = !_cameraOff.value;
      _cameraOff.value = muted;
      _localVideo?.stream.getVideoTracks()[0].enabled = !muted;
    } else {
      _showSnackBar(":::Unable to operate the camera:::");
    }
  }

  //Open or close local audio
  _turnMicrophone() {
    if (_localVideo != null &&
        _localVideo!.stream.getAudioTracks().length > 0) {
      var muted = !_microphoneOff.value;
      _microphoneOff.value = muted;
      _localVideo?.stream.getAudioTracks()[0].enabled = !muted;
      _showSnackBar(":::The microphone is ${muted ? 'muted' : 'unmuted'}:::");
    } else {}
  }

  _cleanUp() async {
    if (_localVideo != null) {
      await _localStream!.unpublish();
    }
    videoRenderers.value.forEach((item) async {
      var stream = item.stream;
      try {
        rtc!.close();
        await stream.dispose();
      } catch (error) {}
    });
    videoRenderers.value.clear();
    await _ionController.close();
  }

  _showSnackBar(String message) {
    print(message);
    /*
    _scaffoldkey.currentState!.showSnackBar(SnackBar(
      content: Container(
        //color: Colors.white,
        decoration: BoxDecoration(
            color: Colors.black38,
            border: Border.all(width: 2.0, color: Colors.black),
            borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.fromLTRB(45, 0, 45, 45),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(message,
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center),
        ),
      ),
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      duration: Duration(
        milliseconds: 1000,
      ),
    ));*/
  }

  _hangUp() {
    Get.dialog(AlertDialog(
        title: Text("Hangup"),
        content: Text("Are you sure to leave the room?"),
        actions: <Widget>[
          TextButton(
            child: Text("Cancel"),
            onPressed: () {
              Get.back();
            },
          ),
          TextButton(
            child: Text(
              "Hangup",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              Get.offAllNamed("/login");
              _cleanUp();
            },
          )
        ]));
  }
}

class BoxSize {
  BoxSize({required this.width, required this.height});

  double width;
  double height;
}

class MeetingView extends GetView<MeetingController> {
  List<VideoRendererAdapter> get remoteVideos => controller._remoteVideos;

  VideoRendererAdapter? get localVideo => controller._localVideo;

  final double localWidth = 114.0;
  final double localHeight = 72.0;
  String dropdownValue = 'Simulcast';
  BoxSize localVideoBoxSize(Orientation orientation) {
    return BoxSize(
      width: (orientation == Orientation.portrait) ? localHeight : localWidth,
      height: (orientation == Orientation.portrait) ? localWidth : localHeight,
    );
  }


  Widget _buildMajorVideo() {
    return Obx(() {
      if (remoteVideos.isEmpty) {
        return Image.asset(
          'assets/images/loading.jpeg',
          fit: BoxFit.cover,
        );
      }
      var adapter = remoteVideos[0];
      return GestureDetector(
          onDoubleTap: () {
            adapter.switchObjFit();
          },
          child: RTCVideoView(adapter.renderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain));
    });
  }

  Widget _buildVideoList() {
    return Obx(() {
      if (remoteVideos.length <= 1) {
        return Container();
      }
      return ListView(
          scrollDirection: Axis.horizontal,
          children:
              remoteVideos.getRange(1, remoteVideos.length).map((adapter) {
            adapter.objectFit =
                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
            return _buildMinorVideo(adapter);
          }).toList());
    });
  }

  Widget _buildLocalVideo(Orientation orientation) {
    return Obx(() {
      if (localVideo == null) {
        return Container();
      }
      var size = localVideoBoxSize(orientation);
      return SizedBox(
          width: size.width,
          height: size.height,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              border: Border.all(
                color: Colors.white,
                width: 0.5,
              ),
            ),
            child: GestureDetector(
                onTap: () {
                  controller._switchCamera();
                },
                onDoubleTap: () {
                  localVideo?.switchObjFit();
                },
                child: RTCVideoView(localVideo!.renderer!,
                    objectFit: localVideo!.objFit)),
          ));
    });
  }

  Widget _buildMinorVideo(VideoRendererAdapter adapter) {
    return SizedBox(
      width: 120,
      height: 90,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          border: Border.all(
            color: Colors.white,
            width: 1.0,
          ),
        ),
        child: GestureDetector(
            onTap: () => controller._swapAdapter(adapter),
            onDoubleTap: () => adapter.switchObjFit(),
            child: RTCVideoView(adapter.renderer!, objectFit: adapter.objFit)),
      ),
    );
  }

  //Leave current video room

  Widget _buildLoading() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          SizedBox(
            width: 10,
          ),
          Text(
            'Waiting for others to join...',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22.0,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return
      Transform.rotate(angle: -pi / 2,
        //  Center(
        child: Container(
          //color: Colors.blue,//black54,
          child:
          SizedBox(
            width: 260,
            height: 260,

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  CommunityMaterialIcons.speedometer,
                  color: Colors.red,
                  size: 40,
                ),

                Slider(
                  value:1,// controller._value02,
                  min: 0.0,
                  max: 100.0,
                  activeColor: Colors.deepOrange,
                  inactiveColor: Colors.grey,
                  onChanged: (val) =>{},
                  onChangeStart: (val) => print('onChangeStart -> $val'),
                  onChangeEnd: (val) => print('onChangeEnd -> $val'),
                ),

                  ],
            ),
          ),
        ),
      );

  }

  //tools
  List<Widget> _buildTools() {
    return <Widget>[
      SizedBox(
        width: 36,
        height: 36,
        child: RawMaterialButton(
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white,
              width: 1,
            ),
          ),
          child: Obx(() => Icon(
                controller._microphoneOff.value
                    ? CommunityMaterialIcons.microphone_off
                    : CommunityMaterialIcons.microphone,
                color:
                    controller._microphoneOff.value ? Colors.red : Colors.white,
              )),
          onPressed: controller._turnMicrophone,
        ),
      ),
      SizedBox(
        width: 36,
        height: 36,
        child: RawMaterialButton(
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white,
              width: 1,
            ),
          ),
          child: Obx(() => Icon(
                controller._speakerOn.value
                    ? CommunityMaterialIcons.volume_high
                    : CommunityMaterialIcons.speaker_off,
                color: Colors.white,
              )),
          onPressed: controller._switchSpeaker,
        ),
      ),
      SizedBox(
        width: 36,
        height: 36,
        child: RawMaterialButton(
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white,
              width: 1,
            ),
          ),
          child: Icon(
            CommunityMaterialIcons.phone_hangup,
            color: Colors.red,
          ),
          onPressed: controller._hangUp,
        ),
      ),

    ];
  }

  @override
  Widget build(BuildContext context) {

    return OrientationBuilder(builder: (context, orientation) {
      return SafeArea(
        child: Scaffold(
            key: controller._scaffoldkey,
            body: Container(
              color: Colors.black87,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: Container(
                              child: _buildMajorVideo(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Obx(() =>
                      (remoteVideos.isEmpty) ? _buildLoading() : Container()),
                  Positioned(
                    left: 0,
                    //right: 0,
                    top:0,
                    bottom: 200,
                    //height: 48,
                    width: 48,
                    child: Stack(
                      children: <Widget>[
                        Opacity(
                          opacity: 0.1,
                          child: Container(
                            color: Colors.black,
                          ),
                        ),
                        Container(
                         // height: 48,
                          width: 48,
                          margin: EdgeInsets.all(0.0),
                          //child: Row(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: _buildTools(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 10,
                    bottom: 20,
                    //height: 48,
                    //width: 48,
                    child: Stack(
                      children: <Widget>[
                        Opacity(
                          opacity: 0.6,
                          child: Container(
                            color: Colors.green,//black,
                          ),
                        ),
                        Container(
                          // height: 48,
                          //width: 48,
                          margin: EdgeInsets.all(0.0),
                          //child: Row(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children:[
                              SizedBox(height: 20),
                              //两个摇杆 位于屏幕两端，发射按钮下方
                              Row(
                                children: [
                                  SizedBox(width: 48),
                                  Opacity(
                                    opacity: 0.3,
                                    child: JoyStick(
                                      onChange: (Offset delta)=>controller._stickOnChange(delta),
                                    ),
                                  ),

                                  // Spacer(),
                                  // JoyStick(
                                  //   onChange: (Offset delta)=>print(delta),
                                  // ),
                                  // SizedBox(width: 48)
                                ],
                              ),
                              SizedBox(height: 24)
                             ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: -80,
                    bottom: 20,
                    //height: 48,
                    //width: 48,
                    child: Opacity(
                      opacity: 0.6,
                      child:   SliderSpeedView(),
                    ),
                  ),
                ],
              ),
            )),
      );
    });
  }
}
