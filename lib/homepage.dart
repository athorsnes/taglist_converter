import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as exc;
import 'package:flutter/services.dart';
import 'package:taglist_converter/backend/test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'classes/alarm.dart';
import 'classes/tag.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  List<Tag> tags = [];
  List functionGroups = [];
  List dataTypes = [];
  Map filterValues = {
    "Function groups": [],
    "Data types": [],
  };

  Alarm alarmToCopy = Alarm.empty();
  bool alarmIsCopied = false;
  Map<String, String> protocolPrefixes = {};

  Map<String, double> columns = {
    "Function group": 180.0,
    "PLC address": 130.0,
    "Bit": 60.0,
    "Controller function name": 400.0,
    "Data type": 130.0,
    "Alarm": 420.0,
  };

  List possibleControllerTypes = [
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
    "_1",
  ];
  List detectedControllerTypes = [];
  String activeController = "";
  bool zeroBased = false;
  bool searchActive = false;

  bool listLoaded = false;

  String searchString = "";
  String dataTypeFilter = "";
  String functionGroupFilter = "";

  void _resetFiltersAndSearch() {
    searchString = "";
    dataTypeFilter = "";
    functionGroupFilter = "";
  }

  void _closeCurrentSetup() {
    detectedControllerTypes = [];
    activeController = "";
    tags = [];
    functionGroups = [];
    dataTypes = [];
    filterValues = {
      "Function groups": [],
      "Data types": [],
    };
    protocolPrefixes = {};
    listLoaded = false;
    _resetFiltersAndSearch();
    setState(() {});
  }

  void _toggleZeroOneBased() {
    zeroBased = !zeroBased;
    setState(() {});
  }

  void _readFromExcel(String path) {
    _closeCurrentSetup();
    Uint8List bytes = File(path).readAsBytesSync();
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
    listLoaded = true;
    setState(() {});
  }

  Future<bool> _saveAsJson() async {
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null) {
      File file = File("$result.json");
      List jsonTags = [];
      for (Tag tag in tags) {
        jsonTags.add(tag.toJsonMap());
      }
      Map finalMap = {
        "Detected controllers": detectedControllerTypes,
        "Filter values": filterValues,
        "Tags": jsonTags,
      };
      try {
        file.writeAsString(jsonEncode(finalMap));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Setup saved")));
        return true;
      } catch (e) {
        print(e);
        return false;
      }
    }
    return false;
  }

  Future<void> _readFromJson(String path) async {
    _closeCurrentSetup();
    var bytes = File(path).readAsBytesSync();
    String jsonString = String.fromCharCodes(bytes);
    Map jsonMap = jsonDecode(jsonString);

    detectedControllerTypes = jsonMap["Detected controllers"];
    filterValues = jsonMap["Filter values"];
    for (var element in jsonMap["Tags"]) {
      Tag tag = Tag.fromJsonMap(element);
      tags.add(tag);
    }

    activeController = detectedControllerTypes[0];
    listLoaded = true;
    setState(() {});
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'json'],
    );
    if (result != null) {
      if (result.paths[0]?.split(".").last == "json") {
        _readFromJson(result.paths[0]!);
      } else {
        _readFromExcel(result.paths[0]!);
      }
    }
  }

  //NEEDS work
  Future<void> _exportToTaglist(String controller) async {
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );
    if (result != null) {
      File file = File("$result.xml");

      file.writeAsString(xmlTagString(
          List<Tag>.from(tags.where((tag) =>
              tag.selected && tag.controllerTypes.contains(controller))),
          zeroBased));
    }
  }

  Future<void> _exportToAlarmList() async {
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );
    if (result != null) {
      File alarmFile = File("$result.xml");

      alarmFile.writeAsString(alarmStringXML(
          protocolPrefixes, List<Tag>.from(tags.where((tag) => tag.selected))));
    }
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
                onTap: () => _openFile(),
                title: const Text("Open file (xlsx or json)"),
              ),
              ListTile(
                onTap: () => _saveAsJson(),
                title: const Text("Save as Json"),
              ),
              ListTile(
                onTap: () => _closeCurrentSetup(),
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
                title: const Text("Zero-based"),
                trailing: Switch(
                    value: zeroBased,
                    onChanged: (value) => setState(() => zeroBased = value)),
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
          Expanded(child: Container()),
          ...listLoaded
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
      body: !listLoaded
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                      onPressed: () => _openFile(),
                      child: const Icon(Icons.folder_open)),
                  const Text(
                      "Start by opening a DEIF modbuslist in excel format, or a previously saved setup."),
                  const Text("Modbuslists can be found on DEIFs webpage"),
                  TextButton(
                      onPressed: () => _launchUrl("https://www.deif.com"),
                      child: const Text("Go to DEIF webpage")),
                  const Text("Or downloaded directly here:"),
                  ...deifLinks.entries.map((e) {
                    return TextButton(
                        onPressed: () => _launchUrl(e.value),
                        child: Text(e.key));
                  }).toList(),
                ],
              ),
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
                            "$dataTypeFilter $functionGroupFilter"
                      }
                          .entries
                          .map((e) => Text("${e.key}: ${e.value}"))
                          .toList(),

                      /*[
                        Text(
                            "Selected tags: ${tags.where((element) => element.selected).length}"),
                        Text(
                            "Selected tags with alarm: ${tags.where((element) => element.selected && element.alarm.isActive).length}"),
                        Text("Tags in current view: ${visibleTags.length}")
                      ],*/
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
  for (var i = 0; i < sheet.maxCols; i++) {
    sheetMap[sheet
        .cell(exc.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .value
        .toString()] = sheet.rows.map((e) => e[i]?.value.toString()).toList()
      ..removeAt(0);
  }
  return sheetMap;
}

