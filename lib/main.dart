import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:parse_video/components/loading.dart';
import 'package:parse_video/page/SearchMobilePage.dart';
import 'package:parse_video/page/TestPage.dart';
import 'package:parse_video/page/WeatherPage.dart';
import 'package:parse_video/page/downloadPage.dart';
import 'package:parse_video/page/local_video_page.dart';
import 'package:parse_video/page/readyToDown.dart';
import 'package:parse_video/page/video_page.dart';
import 'package:parse_video/plugin/download.dart';
import 'package:parse_video/plugin/flutterToastManage.dart';
import 'package:parse_video/plugin/httpManage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'common/niceButton.dart';
import 'components/taskListItem.dart';
import 'components/textField.dart';
import 'database/downloadVideoDatabase.dart';
import 'database/readyToDownDatabase.dart';
import 'model/currentDownLoad.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true);
  if (Platform.isAndroid) {
    SystemUiOverlayStyle systemUiOverlayStyle =
        SystemUiOverlayStyle(statusBarColor: Colors.black);
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => CurrentDownLoad()),
  ], child: MyApp()));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return NeumorphicApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('zh', 'CN'),
        const Locale('en', 'US'),
      ],
      title: '无水印视频下载',
      themeMode: ThemeMode.light,
      theme: NeumorphicThemeData(
        baseColor: Color(0xFFFFFFFF),
        lightSource: LightSource.topLeft,
        depth: 10,
      ),
      darkTheme: NeumorphicThemeData(
        baseColor: Color(0xFF3E3E3E),
        lightSource: LightSource.topLeft,
        depth: 6,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver{
  String result = '';
  String _videoLink = '';
  final String _cache_clipboard = '_cache_clipboard';
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();
  ReceivePort _port = ReceivePort();
  DateTime lastPopTime;
  bool showLoading = false;
  bool showGuessLikeDialog = false;



  @override
  void initState(){
    DownLoadInstance().prepare();
    _portListen();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  getClipboardText() async{
    FocusScope.of(context).requestFocus(new FocusNode());
    var clipboardData = await Clipboard.getData(Clipboard.kTextPlain);//获取粘贴板中的文本
    print(clipboardData);
    // print(clipboardData.text);
    if (clipboardData != null && clipboardData.text.isNotEmpty) {
      SharedPreferences sp = await SharedPreferences.getInstance();
      print('current ${clipboardData.text}  cache ${sp.getString(
          _cache_clipboard)}'); //打印内容
      if (clipboardData.text != sp.getString(_cache_clipboard) && !showGuessLikeDialog) {
        sp.setString(_cache_clipboard, clipboardData.text);
        showGuessLikeDialog = true;
        showDialog(
            context: context,
            builder: (context) =>
                AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10.0))),
                  contentPadding: EdgeInsets.only(top: 10.0),
                  title: Text('猜你想搜索以下内容'),
                  content: Text(clipboardData.text),
                  actions: <Widget>[
                    FlatButton(
                      child: Text('取消'),
                      onPressed: () {
                        showGuessLikeDialog = false;
                        Navigator.pop(context, false);
                      },
                    ),
                    FlatButton(
                        child: Text('确定', style: TextStyle(
                            color: Colors.red
                        ),),
                        onPressed: () {
                          showGuessLikeDialog = false;
                          Navigator.pop(context, true);
                          _futureGetLink(clipboardData.text);
                        }),
                  ],
                ));
      }
    }
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) async{
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive: // 处于这种状态的应用程序应该假设它们可能在任何时候暂停。
        print("didChangeAppLifecycleState inactive");
        break;
      case AppLifecycleState.resumed:// 应用程序可见，前台
        print("didChangeAppLifecycleState resumed");
        getClipboardText();
        break;
      case AppLifecycleState.paused: // 应用程序不可见，后台
        print("didChangeAppLifecycleState paused");
        break;
      default:
        print("didChangeAppLifecycleState $state");
        break;
    }
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  _portListen() {
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    FlutterDownloader.registerCallback(downloadCallback);
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      context.read<CurrentDownLoad>().setDownLoadAbleItem(
          new DownLoadAbleItem(id: id, progress: progress, status: status));
      if(status == DownloadTaskStatus.running){

      }else if(status == DownloadTaskStatus.complete){
        FlutterToastManage().showToast("下载完成");
      }else if(status == DownloadTaskStatus.failed){

      }else if(status == DownloadTaskStatus.paused){

      }else{

      }
    });
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    print('Download task ($id) is in status ($status) and process ($progress)');
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
  }

  Future _futureGetLink(String url) async {
    // location.onLocationChanged.listen((LocationData currentLocation) {
    //   // Use current location
    //   print(currentLocation);
    // });
    FocusScope.of(context).requestFocus(new FocusNode());     // 获取焦点
     if(url==null || url.isEmpty){
       FlutterToastManage().showToast("请输入网址~");
      return;
    }
    final urlRegex =
    new RegExp(r'(https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]');

    List<String> urls =
        urlRegex.allMatches(url).map((m) => m.group(0)).toList();
    print(urls);
    int findIndex = -1;
    for(int i = 0; i < urls.length; i++){
      if(RegExp(r"^((https|http|ftp|rtsp|mms)?:\/\/)[^\s]+")
          .hasMatch(urls[i])){
        findIndex = i;
        break;
      }
    }

    if (findIndex == -1) {
      FlutterToastManage().showToast("请输入正确的网址哦~");
      return;
    }

    setState(() {
      showLoading = true;
    });
    final Response response =
        await HttpManager().get('video/', data: {'url': urls[findIndex]});
    setState(() {
      showLoading = false;
    });
    print("------------------------>");
    print(urls[findIndex]);
    print(response.data);
    Map result = Map.from(response.data);

    if (result['code'] == 200) {
      _videoLink = result['url'];
      print(_videoLink);
      if(!_videoLink.startsWith("http")){
        _videoLink = "https:" + _videoLink;
      }
      FlutterToastManage().showToast("已找到视频,您可选择播放或者下载视频");
    } else {
      FlutterToastManage().showToast(result['msg']);
    }
  }

  Future<bool> _onBackPressed() {
    if (_scaffoldKey.currentState.isDrawerOpen) {
      Navigator.of(context).pop();
    }
    return showDialog(
        context: context,
        builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10.0))),
              contentPadding: EdgeInsets.only(top: 10.0),
              title: Text('确定退出程序吗?'),
              actions: <Widget>[
                FlatButton(
                  child: Text('暂不'),
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                ),
                FlatButton(
                    child: Text('确定',style: TextStyle(
                      color: Colors.red
                    ),),
                    onPressed: () {
                      Navigator.pop(context, true);
                    }),
              ],
            ));
  }

  _openRoute({@required Widget page}) {
    //打开B路由
    Navigator.push(context, PageRouteBuilder(pageBuilder: (BuildContext context,
        Animation animation, Animation secondaryAnimation) {
      return new FadeTransition(
        opacity: animation,
        child: page,
      );
    }));
  }

  _addVideoToReadyDownload() async {
    print(result);
    if (result.isEmpty) {
      FlutterToastManage().showToast("请输入视频链接~");
      return;
    }
    bool hasadded = await DataBaseReadyDownLoadProvider.db.queryWithUrl(result);
    if (!hasadded) {
      await DataBaseReadyDownLoadProvider.db.insetDB(url: result);
      FlutterToastManage().showToast("已添加到待下载列表了~");
    } else {
      FlutterToastManage().showToast("已经添加过了~");
    }
  }

  // md5 加密
  String generateMd5(String data) {
    var content = new Utf8Encoder().convert(data);
    var digest = md5.convert(content);
    // 这里其实就是 digest.toString()
    return hex.encode(digest.bytes);
  }

  _startDownLoad() async {
    if (_videoLink.isEmpty) {
      FlutterToastManage().showToast("请先搜索下载视频~");
      return;
    }
    String fileName = generateMd5(_videoLink);
    bool hasDownLoad = await DataBaseDownLoadListProvider.db
        .queryWithFileName(fileName + '.mp4');
    if (hasDownLoad) {
      FlutterToastManage().showToast("已经下载过该视频了哦~");
      return;
    }
    DownLoadInstance().startDownLoad(_videoLink, fileName);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(onWillPop: _onBackPressed, child: _buildScaffold());
  }

  Widget _buildScaffold() {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Color(0xFF000000),
        actionsIconTheme: NeumorphicTheme.currentTheme(context).iconTheme,
        leading: IconButton(
          icon: new NeumorphicIcon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState.openDrawer();
          },
        ),
        title: NeumorphicText(
          "无水印视频下载",
          style: NeumorphicStyle(
            depth: 4, //customize depth here
            color: Colors.white, //customize color here
          ),
          textStyle: NeumorphicTextStyle(
            fontSize: 18, //customize size here
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage("assets/2.png"), fit: BoxFit.cover)),
              accountEmail: Text(''),
              accountName: Text(''),
            ),
            SimpleListTile(
              title: '待下载列表',
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                _openRoute(page: new ReadyToDownPage());
              },
            ),
            SimpleListTile(
              title: '本地视频',
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                _openRoute(page: new LocalVideoPage());
              },
            ),
            SimpleListTile(
              title: '我的下载',
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                _openRoute(page: new DownLoadPage());
              },
            ),
            SimpleListTile(
              title: '手机号码查询',
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                _openRoute(page: new SearchMobilePage());
              },
            ),
            SimpleListTile(
              title: '天气预报查询',
              trailing: Icon(Icons.chevron_right),
              onTap: () {
              _openRoute(page: new WeatherPage());
              },
            ),
            SimpleListTile(
              title: '测试',
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                _openRoute(page: new TestPage());
              },
            )
          ],
        ),
      ),
      body: Container(
        decoration: new BoxDecoration(
          color: Colors.black,
        ),
        child: Container(
          decoration: new BoxDecoration(
            color: Colors.white,
            //设置四周圆角 角度
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0)),
          ),
          child: Stack(
            children: <Widget>[
              ListView(
                children: <Widget>[
                  SizedBox(
                    height: 20,
                  ),
                  TextSearchField(
                    hint: "请输入视频链接",
                    onChanged: (text) {
                      final urlRegex = new RegExp(
                          r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+');
                      List<String> urls = urlRegex
                          .allMatches(text)
                          .map((m) => m.group(0))
                          .toList();
                          if(urls.length>0){
                                                  result = urls[0];
                          }

                    },
                    onSubmit: (text) {
                      if (lastPopTime == null ||
                          DateTime.now().difference(lastPopTime) >
                              Duration(seconds: 2)) {
                        lastPopTime = DateTime.now();
                        _futureGetLink(text);
                      } else {
                        lastPopTime = DateTime.now();
                      }
                    },
                    clear: () {
                      result = '';
                      _videoLink = '';
                    },
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Column(
                    children: <Widget>[
                      new Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        children: <Widget>[
                          NiceButton(
                            width: MediaQuery.of(context).size.width / 4,
                            elevation: 8.0,
                            radius: 52.0,
                            text: "下载",
                            fontSize: 12,
                            background: Color(0xff000000),
                            onPressed: () {
                              _startDownLoad();
                            },
                          ),
                          NiceButton(
                            width: MediaQuery.of(context).size.width / 4,
                            elevation: 8.0,
                            radius: 52.0,
                            text: "播放",
                            fontSize: 12,
                            background: Color(0xff000000),
                            onPressed: () {
                              _openRoute(
                                  page: new VideoScreen(url: _videoLink));
                            },
                          ),
                          NiceButton(
                            width: MediaQuery.of(context).size.width / 4,
                            elevation: 8.0,
                            radius: 52.0,
                            fontSize: 12,
                            text: "添加到待下载",
                            background: Color(0xff000000),
                            onPressed: () {
                              _addVideoToReadyDownload();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: new Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          height: 20,
                        ),
                        new Container(
                          child: Text(
                            '短视频去水印下载，支持 抖音、皮皮虾、火山、微视、微博、绿洲、最右、轻视频、ins、哔哩哔哩、快手、全民。',
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              showLoading ? LoginLoading() : Container()
            ],
          ),
        ),
      ),
    );
  }
}
