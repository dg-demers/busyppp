# busyppp
busyppp.sh is a bash script for dial-up connections that downloads files in the background while you browse


#####  Overview  #####
Busyppp controls wget to download files in the background somewhat like Microsoft's BITS, but specifically while you are 
web browsing. Busyppp is intended to maximize the bytes downloaded on a dial-up connection that is also intermittently being 
used for browsing. That way you can productively use every minute of connection time to your ISP. 

Say you have a list of URLs of files to download. Maybe some ISOs, or some Ubuntu or Debian packages, or whatever. Now 
presumably while surfing the net you will spend some time actually reading webpages that have already loaded. Or maybe you 
will simply leave the computer temporarily for a short time. That's when busyppp senses you have stopped loading webpages 
and puts wget to work successively downloading files from your list. But then, you come back and begin loading a new webpage. 
Soon afterward busyppp will stop the current wget download (by killing wget). And now again, even later, the page loading has 
finished, and so busyppp starts wget again. And so the cycle repeats. 

This strategy makes sense for any internet connection that is billed by minute rather than by bytes, and that takes a significant 
time to connect and disconnect---like a dial-up connection! 

Busyppp currently does not have an interactive way to change its default settings. So if you want to change a setting---with one 
exception---you will have to modify the script's code. Some such possible changes are discussed later in these notes. 


#####  System Requirements  #####
Busyppp requires bash, of course, as well as several external processes: wget, beep, ifstat, and nethogs. So their 
so-named packages should be installed and they must be available to be run by the user.

So far busyppp has only been tested with the following software:  
  Debian Stretch (Linux kernel release 4.13.0-1-686-pae)  
  xterm 327-2  
  bash 4.4.12  
  wget 1.18  
  beep 1.3  
  ifstat 1.1 with the compiled-in drivers proc and snmp   
  nethogs 0.8.5-37

It's convenient to allow non-root users to be able to run nethogs. This can be accomplished by setting the 
cap_net_admin and cap_net_raw capabilities for it with the setcap command. For details see  
  https://github.com/raboof/nethogs/README.md


In addition, to hear the helpful beep cues (see the section below with that title) you must set up your system to beep. It seems the default 
in some Linux distributions is to turn off the ability to beep. To find out how to turn it back on see, for example,  
  https://askubuntu.com/questions/277215/make-a-sound-once-process-is-complete

And beep itself needs to have its suid bit set. See  
  https://github.com/johnath/beep


#####  Downloaded and Wget Log Files  #####
The files busyppp downloads are saved in the current directory/folder (unless otherwise specified with a user-provided wget command-line option). 

Busyppp also creates (if nonexistent) or appends to the wget log file, named by default "wget-log," in the current directory/folder. Wget, of 
course, also writes to wget-log, so busyppp augments the wget log file with its own report of what is happening. The user should not change the 
name and location of this file with a wget option unless all occurrences of the file name "wget-log" in the script are also so changed.


#####  Auxiliary Files Used by Busyppp  #####
During operation a couple of temporary files are created in the current directory/folder, and written to and read by busyppp. These two files are 
named wgetexitfile and netinfile. 

Busyppp does not respect any preexisting files with these names: If they exist just after busyppp starts, it deletes them, (because they should have been 
deleted during a previous termination of busyppp). While running it usually first creates and then repeatedly overwrites them. And, finally, before 
it stops executing busyppp deletes these two files. 


#####  Terminal Messages  #####
Busyppp also reports what's happening every 2 seconds to the terminal window. It works in "trace mode" with the latest printout at the bottom of the 
window and earlier messages scrolling off the top of the terminal window. Busyppp's scrolling output includes the download rate of both the browser 
and wget, and whether wget is running or stopped, as well as some other messages. 


#####  Beep Cues  #####
In addition to what it reports in the terminal window busyppp also uses pc speaker beeps (through the beep package) as audio cues about the state 
of wget's downloading. It gives one low-pitched beep when wget is stopped by busyppp and two short high-pitched beeps when wget is about to be started. 

