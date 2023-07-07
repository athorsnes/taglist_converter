# taglist_converter

A program to convert DEIF modbus-lists to importable XML for AGI Creator
+ Create importable taglist and alarmlist, containing your specific selection
+ Save your setups
+ Supports AGC-4 (also MKII), ALC-4, ASC-4, AGC 150, ASC 150, PPM 300, PPU 300

Currently in beta


## Install and run

1. Download betaRelease.zip

2. Extract content somewhere on your PC

3. Run taglist_converter.exe


No signature on the application, so make your way past security measures. 

## Usage

### Start
![Screenshot](/screenshots/start.jpg "Application on start")

When the application has started, you can use the buttons to download modbuslists from DEIFs server, or if you already have lists, open them from the menu:

### Menu
![Screenshot](/screenshots/menu.jpg "Menu")

In the menu, you can
+ Open a DEIF modbus list in xlsx format or a previosly saved setup in json format.
+ Save the current setup.
+ Adjust settings.
++ Zero-based adjusts the address by -1.
++ Value of tag in Custom Field (Alarms), adds the value of the triggering tag in Custom field in the alarm list. This allows for setting colors depending on state if you are using "Alarm status : alarm state" tags as alarms for ML 300.
+ Close the open setup, to get back to the start page.
+ Export taglists and alarmlists



### Selecting tags and alarms
![Screenshot](/screenshots/loaded.jpg "After loading a modbus-list")

When you have loaded a modbus list, or Json file, the following happens:
+ the file is scanned for controller types, and all that are found will be displayed just below the app bar. These can be switched between, to display the tags avaiable for each controller-type.
+ All tags in the list that exist for the chosen controller type will be displayed in a scrollable list. Pressing a list item will add it to your selected tags. 
+ Pressing the alarm icon will add an alarm to the tag. The type of alarm, and its parameters can be set. The alarm can also be copied to all tags in the current list. An alarm can be added also on unselected tags. If the tag is unselected the connected alarm will not be included in the alarmlist output.
+ You can filter on "Function group" and "Data type". The filters can be combined, but might give zero results when used together. 
+ You can search in "Controller function name". This search is applied in addition the any active filter. 
+ You can use the buttons next to "Selected" to select or deselect all tags currently in the list.

### Generating importable lists
![Screenshot](/screenshots/export.jpg "Export section in menu")

When you are done selecting tags and alarms, go to "export" in the menu to create importable taglist and alarmlist in XML format. 
Upon opening a modbus list, the program automatically suggests units to create alarms for. These can be removed and new ones added.
There can not be two units with the same prefix!


If you need guidance in importing the taglist / alarmlist in AGI Creator, see the AGI Creator manual.