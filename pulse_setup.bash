#!/bin/bash

# TODO - Write created devices to a file somewhere and clean that up.


# Setups up a pulse-audio feed with microphone + extras going to recording
# and all the extras still going to the speakers.
declare -r SCRIPT_NAME=${0##*/}

declare verbose=false

# Helpers

# Grabs the client id, given a client name we search for.
paInputSource() {
  echo $(pactl list short sources | grep -i "$1" | head -1 | awk "{ print \$2 }")
}
paClientId() {
  echo $(pactl list short clients | grep "$1" | head -1 | awk "{print \$1}")
}

paSinkId() {
  echo $(pactl list short sinks | grep "$1" | head -1 | awk "{print \$1}")
}

paClientInputId() {
  local CLIENT_ID=$(paClientId "$1")
  echo $(pactl list short sink-inputs | mawk -v check=${CLIENT_ID} '$3 == check {print $1}')
}

paClientOutputId() {
  local CLIENT_ID=$(paClientId "$1")
  echo $(pactl list short source-outputs | mawk -v check=${CLIENT_ID} '$3 == check {print $1}')
}

linkInputToSink() {
  local INPUT=$(paInputSource "$1")
  local OUTPUT="$2"
  pactl load-module module-loopback source=${INPUT} sink=${OUTPUT}
}

moveClientSinks() {
  local INPUT_ID=$(paClientInputId "$1")
  local OUTPUT_ID=$(paSinkId "$2")
  pactl move-sink-input ${INPUT_ID} ${OUTPUT_ID}
  if [[ $? -gt 0 ]]; then
    echo "Failed to connect $INPUT_ID to $OUTPUT_ID"
  fi
}

checkClientExists() {
	# TODO - write
  local name="$1"
  local id=$(paClientId "$name")
  if [[ "$id" == "" ]]; then
    echoerr "[ERROR] No client $name found."
    exit 1
  fi	
}

checkClientSinkExists() {
  # TODO - write
  local name="$1"
  local id=$(paClientInputId "$name")
  if [[ "$id" == "" ]]; then
    echoerr "[ERROR] No client $name found."
    exit 1
  fi  
}

echoerr() {
  $verbose && echo 1>&2 "$@"  
}

# Sources, like microphone
declare -a sources
# Inputs which we do not want to hear on the speakers (like our own microphone)
declare -a inputs
# Inputs we want on the recording *AND* in our speakers
declare -a monitored_inputs
pa_setup=true

require_arg () {
  local type="$1"
  local opt="$2"
  local arg="$3"
  if [[ -z "$arg" ]] || [[ "${arg:0:1}" == "-" ]]; then
    echo "$opt requires <$type> argument"
    exit 1
  fi
}

requireClientWithSink() {
  local source="$1"
  checkClientExists "$source"
  checkClientSinkExists "$source"
}

requireSource() {
  local source=$(paInputSource "$1")
  if [[ "$source" == "" ]]; then
    echoerr "Source $1 does not exist!"
    exit 1
  fi
}

addSource() {
  requireSource "$1"
  sources=( "${sources[@]}" "$1" )
}

addInput() {
  requireClientWithSink "$1"
  inputs=( "${inputs[@]}" "$1" )
}

addMonitoredInput() {
  requireClientWithSink "$1"
  monitored_inputs=( "${silent_inputs[@]}" "$1" )
}

usage() {
  echo ""
  echo "Usage:"
  echo "$SCRIPT_NAME [options]"
  echo "    This script constructs the necessaary pulse-audio sinks"
  echo "    for recording.  There are two sinks created: "
  echo "     * recording_feed_out - for actually recording."
  echo "     * comp_feed_out - for recording & playback through speakers."
  echo
  echo "Options:"
  echo
  echo "  -i <client>          Adds a given pulse audio client to the recording."
  echo "                       You will not be able to hear this input in your speakers."
  echo "  -mi <client>         Adds some monitored input.  This client will be recorded,"
  echo "                       and you'll be able to listen to it."
  echo "  -s  <microphone>     Adds the specified microphone to the recording."
  echo "                       This will not be heard in your headphones."
  echo "  -rhythmbox           Adds rhythmbox to the recording + still in speakers."
  echo "  -skip-setup          Don't create the pulse sinks for recording/playback"
  echo "  -snowball            Add the snowball microphone to the recording."
  echo "  -h                   Display this message"
  echo "  -v                   Verbose script debugging"
  echo

}

process_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|-help) usage; exit 1 ;;
      -i|-input) require_arg "pulse audio client name" "$1" "$2" && addInput "$2" && shift 2 ;;
      -mi|-monitored-input) require_arg "pulse audio client name" "$1" "$2" && addMonitoredInput "$2" && shift 2 ;;
      -s|-source) require_arg "pulse audio source name" "$1" "$2" && addSource "$2" && shift 2 ;;
      -rhythmbox) addMonitoredInput "rhythmbox" && shift ;;
      -snowball) addSource "snowball" && shift ;;
      -skip-setup) pa_setup=false && shift ;;
      -v) verbose=true && shift ;;
      *) echoerr "Unknown argument: $1"; usage; exit 1 ;;
    esac
  done
}


