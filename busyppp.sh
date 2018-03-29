#!/bin/bash

#####  Busyppp  #####
# busyppp.sh is a bash script for dial-up connections that downloads files in the background while you browse.  
# It is self-throttling and uses relatively few system resources. 

# It is not warranted to be error-free and any adverse consequences of its use or misuse are the sole responsibility 
# of the user. 

# busyppp is released as free of charge software, as well as free and open source software, under the 
# GNU General Public License v3.0 by its developer D. G. Demers through the GitHub project page
# https://github.com/dg-demers/busyppp/

# If you have any questions of comments related to busyppp, please contact me by registering for a free account on 
# github.com and creating a new issue for busyppp at 
# https://github.com/dg-demers/busyppp/issues


#####  Overview  #####
# Busyppp controls wget to download files in the background somewhat like Microsoft's BITS, but specifically while you are 
# web browsing. Busyppp is intended to maximize the bytes downloaded on a dial-up connection that is also intermittently  
# used for browsing. 

# Say you have a list of URLs of files to download. Maybe some ISOs, or some Ubuntu or Debian packages, or whatever. Now 
# presumably while surfing the net you will spend some time actually reading webpages that have already loaded. Or maybe you 
# will simply leave the computer temporarily for a short time. That's when busyppp senses you have stopped loading webpages 
# and puts wget to work successively downloading files from your list. But then, you come back and begin loading a new webpage. 
# Soon afterward busyppp will stop the current wget download (by killing wget). And now again, even later, the page loading has 
# finished, and so busyppp starts wget again. And so the cycle repeats. This way every minute of connection time to your ISP 
# can be productive. 

# This strategy makes sense for any internet connection that is billed by the minute rather than by bytes transferred, and that 
# also takes a significant time to connect and disconnect---like a dial-up connection! 

# Busyppp currently does not have a .config file or an interactive way to change its default settings. So, to change a 
# default---with one exception---you will have to modify the script itself. Some such possible changes are discussed in 
# the README.md file. (The README.md file is the only documentation currently available.) 


#####  System Requirements  #####
# Busyppp requires bash, of course, as well as several external processes: wget, beep, pppd, ifstat, and nethogs. So their 
# so- or similar-named packages should be installed and they must be available to be run by the user.

# So far busyppp has only been tested with the following software:  
#   Debian Stretch (Linux kernel release 4.13.0-1-686-pae)
#   xterm 327-2
#   bash 4.4.12
#   wget 1.18
#   beep 1.3
#   pppd 2.4.7
#   ifstat 1.1 with the compiled-in drivers proc and snmp
#   nethogs 0.8.5-37


#####  functions defined  #####
# deathwatch                    # 1 argument  (the process name of a process to be watched until it terminates)
# deletionwatch                 # 1 argument  (the file name of a file to be watched until it no longer exists)
# pppdowncleanup                # 0 arguments
# wgetexitedcleanup             # 0 arguments
# finalcleanup                  # 1 argument  (the exit code busyppp should return)
                                #   RETURNS its argument as the busyppp exit code
# trap_ctrlc                    # 0 arguments
# putnetin                      # 1 argument  (the repeat interval of ifstat's' output, a decimal number of S.T seconds)
                                #   runs in background asynchronously
                                #   RETURNS 1 if there is no network connection of any kind (but return value is not used)
# wgetwrap                      # 0 to multiple arguments (that are all passed to wget)
# startwget                     # 1 argument  (a URL starting with http://, or https://, ftp://, or ftps://, and no or some wget options, all in any order)
# mainloop                      # 1 argument  (a URL starting with http://, or https://, ftp://, or ftps://, and no or some wget options, all in any order)
                                #   RETURNS the wget exit code: 0-8


#####  files used/generated  #####
#
# by default all files are in the current directory/folder
#
# wget-log                      # used in pppdowncleanup (writes), wgetexitedcleanup (reads), finalcleanup (writes), trap_ctrlc (writes), 
                                #         wgetwrap (writes), startwget (writes), mainloop (writes), script body (writes)
# wgetexitfile                  # used in finalcleanup (deletes), wgetwrap (writes), startwget (deletes), mainloop (reads, deletes), script body (deletes)
                                #   temporary, deleted when busyppp stops
# netinfile                     # used in finalcleanup (deletes), putnetin (writes), mainloop (reads), script body (deletes)
                                #   temporary, deleted when busyppp stops; updated (rewritten) every 2 seconds


#####  environment-wise global variables changed and restored  #####
#
# IFS


#####  script-wise global variable declaration and typing  #####
#
declare -i wgetpid;             # used in wgetexitedcleanup,      wgetpid declared as integer; 
                                #         finalcleanup,             normal value: positive integer up to max Linux assigns to pids; 
                                #         startwget, mainloop       used values include 0
declare -ia allkidspids;        # used in finalcleanup            allkidspids declared as integer array; 
                                #                                   normal value: positive integer up to max Linux assigns to pids; 
                                #                                   used values include 0
