import 'dart:convert';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:parse_video/model/MobileBean.dart';
import 'package:parse_video/plugin/flutterToastManage.dart';
import 'package:parse_video/plugin/httpManage.dart';

class SearchMobilePage extends StatefulWidget {
  @override
  _SearchMobilePage createState() => _SearchMobilePage();
}

class _SearchMobilePage extends State<SearchMobilePage> {
  @override
  Widget build(BuildContext context) {
    return NeumorphicTheme(
        themeMode: ThemeMode.light,
        theme: NeumorphicThemeData(
          defaultTextColor: Color(0xFF3E3E3E),
          baseColor: Colors.white,
          intensity: 0.5,
          lightSource: LightSource.topLeft,
          depth: 10,
        ),
        darkTheme: neumorphicDefaultDarkTheme.copyWith(
            defaultTextColor: Colors.white70),
        child: _Page());
  }
}

class _Page extends StatefulWidget {
  @override
  __PageState createState() => __PageState();
}

class __PageState extends State<_Page> {
  String _start = "";
  String _end = "";
  CancelToken _cancelToken;
  List<MobileBean> tasksList = [];
  bool showLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
              child: Container(
            child: Column(
              children: <Widget>[
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                      onChanged: (text) {
                        _start = text;
                      },
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                    )),
                    Text(
                      "****",
                      style: TextStyle(color: Colors.black),
                    ),
                    Expanded(
                        child: TextField(
                      onChanged: (text) {
                        _end = text;
                      },
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                    )),
                    GestureDetector(
                        child: Text("start"),
                        onTap: () {
                          _search();
                        })
                  ],
                ),
                Expanded(
                  child: Container(
                    decoration: new BoxDecoration(
                      color: Colors.white,
                      //设置四周圆角 角度
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20.0),
                          topRight: Radius.circular(20.0)),
                    ),
                    child: ListView.separated(
                        physics: BouncingScrollPhysics(),
                        separatorBuilder: (context, index) {
                          return new Divider(
                            color: Colors.grey,
                          );
                        },
                        itemBuilder: (item, index) {
                          return Padding(
                              padding: EdgeInsets.only(left: 10, right: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text("${tasksList[index].tel}")),
                                  GestureDetector(
                                      child: Text(
                                        "copy",
                                      ),
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(
                                            text: "${tasksList[index].tel}"));
                                        FlutterToastManage().showToast("复制成功");
                                      })
                                ],
                              ));
                        },
                        itemCount: tasksList.length),
                  ),
                ),
              ],
            ),
          ))
        ],
      ),
    );
  }

  void _search() async {
    assert(false);
    if (this._start.length != 3) {
      FlutterToastManage().showToast("手机号开始部分不能少于3个");
      return;
    }
    if (this._end.length != 4) {
      FlutterToastManage().showToast("手机号结束部分不能少于4个");
      return;
    }
    for (int middle = 0; middle < 10000; middle++) {
      String mobile = "$_start${middle.toString().padLeft(4, "0")}$_end";
      print('start request：$mobile');
      _cancelToken = new CancelToken();
      final Response response = await HttpManager()
          .get('tel/', data: {'tel': mobile}, cancelToken: _cancelToken);
      print('request success 手机号码数据：' + response.toString());
      if (response != null) {
        Map mobileMap = json.decode(response.toString());
        var m = new MobileBean.fromJson(mobileMap);
        if(m.code == "200" && m.local.contains("广州市")){
        tasksList.add(m);
        setState(() {});
        }
      }
    }
  }

  @override
  void dispose() {
    if (_cancelToken != null) {
      _cancelToken.cancel("组件卸载 取消网络请求");
    }
    super.dispose();
  }
}