# Basic setup

#  silent_inputs---------------+--> recording_feed --> capture program   
#                             /
#  inputs ---->  comp_feed --+--> hardware_output

basicSetup() {
  echoerr "- Setting up recording + monitor feeds -"
  # Create sinks
  SINK_RECORDING_ID=$(pactl load-module module-null-sink sink_name="recording_feed_out" sink_properties=device.description="RecordingOUT")
  SINK_COMP_ID=$(pactl load-module module-null-sink sink_name="comp_feed_out" sink_properties=device.description="CompFeedOUT")

  echoerr "    * wiring monitor feed into local speakers "
  # Hook the computer feed to the hardware speakers.
  LINK_HW_TO_COMP=$(pactl load-module module-loopback source="comp_feed_out.monitor")

  echoerr "    * hook monitor feed into recording feed"
  # Hook the computer feed to the recording feed.
  LINK_COMP_TO_RECORDING=$(pactl load-module module-loopback source="comp_feed_out.monitor" sink="recording_feed_out")
}

hookSourceInputImpl() {
  echoerr "- Conecting input sources"
  while [[ $# -gt 0 ]]; do 
    echoerr "    * connecting $1..."
    linkInputToSink "$1" "recording_feed_out"
    shift
  done
}

hookSourceInputs() {
  hookSourceInputImpl "${sources[@]}"
}

hookMonitoredInputImpl() {
  echoerr "- Conecting monitored inputs"
  while [[ $# -gt 0 ]]; do 
    echoerr "    * connecting $1..."
    moveClientSinks "$1" "comp_feed_out"
    shift
  done
}
hookMonitoredInputs() {
  hookMonitoredInputImpl "${monitored_inputs[@]}"
}
hookInputImpl() {
  echoerr "- Conecting recorded inputs"
  while [[ $# -gt 0 ]]; do 
    echoerr "    + connecting $1..."
    moveClientSinks "$1" "recording_feed_out"
    shift
  done
}
hookInputs() {
  hookInputImpl "${inputs[@]}"
}

# TODO - Read inputs here and make sure we're recording something.

process_args "$@"


# Check sanity
if [[ ${#sources[@]} -lt 1 ]] && [[ ${#inputs[@]} -lt 1 ]] && [[ ${#monitored_inputs[@]} -lt 1 ]]; then
  echoerr "No inputs defined!"
  usage
  exit 1
fi

echo
echo "Audio Inputs "
echo "========================================="
echo "recorded     : $sources $inputs $monitored_inputs"
echo "monitored    : $monitored_inputs"
echo

if $pa_setup; then
  basicSetup
fi
hookSourceInputs
hookInputs
hookMonitoredInputs