declare -i thiskidspid;         # used in finalcleanup            thiskidspid declared as integer; 
                                #                                   normal value: positive integer up to max Linux assigns to pids; 
                                #                                   used values include 0
declare oldifs;                 # used in finalcleanup,           oldifs declared as untyped; 
                                #         script body               normal value: general string
declare -i putnetinpid;         # used in finalcleanup,           putnetinpid declared as integer; 
                                #         scriptbody                normal value: positive integer up to max Linux assigns to pids; 
                                #                                   used values include 0
declare wgetlogtail;            # used in wgetexitedcleanup;      wgetlogtail declared as untyped; 
                                #                                   normal value: general string
# Note: must not declare wgetexit as integer to 
# meanifully use UNSET or EMPTY STRING as values
declare wgetexit;               # used in wgetexitedcleanup,      wgetexit declared as untyped; 
                                #         mainloop                  normal value: integer, 0-8 range; 
                                #                                   used values include UNSET

declare -i wgetpidtries;        # used in startget                wgetpidtries declared as integer; 
                                #                                   normal value: integer, 0-3 range (max 3, but may possibly be changed)
declare -i wgetgrgrparentpid;   # used in startwget               wgetgrgrparentpid declared as integer; 
                                #                                   normal value: positive integer up to max Linux assigns to pids; 
                                #                                   used values include 0
declare -i wgetrun;             # used in startwget, mainloop     wgetrun declared as integer; 
                                #                                   normal value: integer, 0-1 range

declare nhline;                 # used in mainloop                nhline declared as untyped; 
                                #                                   normal value: general string
declare bline;                  # used in mainloop                bline declared as untyped; 
                                #                                   normal value: general string (includes EMPTY STRING)
declare bbline;                 # used in mainloop                bbline declared as untyped; 
                                #                                   normal value: general string (excludes EMPTY STRING)
declare wline;                  # used in mainloop                wline declared as untyped; 
                                #                                   normal value: general string (includes EMPTY STRING)
declare brate;                  # used in mainloop                brate declared as untyped; 
                                #                                   normal value: general non-negative floating point number
                                #                                   used values include UNSET

declare -i refreshnumber;       # used in mainloop                refreshnumber declared as integer; 
                                #                                   normal value: integer, 0 up to max bash integer
declare -i stoprefreshnumber;   # used in mainloop                stoprefreshnumber declared as integer; 
                                #                                   normal value: integer, 8 up to max bash integer (min 8=4+1+3, but may possibly be changed)
declare -i bratelowtimes;       # used in mainloop                bratelowtimes declared as integer; 
                                #                                   normal value: integer, 0 up to max bash integer
declare -i wgetrerun;           # used in mainloop                wgetrerun declared as integer; 
                                #                                   normal value: integer, 0-2 range
declare -i wgetexittries;       # used in mainloop                wgetexittries declared as integer; 
                                #                                   normal value: integer, 0-3 range (max 3, but may possibly be changed)
declare -i netintries;          # used in mainloop                netintries declared as integer; 
                                #                                   normal value: integer, 0-3 range (max 3, but may possibly be changed)


declare LINE;                   # used in script body             LINE declared as untyped; 
                                #                                   normal value: general string
declare -a LINES;               # used in script body             LINES declared as array; 
                                #                                   normal value (of elements): general string
declare -i isfilename;          # used in script body             isfilename declared as integer; 
                                #                                   normal value: integer, 0-1 range
declare -i lastIndex;           # used in script body             lastIndex declared as integer; 
                                #                                   normal value: integer, 1 up to max bash integer
declare -i j;                   # used in script body             j declared as integer; 
                                #                                   normal value: integer, 1 up to max bash integer
declare -i k;                   # used in script body             k declared as integer; 
                                #                                   normal value: integer, 1 up to max bash integer
declare -i usableURLs;          # used in script body             usableURLs declared as integer; 
                                #                                   normal value: integer, 0 up to max bash integer
declare -i mainloopexit;        # used in script body             mainloopexit declared as integer; 
                                #                                   normal value: integer, 0-8 range
declare sleeptime;              # used in script body             sleeptime declared as untyped; 
                                #                                   normal value: general non-negative floating point number


#####  function-wise local variable declaration and type  #####
###        in function putnetin        ###
# declare ifstatline="";        # locally declared untyped in and used in putnetin; normal value: general string
# declare netin="";             # locally declared untyped in and used in putnetin; normal value: general string
# declare -i j=0;               # locally declared integer in and used in putnetin; normal value: integer, 0-3 range


${IFS+"false"} && unset oldifs || oldifs="$IFS"   # correctly store IFS

deathwatch() { 
  while [ -e /proc/"$1" ]; do sleep 0.5; done; 
}; 

deletionwatch() { 
  while [ -e "$1" ]; do sleep 0.5; done; 
}; 

