# Casting scripts

Come in two forms:

##  setup_pulse.bash

This guy lets you set up your pulse audio so that you can still listen to music/applications but not your own microphone.  It feeds incoming audio to a recordable sink, while not looping back all things you hear in hardware out to the recording software.

Primary use case:  Scalawags video casting with intro/outro music as part of the live event.  Maybe even a sound board one day.

## twitch-stream.bash

Screencasting focused on twitch.tv.  This one lets you record the desktop, an optional image overlay and webcam (in the top right).  It uses the setup_pulse script so you have fine controls over the audio portion.

### usage
```
 (master %=) ➜ ./twitch-stream.bash -h

Usage:
twitch-stream.bash [options]
 This script records to twitch with the given inputs/outputs.
   By default the entire screen is recorded and the default  
   pulse audio device is recorded.

 Options:

  -webcam <device>            Record the webcam.
  -twitch-server <subdomain>  The twitch subdomain server
                              (default: live-jfk)
  -overlay <image>            An image to overlay on top of
                              the video, but under the webcam,
                              if the webcam is enabled.
  -window                     On startup select a window to
                              set the xgrab coordinates.
  -s <input>                  Record a given pulse audio source
                              on the audio stream.
                              Example: 'snowball' would find any 
                              snowball microphone connected.
  -mi <pulse client>          Record any pulse-audio client
                              and also output to hardware speakers
                              Examples:  rhythmbox, wine
```



Use at your own risk.  If you do, please contribute fixes back.  Happy casting!


