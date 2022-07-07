import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:ion/controllers/ion_controller.dart';
import 'package:dart_printf/dart_printf.dart';

class SliderSpeedControl extends GetxController{
  var speed=10.0.obs;
  Map<String,int> dataChannelDataSpeed={};
  final _ionController = Get.find<IonController>();

  _sendSpeed(val){
    dataChannelDataSpeed={
      'type':2,
      'speed':speed.value.round()
    };
    String s=jsonEncode(dataChannelDataSpeed);
    print("onchangeEnd:${s}");
    _ionController.dataChannelSend(s);
  }
}
class SliderSpeedView extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    final SliderSpeedControl controller = Get.put(SliderSpeedControl());
    return
      Transform.rotate(angle: - pi / 2,
        //  Center(
        child: Container(
          //color: Colors.blue,//black54,
          child:
          SizedBox(
            width: 260,
            height: 260,

            child:

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  CommunityMaterialIcons.speedometer,
                  color: Colors.red,
                  size:40,
                ),
                 //Obx(() => Text("Clicks: ${controller.speed}")
                Obx(()=> Slider(
                  value:controller.speed.value,
                  min: 0.0,
                  max: 100.0,
                  activeColor: Colors.deepOrange, inactiveColor: Colors.grey,
                  onChanged: (val) => {controller.speed.value=val},
                  onChangeStart: (val) => print('onChangeStart -> $val'),
                  onChangeEnd: (val) => {controller._sendSpeed(val)},
                ),
                )
              ],
            ),
          ),
        ),
      );

  }
}