pppdowncleanup() { 
  beep -f 4500 -l 200 -r 5 -d 400; 
  echo; 
  echo "busyppp ERROR code 10:  FAILED:  The ppp network interface is or went down"; 
  echo "  (re-)start it if desired and possible"; 
  echo -e $'\n'$'\n'"busyppp ERROR code 10:  FAILED:  The ppp network interface is or went down" >>wget-log; 
  echo "  (re-)start it if desired and possible" >>wget-log; 
  finalcleanup 10;    # set final exit/error code to 10 
}; 

wgetexitedcleanup() { 
  # declare wgetlogtail;    # globally declared untyped at top of script
  # declare wgetexit;       # globally declared untyped at top of script
  # declare -i wgetpid;     # globally declared integer at top of script
  echo; 
  echo "tail end of wget-log follows:"; 
  wgetlogtail=$(tail "wget-log"); 
  sed '/^$/d' <<<"$wgetlogtail";  # sed to remove blank lines
  if ((wgetexit));  # this gives true for a non-zero value
  then 
    echo -e $'\n'"wget ERROR code $wgetexit:  wget FAILED." >>wget-log; 
    echo "  Please find code $wgetexit in the wget documentation (try man wget)." >>wget-log; 
  fi; 
  # now make sure wget is dead
  ((wgetpid)) && ps -q "$wgetpid" >/dev/null && kill -2 "$wgetpid" && deathwatch "$wgetpid" && { echo; echo "wget stopped (but it should have already been dead)"; }; 
  beep -f 3900 -l 200 -r 5 -d 400; 
}; 

finalcleanup() { 
  # declare -i wgetpid;         # globally declared integer at top of script
  # declare -i putnetinpid;     # globally declared integer at top of script
  # declare -ia allkidspids;    # globally declared integer array at top of script
  # declare -i thiskidspid;     # globally declared integer at top of script
  # declare oldifs;             # globally declared untyped at top of script
  echo -e $'\n'"STOPPED" >>wget-log; 
  echo "------------------------------------------------------------" >>wget-log; 
  echo; 
  echo "busyppp is stopping now"; 
  echo; 
  echo "Doing final cleanup:"; 
  echo "please wait"; 
  ((wgetpid)) && ps -q "$wgetpid" >/dev/null && kill -2 "$wgetpid" && deathwatch "$wgetpid" && echo "  wget stopped"; 
  ((putnetinpid)) && ps -q "$putnetinpid" >/dev/null && kill -2 "$putnetinpid" && deathwatch "$putnetinpid" && echo "  putnetin stopped"; 
  allkidspids=($(pgrep $$)); 
  for thiskidspid in "${allkidspids[@]}"; 
  do 
    ((thiskidspid)) && ps -q "$thiskidspid" && kill "$thiskidspid"; 
    wait "$thiskidspid" 2>/dev/null; 
  done; 
  echo "  deleting some auxiliary files (if they exist)"; 
  sleep 1; 
  [ -e netinfile ] && rm netinfile >/dev/null && deletionwatch netinfile && echo "    netinfile deleted"; 
  [ -e wgetexitfile ] && rm wgetexitfile >/dev/null && deletionwatch wgetexitfile && echo "    wgetexitfile deleted"; 
  sleep 1; 
  ${oldifs+"false"} && unset IFS || IFS="$oldifs"    # restore IFS
  echo; echo "bye-bye"; 
  exit "$1"; 
}; 

trap_ctrlc() { 
  echo; 
  echo "busyppp EXIT code 9:  CTRL+C was pressed."; 
  echo "  Stopping normally by your request."; 
  echo -e $'\n'$'\n'"busyppp EXIT code 9:  CTRL+C was pressed." >>wget-log; 
  echo "  Stopping normally by your request." >>wget-log; 
  finalcleanup 9;   # set final exit/error code to 9
}; 

trap trap_ctrlc SIGINT; 

[ -e netinfile ] && rm netinfile >/dev/null && deletionwatch netinfile && echo "netinfile deleted"; 
[ -e wgetexitfile ] && rm wgetexitfile >/dev/null && deletionwatch wgetexitfile && echo "wgetexitfile deleted"; 

pgrep -x pppd >/dev/null || pppdowncleanup;   # sets the final exit/error code to 10 meaning the ppp network interface went down

putnetin() { 
  declare ifstatline=""; 
  declare netin=""; 
  declare -i j=0; 
  { 
    while IFS=$' \t\n' read -r ifstatline; 
    do 
      if ((j <= 2)); 
      then 
        j+=1; 
      else
        netin=$(awk '{print $1}' <<<"$ifstatline"); 
        if [[ $netin == "n/a" ]]; 
        then 
          return 1; 
        fi; 
        echo "$netin" >netinfile; 
      fi; 
    done; 
  } < <(ifstat -zwn "$1"); # removed -b to change to kB/s from kbps 
}; 

