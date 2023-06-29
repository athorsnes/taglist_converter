import 'dart:convert';
import 'dart:io';
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
  bool crossUpdate = false;
  bool crossUpdateOld = false;
  bool zeroBased = false;

  bool searchActive = false;

  void _closeCurrentSetup() {
    for (var key in viewMap.keys) {
      viewMap[key] = [];
    }
    /*
    for(int i=0; i> viewMap.values.length; i++){
      viewMap.values[i] = [];
    }*/
    detectedControllerTypes = [];
    activeController = "";
    setState(() {});
  }

  void _toggleZeroOneBased() {
    zeroBased = !zeroBased;
    setState(() {});
  }

  void _filter(List filterList) {
    List tempList = List.filled(viewMap["Function group"]!.length, false);
    for (var element in filterList) {
      tempList[element] = true;
    }
    viewMap["Filtered"] = tempList;
    //crossUpdate = !crossUpdate;

    setState(() {});
  }

  void _search(List searchList) {
    List tempList = List.filled(viewMap["Function group"]!.length, false);
    for (var element in searchList) {
      tempList[element] = true;
    }
    viewMap["Searched"] = tempList;

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
      detectedControllerTypes = controllersInViewMap();
      activeController = detectedControllerTypes[0];
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

  void _showFilterMenu(entrykey, entryValue) {
    List filterList = List.from(entryValue);
    filterList.removeWhere((value) => value == null);
    filterList = filterList.toSet().toList()..insert(0, "Show all");
    if (filterList.isEmpty) {
      return;
    }
    showMenu(
            context: context,
            position: RelativeRect.fromLTRB(0, 0, 0, 0),
            items: filterList.map((e) {
              return PopupMenuItem(
                  value: e, child: Text(e != null ? e.toString() : ""));
            }).toList())
        .then((value) {
      if (value != null) {
        if (value == "Show all") {
          viewMap["Filtered"] = List.filled(viewMap[entrykey]!.length, true);
          setState(() {});
          return;
        }
        _filter(indexFilter(viewMap, entrykey, value.toString()));
        setState(() {});
      } else {
        return;
      }
    });
  }

  void _selectAllVisible() {
    for (var i = 0; i < viewMap["Filtered"]!.length; i++) {
      if (viewMap["Filtered"]![i] &&
          viewMap["Searched"]![i] &&
          viewMap[activeController]![i] == "X") {
        viewMap["Selected"]![i] = true;
      }
    }
  }

  void _deselectAllVisible() {
    for (var i = 0; i < viewMap["Filtered"]!.length; i++) {
      if (viewMap["Filtered"]![i] &&
          viewMap["Searched"]![i] &&
          viewMap[activeController]![i] == "X") {
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
    if (viewMap["Filtered"]![index] &&
        (viewMap[activeController]![index] == "X") &&
        (viewMap["Searched"]![index])) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> _selectFile() async {
    viewMap = Map.fromIterables(baseMap.keys, baseMap.values);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result != null) {
      var bytes = File(result.paths[0]!).readAsBytesSync();
      var excel = exc.Excel.decodeBytes(bytes);

      List<exc.Sheet> sheets = excel.tables.values.toList()..removeAt(0);

      for (var sheet in sheets) {
        sheet.removeRow(0);
        sheet.removeRow(0);
        sheet.removeRow(0);
        //Clean up empty rows

        sheet.removeRow(sheet.maxRows - 1);
        sheet.removeRow(sheet.maxRows - 1);
        sheet.removeRow(sheet.maxRows - 1);
        /*
        sheet.rows.asMap().forEach((index, row) {
          if (row[0]?.value == null) {
            sheet.removeRow(index);
          }
        });*/
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

      //for loop that prints index of any element in each value of discreteInputMap that is null
      for (var i = 0; i < discreteInputMap.values.first.length; i++) {
        if (discreteInputMap.values.first.elementAt(i) == null) {
          print(i);
        }
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
                  position: RelativeRect.fromLTRB(0, 0, 0, 0),
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
                        value: _closeCurrentSetup,
                        child: const Text('Close current setup')),
                    PopupMenuItem(
                        value: _toggleZeroOneBased,
                        child: Text("Toggle zero/one based (currently " +
                            (zeroBased ? "zero" : "one") +
                            " based)")),
                  ]).then((value) {
                if (value != null) {
                  value();
                } else {}
              });
            },
          )),
      body: viewMap.values.first.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      "Start by loading a DEIF modbuslist in excel format, or a previously saved setup."),
                  Text("Modbuslists can be found on DEIFs webpage"),
                  TextButton(
                      onPressed: () => _launchUrl("https://www.deif.com"),
                      child: const Text("Go to DEIF webpage")),
                  Text("Or downloaded directly here:"),
                  TextButton(
                      onPressed: () => _launchUrl(
                          "https://deif-cdn-umbraco.azureedge.net/media/shjn54mw/agc-4-mk-ii-modbus-tables-4189341272-uk.xlsx"),
                      child: const Text("AGC-4-MK-II")),
                  TextButton(
                      onPressed: () => _launchUrl(
                          "https://deif-cdn-umbraco.azureedge.net/media/va3b0mah/asc-4-modbus-server-tables-4189341284-uk.xlsx"),
                      child: const Text("ASC-4")),
                  TextButton(
                      onPressed: () => _launchUrl(
                          "https://deif-cdn-umbraco.azureedge.net/media/qyeogmjx/alc-4-modbus-tables-4189341283-uk.xlsx"),
                      child: const Text("ALC-4")),
                  TextButton(
                      onPressed: () => _launchUrl(
                          "https://deif-cdn-umbraco.azureedge.net/media/f2hiadel/agc-150-modbus-server-tables-4189341212-uk.xlsx"),
                      child: const Text("AGC 150")),
                  TextButton(
                      onPressed: () => _launchUrl(
                          "https://deif-cdn-umbraco.azureedge.net/media/qzbo5thj/asc-150-modbus-server-tables-4189341324-uk.xlsx"),
                      child: const Text("ASC 150")),
                  TextButton(
                      onPressed: () => _launchUrl(
                          "https://deif-cdn-umbraco.azureedge.net/media/zizlfabe/ppm-300-modbus-tables-4189341079-uk.xlsx"),
                      child: const Text("PPM 300")),
                  TextButton(
                      onPressed: () => _launchUrl(
                          "https://deif-cdn-umbraco.azureedge.net/media/wfcn3snq/ppu-300-modbus-tables-4189341101-uk.xlsx"),
                      child: const Text("PPU 300")),

                  //https://deif-cdn-umbraco.azureedge.net/media/shjn54mw/agc-4-mk-ii-modbus-tables-4189341272-uk.xlsx?rnd=133226713347070000&v=8
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
                                  ? TextStyle(
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
                                    "Function group" => IconButton(
                                        icon: Icon(Icons.filter_list),
                                        onPressed: () {
                                          _showFilterMenu(
                                              entry.key, entry.value);
                                        }),
                                    "Data type" => IconButton(
                                        icon: Icon(Icons.filter_list),
                                        onPressed: () {
                                          _showFilterMenu(
                                              entry.key, entry.value);
                                        }),
                                    "Controller function name" => IconButton(
                                        onPressed: () => setState(() {
                                              searchActive = true;
                                            }),
                                        icon: Icon(Icons.search)),
                                    "Selected" => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: "Select all in list",
                                            child: IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: Icon(Icons.check_box),
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
                                                icon: Icon(Icons
                                                    .indeterminate_check_box),
                                                onPressed: () {
                                                  _deselectAllVisible();
                                                  setState(() {});
                                                }),
                                          ),
                                        ],
                                      ),
                                    String() => SizedBox.shrink()
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
                                  _search(indexSearch(
                                      viewMap, "Controller function name", ""));
                                  searchActive = false;
                                }),
                            icon: Icon(Icons.close)),
                        title: TextField(
                            autofocus: true,
                            onChanged: (value) {
                              _search(indexSearch(
                                  viewMap, "Controller function name", value));
                            }),
                      )
                    : SizedBox.shrink(),
                Expanded(
                  child: ListView.builder(
                    itemCount: viewMap.values.first.length,
                    itemBuilder: (context, index) {
                      return Visibility(
                        visible: shouldBeVisible(index),
                        child: Card(
                          color: viewMap["Selected"]![index]
                              ? Colors.green[100]
                              : Colors.white,
                          child: ListTile(
                            dense: true,
                            title: Row(
                              children: [
                                SizedBox(
                                    width: columnWidths["Function group"],
                                    child: Text(
                                        viewMap["Function group"]![index]
                                            .toString())),
                                SizedBox(
                                    width: columnWidths["PLC address"],
                                    child: Text(viewMap["PLC address"]![index]
                                        .toString())),
                                SizedBox(
                                    width: columnWidths["Bit"],
                                    child: Text(
                                        viewMap["Bit"]![index].toString())),
                                SizedBox(
                                    width: columnWidths[
                                        "Controller function name"],
                                    child: Text(viewMap[
                                            "Controller function name"]![index]
                                        .toString())),
                                SizedBox(
                                    width: columnWidths["Data type"],
                                    child: Text(viewMap["Data type"]![index]
                                        .toString())),
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

List indexSearch(Map map, String keyToSearch, var search) {
  if (search == "") {
    return List.generate(map[keyToSearch]!.length, (index) => index);
  }
  List indexSearch = [];
  for (var i = 0; i < map[keyToSearch]!.length; i++) {
    if (map[keyToSearch]?[i].toLowerCase().contains(search.toLowerCase())) {
      indexSearch.add(i);
    }
  }
  return indexSearch;
}
