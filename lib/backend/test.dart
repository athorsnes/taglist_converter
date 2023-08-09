import 'dart:math';

import '../classes/tag.dart';

String xmlTagString(List<Tag> tags, bool isZeroBased) {
  String myXmlString = "<tags>\n\t";
  String xmlEnd = "</tags>";

  for (Tag tag in tags) {
    String tagname = tag.name;
    tagname = tagname.replaceAll('&', '&#38;');
    tagname = tagname.replaceAll('>', '&gt;');
    tagname = tagname.replaceAll('<', '&lt;');
    tagname = tagname.replaceAll('°', 'degrees');
    tagname = tagname.replaceAll('.', ',');

    tagname += " -${tag.functionCode}";
    String offset = isZeroBased
        ? (int.parse(tag.plcAddress) - 1).toString()
        : tag.plcAddress;
    String subindex = tag.bit.toString().isNotEmpty ? tag.bit : "";
    String comment = tag.functionGroup;
    String dataType = "";
    String memoryType = "";
    String readWriteAccess = "READ-WRITE";

    String maxVal = "";
    String minVal = "";

    switch (tag.functionGroup) {
      case "Command flag" || "Control command":
        readWriteAccess = "WRITE";
        break;
      case "Digital input" || "Digital output" || "Status flag":
        readWriteAccess = "READ";
        break;

      default:
        readWriteAccess = "READ-WRITE";
    }

    switch (tag.functionCode) {
      case "F01":
        memoryType = "OUTP";
        break;
      case "F02":
        memoryType = "INP";
        readWriteAccess = "READ";
        break;
      case "F03":
        memoryType = "HREG";
        break;
      case "F04":
        memoryType = "IREG";
        readWriteAccess = "READ";
        break;
      default:
    }

    switch (tag.dataType) {
      case "BOOL":
        dataType = "boolean";
        minVal = "0";
        maxVal = "1";
        break;
      case "INT8u" || "INT16u":
        dataType = "unsignedShort";
        minVal = "0";
        maxVal = "65535";
        break;
      case "INT16" || "INT16s":
        dataType = "short";
        minVal = "-32768";
        maxVal = "32767";
        break;

      case "INT32" || "INT32s":
        dataType = "int(swap4,swap2)";
        minVal = "-2.1e+9";
        maxVal = "2.1e+9";
        break;
      case "INT32u":
        dataType = "unsignedInt(swap4,swap2)";
        minVal = "0";
        maxVal = "4.2e+9";
        break;
      case "FLOAT":
        dataType = "float";
        minVal =
            "-3.40282e+38"; //1.17e-38 in AGI user manual -3.40282e+38 in AGI Creator
        maxVal = "3.40282e+38";
        break;
      // TODO(athorsnes): add data type "string"
    }
    String xml = '''<tag>
  <name>$tagname</name>
  <group></group>
  <resourceLocator>
    <protocolName>MODT</protocolName>
    <node_id></node_id>
    <memory_type>$memoryType</memory_type>
    <offset>$offset</offset>
    <subindex>$subindex</subindex>
    <data_type>$dataType</data_type>
    <arraysize></arraysize>
    <conversion></conversion>
  </resourceLocator>
  <encoding></encoding>
  <refreshTime>500</refreshTime>
  <accessMode>$readWriteAccess</accessMode>
  <active>false</active>
  <TAGLOCATOR></TAGLOCATOR>
  <comment>$comment</comment>
  <simulator>
    <DataSimulator>Variables</DataSimulator>
    <Amplitude></Amplitude>
    <Simulator_offset></Simulator_offset>
    <Period></Period>
  </simulator>
  <scaling>
    <enableScaling>false</enableScaling>
    <scalingType>byFormula</scalingType>
    <enableLimits>false</enableLimits>
    <factors>
      <s1>1</s1>
      <s2>1</s2>
      <s3>0</s3>
      <tagS1></tagS1>
      <tagS2></tagS2>
      <tagS3></tagS3>
    </factors>
    <limits>
      <eumin>0</eumin>
      <eumax>100</eumax>
      <elmin></elmin>
      <elmax></elmax>
    </limits>
  </scaling>
  <decimalDigits>
    <ddTag></ddTag>
    <ddDigits></ddDigits>
  </decimalDigits>
  <castType></castType>
  <default></default>
  <min>$minVal</min>
  <max>$maxVal</max>
  <statesText></statesText>
</tag>\n''';

    myXmlString += xml;
  }
  return myXmlString + xmlEnd;
}

