import 'dart:async';
import 'dart:convert';

import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:parse_video/model/WeatherBean.dart';
import 'package:parse_video/plugin/httpManage.dart';
import 'package:permission_handler/permission_handler.dart';

class WeatherPage extends StatefulWidget {
  @override
  _WeatherPageState createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  Map<String, Object> _locationResult;

  StreamSubscription<Map<String, Object>> _locationListener;

  AMapFlutterLocation _locationPlugin = new AMapFlutterLocation();

  WeatherBean _weatherBean;

  int _currentIndex;

  @override
  void initState() {
    /// 设置是否已经包含高德隐私政策并弹窗展示显示用户查看，如果未包含或者没有弹窗展示，高德定位SDK将不会工作
    ///
    /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy
    /// <b>必须保证在调用定位功能之前调用， 建议首次启动App时弹出《隐私政策》并取得用户同意</b>
    ///
    /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy
    ///
    /// [hasContains] 隐私声明中是否包含高德隐私政策说明
    ///
    /// [hasShow] 隐私权政策是否弹窗展示告知用户
    AMapFlutterLocation.updatePrivacyShow(true, true);

    /// 设置是否已经取得用户同意，如果未取得用户同意，高德定位SDK将不会工作
    ///
    /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy
    ///
    /// <b>必须保证在调用定位功能之前调用, 建议首次启动App时弹出《隐私政策》并取得用户同意</b>
    ///
    /// [hasAgree] 隐私权政策是否已经取得用户同意
    AMapFlutterLocation.updatePrivacyAgree(true);
    AMapFlutterLocation.setApiKey(
        "326cd188175c1a0fca02013dd187713c", "ios ApiKey");

    /// 动态申请定位权限
    requestPermission();

    ///注册定位结果监听
    _locationListener = _locationPlugin
        .onLocationChanged()
        .listen(onData, onError: onError, onDone: onDone);

    _startLocation();
    super.initState();
  }

  ///开始定位
  void _startLocation() {
    if (null != _locationPlugin) {
      ///开始定位之前设置定位参数
      _setLocationOption();
      _locationPlugin.startLocation();
    }
  }

  ///设置定位参数
  void _setLocationOption() {
    if (null != _locationPlugin) {
      AMapLocationOption locationOption = new AMapLocationOption();

      ///是否单次定位
      locationOption.onceLocation = false;

      ///是否需要返回逆地理信息
      locationOption.needAddress = true;

      ///逆地理信息的语言类型
      locationOption.geoLanguage = GeoLanguage.DEFAULT;

      locationOption.desiredLocationAccuracyAuthorizationMode =
          AMapLocationAccuracyAuthorizationMode.ReduceAccuracy;

      locationOption.fullAccuracyPurposeKey = "AMapLocationScene";

      ///设置Android端连续定位的定位间隔
      locationOption.locationInterval = 1000 * 60;

      ///设置Android端的定位模式<br>
      ///可选值：<br>
      ///<li>[AMapLocationMode.Battery_Saving]</li>
      ///<li>[AMapLocationMode.Device_Sensors]</li>
      ///<li>[AMapLocationMode.Hight_Accuracy]</li>
      locationOption.locationMode = AMapLocationMode.Hight_Accuracy;

      ///设置iOS端的定位最小更新距离<br>
      locationOption.distanceFilter = -1;

      ///设置iOS端期望的定位精度
      /// 可选值：<br>
      /// <li>[DesiredAccuracy.Best] 最高精度</li>
      /// <li>[DesiredAccuracy.BestForNavigation] 适用于导航场景的高精度 </li>
      /// <li>[DesiredAccuracy.NearestTenMeters] 10米 </li>
      /// <li>[DesiredAccuracy.Kilometer] 1000米</li>
      /// <li>[DesiredAccuracy.ThreeKilometers] 3000米</li>
      locationOption.desiredAccuracy = DesiredAccuracy.Best;

      ///设置iOS端是否允许系统暂停定位
      locationOption.pausesLocationUpdatesAutomatically = false;

      ///将定位参数设置给定位插件
      _locationPlugin.setLocationOption(locationOption);
    }
  }

  void onData(Map<String, Object> result) {
    print("定位成功---------------->");
    print(result);
    setState(() {
      _locationResult = result;
    });
    getWeather();
  }

  onError(error) {
    print("定位失败---------------->");
    print(error);
  }

  onDone() {
    print("定位onDone---------------->");
  }

  /// 动态申请定位权限
  void requestPermission() async {
    // 申请权限
    bool hasLocationPermission = await requestLocationPermission();
    if (hasLocationPermission) {
      print("定位权限申请通过");
    } else {
      print("定位权限申请不通过");
    }
  }

  /// 申请定位权限
  /// 授予定位权限返回true， 否则返回false
  Future<bool> requestLocationPermission() async {
    //获取当前的权限
    var status = await Permission.location.status;
    if (status == PermissionStatus.granted) {
      //已经授权
      return true;
    } else {
      //未授权则发起一次申请
      status = await Permission.location.request();
      if (status == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }

  Future<void> getWeather() async {
    final Response response = await HttpManager()
        .get('wether/', data: {'city': _locationResult["city"]});

    if (response != null) {
      print('request success 手机号码数据：' + response.toString());
      Map mobileMap = json.decode(response.toString());
      var m = new WeatherBean.fromJson(mobileMap);
      if (m.status == 1000) {
        setState(() {
          _weatherBean = m;
        });
      }
    }
  }

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
        child: Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                    children: _weatherBean != null
                        ? [
                            Text(_weatherBean.data.city,
                                style: TextStyle(fontSize: 30)),
                            Text("7天城市天气预报"),
                            SizedBox(
                              height: 200,
                              child: PageView(
                                controller:
                                    PageController(viewportFraction: 0.9),
                                onPageChanged: (int index) {
                                  setState(() {
                                    _currentIndex = index;
                                  });
                                },
                                children: List.generate(
                                    _weatherBean.data.forecast.length,
                                    (index) => Container(
                                          child: Column(
                                            children: [
                                              Text(
                                                  '日期: ${_weatherBean.data.forecast[index].date}'),
                                              Text(
                                                  '温度: ${_weatherBean.data.forecast[index].high}'),
                                              Text(
                                                  '低温: ${_weatherBean.data.forecast[index].low}'),
                                              Text(
                                                  '风力: ${_weatherBean.data.forecast[index].fengli}'),
                                              Text(
                                                  '风向: ${_weatherBean.data.forecast[index].fengxiang}'),
                                              Text(
                                                  ' ${_weatherBean.data.forecast[index].type}'),
                                            ],
                                          ),
                                          decoration: BoxDecoration(
                                              color: Colors.grey,
                                              borderRadius:
                                                  BorderRadius.circular(10.0)),
                                        )),
                              ),
                            )
                          ]
                        : [Container()]),
              )
            ],
          ),
        ));
  }

  @override
  void dispose() {
    super.dispose();

    ///移除定位监听
    if (null != _locationListener) {
      _locationListener.cancel();
    }

    ///销毁定位
    if (null != _locationPlugin) {
      _locationPlugin.destroy();
    }
  }
}
