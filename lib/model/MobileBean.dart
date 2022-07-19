class MobileBean {
  String code;
  String tel;
  String local;
  String duan;
  String type;
  String yys;
  String bz;

  MobileBean(
      {this.code,
      this.tel,
      this.local,
      this.duan,
      this.type,
      this.yys,
      this.bz});

  MobileBean.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    tel = json['tel'];
    local = json['local'];
    duan = json['duan'];
    type = json['type'];
    yys = json['yys'];
    bz = json['bz'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    data['tel'] = this.tel;
    data['local'] = this.local;
    data['duan'] = this.duan;
    data['type'] = this.type;
    data['yys'] = this.yys;
    data['bz'] = this.bz;
    return data;
  }
}
