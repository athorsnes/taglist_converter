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
+ Open a modbus list. Must be xlsx format (default from DEIF).
+ Save or load setup to/from Json file. The Json file will hold the info of tags you have selected, so they are good for saving custom setups.
+ Close the open setup, to get back to the start page.
+ Toggle between 0- and 1-based modbus communication. Default is 1-based.


### Selecting tags
![Screenshot](/screenshots/loaded.jpg "After loading a modbus-list")

When you have loaded a modbus list, or Json file, the following happens:
+ the file is scanned for controller types, and all that are found will be displayed just below the app bar. In this case controller types BTB, MAINS and DG are found. These can be switched between, depending on what controller-type you are generating tags for.
+ All tags in the list that exist for the chosen controller type will be displayed in a scrollable list. Pressing a list item will add it to your selected tags. 
+ Pressing the alarm icon will add an alarm to the tag. The type of alarm, and its parameters can be set. The alarm can also be copied to all tags in the current list. An alarm can be added also on unselected tags. If the tag is unselected the connected alarm will not be included in the alarmlist output.
+ You can filter on "Function group" and "Data type". The filters can be combined, but might give zero results when used together. 
+ You can search in "Controller function name". This search is applied in addition the an active filter. 
+ You can use the buttons next to "Selected" to select or deselect all tags currently in the list.

### Creating importable taglist
![Screenshot](/screenshots/export.jpg "Export section in menu")
When you are done selecting tags and alarms, go to "export" in the menu to create importable taglist and alarmlist in XML format. 
Upon opening a modbus list, the program automatically suggests units to create alarms for. These can be removed and new ones added.
There can not be two units with the same prefix!


If you need guidance in importing the taglist / alarmlist in AGI Creator, see the AGI Creator manual.