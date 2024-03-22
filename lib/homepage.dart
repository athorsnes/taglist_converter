import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as exc;
import 'package:taglist_converter/backend/test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'classes/alarm.dart';
import 'classes/tag.dart';
import 'widgets/alarm_editor.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:html' as webfile;

class HomePage extends StatefulWidget {
  final PackageInfo packageInfo;
  const HomePage({Key? key, required this.packageInfo}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //General variables
  final Map<String, String> deifLinks = {
    "AGC-4 MKII":
        "https://deif-cdn-umbraco.azureedge.net/media/shjn54mw/agc-4-mk-ii-modbus-tables-4189341272-uk.xlsx",
    "AGC-4":
        "https://deif-cdn-umbraco.azureedge.net/media/xywdqum0/agc-4-modbus-tables-4189341215-uk.xlsx",
    "ASC-4":
        "https://deif-cdn-umbraco.azureedge.net/media/va3b0mah/asc-4-modbus-server-tables-4189341284-uk.xlsx",
    "ALC-4":
        "https://deif-cdn-umbraco.azureedge.net/media/qyeogmjx/alc-4-modbus-tables-4189341283-uk.xlsx",
    "AGC 150":
        "https://deif-cdn-umbraco.azureedge.net/media/f2hiadel/agc-150-modbus-server-tables-4189341212-uk.xlsx",
    "ASC 150":
        "https://deif-cdn-umbraco.azureedge.net/media/qzbo5thj/asc-150-modbus-server-tables-4189341324-uk.xlsx",
    "PPM 300":
        "https://deif-cdn-umbraco.azureedge.net/media/zizlfabe/ppm-300-modbus-tables-4189341079-uk.xlsx",
    "PPU 300":
        "https://deif-cdn-umbraco.azureedge.net/media/wfcn3snq/ppu-300-modbus-tables-4189341101-uk.xlsx",
  };

  final Map<String, double> columns = {
    "Function group": 180.0,
    "PLC address": 130.0,
    "Bit": 60.0,
    "Controller function name": 400.0,
    "Data type": 130.0,
    "Alarm": 420.0,
  };

  List<Tag> tags = [];
  Map filterValues = {
    "Function groups": [],
    "Data types": [],
  };

  Map<String, String> protocolPrefixes = {};

  final List possibleControllerTypes = [
    "DG",
    "SG",
    "SC",
    "BTB",
    "EDG",
    "Hybrid",
    "MAINS",
    "GEN",
    "GEN-H",
    "GEN-M",
    "ENG",
    "ENG-M",
    "SOLAR",
    "BATT",
    "ATS",
    "_1",
  ];

  List detectedControllerTypes = [];
  String activeController = "";
  bool tagListLoaded = false;

  //Filters and search variables
  bool searchActive = false;
  String searchString = "";
  String dataTypeFilter = "";
  String functionGroupFilter = "";

  //Setting variables
  bool zeroBased = false;
  bool tagvalueInCustomField = false;

  //Copy alarm variables
  Alarm alarmToCopy = Alarm.empty();
  bool alarmIsCopied = false;

  void _resetFiltersAndSearch() {
    searchString = "";
    dataTypeFilter = "";
    functionGroupFilter = "";
  }

  void _closeCurrentSetup() {
    detectedControllerTypes = [];
    activeController = "";
    tags = [];
    filterValues = {
      "Function groups": [],
      "Data types": [],
    };
    protocolPrefixes = {};
    tagListLoaded = false;
    _resetFiltersAndSearch();
    setState(() {});
  }

  void _readFromExcel(var bytes) {
    _closeCurrentSetup();
    //Uint8List bytes = File(path).readAsBytesSync();
    exc.Excel excel = exc.Excel.decodeBytes(bytes);
    List<exc.Sheet> sheets = excel.tables.values.toList()..removeAt(0);

    for (var sheet in sheets) {
      //Remove header rows
      sheet.removeRow(0);
      sheet.removeRow(0);
      sheet.removeRow(0);
      //Clean up empty rows at the end that appear when deleting header rows
      sheet.removeRow(sheet.maxRows - 1);
      sheet.removeRow(sheet.maxRows - 1);
      sheet.removeRow(sheet.maxRows - 1);
    }

    //Convert sheets to maps
    Map discreteOutputMap = createMapFromSheet(sheets[0]);
    Map discreteInputMap = createMapFromSheet(sheets[1]);
    Map holdingRegisterMap = createMapFromSheet(sheets[2]);
    Map inputRegisterMap = createMapFromSheet(sheets[3]);

    detectedControllerTypes = [];
    for (String element in discreteInputMap.keys) {
      if (possibleControllerTypes.contains(element)) {
        detectedControllerTypes.add(element);
      }
    }

    if (detectedControllerTypes.isNotEmpty) {
      activeController = detectedControllerTypes.first;
      for (String controller in detectedControllerTypes) {
        protocolPrefixes["${controller}1"] = controller;
      }
    }

    //Add function code
    discreteOutputMap["Function code"] =
        List.filled(discreteOutputMap["PLC address"]!.length, "F01");
    discreteInputMap["Function code"] =
        List.filled(discreteInputMap["PLC address"]!.length, "F02");
    holdingRegisterMap["Function code"] =
        List.filled(holdingRegisterMap["PLC address"]!.length, "F03");
    inputRegisterMap["Function code"] =
        List.filled(inputRegisterMap["PLC address"]!.length, "F04");

    //Add data type to INP ond OUTP
    discreteOutputMap["Data type"] =
        List.filled(discreteOutputMap["PLC address"]!.length, "BOOL");
    discreteInputMap["Data type"] =
        List.filled(discreteInputMap["PLC address"]!.length, "BOOL");
    //Add bit to INP and OUTP (just for formatting)
    discreteOutputMap["Bit"] =
        List.filled(discreteOutputMap["PLC address"]!.length, "");
    discreteInputMap["Bit"] =
        List.filled(discreteInputMap["PLC address"]!.length, "");

    tags.addAll(sheetmapToTags(discreteInputMap, detectedControllerTypes));
    tags.addAll(sheetmapToTags(discreteOutputMap, detectedControllerTypes));
    tags.addAll(sheetmapToTags(holdingRegisterMap, detectedControllerTypes));
    tags.addAll(sheetmapToTags(inputRegisterMap, detectedControllerTypes));

    for (var tag in tags) {
      if (!filterValues["Function groups"].contains(tag.functionGroup)) {
        filterValues["Function groups"].add(tag.functionGroup);
      }

      if (!filterValues["Data types"].contains(tag.dataType)) {
        filterValues["Data types"].add(tag.dataType);
      }
    }
    tagListLoaded = true;
    setState(() {});
  }

  Future<bool> _saveAsJson() async {
    String outputName = "mySetup.json";
    List jsonTags = [];
    for (Tag tag in tags) {
      jsonTags.add(tag.toJsonMap());
    }
    Map finalMap = {
      "Detected controllers": detectedControllerTypes,
      "Filter values": filterValues,
      "Tags": jsonTags,
    };
    var blob = webfile.Blob([jsonEncode(finalMap)], 'xml', 'native');

    webfile.AnchorElement(
      href: webfile.Url.createObjectUrlFromBlob(blob).toString(),
    )
      ..setAttribute("download", outputName)
      ..click();

    return false;
  }

  Future<void> _readFromJson(var bytes) async {
    _closeCurrentSetup();
    //var bytes = File(path).readAsBytesSync();
    String jsonString = String.fromCharCodes(bytes);
    Map jsonMap = jsonDecode(jsonString);

    detectedControllerTypes = jsonMap["Detected controllers"];
    filterValues = jsonMap["Filter values"];
    for (var element in jsonMap["Tags"]) {
      Tag tag = Tag.fromJsonMap(element);
      tags.add(tag);
    }

    activeController = detectedControllerTypes[0];
    tagListLoaded = true;
    setState(() {});
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      if (result.files.first.extension == "xlsx") {
        _readFromExcel(result.files.first.bytes);
      } else if (result.files.first.extension == "json") {
        _readFromJson(result.files.first.bytes);
      }
    }
  }

