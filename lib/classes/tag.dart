import 'alarm.dart';

class Tag {
  String name;
  String functionGroup;
  String plcAddress;
  String bit;
  String dataType;
  String functionCode;
  List controllerTypes;

  bool selected;
  bool visible;
  Alarm alarm;

  Tag(
      this.name,
      this.functionGroup,
      this.plcAddress,
      this.bit,
      this.dataType,
      this.functionCode,
      this.controllerTypes,
      this.selected,
      this.visible,
      this.alarm);

  Tag.fromJsonMap(Map json)
      : name = json["name"],
        functionGroup = json["functionGroup"],
        plcAddress = json["plcAddress"],
        bit = json["bit"],
        dataType = json["dataType"],
        functionCode = json["functionCode"],
        controllerTypes = json["controllerTypes"],
        selected = json["selected"],
        visible = json["visible"],
        alarm = Alarm.fromJsonMap(json["alarm"]);

  toJsonMap() {
    return {
      "name": name,
      "functionGroup": functionGroup,
      "plcAddress": plcAddress,
      "bit": bit,
      "dataType": dataType,
      "functionCode": functionCode,
      "controllerTypes": controllerTypes,
      "selected": selected,
      "visible": visible,
      "alarm": alarm.toJsonMap(),
    };
  }
}
