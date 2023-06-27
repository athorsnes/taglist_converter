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
  Map<String, List> viewMap = {
    "Function group": [],
    "PLC address": [],
    "Controller function name": [],
    "Function code": [],
  };

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
      File file = File(result);
      //Map finalMap =
      // filteredMap(viewMap, indexFilter(viewMap, "Selected", false));

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
      File file = File(result);
      Map<String, List> finalMap =
          filteredMap(viewMap, indexFilter(viewMap, "Selected", false));

      file.writeAsString(xmlString(finalMap));
    }
  }

  void toggleSelectAllVisible() {
    for (var i = 0; i < viewMap["Filtered"]!.length; i++) {
      if (viewMap["Filtered"]![i]) {
        viewMap["Selected"]![i] = true;
      }
    }
  }

  Future<void> _selectFile() async {
    viewMap.forEach((key, value) {
      viewMap[key] = [];
    });
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

      Map discreteOutputMap = createMapFromSheet(sheets[0]);
      Map discreteInputMap = createMapFromSheet(sheets[1]);
      Map holdingRegisterMap = createMapFromSheet(sheets[2]);
      Map inputRegisterMap = createMapFromSheet(sheets[3]);

      discreteOutputMap["Function code"] =
          List.filled(discreteOutputMap["PLC address"]!.length, "F01");
      discreteInputMap["Function code"] =
          List.filled(discreteInputMap["PLC address"]!.length, "F02");
      holdingRegisterMap["Function code"] =
          List.filled(holdingRegisterMap["PLC address"]!.length, "F03");
      inputRegisterMap["Function code"] =
          List.filled(inputRegisterMap["PLC address"]!.length, "F04");

      viewMap.forEach((key, value) {
        value.addAll(discreteOutputMap[key]);
        value.addAll(discreteInputMap[key]);
        value.addAll(holdingRegisterMap[key]);
        value.addAll(inputRegisterMap[key]);
      });

      viewMap["Selected"] =
          List.filled(viewMap["Function group"]!.length, false);
      viewMap["Filtered"] =
          List.filled(viewMap["Function group"]!.length, true);

      //viewMap = Map.from(viewMap);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _exportToTaglist(),
        child: Icon(Icons.download),
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
          ListTile(
            dense: true,
            title: Row(
                children: viewMap.entries.map((entry) {
              Widget sizedBox = SizedBox(
                width: entry.key.length.toDouble() * 15,
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
                                    position: RelativeRect.fromLTRB(0, 0, 0, 0),
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
                                      viewMap["Function group"]!.length, true);
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
                      ? IconButton(
                          icon: Icon(Icons.select_all_rounded),
                          onPressed: () {
                            toggleSelectAllVisible();
                            setState(() {});
                          })
                      : SizedBox.shrink()
                ]),
              );
              return sizedBox;
            }).toList()),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: viewMap.values.first.length,
              itemBuilder: (context, index) {
                return Visibility(
                  visible: viewMap["Filtered"]![index],
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
                              width: 150,
                              child: Text(viewMap["Function group"]![index]
                                  .toString())),
                          SizedBox(
                              width: 100,
                              child: Text(
                                  viewMap["PLC address"]![index].toString())),
                          SizedBox(
                              width: 500,
                              child: Text(
                                  viewMap["Controller function name"]![index]
                                      .toString())),
                          SizedBox(
                              width: 50,
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
  List _indexFilter = [];
  for (var i = 0; i < map[keyToFilter]!.length; i++) {
    if (map[keyToFilter]![i] != filter) {
      _indexFilter.add(i);
    }
  }
  return _indexFilter;
}