  Future<void> _exportToTaglist(String controller) async {
    String outputName = "taglist_${controller}.xml";
    var blob = webfile.Blob([
      xmlTagString(
          List<Tag>.from(tags.where((tag) =>
              tag.selected && tag.controllerTypes.contains(controller))),
          zeroBased)
    ], 'xml', 'native');

    webfile.AnchorElement(
      href: webfile.Url.createObjectUrlFromBlob(blob).toString(),
    )
      ..setAttribute("download", outputName)
      ..click();
  }

  Future<void> _exportToAlarmList() async {
    String outputName = "Alarmlist_${protocolPrefixes.keys.toString()}.xml";
    var blob = webfile.Blob([
      alarmStringXML(
          protocolPrefixes,
          List<Tag>.from(tags.where((tag) => tag.selected)),
          tagvalueInCustomField)
    ], 'xml', 'native');

    webfile.AnchorElement(
      href: webfile.Url.createObjectUrlFromBlob(blob).toString(),
    )
      ..setAttribute("download", outputName)
      ..click();
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  void _showFilterMenu(entrykey, entryValue, TapDownDetails details) {
    //Should be loaded when list is read
    List filterList = [];
    if (entrykey == "Function group") {
      filterList.addAll(filterValues["Function groups"]);
    } else if (entrykey == "Data type") {
      filterList.addAll(filterValues["Data types"]);
    }
    filterList = filterList.toSet().toList()..insert(0, "Show all");
    if (filterList.isEmpty) {
      return;
    }
    showMenu(
            context: context,
            position: RelativeRect.fromLTRB(
                details.globalPosition.dx,
                details.globalPosition.dy,
                details.globalPosition.dx,
                details.globalPosition.dy),
            items: filterList.map((e) {
              return PopupMenuItem(
                  value: e, child: Text(e != null ? e.toString() : ""));
            }).toList())
        .then((value) {
      if (value != null) {
        if (value == "Show all") {
          if (entrykey == "Data type") {
            dataTypeFilter = "";
          } else if (entrykey == "Function group") {
            functionGroupFilter = "";
          }
          setState(() {});
          return;
        }

        if (entrykey == "Data type") {
          dataTypeFilter = value.toString();
        } else if (entrykey == "Function group") {
          functionGroupFilter = value.toString();
        }
        setState(() {});
      } else {
        return;
      }
    });
  }

  void _selectAllVisible(List<Tag> visibleTags) {
    for (var i = 0; i < visibleTags.length; i++) {
      visibleTags[i].selected = true;
    }
    setState(() {});
  }

  void _deselectAllVisible(List<Tag> visibleTags) {
    for (var i = 0; i < visibleTags.length; i++) {
      visibleTags[i].selected = false;
    }
    setState(() {});
  }

  void _addAlarmToVisible(List<Tag> visibleTags) {
    for (var i = 0; i < visibleTags.length; i++) {
      visibleTags[i].alarm.isActive = true;
    }
    setState(() {});
  }

  void _removeAlarmFromVisible(List<Tag> visibleTags) {
    for (var i = 0; i < visibleTags.length; i++) {
      visibleTags[i].alarm.isActive = false;
    }
    setState(() {});
  }

  //ExpansionTileController searchExpanseController = ExpansionTileController();

  @override
  Widget build(BuildContext context) {
    List<Tag> visibleTags = tags;

    visibleTags = visibleTags
        .where((element) => element.controllerTypes.contains(activeController))
        .toList();

    if (dataTypeFilter != "") {
      visibleTags = visibleTags
          .where((element) => element.dataType == dataTypeFilter)
          .toList();
    }
    if (functionGroupFilter != "") {
      visibleTags = visibleTags
          .where((element) => element.functionGroup == functionGroupFilter)
          .toList();
    }
    if (searchString != "") {
      visibleTags = visibleTags
          .where((element) =>
              element.name.toLowerCase().contains(searchString.toLowerCase()))
          .toList();
    }

    return Scaffold(
      drawer: Drawer(
        child: ListView(children: [
          ExpansionTile(
            title: const Text("File"),
            children: [
              ListTile(
                dense: true,
                onTap: () => _openFile(),
                title: const Text("Open file (xlsx or json)"),
              ),
              ListTile(
                dense: true,
                onTap: tagListLoaded ? () => _saveAsJson() : null,
                title: const Text("Save as json"),
              ),
              ListTile(
                dense: true,
                onTap: tagListLoaded ? () => _closeCurrentSetup() : null,
                title: const Text("Close"),
              ),
            ],
          ),
          const Divider(
            height: 2,
          ),
          ExpansionTile(
            title: const Text("Settings"),
            children: [
              ListTile(
                dense: true,
                title: const Text(
                  "Zero-based",
                  //style: TextStyle(fontSize: 14),
                ),
                trailing: Switch(
                    value: zeroBased,
                    onChanged: (value) => setState(() => zeroBased = value)),
              ),
              ListTile(
                dense: true,
                title: const Text(
                  "Value of tag in Custom Field 2 (Alarms)",
                  // style: TextStyle(fontSize: 14),
                ),
                trailing: Switch(
                    value: tagvalueInCustomField,
                    onChanged: (value) =>
                        setState(() => tagvalueInCustomField = value)),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text("Export"),
            children: [
              ...tags.where((element) => element.selected).isNotEmpty
                  ? [
                      const ListTile(title: Text("Create tags for")),
                      for (String controller in detectedControllerTypes)
                        TextButton(
                            onPressed: () => _exportToTaglist(controller),
                            child: Text(controller)),
                      ...[
                        const ListTile(title: Text("Create alarms for")),
                        for (var entry in protocolPrefixes.entries)
                          ListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key),
                                DropdownButton<String>(
                                  isDense: true,
                                  padding: EdgeInsets.zero,
                                  value: entry.value,
                                  onChanged: (value) {
                                    FocusScope.of(context).unfocus();
                                    protocolPrefixes[entry.key] = value!;
                                    setState(() {});
                                  },
                                  items: [
                                    for (String controller
                                        in detectedControllerTypes)
                                      DropdownMenuItem(
                                        value: controller,
                                        child: Text(controller),
                                      ),
                                  ],
                                ),
                                IconButton(
                                    onPressed: () {
                                      protocolPrefixes.remove(entry.key);
                                      setState(() {});
                                      //update();
                                    },
                                    icon: const Icon(Icons.remove))
                              ],
                            ),
                          ),
                        ListTile(
                          title: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                  width: 200,
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                        helperText: "Press enter to add",
                                        labelText: "New prefix"),
                                    onFieldSubmitted: (value) {
                                      protocolPrefixes[value] =
                                          detectedControllerTypes.first;
                                      setState(() {});

                                      //update();
                                    },
                                  )),
                            ],
                          ),
                        ),
                        TextButton(
                            onPressed: () => _exportToAlarmList(),
                            child: const Text("Create alarm list"))
                      ]
                    ]
                  : [const Text("Select some tags first")]
            ],
          ),
          ExpansionTile(
            title: const Text("About"),
            children: [
              Text(widget.packageInfo.appName),
              Text(widget.packageInfo.version),
              TextButton(
                  onPressed: () => _launchUrl(
                      "https://github.com/athorsnes/taglist_converter#taglist_converter"),
                  child: const Text("Readme on github"))
            ],
          )
        ]),
      ),
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        //toolbarHeight: 40,
        title: Row(children: [
          const Text(
            "Taglist converter",
          ),
          Text(
            " BETA ${widget.packageInfo.version}",
            style: const TextStyle(fontSize: 12),
          ),
          Expanded(child: Container()),
          ...tagListLoaded
              ? {
                  ["Select all", Icons.check_box]: _selectAllVisible,
                  ["Deselect all", Icons.check_box_outline_blank]:
                      _deselectAllVisible,
                  ["Add alarm to all", Icons.notification_add]:
                      _addAlarmToVisible,
                  ["Remove alarm from all", Icons.notifications_off]:
                      _removeAlarmFromVisible,
                }
                  .entries
                  .map((e) => DecoratedBox(
                        decoration: const BoxDecoration(
                          border: Border(
                              right: BorderSide(width: 1, color: Colors.white)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 5, right: 5),
                          child: IconButton(
                              tooltip: e.key[0] as String,
                              onPressed: () => e.value(visibleTags),
                              icon: Icon(e.key[1] as IconData)),
                        ),
                      ))
                  .toList()
              : [],
        ]),
      ),
      body: !tagListLoaded
          ? Column(
              children: [
                Expanded(
                  flex: 8,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Tooltip(
                          message: "Open file",
                          child: TextButton(
                              onPressed: () => _openFile(),
                              child: const Icon(
                                Icons.file_open,
                                size: 48,
                              )),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        const Text(
                            "Start by opening a DEIF modbuslist in xlsx format, or a previously saved setup in json format."),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      const Text(
                          "If you dont have a modbuslist, you can get them here:"),
                      Wrap(
                        children: deifLinks.entries.map((e) {
                          return Tooltip(
                            message: e.value,
                            child: TextButton(
                                onPressed: () => _launchUrl(e.value),
                                child: Text(e.key)),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                )
              ],
            )
          : Column(
              children: [
                ListTile(
                  //dense: true,
                  title: Row(children: [
                    const Text("Controller type: "),
                    ...detectedControllerTypes
                        .map((e) => TextButton(
                            onPressed: () => setState(() {
                                  activeController = e;
                                }),
                            child: Text(e,
                                style: e == activeController
                                    ? const TextStyle(
                                        decoration: TextDecoration.underline)
                                    : null)))
                        .toList(),
                  ]),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.black),
                          bottom: BorderSide(color: Colors.black))),
                  child: ListTile(
                    //dense: true,
                    subtitle: searchActive
                        ? ListTile(
                            //dense: true,
                            leading: IconButton(
                                onPressed: () => setState(() {
                                      searchActive = false;
                                      searchString = "";
                                      setState(() {});
                                    }),
                                icon: const Icon(Icons.close)),
                            title: TextField(
                                autofocus: true,
                                onChanged: (value) {
                                  searchString = value;
                                  setState(() {});
                                }),
                          )
                        : null,

                    title: Row(
                      //mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ...columns.entries.map((entry) {
                          Widget sizedBox = SizedBox(
                            width: columns[entry.key],
                            //height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.transparent)),
                              child: Row(

                                  //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(entry.key),
                                    switch (entry.key) {
                                      "Function group" => GestureDetector(
                                          onTapDown: (details) =>
                                              _showFilterMenu(entry.key,
                                                  entry.value, details),
                                          child: Icon(Icons.filter_list,
                                              color: functionGroupFilter != ""
                                                  ? Colors.green
                                                  : null)),
                                      "Data type" => GestureDetector(
                                          onTapDown: (details) =>
                                              _showFilterMenu(entry.key,
                                                  entry.value, details),
                                          child: Icon(Icons.filter_list,
                                              color: dataTypeFilter != ""
                                                  ? Colors.green
                                                  : null)),
                                      "Controller function name" => IconButton(
                                          onPressed: () => setState(() {
                                                searchActive = true;
                                              }),
                                          icon: const Icon(Icons.search)),
                                      String() => const SizedBox.shrink(),
                                    }
                                  ]),
                            ),
                          );
                          return sizedBox;
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: visibleTags.length,
                    itemExtent: 64,
                    itemBuilder: (context, index) {
                      return Card(
                        color: visibleTags[index].selected
                            ? Colors.green[100]
                            : Colors.white,
                        child: ListTile(
                          dense: true,
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                  width: columns["Function group"],
                                  child:
                                      Text(visibleTags[index].functionGroup)),
                              SizedBox(
                                  width: columns["PLC address"],
                                  child: Text(visibleTags[index].plcAddress)),
                              SizedBox(
                                  width: columns["Bit"],
                                  child: Text(visibleTags[index].bit)),
                              SizedBox(
                                  width: columns["Controller function name"],
                                  child: Text(visibleTags[index].name)),
                              SizedBox(
                                  width: columns["Data type"],
                                  child: Text(visibleTags[index].dataType)),
                              SizedBox(
                                width: columns["Alarm"],
                                child: Row(
                                  children: [
                                    IconButton(
                                        onPressed: () {
                                          visibleTags[index].alarm.isActive =
                                              !visibleTags[index]
                                                  .alarm
                                                  .isActive;
                                          setState(() {});
                                        },
                                        icon: visibleTags[index].alarm.isActive
                                            ? const Icon(
                                                Icons.notifications_active,
                                                color: Colors.red)
                                            : const Icon(
                                                Icons.notification_add)),
                                    visibleTags[index].alarm.isActive
                                        ? AlarmEditor(
                                            tag: visibleTags[index],
                                            onCopyToAll: (value) {
                                              for (var tag in visibleTags) {
                                                tag.alarm =
                                                    Alarm.fromOther(value);
                                              }
                                              setState(() {});
                                            },
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                              /*
                              alarmIsCopied
                                  ? SizedBox(
                                      width: columns["Selected"],
                                      child: IconButton(
                                        icon: Icon(Icons.paste),
                                        onPressed: () => setState(() {
                                          visibleTags[index].alarm =
                                              Alarm.fromOther(alarmToCopy);
                                          //alarmIsCopied = false;
                                        }),
                                      ))
                                  : SizedBox.shrink()*/
                            ],
                          ),
                          onTap: () {
                            visibleTags[index].selected =
                                !visibleTags[index].selected;

                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.black))),
                  //bottom: BorderSide(color: Colors.black)))
                  child: ListTile(
                    dense: true,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: {
                        "Selected tags":
                            tags.where((element) => element.selected).length,
                        "Selected tags with alarm": tags
                            .where((element) =>
                                element.selected && element.alarm.isActive)
                            .length,
                        "Tags in current view": visibleTags.length,
                        "Current filters":
                            "$functionGroupFilter $dataTypeFilter"
                      }
                          .entries
                          .map((e) => Text("${e.key}: ${e.value}"))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

Map createMapFromSheet(exc.Sheet sheet) {
  Map sheetMap = {};
  for (var i = 0; i < sheet.maxColumns; i++) {
    sheetMap[sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .value
        .toString()] = sheet.rows.map((e) => e[i]?.value.toString()).toList()
      ..removeAt(0);
  }
  return sheetMap;
}

List<Tag> sheetmapToTags(Map sheetmap, List detectedControllerTypes) {
  List<Tag> tags = [];
  for (var i = 0; i < sheetmap.values.first.length; i++) {
    List<String> controllers = [];
    for (String element in detectedControllerTypes) {
      if (sheetmap[element]![i] == "X") {
        controllers.add(element);
      }
    }
    tags.add(Tag(
        sheetmap["Controller function name"][i],
        sheetmap["Function group"][i],
        sheetmap["PLC address"][i],
        sheetmap["Bit"][i],
        sheetmap["Data type"][i],
        sheetmap["Function code"][i],
        controllers,
        false,
        false,
        Alarm.empty()));
  }
  return tags;
}
