String xmlString(Map<String, List> map) {
  String myXmlString = "<tags>\n\t";
  String xmlEnd = "</tags>";
  for (var i = 0; i < map["Controller function name"]!.length; i++) {
    String tagname = map["Controller function name"]![i];
    String offset = map["PLC address"]![i];
    String comment = map["Function group"]![i];
    String dataType = "";
    String memoryType = "";

    switch (map["Function code"]![i]) {
      case "F01":
        memoryType = "OUTP";
        dataType = "boolean";
        break;
      case "F02":
        memoryType = "INP";
        dataType = "boolean";
        break;
      case "F03":
        memoryType = "HREG";
        dataType = "short";
        break;
      case "F04":
        memoryType = "IREG";
        dataType = "short";
        break;
      default:
    }
    String xml = '''<tag>
  <name>$tagname</name>
  <group></group>
  <resourceLocator>
    <protocolName>MODT</protocolName>
    <node_id></node_id>
    <memory_type>$memoryType</memory_type>
    <offset>$offset</offset>
    <subindex></subindex>
    <data_type>$dataType</data_type>
    <arraysize></arraysize>
    <conversion></conversion>
  </resourceLocator>
  <encoding></encoding>
  <refreshTime>500</refreshTime>
  <accessMode>READ-WRITE</accessMode>
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
  <min>0</min>
  <max>1</max>
  <statesText></statesText>
</tag>\n''';

    myXmlString += xml;
  }
  myXmlString += xmlEnd;
  return myXmlString;
}