You'll also hear five long higher-pitched beeps when wget either finishes downloading a file or gives up on trying to download it due to a wget error. 
Finally, busyppp sounds five long even higher-pitched beeps if the ppp network interface is or just went down.


#####  Command-Line Arguments -- Download Lists #####
Busyppp takes one argument which should be a list of caret (^)-separated URLs of files to download with the whole list enclosed in single-quotes ('), 
for example,  
    $ ~/Scripts/busyppp.sh 'https://somewhere.de/somepdf.pdf ^ http://someplace.au/apackage.deb'  
  OR the name of a file (in the current directory/folder) which contains a list of URLs for the files to download, 
  one per line (but not single-quote (') enclosed and not using the caret as a separator).

Terminology: We will call the first case a "download list argument" or a "URL list argument,"  and the second case a 
"download list file" or a "URL list file." The generic case will just be called a "download list" or a "URL list" without 
specifying "argument" or "file." 

In both cases the URLs may be accompanied by the usual wget command-line options. 

For a busyppp download list argument, the list must immediately start (after the leading single quote) with 
a URL as in http://..., https://..., ftp://..., or ftps://... . After this first item the order URLs and wget options in each item doesn't matter.

For a download list file, in each line of the file the URL and any wget options may be in any order, but any option 
containing spaces, such as a --user-agent option, should be enclosed in single-quotes like this,  
  '--user-agent="Mozilla/5.0 (Windows NT 10.0; WOW64; rv:45.0) Gecko/20100101 Firefox/45.0"'

Also, any line of the file that is blank or starts with a hash mark (#) is not given to wget for downloading by busyppp.

And in both cases the URL plus wget option items may include an optional terminal comment enclosed in square brackets that is ignored by wget, like  
  --limit-rate=1k http://people.au/apackage.deb  [optional comment]


#####  Overwriting the Download List File  #####
Recall that for a download list file any line that is blank or that starts with a hash mark (#) is ignored by busyppp (and wget). 
Busyppp will overwrite each non-blank and non-hash mark (#) commented line of this file according the success or not of its attempt to download the 
file from the URL in the line.

  If wget was able to finish downloading the file, busyppp prepends #D followed by a space to the line containing it.  
  But if wget's attempt to a download the file produces a wget-specific error, busyppp prepends #E, a space, then the wget error code, and finally 
  a space to the line containing the file's URL.  
  No changes are made to the line if busyppp (and wget) were stopped mid-download by pressing CTRL+C. 

Upon termination busyppp writes, using the same codes, a report of the download results to both the terminal window and the file wget-log. It does this 
for both a download list file and a download list argument. 


#####  Busyppp's Exit/Error Codes and Stopping with CTRL+C  #####
Busyppp has 8 possible exit/error codes: 0, 9-14, and 99.

All exit and error codes, except 0, are also reported and described in the scrolling terminal output as well as the wget-log file. 

If there actually are any items that busyppp can attempt to download in the URL list (as it currently exits after having possibly been overwritten in 
previous runs), and busyppp stops because it tried to download all those items, busyppp returns the exit/error code 0. This exit code is used even if 
wget-specific errors have occurred for any individual file in the list in the current or previous runs of busyppp. 

But if all items in the URL list are either blank, or commented out with an initial hash mark (#) followed by anything, busyppp returns 14. 

Busyppp can also be stopped normally (but usually, prematurely, before attempting to download all files in its URL list) by the user pressing CTRL+C 
in the  terminal window. In this case busyppp returns an exit/error code of 9. 

If the ppp network interface is or went down (meaning the process pppd that handles the dial-up connection is not running), busyppp stops with the 
exit/error code 10. 

If busyppp detects an auxiliary file error that prevents it from operating normally it returns either 11 or 12. If the error is related to the file 
wgetexitfile, it returns error code 11. If the error is related to the file netinfile, busyppp returns the code 12. 

If busyppp detects some simple input error that prevents it from operating normally it returns 13. Specifically, if busyppp's command-line argument is 
not written according to the some of the requirements given in the section above "Command-Line Arguments -- Download Lists," or if the command-line 
argument isn't the name of an a non-empty file in the current folder, busyppp returns code 13. 

Finally, it is very abnormal if busyppp reaches the last few lines of the script. So then busyppp returns the exit/error code 99. 


#####  Download Attempt Repeat on Wget Error Code 4  #####
During each run of busyppp, the first time wget returns the error code 4, "network failure," for a given file URL, busyppp immediately gives the download 
one more try. If this immediate second attempt fails with the same error, the item in the download list is prepended with "#E 4 ". 

In my experience wget usually succeeds in starting the download on the second try. And, although it may be due to a misconfiguration of my 
system, such errors occur rather frequently. Busyppp also reports and describes what happened on both these download attempts in the scrolling terminal 
output as well as the wget-log file. 


#####  Web Browsers and Their Busyppp Settings  #####
Busyppp is currently compatible only with web browsers or web browser-like programs (such as wkhtmltopdf or googler).
In particular, it is not compatible with any downloading process run by the root user nor with a separate instance of wget.

You must specify the the names of your usual web browsers in the following line of the script  
  bline="$(grep -E "midori|xombrero|chrome" <<<"$nhline")";  
by adding the process name for your browser (with a prefixed "|") to the list as, for example,  
  bline="$(grep -E "midori|xombrero|chrome|firefox" <<<"$nhline")";  
You may also want to remove from that line the process names of any browsers you usually do not use. 

Busyppp assumes either only one of the browsers in this line or the busyppp-started instance of wget is downloading at any time. (Although there 
may be a few seconds of overlap during the switchover from wget downloading to the browser downloading.) 


#####  Other Default Settings  #####
To modify busyppp's other default settings you must search for and find them in the script. 

By default busyppp gives wget the following options that I have found useful, namely,  
  --limit-rate=4k -nd --read-timeout=600 -t 0 -c -v --progress=dot:giga -a wget-log

However, it appears that the last option passed to wget overrides any earlier conflicting or differently-valued one. So these default option 
settings can also more easily be changed by specifying new values for them in each item of the download list (rather than modifying the 
busyppp script). See the wget manual for details. 

The wget option and value --limit-rate=4k is intended to leave some bandwidth "breathing room" for the web browser to start loading a webpage 
at the same time wget is actively downloading. This value, 4k, works for me, with my usual maximum dial-up bandwidth of around 4.5 kiB/s. 

A related default value is 0.40 kiB/s in this script line  
  if (($(bc <<< "$brate < 0.40")));  
This is the kiB/s threshold for webpage loading by the browser at which busyppp starts or stops wget: It stops wget (kills it) if the browser 
is loading at or higher than this rate and starts wget if the browser is loading at less than it. You may want to fiddle with this threshold value of
0.40, but it works well for me. 

The following line in the busyppp script  
    } < <(nethogs -t -d 2 ppp0 &);  
assumes that there is only one ppp network interface named "ppp0". Another line in the script  
  x=$(awk '{print $1}' <<<"$ifstatline");  
also assumes that there is only one ppp network interface. 


#####  Abnormal Termination of Busyppp   #####
If you ever notice that the auxiliary file netinfile exists prior to starting busyppp and that it is being written to every 2 seconds, i.e., the 
Date Modified timestamp keeps changing, this is due to an earlier abnormal termination of busyppp. It means that ifstat has become a zombie or orphan 
process. So you will have to kill it. See, for example,  
  http://linuxg.net/what-are-zombie-and-orphan-processes-and-how-to-kill-them/

You may also want to run htop, filter for "busyppp", and kill any processes that show up. To be thorough, do the same after filtering for "wget" and 
"nethogs". 

I don't think you will see this happen (unless, perhaps, your system is working near the limits of its processor speed and disk capacity). But it occured 
fairly often during development while bugs were being removed. 
