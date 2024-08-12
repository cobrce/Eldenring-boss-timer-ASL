# Eldenring boss timer

This is an Auto Splitter script that was initially meant to time boss fights.

### Features:
The script displays:
- Current boss fight timer
- Previously recorded time
- Death counter

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
- Play elddenring, enjoy!


## Credit
- Thanks to The Grand Archives for the AOB pattern
- Thanks to [drtchops](https://github.com/drtchops/asl) for the the ASL repository
- Thanks to Ero from autosplitter's discord for the help with controls creation
- SplitMemory.dll is used to read state of Bosses
