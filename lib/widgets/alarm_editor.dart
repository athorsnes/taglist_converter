import 'package:flutter/material.dart';

import '../classes/tag.dart';

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