wgetwrap() { 
  wget "$@" 2>&1 | tee -a wget-log; 
  echo "${PIPESTATUS[0]}" >wgetexitfile; 
}

export -f wgetwrap; 

startwget() { 
  wgetgrgrparentpid=0;  # globally declared integer at top of script
  wgetpid=0;            # globally declared integer at top of script
  wgetpidtries=1;       # globally declared integer at top of script
  wgetrun=1;            # globally declared integer at top of script
                        # set the wgetrun last state to 1
  [ -e wgetexitfile ] && rm wgetexitfile >/dev/null && deletionwatch wgetexitfile; 
  { echo "$1" | sed 's/[ ]\+\[[^]\[]*]$//' | xargs bash -c 'wgetwrap "$@"' _ --limit-rate=4k -nd --read-timeout=600 -t 0 -c -v --progress=dot:giga -a wget-log; } & wgetgrgrparentpid=$!; 
  ((wgetgrgrparentpid)) && wgetpid="$(pstree "$wgetgrgrparentpid" -pnAl | cut -d\( -f5 | cut -d\) -f1)"; 
  until ((wgetpid)); 
  do 
    if ((wgetpidtries >= 4)); # for loop sleep 0.50: give up after 1.5 seconds = 4 tries max 
    then 
      break;  # leave the loop
    else 
      sleep 0.50; 
      wgetpidtries+=1; 
      wgetpid=0; 
      ((wgetgrgrparentpid)) && wgetpid="$(pstree "$wgetgrgrparentpid" -pnAl | cut -d\( -f5 | cut -d\) -f1)"; 
    fi; 
  done; 
}; 

