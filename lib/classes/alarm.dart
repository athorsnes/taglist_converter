class Alarm {
  bool isActive;
  String alarmType; //limitAlarm, bitMaskAlarm, deviationAlarm, valueAlarm
  double minLimit;
  double maxLimit;
  String bitPositions; // ex "0,1,4,19"
  double deviation;
  double setpoint;
  double value;

  Alarm(this.isActive, this.alarmType, this.minLimit, this.maxLimit,
      this.bitPositions, this.deviation, this.setpoint, this.value);
  Alarm.empty()
      : isActive = false,
        alarmType = "limitAlarm",
        minLimit = 0,
        maxLimit = 0,
        bitPositions = "",
        deviation = 0,
        setpoint = 0,
        value = 0;

  Alarm.fromJsonMap(Map json)
      : isActive = json["isActive"],
        alarmType = json["alarmType"],
        minLimit = json["minLimit"],
        maxLimit = json["maxLimit"],
        bitPositions = json["bitPositions"],
        deviation = json["deviation"],
        setpoint = json["setpoint"],
        value = json["value"];

  Alarm.fromOther(Alarm other)
      : isActive = other.isActive,
        alarmType = other.alarmType,
        minLimit = other.minLimit,
        maxLimit = other.maxLimit,
        bitPositions = other.bitPositions,
        deviation = other.deviation,
        setpoint = other.setpoint,
        value = other.value;

  toJsonMap() {
    return {
      "isActive": isActive,
      "alarmType": alarmType,
      "minLimit": minLimit,
      "maxLimit": maxLimit,
      "bitPositions": bitPositions,
      "deviation": deviation,
      "setpoint": setpoint,
      "value": value,
    };
  }
}
