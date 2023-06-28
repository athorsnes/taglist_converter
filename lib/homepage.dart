import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:taglist_converter/backend/test.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, List> baseMap = {
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

  Map columnWidths = {
    "Function group": 150.0,
    "PLC address": 100.0,
    "Bit": 40.0,
    "Controller function name": 500.0,
    "Function code": 100.0,
    "Data type": 100.0,
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
    "ENG-M"
  ];
  List detectedControllerTypes = [];
  String activeController = "";

  void filter(List filterList) {
    List tempList = List.filled(viewMap["Function group"]!.length, true);
    filterList.forEach((element) {
      tempList[element] = false;
    });
    viewMap["Filtered"] = tempList;

    setState(() {});
  }

  Map<String, List> filteredMap(Map map, List filterList) {
    Map<String, List> tempMap = Map.from(map);

    tempMap.forEach((key, value) {
      List tempList = [];
      filterList.forEach((element) {
        tempList.add(value[element]);
      });
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
      var bytes = File(result.paths[0]!).readAsBytesSync();
      String jsonString = String.fromCharCodes(bytes);
      Map jsonMap = jsonDecode(jsonString);
      //Map finalMap =
      // filteredMap(viewMap, indexFilter(viewMap, "Selected", false));

      viewMap = Map.from(jsonMap);
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
          filteredMap(viewMap, indexFilter(viewMap, "Selected", false));

      file.writeAsString(xmlString(finalMap));
    }
  }

  void selectAllVisible() {
    for (var i = 0; i < viewMap["Filtered"]!.length; i++) {
      if (viewMap["Filtered"]![i] && viewMap[activeController]![i] == "X") {
        viewMap["Selected"]![i] = true;
      }
    }
  }

  void deselectAllVisible() {
    for (var i = 0; i < viewMap["Filtered"]!.length; i++) {
      if (viewMap["Filtered"]![i]) {
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

  Future<void> _selectFile() async {
    viewMap = Map.from(baseMap);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result != null) {
      var bytes = File(result.paths[0]!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      List<Sheet> sheets = excel.tables.values.toList()..removeAt(0);

      for (var sheet in sheets) {
        sheet.removeRow(0);
        sheet.removeRow(0);
        sheet.removeRow(0);
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

      for (String element in detectedControllerTypes) {
        viewMap[element] = [];
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

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _exportToTaglist(),
        child: Column(
          children: [
            Text(viewMap["Selected"] != null
                ? lengthOfSelectedAndAvaiable().toString()
                : "0"),
            Icon(Icons.download),
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
                  position: RelativeRect.fromLTRB(0, 0, 0, 0),
                  items: [
                    PopupMenuItem(
                        value: _selectFile,
                        child: const Text('Open modbus list')),
                    PopupMenuItem(
                        value: _saveAsJson, child: const Text('Save Json')),
                    PopupMenuItem(
                        value: _readFromJson, child: const Text('Load Json')),
                  ]).then((value) {
                if (value != null) {
                  value();
                } else {}
              });
            },
          )),
      body: Column(
        children: [
          Row(
            children: controllersInViewMap()
                .map((e) => TextButton(
                    onPressed: () => setState(() {
                          activeController = e;
                        }),
                    child: Text(e,
                        style: e == activeController
                            ? TextStyle(decoration: TextDecoration.underline)
                            : null)))
                .toList(),
          ),
          ListTile(
            dense: true,
            title: Row(
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
                  child: Row(children: [
                    Text(entry.key),
                    entry.key == "Function group"
                        ? IconButton(
                            icon: Icon(Icons.filter_list),
                            onPressed: () {
                              List filterList = List.from(entry.value);
                              filterList.removeWhere((value) => value == null);
                              filterList = filterList.toSet().toList()
                                ..insert(0, "Show all");
                              if (filterList.isEmpty) {
                                return;
                              }
                              showMenu(
                                      context: context,
                                      position:
                                          RelativeRect.fromLTRB(0, 0, 0, 0),
                                      items: filterList.map((e) {
                                        return PopupMenuItem(
                                            value: e,
                                            child: Text(
                                                e != null ? e.toString() : ""));
                                      }).toList())
                                  .then((value) {
                                if (value != null) {
                                  if (value == "Show all") {
                                    viewMap["Filtered"] = List.filled(
                                        viewMap["Function group"]!.length,
                                        true);
                                    setState(() {});
                                    return;
                                  }
                                  filter(indexFilter(viewMap, "Function group",
                                      value.toString()));
                                  setState(() {});
                                } else {
                                  return;
                                }
                              });
                            })
                        : SizedBox.shrink(),
                    entry.key == "Selected"
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: "Select all in list",
                                child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(Icons.check_box),
                                    onPressed: () {
                                      selectAllVisible();
                                      setState(() {});
                                    }),
                              ),
                              Tooltip(
                                message: "Deselect all in list",
                                child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(Icons.indeterminate_check_box),
                                    onPressed: () {
                                      deselectAllVisible();
                                      setState(() {});
                                    }),
                              ),
                            ],
                          )
                        : SizedBox.shrink()
                  ]),
                ),
              );
              return sizedBox;
            }).toList()),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: viewMap.values.first.length,
              itemBuilder: (context, index) {
                return Visibility(
                  visible: viewMap["Filtered"]![index] &&
                      (viewMap[activeController]![index] == "X"),
                  child: Card(
                    color: viewMap["Selected"]![index]
                        ? Colors.green[100]
                        : Colors.white,
                    child: ListTile(
                      //selected: widget.data[5],
                      dense: true,
                      title: Row(
                        children: [
                          SizedBox(
                              width: columnWidths["Function group"],
                              child: Text(viewMap["Function group"]![index]
                                  .toString())),
                          SizedBox(
                              width: columnWidths["PLC address"],
                              child: Text(
                                  viewMap["PLC address"]![index].toString())),
                          SizedBox(
                              width: columnWidths["Bit"],
                              child: Text(viewMap["Bit"]![index].toString())),
                          SizedBox(
                              width: columnWidths["Controller function name"],
                              child: Text(
                                  viewMap["Controller function name"]![index]
                                      .toString())),
                          SizedBox(
                              width: columnWidths["Data type"],
                              child: Text(
                                  viewMap["Data type"]![index].toString())),
                          SizedBox(
                              width: columnWidths["Selected"],
                              child: Icon(viewMap["Selected"]![index]
                                  ? Icons.check_box
                                  : Icons.indeterminate_check_box)),
                        ],
                      ),
                      onTap: () {
                        viewMap["Selected"]![index] =
                            !viewMap["Selected"]![index];

                        setState(() {});
                      },
                    ),
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

Map createMapFromSheet(Sheet sheet) {
  Map sheetMap = {};
  for (var i = 0; i < sheet.maxCols; i++) {
    sheetMap[sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .value
        .toString()] = sheet.rows.map((e) => e[i]?.value.toString()).toList()
      ..removeAt(0);
  }
  return sheetMap;
}

List indexFilter(Map map, String keyToFilter, var filter) {
  List indexFilter = [];
  for (var i = 0; i < map[keyToFilter]!.length; i++) {
    if (map[keyToFilter]![i] != filter) {
      indexFilter.add(i);
    }
  }
  return indexFilter;
}