String alarmStringXML(
    Map protocolPrefixes, List<Tag> tags, bool tagvalueInCustomField) {
  String myXmlString = "<alarms>\n\t";
  String xmlEnd = "</alarms>";
  for (var prefix in protocolPrefixes.entries) {
    int i = 0;
    for (Tag tag in tags.where((tag) =>
        tag.alarm.isActive && tag.controllerTypes.contains(prefix.value))) {
      String tagname = tag.name;
      if (prefix.key != "") {
        tagname = "${prefix.key}/${tag.name}";
      }

      tagname = tagname.replaceAll('&', '&#38;');
      tagname = tagname.replaceAll('>', '&gt;');
      tagname = tagname.replaceAll('<', '&lt;');
      tagname = tagname.replaceAll('°', 'degrees');
      tagname = tagname.replaceAll('.', ',');

      tagname += " -${tag.functionCode}";
      String alarmname = tagname.split('-F').first;
      String tagValue = "";
      if (tagvalueInCustomField) {
        tagValue = "[$tagname]";
      }
      //alarmname = alarmname.replaceAll(RegExp(r'[,./!?:"]'), '_');
      String alarmParameters = "";
      switch (tag.alarm.alarmType) {
        case "limitAlarm":
          alarmParameters = '''
  <lowLimit>${tag.alarm.minLimit}</lowLimit>
  <highLimit>${tag.alarm.maxLimit}</highLimit>
  ''';
          break;
        case "valueAlarm":
          alarmParameters = '''
  <value>${tag.alarm.value}</value>''';
          break;
        case "deviationAlarm":
          alarmParameters = '''
  <deviation>${tag.alarm.deviation}</deviation>
  <setPoint>${tag.alarm.setpoint}</setPoint>''';
          break;
        case "bitMaskAlarm":
          String bitMask = "";

          List bitPosList = tag.alarm.bitPositions.split(",");
          int bitMaskValue = 0;
          for (String bitPosition in bitPosList) {
            int posValue = pow(2, int.parse(bitPosition)).toInt();
            bitMaskValue += posValue;
          }
          bitMask = bitMaskValue.toRadixString(16);

          alarmParameters = '''
  <bitMask>$bitMask</bitMask>''';
          break;

        default:
          print("Alarm type not supported${tag.alarm.alarmType}");
      }

      String text = '''
<alarm eventBuffer="AlarmBuffer1" logToEventArchive="true" eventType="14" subType="1" storeAlarmInfo="true">
  <name>Alarm_${prefix.key}_$i</name>
  <groups></groups>
  <source>$tagname</source>
  <alarmType>${tag.alarm.alarmType}</alarmType>
  $alarmParameters
  <enableTag></enableTag>
  <remoteAck></remoteAck>
  <ackNotify></ackNotify>
  <enabled>true</enabled>
  <requireAck>false</requireAck>
  <blinkTxt>false</blinkTxt>
  <requireReset>false</requireReset>
  <severity>1</severity>
  <priority>3</priority>
  <logMask>76</logMask>
  <notifyMask>76</notifyMask>
  <actionMask>1</actionMask>
  <printMask>1</printMask>
  <customFields>
    <customField_1>
      <L1 langName="Lang1">$tagValue</L1>
    </customField_1>
    <customField_2>
      <L1 langName="Lang1">$alarmname</L1>
    </customField_2>
  </customFields>
  <colors>
    <ackTxtColor>#ff0000</ackTxtColor>
    <ackBgColor>#ffff00</ackBgColor>
    <disabledTxtColor>#000000</disabledTxtColor>
    <disabledBgColor>#ffffff</disabledBgColor>
    <triggeredTxtColor>#000000</triggeredTxtColor>
    <triggeredBgColor>#ffffff</triggeredBgColor>
    <notTriggeredTxtColor>#000000</notTriggeredTxtColor>
    <notTriggeredBgColor>#ffffff</notTriggeredBgColor>
    <triggeredAckedTxtColor>#000000</triggeredAckedTxtColor>
    <triggeredAckedBgColor>#ffffff</triggeredAckedBgColor>
    <triggeredNotAckedTxtColor>#000000</triggeredNotAckedTxtColor>
    <triggeredNotAckedBgColor>#ffffff</triggeredNotAckedBgColor>
    <notTriggeredAckedTxtColor>#000000</notTriggeredAckedTxtColor>
    <notTriggeredAckedBgColor>#ffffff</notTriggeredAckedBgColor>
    <notTriggeredNotAckedTxtColor>#000000</notTriggeredNotAckedTxtColor>
    <notTriggeredNotAckedBgColor>#ffffff</notTriggeredNotAckedBgColor>
  </colors>
  <actions>
    <macroAction1>
      <actionFunction>showDialog</actionFunction>
      <actionID>5</actionID>
      <actionType></actionType>
      <supportML>false</supportML>
      <parameters>alarm_alert.jmx</parameters>
    </macroAction1>
  </actions>
  <useractions/>
  <description>
    <L1 langName="Lang1"></L1>
  </description>
  <enableAudit auditBuff="" subT="1" eventT="18">false</enableAudit>
</alarm>
''';
      myXmlString += text;
      i++;
    }
  }

  return myXmlString + xmlEnd;
}