mainloop() { 
  nhline="";                # globally declared untyped at top of script
  bbline="Browser 0.000";   # globally declared untyped at top of script
  bline="";                 # globally declared untyped at top of script
  brate=;                   # globally declared untyped at top of script
  wline="";                 # globally declared untyped at top of script
  refreshnumber=0;          # globally declared integer at top of script
  stoprefreshnumber=0;      # globally declared integer at top of script
  bratelowtimes=0;          # globally declared integer at top of script
  wgetrun=0;                # globally declared integer at top of script
                            #   set the wgetrun last state to 0
  wgetrerun=0;              # globally declared integer at top of script
  wgetpid=0;                # globally declared integer at top of script
  wgetexit=;                # globally declared untyped at top of script
  wgetexittries=0;          # globally declared integer at top of script
  netintries=0;             # globally declared integer at top of script
  {
    while IFS=$' \t\n' read -r nhline; 
    do 
      pgrep -x pppd >/dev/null || pppdowncleanup;   # sets the final exit/error code to 10 meaning the ppp network interface went down
      bline="$(grep -E "midori|xombrero|chrome" <<<"$nhline")"; 
      [ -z "$bline" ] || bbline=$bline; 
      ((wgetpid)) && wline=$(grep "$wgetpid" <<<"$nhline"); 
      if [ -n "$wline" ]; 
      then 
        tput cuu 2; # move cursor 2 lines up
        echo "RUN wget: $(awk '{print $NF}' <<<"$wline") KB/s"; 
        echo; 
      fi; 
      if fgrep "Refreshing:" <<<"$nhline" >/dev/null;  # if this is a refresh line, update screen & choose to continue/start or keep stopped/stop wget
      then 
        refreshnumber+=1;  # increment nethogs refresh cycle number
        if ((refreshnumber <= 2)); 
        then 
          echo "refresh $refreshnumber/2:  waiting for network stats to stabilize"; 
          ((refreshnumber == 2)) && echo; 
        else # opening the "if ((refreshnumber <= 2)); else" conditional branch
          if ! ((wgetrun)); 
          then # opening the "if ! ((wgetrun)); then" conditional branch
            brate=;  # initialize brate to UNSET
            netintries=0; # initialize loop counter to 0
            while ((netintries <= 2)); # for loop sleep 0.50: give up after 1.0 seconds = 3 tries max
            do
              if [ -s netinfile ]; 
              then 
                brate=$(< netinfile); 
                until [ -n "$brate" ]; 
                do 
                  if ((netintries > 2)); # for loop sleep 0.50: give up after 1.0 seconds = 3 tries max
                  then 
                    break 2;  # leave the netintries do loop (and this inner loop) 
                  else 
                    netintries+=1; 
                    brate=$(< netinfile); 
                    sleep 0.50; 
                  fi; 
                done;  # closing the "until [ -n "$brate" ]; do" loop
                break;  # leave the netintries do loop
              else 
                netintries+=1; 
                sleep 0.50; 
              fi; 
            done;  # closing the "((netintries <= 2)); do" loop
            if [ -z "$brate" ];    # this gives true for UNSET and the empty string, but not the value 0 AND is portable
            then 
              echo; 
              echo "busyppp ERROR code 12:  FAILED to read brate (the network stats) from the file netinfile after 1.0 seconds = 3 tries"; 
              echo "This is a FATAL error. Maybe the system is too busy right now; try again after closing some programs."; 
              echo "  Or maybe the program/package \"ifstat\" is not installed and runnable; consider checking it."; 
              echo -e $'\n'"busyppp ERROR code 12:  FAILED to read brate (the network stats) from the file netinfile after 1.0 seconds = 3 tries" >>wget-log; 
              echo "This is a FATAL error. Maybe the system is too busy right now; try again after closing some programs." >>wget-log; 
              echo "  Or maybe the program/package \"ifstat\" is not installed and runnable; consider checking it." >>wget-log; 
              sleep 2; 
              finalcleanup 12;   # set final exit/error code to 12
            fi; 
          elif ((refreshnumber <= stoprefreshnumber)); 
          then 
            brate="0.00000";  # if $refreshnumber (nethogs refresh cycle number) is <= $stoprefreshnumber inhibit stopping wget while $brate may be jittery
          else 
            brate=$(awk '{print $NF}' <<<"$bbline"); 
          fi; # closing the "if ! ((wgetrun)); elif..." conditional branch
          echo " Browser: $brate KB/s"; 
          ((wgetrerun >= 2)) && wgetrerun=0; 
          ((wgetrerun)) && wgetrerun=2; 
          if (($(bc <<< "$brate < 0.40")));  # 0.40 kiB/s is the browser data rate in threshold for running/stopping wget
          then  # opening the "if (($(bc <<< "$brate < 0.40"))); then" conditional branch
            bratelowtimes+=1; 
            if ((bratelowtimes >= 2));  # browser data rate in must be below threshold for at least 2 consective refresh cycles to start/continue running wget
            then  # opening the "if ((bratelowtimes" >= 2)); then" conditional branch (within the "if (($(bc <<< "$brate < 0.40"))); then" conditional branch)
              echo "RUN wget"; echo; 
              if ((wgetrun));  # was the last attempt to change wget's state in the direction STOPPED-->STARTED?
              then 
                if ((wgetpid)) && ps -q "$wgetpid" >/dev/null;  # is the last started instance of wget actually still running?
                then 
                  :;  # wget is still running, so do nothing
                else  # wget has stopped running, now try to get its exit code
                  wgetexit=;  # initialize wgetexit to UNSET
                  wgetexittries=0; # initialize loop counter to 0
                  while ((wgetexittries <= 2)); # for loop sleep 0.50: give up after 1.0 seconds = 3 tries max
                  do
                    if [ -s wgetexitfile ]; 
                    then 
                      wgetexit=$(< wgetexitfile); 
                      until [ -n "$wgetexit" ]; 
                      do 
                        if ((wgetexittries > 2)); # for loop sleep 0.50: give up after 1.0 seconds = 3 tries max
                        then 
                          break 2;  # leave the wgetexittries do loop (and this inner loop)
                        else 
                          wgetexittries+=1; 
                          wgetexit=$(< wgetexitfile); 
                          sleep 0.50; 
                        fi; 
                      done;  # closing the "until [ -n "$wgetexit" ]; do" loop
                      rm wgetexitfile >/dev/null && deletionwatch wgetexitfile; 
                      break;  # leave the wgetexittries do loop
                    else 
                      wgetexittries+=1; 
                      sleep 0.50; 
                    fi; 
                  done;  # closing the "while ((wgetexittries <= 2)); do" loop
                  if [ -z "$wgetexit" ];    # this gives true for UNSET and the empty string, but not the value 0 AND is portable
                  then 
                    echo; 
                    echo "busyppp ERROR code 11:  FAILED to read wgetexit from wgetexitfile after 1.0 seconds = 3 tries"; 
                    echo "This is a FATAL error. Maybe the system is too busy right now; try again after closing some programs."; 
                    echo "busyppp ERROR code 11:  FAILED to read wgetexit from wgetexitfile after 1.0 seconds = 3 tries" >>wget-log; 
                    echo "This is a FATAL error. Maybe the system is too busy right now; try again after closing some programs." >>wget-log; 
                    sleep 2; 
                    finalcleanup 11;   # set final exit/error code to 11
                  else  # opening the "if [ -z "$wgetexit" ]; else" conditional branch
                    if ! ((wgetexit));  # this gives true for the value 0
                    then 
                      echo; 
                      echo "File already downloaded or just finished downloading - nothing to do"; 
                      wgetexitedcleanup; 
                      return 0;  # set mainloop exit/error code to 0
                    elif ! ((wgetexit == 4)); 
                    then 
                      echo; 
                      echo "wget ERROR code $wgetexit:  wget FAILED."; 
                      echo "  Please find code $wgetexit in the wget documentation (try man wget)."; 
                      if ((wgetexit == 1)); 
                      then 
                        echo "  But for GNU wget 1.18, code 1 means:  \"Generic error code.\""; 
                        wgetexitedcleanup; 
                        echo "  But for GNU wget 1.18, code 1 means:  \"Generic error code.\"" >>wget-log; 
                      elif ((wgetexit == 2)); 
                      then 
                        echo "  But for GNU wget 1.18, code 2 means:  \"Parse error---for instance, when parsing command-line options, etc.\""; 
                        wgetexitedcleanup; 
                        echo "  But for GNU wget 1.18, code 2 means:  \"Parse error---for instance, when parsing command-line options, etc.\"" >>wget-log; 
                      elif ((wgetexit == 3)); 
                      then 
                        echo "  But for GNU wget 1.18, code 3 means:  \"File I/O error.\""; 
                        wgetexitedcleanup; 
                        echo "  But for GNU wget 1.18, code 3 means:  \"File I/O error.\"" >>wget-log; 
                      elif ((wgetexit == 5)); 
                      then 
                        echo "  But for GNU wget 1.18, code 5 means:  \"SSL verification failure.\""; 
                        echo "  But for GNU wget 1.18, code 5 means:  \"SSL verification failure.\"" >>wget-log; 
                      elif ((wgetexit == 6)); 
                      then 
                        echo "  But for GNU wget 1.18, code 6 means:  \"Username/password authentication failure.\""; 
                        wgetexitedcleanup; 
                        echo "  But for GNU wget 1.18, code 6 means:  \"Username/password authentication failure.\"" >>wget-log; 
                      elif ((wgetexit == 7)); 
                      then 
                        echo "  But for GNU wget 1.18, code 7 means:  \"Protocol errors.\""; 
                        wgetexitedcleanup; 
                        echo "  But for GNU wget 1.18, code 7 means:  \"Protocol errors.\"" >>wget-log; 
                      elif ((wgetexit == 8)); 
                      then 
                        echo "  But for GNU wget 1.18, code 8 means:  \"Server issued an error response.\""; 
                        wgetexitedcleanup; 
                        echo "  But for GNU wget 1.18, code 8 means:  \"Server issued an error response.\"" >>wget-log; 
                      else 
                        echo "  Also, code $wgetexit is not in the GNU wget 1.18 documentation, but it may be in the docs for a later version."; 
                        echo "  Or, if it's 126-165, or 255, it may be an exit/error code generated by the bash shell or Linux with a special meaning."; 
                        wgetexitedcleanup; 
                        echo "  Also, code $wgetexit is not in the GNU wget 1.18 documentation, but it may be in the docs for a later version." >>wget-log; 
                        echo "  Or, if it's 126-165, or 255, it may be an exit/error code generated by the bash shell or Linux with a special meaning." >>wget-log; 
                      fi; 
                      return "$wgetexit";   # set mainloop exit/error code to "$wgetexit"
                    elif ((wgetrerun == 2)); 
                    then 
                      echo; 
                      echo "wget ERROR code 4:  wget FAILED."; 
                      echo "  For GNU wget 1.18 code 4 means:  \"Network failure.\""; 
                      echo "Also busyppp FAILED to start this download twice in a row."; 
                      echo "  Giving up on the current download for now. But busyppp will try the next download (if there is one in file ${1})."; 
                      wgetexitedcleanup; 
                      echo -e $'\n'"wget ERROR code 4:  wget FAILED." >>wget-log; 
                      echo "  For GNU wget 1.18 code 4 means:  \"Network failure.\"" >>wget-log; 
                      echo "Also busyppp FAILED to start this download twice in a row." >>wget-log; 
                      echo "  Giving up on the current download for now. But busyppp will try the next download (if there is one in file ${1})." >>wget-log; 
                      return 4;   # set mainloop exit/error code to 4
                    else 
                      echo "wget ERROR code 4:  wget FAILED."; 
                      echo "  For GNU wget 1.18 code 4 means:  \"Network failure.\""; 
                      echo -e  "  But busyppp will try to re-start this same download now."$'\n'; 
                      echo -e $'\n'"wget ERROR code 4:  wget FAILED." >>wget-log; 
                      echo "  For GNU wget 1.18 code 4 means:  \"Network failure.\"" >>wget-log; 
                      echo -e  "  But busyppp will try to re-start this same download now."$'\n' >>wget-log; 
                      wgetrerun=1;  # initialize the wgetrerun refresh cycle counter
                      startwget "$1";  # the wget (re-)start code has been abstracted into this function 
                    fi;   # closing the "if ! ((wgetexit)); then..." conditional chain
                  fi;   # closing the "if [ -z "$wgetexit" ]; else" conditional branch
                fi;   # closing the "if ((wgetpid)) && ps -q "$wgetpid" >/dev/null; else" conditional branch
              else  # opening the "if ((wgetrun)); else" conditional branch 
                beep -f 480 -r 2;   # 2 high-pitched beeps
                ((refreshnumber == 4)) || stoprefreshnumber=$((refreshnumber + 3));  # inhibit stopping wget for next 3 nethogs refresh cycles if this is not the 4th cycle
                startwget "$1";  # the wget (re-)start code has been abstracted into this function
              fi;   # closing the "if ((wgetrun)); else" conditional branch
            fi;   # closing the "if ((bratelowtimes >= 2)); then" conditional branch (within the "if (($(bc <<< "$brate < 0.40"))); then" conditional branch)
          else  # opening the "if (($(bc <<< "$brate < 0.40"))); else" conditional branch, the (the "STOP wget") conditional branch
            echo "STOP wget"; 
            echo; 
            ((wgetpid)) && ps -q "$wgetpid" >/dev/null && kill -2 "$wgetpid" && deathwatch "$wgetpid"; 
            bratelowtimes=0; 
            if ((wgetrun)); 
            then
              beep -f 180 && echo -e $'\n' >>wget-log;  # one low-pitched beep
              wgetrun=0;  # set the wgetrun last state to 0
              wgetpid=0; 
            fi; 
          fi; # closing the "if (($(bc <<< "$brate < 0.40"))); else" conditional branch, the (the "STOP wget") conditional branch
          bline="";   # set bline to empty string as default
          bbline="Browser 0.00";   # brate set to 0.00 KB/s - default if no nonempty bline occurs in a refresh cycle
          wline="";   # set wline to empty string as default
        fi;   # closing the "if ((refreshnumber <= 2)); else" conditional branch
      fi;   # closing the "if fgrep "Refreshing:" <<<$nhline >/dev/null; then" conditional branch
    done; # closing the "while IFS=$' \t\n' read -r nhline; do" loop, the main loop reading lines of on-going output from nethogs
  } < <(nethogs -t -d 2 ppp0 &); 
}; 

