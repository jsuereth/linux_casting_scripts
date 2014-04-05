#!/bin/bash

declare -r SCRIPT_NAME=${0##*/}

# Requires
# * avconv
# * v4l
# * v4l-utils

# Static Configuration
declare -r OUTPUT_RESOLUTION="1280x720" # Video Output Resolution
declare -r FPS="24"                     # Frame per Seconds (Suggested 24, 25, 30 or 60)
declare -r THREADS="4"                  # Change this if you have a good CPU (Suggested 4 threads, Max 6 threads)
declare -r VIDEO_QUALITY="ultrafast"    # ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo
declare -r BITRATE="1000k"              # Constant bitrate (CBR) Increase this to get a better pixel quality (1000k - 3000k for twitch)
declare -r AUDIO_RATE="44100"           # Twitch says it MUST have a 44k rate.
declare -r PA_INPUT="recording_feed_out.monitor" # Hardcoded in pulse)setup script


# Discovered information from arguments
declare input_resolution          # incoming resolution of the game
declare twitch_server=live-jfk    # Twitch server to use (see http://bashtech.net/twitch/ingest.php)
declare window_position           # Positioning of the window, auto-detected
declare webcam_resolution=320:240 # incoming resolution of the webcam
declare webcam_device             # device location for the webcam
declare -a pulse_args             # Arguments for pulse audio script.
declare overlay_image             # The overlay image to use for the stream.


# TODO - trapexit calls with pulseaudio cleanups

echoerr() {
  echo 1>&2 "$@"  
}

# Finds one of the various ways you can configure your twitch key.
findTwitchKey() {
	LOCAL_KEY=$(cat .twitchkey)
	HOME_DIR_KEY=$(cat ~/.twitchkey)
	if [ "$STREAM_KEY" != "" ]; then
		echo "$STREAM_KEY"
	elif [ "$LOCAL_KEY" != "" ]; then
		echo "$LOCAL_KEY"
	elif [ "$HOME_DIR_KEY" != "" ]; then
		echo "$HOME_DIR_KEY"
	else
		echoerr "No twitch key found! Please place one in either of the following: "
		echoerr " * STREAM_KEY environment variable"
		echoerr " * .twitchkey file in current directory"
		echoerr " ~/.twitchkey file"
		exit 1
	fi
}

twitchStreamUrl() {
	echo "rtmp://${twitch_server}.twitch.tv/app/$(findTwitchKey)"
}

setFullscreen() {
	window_position="0,0"
	input_resolution=$(xwininfo -root | awk '/geometry/ {print $2}'i | sed -e 's/\+[0-9]//g')
}

# TODO - This only limits the screen grab to coordinates, rather then the xid.
selectWindow() {
	echo "Click a window, dude"
	xwininfo -stats > .record_window_info
	window_position=$(cat .record_window_info | awk 'FNR == 8 {print $4}')","$(cat .record_window_info | awk 'FNR == 9 {print $4}')
	input_resolution=$(cat .record_window_info | awk 'FNR == 12 {print $2}')"x"$(cat .record_window_info | awk 'FNR == 13 {print $2}')
	rm -f .record_window_info 2> /dev/null
	echo " "
}

selectWebcamError() {
  echo "Please select on of the following webcams: "
  echo "$(v4l2-ctl --list-device | grep /dev/)"
}

setWebcamResolution() {
	# TODO - Validate input
	webcam_resolution="$1"
}

createAvconvFilterString() {
	if test -z "$overlay_image" ; then
		# We do not have an overlay
		if test -z "$webcam_device" ; then
			echo ""
		else
      echo "movie=$webcam_device:f=video4linux2, scale=$webcam_resolution , setpts=PTS-STARTPTS [WebCam];
             [in] setpts=PTS-STARTPTS, [WebCam] overlay=main_w-overlay_w-10:10 [out]"
		fi
	else
		# We have an overlay
		if test -z "$webcam_device" ; then
			echo " movie=$overlay_image [OverlayPng];
                   [in][OverlayPng] overlay=10:10 [out]"
		else
			echo " movie=$webcam_device:f=video4linux2, scale=$webcam_resolution , setpts=PTS-STARTPTS [WebCam]; 
                   movie=$overlay_image [OverlayPng];
                   [in][OverlayPng] overlay=10:10 [videoWithOverlay];
                   [videoWithOverlay] setpts=PTS-STARTPTS, [WebCam] overlay=main_w-overlay_w-10:10 [out]"
		fi
	fi
}

streamTo(){
	echo "Press Ctl-C to stop."
	local filter_string=$(createAvconvFilterString)
	if test -z "$filter_string"; then
	  avconv \
        -f x11grab \
        -s $input_resolution \
        -r "$FPS" \
        -i :0.0+${window_position} \
        -f pulse \
        -i $PA_INPUT \
        -f flv -ac 2 -ar $AUDIO_RATE \
        -vcodec libx264 \
        -g $(($FPS*2)) \
        -keyint_min $FPS \
        -b $BITRATE \
        -minrate $BITRATE \
        -maxrate $BITRATE \
        -pix_fmt yuv420p \
        -s $OUTPUT_RESOLUTION \
        -preset $VIDEO_QUALITY \
        -tune film  \
        -acodec libmp3lame \
        -threads $THREADS \
        -strict normal \
        -bufsize $BITRATE \
        "$1"
	else
      avconv \
        -f x11grab \
        -s $input_resolution \
        -r "$FPS" \
        -i :0.0+${window_position} \
        -f alsa \
        -i pulse \
        -f flv -ac 2 -ar $AUDIO_RATE \
        -vcodec libx264 \
        -g $(($FPS*2)) \
        -keyint_min $FPS \
        -b $BITRATE \
        -minrate $BITRATE \
        -maxrate $BITRATE \
        -pix_fmt yuv420p \
        -s $OUTPUT_RESOLUTION \
        -preset $VIDEO_QUALITY \
        -tune film  \
        -acodec libmp3lame \
        -threads $THREADS \
        -vf "$(createAvconvFilterString)" \
        -strict normal \
        -bufsize $BITRATE \
        "$1"
    fi
}

streamWithWebcamToTwitch() {
	echo "Online! Check on http://twitch.tv/"
    echo " "
	streamWithWebcamTo "$(twitchStreamUrl)"
}

addPulseArg() {
  pulse_args=( "${pulse_args[@]}" "$1" )
}

setTwitchServer() {
	twitch_server="$1"
}

setWebcam() {
	webcam_device="$1"
}

setOverlayImage() {
	overlay_image="$1"
}

require_arg () {
  local type="$1"
  local opt="$2"
  local arg="$3"
  if [[ -z "$arg" ]] || [[ "${arg:0:1}" == "-" ]]; then
    echo "$opt requires <$type> argument"
    exit 1
  fi
}

usage() {
  echo ""
  echo "Usage:"
  echo "$SCRIPT_NAME [options]"
  echo " This script records to twitch with the given inputs/outputs."
  echo "   By default the entire screen is recorded and the default  "
  echo "   pulse audio device is recorded."
  echo
  echo " Options:"
  echo
  echo "  -webcam <device>            Record the webcam."
  echo "  -twitch-server <subdomain>  The twitch subdomain server"
  echo "                              (default: live-jfk)"
  echo "  -overlay <image>            An image to overlay on top of"
  echo "                              the video, but under the webcam,"
  echo "                              if the webcam is enabled."
  echo "  -window                     On startup select a window to"
  echo "                              set the xgrab coordinates."
  echo "  -s <input>                  Record a given pulse audio source"
  echo "                              on the audio stream."
  echo "                              Example: 'snowball' would find any "
  echo "                              snowball microphone connected."
  echo "  -mi <pulse client>          Record any pulse-audio client"
  echo "                              and also output to hardware speakers"
  echo "                              Examples:  rhythmbox, wine"
}

processArgs() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|-help) usage; exit 1 ;;
      -window) selectWindow && shift ;;
      -twitch-server) require_arg "twitch server" "$1" "$2" && setTwitchServer "$2" && shift 2 ;;
	    -webcam) require_arg "webcamdevice" "$1" "$2" && setWebcam "$2" && shift 2 ;;
      -overlay) require_arg "image file" "$1" "$2" && setOverlayImage "$2" && shift 2 ;;
      *) addPulseArg "$1" && shift ;;
    esac
  done

  # Default to full screen recording.
  if [[ -z "$input_resolution" ]]; then 
  	setFullscreen
  fi
}

processArgs "$@"

echo "Inputs "
echo "========================================="
echo "Webcam            :  $webcam_device"
echo "Webcam Resolution :  $webcam_resolution"
echo "Screen Start      :  $window_position"
echo "Screen Resolution :  $input_resolution"
echo "Twitch Server     :  $twitch_server"
echo "Pulse Args        :  ${pulse_args[@]}"
echo "Filter            :  $(createAvconvFilterString)"

# We just make sure we can find it beofre setting up audio.
ignore_me=$(findTwitchKey)
# setup pulse audio
bash pulse_setup.bash "${pulse_args[@]}"
# start streaming
streamTo "test.mp4"

# TODO - cleanup pulse audio...