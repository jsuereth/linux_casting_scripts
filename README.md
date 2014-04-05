# Casting scripts

Come in two forms:

##  setup_pulse.bash

This guy lets you set up your pulse audio so that you can still listen to music/applications but not your own microphone.  It feeds incoming audio to a recordable sink, while not looping back all things you hear in hardware out to the recording software.

Primary use case:  Scalawags video casting with intro/outro music as part of the live event.  Maybe even a sound board one day.

## twitch-stream.bash

Screencasting focused on twitch.tv.  This one lets you record the desktop, an optional image overlay and webcam (in the top right).  It uses the setup_pulse script so you have fine controls over the audio portion.


Use at your own risk.  If you do, please contribute fixes back.  Happy casting!


