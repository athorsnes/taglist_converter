import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as exc;
import 'package:taglist_converter/backend/test.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Map<String, double> columns = {
    "Function group": 200.0,
    "PLC address": 150.0,
    "Bit": 70.0,
    "Controller function name": 500.0,
    //"Function code": 100.0,
    "Data type": 130.0,
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
    _resetFiltersAndSearch();
  }

  void _toggleZeroOneBased() {
    zeroBased = !zeroBased;
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

  Future<void> _readFromJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null) {
      _closeCurrentSetup();
      var bytes = File(result.paths[0]!).readAsBytesSync();
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
  }

  //NEEDS work
  Future<void> _exportToTaglist() async {
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );
    if (result != null) {
      File file = File("$result.xml");
      Map<String, List> finalMap = {};

      file.writeAsString(xmlString(finalMap, zeroBased));
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

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result != null) {
      _closeCurrentSetup();
      Uint8List bytes = File(result.paths[0]!).readAsBytesSync();
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
  }

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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _exportToTaglist(),
        child: Column(
          children: [
            Text(
                '${visibleTags.where((element) => element.selected).length.toString()}/${visibleTags.length}'),
            const Icon(Icons.download),
          ],
        ),
      ),
      appBar: AppBar(
          title: const Text('Taglist converter'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              showMenu(
                  context: context,
                  position: const RelativeRect.fromLTRB(0, 0, 0, 0),
                  items: [
                    PopupMenuItem(
                        value: _selectFile,
                        child: const Text('Open modbus list')),
                    const PopupMenuItem(
                        enabled: false,
                        height: 2,
                        child: PopupMenuDivider(height: 2)),
                    PopupMenuItem(
                        value: _saveAsJson,
                        child: const Text('Save setup as Json')),
                    PopupMenuItem(
                        value: _readFromJson,
                        child: const Text('Load setup from Json')),
                    const PopupMenuItem(
                        enabled: false,
                        height: 2,
                        child: PopupMenuDivider(height: 2)),
                    PopupMenuItem(
                        value: () {
                          _closeCurrentSetup();
                          setState(() {});
                          return true;
                        },
                        child: const Text('Close current setup')),
                    PopupMenuItem(
                        value: _toggleZeroOneBased,
                        child: Text(
                            "Toggle zero/one based (currently ${zeroBased ? "zero" : "one"} based)")),
                  ]).then((value) {
                if (value != null) {
                  value();
                } else {}
              });
            },
          )),
      body: !listLoaded
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "Start by loading a DEIF modbuslist in excel format, or a previously saved setup."),
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
                Row(
                  children: detectedControllerTypes
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
                ),
                ListTile(
                  dense: true,
                  title: Row(
                    //mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ...columns.entries.map((entry) {
                        Widget sizedBox = SizedBox(
                          width: columns[entry.key],
                          //height: 48,
                          child: Row(

                              //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key),
                                switch (entry.key) {
                                  "Function group" => GestureDetector(
                                      onTapDown: (details) => _showFilterMenu(
                                          entry.key, entry.value, details),
                                      child: Icon(Icons.filter_list,
                                          color: functionGroupFilter != ""
                                              ? Colors.green
                                              : null)),
                                  "Data type" => GestureDetector(
                                      onTapDown: (details) => _showFilterMenu(
                                          entry.key, entry.value, details),
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
                        );
                        return sizedBox;
                      }).toList(),
                      TextButton(
                          onPressed: () => _selectAllVisible(visibleTags),
                          child: const Text("Select all")),
                      TextButton(
                          onPressed: () => _deselectAllVisible(visibleTags),
                          child: const Text("Deselect all")),
                    ],
                  ),
                ),
                searchActive
                    ? ListTile(
                        dense: true,
                        leading: IconButton(
                            onPressed: () => setState(() {
                                  searchString = "";
                                  searchActive = false;
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
                    : const SizedBox.shrink(),
                Expanded(
                  child: ListView.builder(
                    itemCount: visibleTags.length,
                    itemExtent: 48,
                    itemBuilder: (context, index) {
                      return Card(
                        color: visibleTags[index].selected
                            ? Colors.green[100]
                            : Colors.white,
                        child: ListTile(
                          dense: true,
                          title: Row(
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
                                  width: columns["Selected"],
                                  child: Icon(visibleTags[index].selected
                                      ? Icons.check_box
                                      : Icons.indeterminate_check_box)),
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

class Tag {
  String name;
  String functionGroup;
  String plcAddress;
  String bit;
  String dataType;
  List controllerTypes;
  bool selected;
  bool visible;

  Tag(this.name, this.functionGroup, this.plcAddress, this.bit, this.dataType,
      this.controllerTypes, this.selected, this.visible);

  Tag.fromJsonMap(Map json)
      : name = json["name"],
        functionGroup = json["functionGroup"],
        plcAddress = json["plcAddress"],
        bit = json["bit"],
        dataType = json["dataType"],
        controllerTypes = json["controllerTypes"],
        selected = json["selected"],
        visible = json["visible"];

  toJsonMap() {
    return {
      "name": name,
      "functionGroup": functionGroup,
      "plcAddress": plcAddress,
      "bit": bit,
      "dataType": dataType,
      "controllerTypes": controllerTypes,
      "selected": selected,
      "visible": visible,
    };
  }
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
        controllers,
        false,
        true));
  }
  return tags;
}