# declare -i putnetinpid;     # globally declared integer at top of script
# declare -a LINES;           # globally declared array at top of script
# declare LINE;               # globally declared untyped at top of script
# declare -i isfilename;      # globally declared integer at top of script
# declare -i lastIndex;       # globally declared integer at top of script
# declare -i j;               # globally declared integer at top of script
# declare -i usableURLs;      # globally declared integer at top of script
# declare -i mainloopexit;    # globally declared integer at top of script
# declare -i sleeptime;       # globally declared integer at top of script
(putnetin 2.0) & putnetinpid=$!; 
if [[ $1 == http://* || $1 == https://* || $1 == ftp://* || $1 == ftps://* ]]; 
then
  IFS='^' read -r -a LINES <<< "$1"; 
  isfilename=0; 
elif [ -s "$1" ]; 
then 
  readarray -t LINES < "$1"; 
  isfilename=1; 
else
  echo; 
  echo "busyppp ERROR code 13:  FAILED:  the command-line argument \"$1\" is not a usable list of URLs"; 
  echo "  or isn't the name of a non-empty file in the current folder"; 
  echo -e $'\n'"busyppp ERROR code 13:  FAILED:  the command-line argument \"$1\" is not a usable list of URLs" >>wget-log; 
  echo "  or isn't the name of a non-empty file in the current folder" >>wget-log; 
  finalcleanup 13;  # set final exit/error code to 13
fi; 
lastIndex=${#LINES[@]}; 
j=1; 
usableURLs=0; 
for LINE in "${LINES[@]}"; 
do 
  LINE=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<${LINE}); 
  if [[ ! $LINE == \#* && $LINE = *[![:space:]]* ]]; 
  then
    usableURLs+=1; 
    if ((isfilename)); 
    then 
      echo -e $'\n'$'\n'"Downloading the file with URL & any wget options (line # $j of $lastIndex in the URL list file $1):"; 
      echo "$LINE"; 
      echo -e $'\n'$'\n'"Downloading the file with URL & any wget options (line # $j of $lastIndex in the URL list file $1):" >>wget-log; 
      echo -e "$LINE"$'\n' >>wget-log; 
      echo; 
    else 
      echo -e $'\n'$'\n'"Downloading the file with URL & any wget options (item # $j of $lastIndex in the URL list argument):"; 
      echo "$LINE"; 
      echo -e $'\n'$'\n'"Downloading the file with URL & any wget options (item # $j of $lastIndex in the URL list argument):" >>wget-log; 
      echo -e "$LINE"$'\n' >>wget-log; 
      echo; 
    fi; 
    sleep 1.0;  # some delay to allow the lines above like "Downloading the URL & any wget options in the # $j of..." to finish writing to wget-log 
    mainloop "$LINE"; 
    mainloopexit=$?; 
    if ((isfilename)); 
    then 
      if [ -n "$mainloopexit" ] && ! ((mainloopexit));   # just to be safe check for empty string or unset variable
      then 
        echo; 
        echo "Prepending \"#D \" to line # $j of $lastIndex in the list $1 containing this file's URL & any wget options:"; 
        echo "${LINES[j - 1]}"; 
        echo "Prepending \"#D \" to line # $j of $lastIndex in the list $1 containing this file's URL & any wget options" >>wget-log; 
        LINES[j - 1]="#D ${LINES[j - 1]}"; 
        printf "%s\n" "${LINES[@]}" >"$1"; 
        echo "DONE prepending"; 
      else 
        echo; 
        echo "Giving up on the current download for now. But busyppp will try the next download (if there is one in file ${1})."; 
        echo -e $'\n'"Giving up on the current download for now. But busyppp will try the next download (if there is one in file ${1})." >>wget-log; 
        echo; 
        echo "Prepending \"#E $mainloopexit \" ($mainloopexit is the ERROR CODE) to line # $j of $lastIndex in the list $1 containing this file's URL & any wget options:"; 
        echo "${LINES[j - 1]}"; 
        echo "Prepending \"#E $mainloopexit \" ($mainloopexit is the ERROR CODE) to line # $j of $lastIndex in the list $1 containing this file's URL & any wget options" >>wget-log; 
        LINES[j - 1]="#E $mainloopexit ${LINES[j - 1]}"; 
        printf "%s\n" "${LINES[@]}" >"$1"; 
        echo "DONE prepending"; 
      fi; 
    else  
      if [ -n "$mainloopexit" ] && ! ((mainloopexit));   # just to be safe check for empty string or unset variable
      then 
        echo; 
        echo "Prepending \"#D \" to line # $j of $lastIndex in the URL list argument containing this file's URL & any wget options:"; 
        echo "${LINES[j - 1]}"; 
        echo "Prepending \"#D \" to line # $j of $lastIndex in the URL list argument containing this file's URL & any wget options" >>wget-log; 
        LINES[j - 1]="#D ${LINES[j - 1]}"; 
        echo "DONE prepending"; 
      else 
        echo; 
        echo "Giving up on the current download for now. But busyppp will try the next download (if there is one in the URL list argument)."; 
        echo -e $'\n'"Giving up on the current download for now. But busyppp will try the next download (if there is one in the URL list argument)." >>wget-log; 
        echo; 
        echo "Prepending \"#E $mainloopexit \" ($mainloopexit is the ERROR CODE) to line # $j of $lastIndex in the URL list argument containing this file's URL & any wget options:"; 
        echo "${LINES[j - 1]}"; 
        echo "Prepending \"#E $mainloopexit \" ($mainloopexit is the ERROR CODE) to line # $j of $lastIndex in the URL list argument containing this file's URL & any wget options" >>wget-log; 
        LINES[j - 1]="#E $mainloopexit ${LINES[j - 1]}"; 
        echo "DONE prepending"; 
      fi; 
    fi; 
    sleeptime=2; 
  else
    sleeptime=1; 
  fi; 
  sleep "$sleeptime"; 
  j+=1; 
done;   # closing "for LINE in "${LINES[@]}"; do" loop
if ((usableURLs)); 
then 
  if ((isfilename)); 
  then 
    echo; 
    echo; 
    echo "busyppp tried to download all files from the list in file $1"; 
    echo "  but some may not have been downloaded"; 
    echo -e $'\n'"busyppp tried to download all files from the list in file $1" >>wget-log; 
    echo "  but some may not have been downloaded" >>wget-log; 
  else 
    echo; 
    echo; 
    echo "busyppp tried to download all files in its URL list argument:"; 
    echo; 
    k=0; 
    for LINE in "${LINES[@]}"; 
    do 
      k+=1; 
      LINE=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<${LINE}); 
      echo "$k. $LINE"; 
      echo; 
    done; 
    echo "  but some may not have been downloaded"; 
    echo -e $'\n'"busyppp tried to download all files in its URL list argument:"$'\n' >>wget-log; 
    k=0; 
    for LINE in "${LINES[@]}"; 
    do 
      k+=1; 
      LINE=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<${LINE}); 
      echo -e "$k. $LINE"$'\n' >>wget-log; 
    done; 
    echo "  but some may not have been downloaded" >>wget-log; 
  fi; 
  finalcleanup 0; 
else 
  echo; 
  echo "busyppp ERROR code 14:  FAILED:  All lines the URL list file $1 are either blank or are commented out by an initial hash mark \#."; 
  echo "  No downloads can be attempted."; 
  echo -e $'\n'"busyppp ERROR code 14:  FAILED:  All lines the URL list file $1 are either blank or are commented out by an initial hash mark \#." >>wget-log; 
  echo "  No downloads can be attempted." >>wget-log; 
  finalcleanup 14; # set final exit/error code to 14
fi; 

echo; 
echo "busyppp ERROR code 99:  FAILED:  This is a very abnormal exit code."; 
echo -e $'\n'"busyppp ERROR code 99:  FAILED:  This is a very abnormal exit code" >>wget-log; 
finalcleanup 99;  # set final exit/error code to 99, meaning very abnormal because busyppp should never exit from here
