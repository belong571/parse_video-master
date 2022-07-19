import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TestPage extends StatefulWidget {
  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Container(
      color: Colors.white,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          // Container(decoration: BoxDecoration(color: Colors.yellow),width: 100,height: 100,child: Container(decoration: BoxDecoration(color: Colors.green),width: 50,height: 50),alignment: Alignment.bottomLeft,),
          // Container(decoration: BoxDecoration(color: Colors.red),width: 50,height: 50),
          RichText(
            text: new TextSpan(
              // 注意:TextSpan需要指定样式
              // TextSpan子组件会继承父组件的样式
              style: new TextStyle(
                fontSize: 14.0, //设置大小
                color: Colors.red, //设置颜色
              ),
              children: <TextSpan>[
                new TextSpan(
                    text: '¥',
                    style: new TextStyle(fontSize: 14, color: Colors.red)),
                new TextSpan(
                    text: '1399',
                    style: new TextStyle(
                        fontSize: 20,
                        color: Colors.red,
                        fontWeight: FontWeight.bold)), //
                new TextSpan(
                    text: '.00',
                    style:
                        new TextStyle(fontSize: 14, color: Colors.red)), // 设置粗体
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
