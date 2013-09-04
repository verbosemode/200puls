Script for controlling PulseAudio output devices
================================================

- If you find a bug, please let me know
- If you know how to toggle the mute status of an active PulseAudio sink out of the box from command line, please let me know too

Usage examples from my i3 config
--------------------------------

bindsym XF86AudioMute exec --no-startup-id /usr/local/bin/200puls mute && killall -SIGUSR1 i3status
bindsym XF86AudioRaiseVolume exec --no-startup-id /usr/local/bin/200puls raise-volume && killall -SIGUSR1 i3status
bindsym XF86AudioLowerVolume exec --no-startup-id /usr/local/bin/200puls lower-volume && killall -SIGUSR1 i3status

License
-------

	"THE BEER-WARE LICENSE" (Revision 42):
	<jochenbartl@mail.de> wrote this file. As long as you retain this notice you
	can do whatever you want with this stuff. If we meet some day, and you think
	this stuff is worth it, you can buy me a beer in return Jochen Bartl

