# Eldenring boss timer

This is an Auto Splitter script that was initially meant to time boss fights.

### Features:
The script displays:
- Current boss fight timer
- Category : 
  - Custom
  - All bosses
  - All base game
  - All remembrances
  - All DLC bosses
  - Main DLC bosses (remembrances + bayle)
- Number of defeated bosses based on selected category
- Death counter
- Great runes aquired
- Previous fight time
- Previous boss time (the successful attempt)
- Name of last defeated boss

<p align="center">
  <img src="https://raw.githubusercontent.com/cobrce/Eldenring-boss-timer-ASL/master/img.png">
</p>

- The timer starts with a boss fight, and is paused whenever the fight ends(win / loss / quitout)
- The death counter displays the number of times the character died
- If a new boss fight starts the timer is restarted and its previous value is moved to "previous fight time"
- the two last textboxes display informations about the last victory, the first one is the time spent, the second one is the name of the defeated boss


### How to use:
- Your layout should contain at least a timer, add this script as a Scriptable Auto Splitter that, the other controls will be created automatically
- The timing method should be "Game Time", the script will ask to change it if it's not the case
- Play eldenring, enjoy!

### Note:
- To change category goto "Edit layout..." > "Layout settings" > "Scriptable auto splitter" tab, check one of the categories
- The script can read the number of defeated bosses, death counter and great runes directly from the process, but it uses a different way to detect last defeated boss, so it's preferable to save the layout and reload it to keep track of previous boss fight.
- Sometimes when the script is running before the game it may fail to detect boss fights, to solve this just reload the previously saved layout


## Credit
- Thanks to Norii from The Grand Archives for the AOB pattern and inventory reading code
- Thanks to [drtchops](https://github.com/drtchops/asl) for the the ASL repository
- Thanks to Ero from autosplitter's discord for the help with controls creation
- SplitMemory.dll is used to read state of Bosses
