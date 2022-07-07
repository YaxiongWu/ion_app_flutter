import 'dart:math';
import 'package:flutter/material.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/cupertino.dart';
class JoyStick extends StatefulWidget{

  //用于回传摇杆移动的方位
  final void Function(Offset) onChange;

  const JoyStick({Key? key, required this.onChange}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return JoyStickState();
  }

}
class JoyStickState extends State<JoyStick> {

  //摇杆中间的圆的位置，简称 摇杆头
  Offset delta = Offset.zero;

  //更新 摇杆头的位置，并将位置传出去（这样就可以控制坦克了）
  void updateDelta(Offset newD){
    widget.onChange(newD);
    setState(() {
      delta = newD;
    });
  }

  //这个是根据用户移动摇杆头时的控制计算，主要是确保摇杆头的活动范围不能超出 外层白圈
  void calculateDelta(Offset offset){
    Offset newD = offset - Offset(bgSize/2,bgSize/2);
    updateDelta(Offset.fromDirection(newD.direction,min(bgSize/4, newD.distance)));//活动范围控制在bgSize之内
  }

  //摇杆外层的白圈尺寸，摇杆头的尺寸跟这个也有关系
  final double bgSize = 60;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: bgSize,height: bgSize,
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(bgSize/2)
        ),
        //监听用户手势
        child: GestureDetector(
          ///摇杆底部白圈
          child: Container(
            decoration: BoxDecoration(
              color: Color(0x88ffffff),
              borderRadius: BorderRadius.circular(bgSize/2),
            ),
            child: Center(
              child: Transform.translate(offset: delta,
                ///摇杆头
                child: SizedBox(
                  width:2*bgSize/3,
                  height: 2*bgSize/3,
                  child: Container(
                    child:Icon(
                      CommunityMaterialIcons.steering,
                      color: Colors.red,
                      size:2*bgSize/3,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xccffffff),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
          ),
          onPanDown: onDragDown,
          onPanUpdate: onDragUpdate,
          onPanEnd: onDragEnd,
        ),
      ),
    );
  }
  //三个方法主要用于获取用户触摸位置的数据
  void onDragDown(DragDownDetails d) {
    calculateDelta(d.localPosition);
  }

  void onDragUpdate(DragUpdateDetails d) {
    calculateDelta(d.localPosition);
  }

  void onDragEnd(DragEndDetails d) {
    updateDelta(Offset.zero);
  }
}
