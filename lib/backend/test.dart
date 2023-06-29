//add subindex

String xmlString(Map<String, List> map, bool isZeroBased) {
  String myXmlString = "<tags>\n\t";
  String xmlEnd = "</tags>";
  for (var i = 0; i < map["Controller function name"]!.length; i++) {
    String tagname = map["Controller function name"]![i];
    tagname = tagname.replaceAll('>', '&gt;');
    tagname = tagname.replaceAll('<', '&lt;');
    tagname = tagname.replaceAll('°', 'degrees');
    tagname = tagname.replaceAll('.', ',');
    tagname = tagname.replaceAll('&', '&#38;');
    tagname += " -${map["Function code"]![i]}";
    String offset = isZeroBased
        ? (int.parse(map["PLC address"]![i]) - 1).toString()
        : map["PLC address"]![i];
    String subindex =
        map["Bit"]![i].toString().isNotEmpty ? map["Bit"]![i] : "";
    String comment = map["Function group"]![i];
    String dataType = "";
    String memoryType = "";
    String readWriteAccess = "READ-WRITE";

    String maxVal = "";
    String minVal = "";

    switch (map["Function group"]![i]) {
      case "Command flag" || "Control command":
        readWriteAccess = "WRITE";
        break;
      case "Digital input" || "Digital output" || "Status flag":
        readWriteAccess = "READ";
        break;

      default:
        readWriteAccess = "READ-WRITE";
    }

    switch (map["Function code"]![i]) {
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

    switch (map["Data type"]![i]) {
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
        dataType = "int";
        minVal = "-2.1e+9";
        maxVal = "2.1e+9";
        break;
      case "INT32u":
        dataType = "unsignedInt";
        minVal = "0";
        maxVal = "4.2e+9";
        break;
      case "FLOAT":
        dataType = "float";
        minVal =
            "-3.40282e+38"; //1.17e-38 in AGI user manual -3.40282e+38 in AGI Creator
        maxVal = "3.40282e+38";
        break;
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
  myXmlString += xmlEnd;
  return myXmlString;
}
