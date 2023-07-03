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

  final Map<String, List> baseMap = {
    "Function group": [],
    "PLC address": [],
    "Bit": [],
    "Controller function name": [],
    "Function code": [],
    "Data type": [],
  };
  Map<String, List> viewMap = {
    "Function group": [],
    "PLC address": [],
    "Bit": [],
    "Controller function name": [],
    "Function code": [],
    "Data type": [],
  };

  List<Tag> tags = [];

  Map columnWidths = {
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

  bool mapLoaded = false;
  int listLength = 0;

  //TESTING
  String searchString = "";
  String dataTypeFilter = "";
  String functionGroupFilter = "";

  void _resetFiltersAndSearch() {
    searchString = "";
    dataTypeFilter = "";
    functionGroupFilter = "";
  }

  void _closeCurrentSetup() {
    mapLoaded = false;
    viewMap = Map.fromIterables(baseMap.keys, baseMap.values);
    detectedControllerTypes = [];
    activeController = "";
    _resetFiltersAndSearch();
  }

  void _toggleZeroOneBased() {
    zeroBased = !zeroBased;
    setState(() {});
  }

  Map<String, List> filteredMap(Map map, List filterList) {
    Map<String, List> tempMap = Map.from(map);

    tempMap.forEach((key, value) {
      List tempList = [];
      for (var element in filterList) {
        tempList.add(value[element]);
      }
      tempMap[key] = tempList;
    });
    return tempMap;
  }

  Future<void> _saveAsJson() async {
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null) {
      File file = File("$result.json");
      file.writeAsString(jsonEncode(viewMap));
    }
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

      viewMap = Map.from(jsonMap);
      detectedControllerTypes = controllersInViewMap();
      activeController = detectedControllerTypes[0];
      if (viewMap.values.first.isNotEmpty) {
        listLength = viewMap.values.first.length;
        mapLoaded = true;
      }
      setState(() {});
    }
  }

  Future<void> _exportToTaglist() async {
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );
    if (result != null) {
      File file = File("$result.xml");
      Map<String, List> finalMap =
          filteredMap(viewMap, indexFilter(viewMap, "Selected", true));

      file.writeAsString(xmlString(finalMap, zeroBased));
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  void _showFilterMenu(entrykey, entryValue, TapDownDetails details) {
    List filterList = List.from(entryValue);
    filterList.removeWhere((value) => value == null);
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
          //viewMap["Filtered"] = List.filled(viewMap[entrykey]!.length, true);
          if (entrykey == "Data type") {
            dataTypeFilter = "";
          } else if (entrykey == "Function group") {
            functionGroupFilter = "";
          }
          setState(() {});
          return;
        }
        //_filter(indexFilter(viewMap, entrykey, value.toString()));
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

  void _selectAllVisible() {
    for (var i = 0; i < viewMap.values.first.length; i++) {
      if (shouldBeVisible(i)) {
        viewMap["Selected"]![i] = true;
      }
    }
  }

  void _deselectAllVisible() {
    for (var i = 0; i < viewMap.values.first.length; i++) {
      if (shouldBeVisible(i)) {
        viewMap["Selected"]![i] = false;
      }
    }
  }

  List controllersInViewMap() {
    List controllersInViewMap = [];
    for (String element in viewMap.keys) {
      if (possibleControllerTypes.contains(element)) {
        controllersInViewMap.add(element);
      }
    }
    return controllersInViewMap;
  }

  bool selectedAndAvailable(int index) {
    if (viewMap["Selected"]![index] == true &&
        viewMap[activeController]![index] == "X") {
      return true;
    } else {
      return false;
    }
  }

  int lengthOfSelectedAndAvaiable() {
    List selectedAndAvaliableList = List<bool>.generate(
        viewMap["Function code"]!.length,
        (index) => selectedAndAvailable(index));
    return selectedAndAvaliableList.where((element) => element == true).length;
  }

  bool shouldBeVisible(int index) {
    bool searchHit = true;
    bool dataTypeMatch = false;
    bool functionGroupMatch = false;
    bool controllerMatch = false;

    if (searchString != "" &&
        !viewMap["Controller function name"]![index]
            .toLowerCase()
            .contains(searchString.toLowerCase())) {
      searchHit = false;
    }
    if (dataTypeFilter == "" ||
        viewMap["Data type"]![index] == dataTypeFilter) {
      dataTypeMatch = true;
    }
    if (functionGroupFilter == "" ||
        viewMap["Function group"]![index] == functionGroupFilter) {
      functionGroupMatch = true;
    }

    if (viewMap[activeController]![index] == "X") {
      controllerMatch = true;
    }

    if (searchHit && dataTypeMatch && functionGroupMatch && controllerMatch) {
      return true;
    } else {
      return false;
    }
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

      //Add detected controller types as keys in viewMap
      for (String element in detectedControllerTypes) {
        viewMap[element] = [];
      }

      for (var i = 0; i < discreteInputMap.values.first.length; i++) {
        tags.add(Tag(
            discreteInputMap["Controller function name"][i],
            discreteInputMap["Function group"][i],
            discreteInputMap["PLC address"][i],
            discreteInputMap["Bit"][i],
            discreteInputMap["Data type"][i],
            false,
            true));
      }

      for (var i = 0; i < discreteOutputMap.values.first.length; i++) {
        tags.add(Tag(
            discreteOutputMap["Controller function name"][i],
            discreteOutputMap["Function group"][i],
            discreteOutputMap["PLC address"][i],
            discreteOutputMap["Bit"][i],
            discreteOutputMap["Data type"][i],
            false,
            true));
      }

      for (var i = 0; i < holdingRegisterMap.values.first.length; i++) {
        tags.add(Tag(
            holdingRegisterMap["Controller function name"][i],
            holdingRegisterMap["Function group"][i],
            holdingRegisterMap["PLC address"][i],
            holdingRegisterMap["Bit"][i],
            holdingRegisterMap["Data type"][i],
            false,
            true));
      }
      for (var i = 0; i < inputRegisterMap.values.first.length; i++) {
        tags.add(Tag(
            inputRegisterMap["Controller function name"][i],
            inputRegisterMap["Function group"][i],
            inputRegisterMap["PLC address"][i],
            inputRegisterMap["Bit"][i],
            inputRegisterMap["Data type"][i],
            false,
            true));
      }

      viewMap.forEach((key, value) {
        if (discreteOutputMap[key] != null) {
          value.addAll(discreteOutputMap[key]);
        }
        if (discreteInputMap[key] != null) {
          value.addAll(discreteInputMap[key]);
        }
        if (holdingRegisterMap[key] != null) {
          value.addAll(holdingRegisterMap[key]);
        }
        if (inputRegisterMap[key] != null) {
          value.addAll(inputRegisterMap[key]);
        }
      });

      viewMap["Selected"] =
          List.filled(viewMap["Function group"]!.length, false);
      viewMap["Filtered"] =
          List.filled(viewMap["Function group"]!.length, true);
      viewMap["Searched"] =
          List.filled(viewMap["Function group"]!.length, true);

      if (viewMap.isNotEmpty) {
        listLength = viewMap["Function group"]!.length;
        mapLoaded = true;
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Tag> visibleTags = tags;

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

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _exportToTaglist(),
        child: Column(
          children: [
            Text(viewMap["Selected"] != null
                ? lengthOfSelectedAndAvaiable().toString()
                : "0"),
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
      body: !mapLoaded
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
                  children: controllersInViewMap()
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
                      children: viewMap.entries.map((entry) {
                        Widget sizedBox = Visibility(
                          visible: switch (entry.key) {
                            "Function group" => true,
                            "PLC address" => true,
                            "Bit" => true,
                            "Controller function name" => true,
                            "Function code" => false,
                            "Data type" => true,
                            "Selected" => true,
                            String() => false
                          },
                          child: SizedBox(
                            width: columnWidths[entry.key],
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
                                    "Selected" => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: "Select all in list",
                                            child: IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon:
                                                    const Icon(Icons.check_box),
                                                onPressed: () {
                                                  _selectAllVisible();
                                                  setState(() {});
                                                }),
                                          ),
                                          Tooltip(
                                            message: "Deselect all in list",
                                            child: IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(Icons
                                                    .indeterminate_check_box),
                                                onPressed: () {
                                                  _deselectAllVisible();
                                                  setState(() {});
                                                }),
                                          ),
                                        ],
                                      ),
                                    String() => const SizedBox.shrink()
                                  }
                                ]),
                          ),
                        );
                        return sizedBox;
                      }).toList()),
                ),
                searchActive
                    ? ListTile(
                        dense: true,
                        leading: IconButton(
                            onPressed: () => setState(() {
                                  //_search(indexSearch(
                                  // viewMap, "Controller function name", ""));
                                  searchString = "";
                                  searchActive = false;
                                  setState(() {});
                                }),
                            icon: const Icon(Icons.close)),
                        title: TextField(
                            autofocus: true,
                            onChanged: (value) {
                              //_search(indexSearch(
                              //    viewMap, "Controller function name", value));

                              searchString = value;
                              setState(() {});
                            }),
                      )
                    : const SizedBox.shrink(),
                Expanded(
                  child: ListView.builder(
                    itemCount: visibleTags.length,
                    itemExtent: 60,
                    itemBuilder: (context, index) {
                      return Card(
                        color: tags[index].selected
                            ? Colors.green[100]
                            : Colors.white,
                        child: ListTile(
                          dense: true,
                          title: Row(
                            children: [
                              SizedBox(
                                  width: columnWidths["Function group"],
                                  child:
                                      Text(visibleTags[index].functionGroup)),
                              SizedBox(
                                  width: columnWidths["PLC address"],
                                  child: Text(visibleTags[index].plcAddress)),
                              SizedBox(
                                  width: columnWidths["Bit"],
                                  child: Text(visibleTags[index].bit)),
                              SizedBox(
                                  width:
                                      columnWidths["Controller function name"],
                                  child: Text(visibleTags[index].name)),
                              SizedBox(
                                  width: columnWidths["Data type"],
                                  child: Text(visibleTags[index].dataType)),
                              SizedBox(
                                  width: columnWidths["Selected"],
                                  child: Icon(visibleTags[index].selected
                                      ? Icons.check_box
                                      : Icons.indeterminate_check_box)),
                            ],
                          ),
                          onTap: () {
                            tags[index].selected = !tags[index].selected;

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
  bool selected;
  bool visible;
  Tag(this.name, this.functionGroup, this.plcAddress, this.bit, this.dataType,
      this.selected, this.visible);
}