List indexFilter(Map map, String keyToFilter, var filter) {
  List indexFilter = [];
  for (var i = 0; i < map[keyToFilter]!.length; i++) {
    if (map[keyToFilter]![i] == filter) {
      indexFilter.add(i);
    }
  }
  return indexFilter;
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

List<SizedBox> editableFields(BuildContext context, Map fields) {
  List<SizedBox> textFormFields = [];
  for (var i = 0; i < fields.length; i++) {
    textFormFields.add(SizedBox(
      width: 100,
      child: TextFormField(
        keyboardType: fields.values.elementAt(i).runtimeType == double
            ? TextInputType.number
            : null,
        initialValue: fields.values.elementAt(i).toString(),
        decoration: InputDecoration(
            labelText: fields.keys.elementAt(i).toString(),
            isDense: true,
            contentPadding: const EdgeInsets.all(4)),

        //onTapOutside: (event) => print("tapped outside"),

        onChanged: (value) {
          if (fields.values.elementAt(i).runtimeType == double) {
            try {
              fields[fields.keys.elementAt(i)] = double.parse(value);
            } catch (e) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }
          if (fields.values.elementAt(i).runtimeType == String) {
            fields[fields.keys.elementAt(i)] = value;
          }
        },
      ),
    ));
  }
  return textFormFields;
}

class AlarmEditor extends StatefulWidget {
  AlarmEditor({super.key, required this.tag, required this.onCopyToAll});
  Tag tag;
  Function onCopyToAll;
  @override
  State<AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<AlarmEditor> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: DropdownButton<String>(
            isDense: true,
            padding: EdgeInsets.zero,
            value: widget.tag.alarm.alarmType,
            onChanged: (value) {
              FocusScope.of(context).unfocus();
              widget.tag.alarm.alarmType = value!;
              setState(() {});
            },
            items: const [
              DropdownMenuItem(
                value: "limitAlarm",
                child: Text("Limit Alarm"),
              ),
              DropdownMenuItem(
                value: "bitMaskAlarm",
                child: Text("Bit Mask Alarm"),
              ),
              DropdownMenuItem(
                value: "deviationAlarm",
                child: Text("Deviation Alarm"),
              ),
              DropdownMenuItem(
                value: "valueAlarm",
                child: Text("Value Alarm"),
              ),
            ],
          ),
        ),
        ...switch (widget.tag.alarm.alarmType) {
          "limitAlarm" => [
              SizedBox(
                width: 100,
                child: TextFormField(
                    keyboardType: TextInputType.number,
                    initialValue: widget.tag.alarm.minLimit.toString(),
                    decoration: const InputDecoration(
                        labelText: "Min limit",
                        isDense: true,
                        contentPadding: EdgeInsets.all(4)),

                    //onTapOutside: (event) => print("tapped outside"),

                    onChanged: (value) {
                      try {
                        widget.tag.alarm.minLimit = double.parse(value);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      }
                    }),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                    keyboardType: TextInputType.number,
                    initialValue: widget.tag.alarm.maxLimit.toString(),
                    decoration: const InputDecoration(
                        labelText: "Max limit",
                        isDense: true,
                        contentPadding: EdgeInsets.all(4)),
                    onChanged: (value) {
                      try {
                        widget.tag.alarm.maxLimit = double.parse(value);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      }
                    }),
              ),
            ],
          "bitMaskAlarm" => [
              SizedBox(
                width: 150,
                child: TextFormField(
                    keyboardType: TextInputType.number,
                    initialValue: widget.tag.alarm.bitPositions.toString(),
                    decoration: const InputDecoration(
                        labelText: "Bit positions",
                        isDense: true,
                        contentPadding: EdgeInsets.all(4)),
                    onChanged: (value) {
                      try {
                        widget.tag.alarm.bitPositions = value;
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      }
                    }),
              ),
            ],
          "deviationAlarm" => [
              SizedBox(
                width: 100,
                child: TextFormField(
                    keyboardType: TextInputType.number,
                    initialValue: widget.tag.alarm.setpoint.toString(),
                    decoration: const InputDecoration(
                        labelText: "Setpoint",
                        isDense: true,
                        contentPadding: EdgeInsets.all(4)),
                    onChanged: (value) {
                      try {
                        widget.tag.alarm.setpoint = double.parse(value);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      }
                    }),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                    keyboardType: TextInputType.number,
                    initialValue: widget.tag.alarm.deviation.toString(),
                    decoration: const InputDecoration(
                        labelText: "Deviation %",
                        isDense: true,
                        contentPadding: EdgeInsets.all(4)),
                    onChanged: (value) {
                      try {
                        widget.tag.alarm.deviation = double.parse(value);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      }
                    }),
              ),
            ],
          "valueAlarm" => [
              SizedBox(
                width: 100,
                child: TextFormField(
                    keyboardType: TextInputType.number,
                    initialValue: widget.tag.alarm.value.toString(),
                    decoration: const InputDecoration(
                        labelText: "Value",
                        isDense: true,
                        contentPadding: EdgeInsets.all(4)),
                    onChanged: (value) {
                      try {
                        widget.tag.alarm.value = double.parse(value);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      }
                    }),
              ),
            ],
          String() => [],
        },
        GestureDetector(
            onTapDown: (details) => showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        details.globalPosition.dx,
                        details.globalPosition.dy),
                    items: [
                      PopupMenuItem(
                          value: widget.onCopyToAll,
                          child:
                              const Text("Copy alarm to all in current list"))
                    ]).then(
                  (value) {
                    if (value == null) {
                      return;
                    } else {
                      value(widget.tag.alarm);
                    }
                  },
                ),
            child: const Icon(Icons.more_horiz))
      ],
    );
  }
}
