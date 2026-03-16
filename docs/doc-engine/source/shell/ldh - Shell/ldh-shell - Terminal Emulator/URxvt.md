# URxvt

is a lite weight terminal emulator with good performance and capabilities.

The following is valid for ArchLinux as prototype as well as:

* Ubuntu (server)
* Fedora (todo)

Its driven by:

* [Mouseless Development](/doc/mouseless-development-Y29fEabR8h)
* *URxvt on My i3 Tiling Manager System:* <https://smarttech101.com/urxvt-installation-color-scheme-fonts-resize-etc/>

# Intro

What are the benefits of using one of the oldest terminal emulators?

* Fewer system resources
  * Extended Laptop Battery Life -> Good for old systems
  * In developing countries, even a 4 GB laptop costs a lot
  * More Frames Per Seconds in games.
  * You can open multiple windows without pressurizing your system.
  * You can minimize the resource consumption even more by using it in daemon-client mode using urxvtd and urxvtc commands.
* Configured through a text file \~/.Xresources
  * sharing configuration is very easy
  * tighter integration with other packages like pywal through this file
* Enhanced over time with modern features like
  * Images in terminal which even many modern emulators struggle
  * Internationalization: unicode support

# Install

```javascript
$ sudo pacman -S rxvt-unicode
```

ubuntu:

```javascript
$ sudo apt install rxvt-unicode
```

fedora:

```bash
$ sudo dnf install rxvt-unicode
```

Example on my Purism Laptop:

```bash
$ urxvt --version
urxvt: "version": unknown or malformed option.
rxvt-unicode (urxvt) v9.30 - released: 2021-11-27
options: perl,xft,styles,combining,blink,iso14755,unicode3,\
  encodings=eu+vn+jp+jp-ext+kr+zh+zh-ext,fade,transparent,tint,pixbuf,XIM,frills,\
  selectionscrolling,wheel,slipwheel,smart-resize,cursorBlink,pointerBlank,\
  scrollbars=plain+rxvt+NeXT+xterm
Usage: urxvt [-help] [--help]
 [-display string] [-tn string] [-geometry geometry] [-C] [-iconic]
 [-cd string] [-dockapp] [-/+rv] [-/+ls] [-mc number] [-/+j] [-/+ss] [-/+ptab]
 [-/+sb] [-/+sr] [-/+st] [-sbt number] [-/+si] [-/+sk] [-/+sw] [-fade number]
 [-fadecolor color] [-/+ut] [-/+vb] [-/+dpb] [-/+tcw] [-/+insecure] [-/+uc]
 [-/+bc] [-/+pb] [-bg color] [-fg color] [-hc color] [-cr color] [-pr color]
 [-pr2 color] [-bd color] [-icon file] [-fn fontname] [-fb fontname]
 [-fi fontname] [-fbi fontname] [-/+is] [-im name] [-pt style]
 [-imlocale string] [-imfont fontname] [-name string] [-title string]
 [-n string] [-sl number] [-embed windowid] [-depth number] [-visual number]
 [-/+override-redirect] [-pty-fd fileno] [-/+hold] [-w number] [-b number]
 [-/+bl] [-lsp number] [-letsp number] [-/+sbg] [-mod modifier] [-/+ssc]
 [-/+ssr] [-rm string] [-pe string] [-e command arg ...]
```

# General Config

Following shows general configuration which is than integrated into dotfiles repo.

As mentioned at benefits section above, urxvt is configured through a simple text file X11 environment`~/.Xresources` .

```bash
$ touch ~/.Xresources
```

Setup Xresources file with font size colors, and other configuration:

Good practice is to symlink it to the default config:

```bash
$ ln -s ~/.Xresources ~/.Xdefaults
```

After configuration changes, the X11 config is updated through xrdb command:

* use -merge option to merge Xresources into database

```bash
$ xrdb ~/.Xdefaults
#or
$ xrdb ~/.Xresources
```

# Config font

Terminal can be started with specific font. Urxvt support two types of fonts X11 core fonts and Xft fonts. An ubuntu update to 22.04, broke the font rendering on my urxvt terminal. It took me a while to find out the problem… Following shows the main steps which will than help to fix such problems in future.

## Where is font setup?

* the installed fonts can be looked up with `fc-list` command
  * `fc-cache -f` : invalidates cached fonts
* dotfiles repo holds font config at `dotfiles/X11/.Xresources` which is symlinked from `~/.Xresources` or `~/.Xdefaults` respectively

```bash
$ fc-list |grep -i "nerd"
/home/michael/.config/local/share/fonts/Inconsolata Nerd Font Complete Mono.otf: Inconsolata Nerd Font Mono:style=Medium

$ cat ~/dotfiles/X11/.Xresources
...
URxvt*font: xft:Inconsolata Nerd Font Mono:style=Medium:size=14:pixelsize=16:antialias=true
...
```

## How to test another font config?

* simply start urxvt terminal session with specific font parameter. If given font is not installed it will fall back to default which looks like following screen shot

One good test is simply define unknown font like foo, where you know it must fallback:

```bash
$ urxvt -fn 'xft:foo'
```

 ![](uploads/02026def-d437-4c64-a89a-337add5098db/05f371ad-fb09-4152-ad8b-f3de42a06bcf/2022-08-02-133451_435x87_scrot%20(1).png)

simply call terminal which should pick up current active X11 font:

```bash
$ urxvt
```

## Install fonts

Lets install a font `Droid Sans Mono Nerd Font` and configure it as replacement of `Inconsolata Nerd` .

A good source for fonts is <https://www.1001freefonts.com/>. However could not find nerd fonts which comes from own web site.

* Droid Sans Mono Nerd Fonts
  * \[Website\] <https://www.nerdfonts.com/>
  * \[github\] <https://github.com/ryanoasis/nerd-fonts>

First download fonts:

* Droid Sans Mono Nerd Fonts
  * \[Downloads\] <https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/DroidSansMono.zip>

On debian based system the font files go to

* system wide: `/usr/share/fonts` or `/usr/local/share/fonts`
* user specific: `~/.local/share/fonts`

Font files can be organized in sub-folders

```bash
$ wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/DroidSansMono.zip
~/Downloads$ unzip DroidSansMono.zip
Archive:  DroidSansMono.zip
  inflating: Droid Sans Mono Nerd Font Complete Mono.otf
  inflating: Droid Sans Mono Nerd Font Complete.otf
  inflating: Droid Sans Mono Nerd Font Complete Windows Compatible.otf
  inflating: Droid Sans Mono Nerd Font Complete Mono Windows Compatible.otf

~/Downloads$ sudo cp Droid\ Sans*.otf /usr/local/share/fonts/urxvt-sample
~/Downloads$ ls -lsa /usr/local/share/fonts/urxvt-sample
total 10784
   4 drwxr-sr-x 2 root staff    4096 Aug  2 13:17  .
   4 drwxrwsr-x 3 root staff    4096 Jul 28 12:56  ..
3340 -rw-r--r-- 1 root staff 3419992 Aug  2 13:17 'Droid Sans Mono Nerd Font Complete Mono.otf'
3340 -rw-r--r-- 1 root staff 3419992 Aug  2 13:17 'Droid Sans Mono Nerd Font Complete Mono Windows Compatible.otf'
2048 -rw-r--r-- 1 root staff 2096384 Aug  2 13:17 'Droid Sans Mono Nerd Font Complete.otf'
2048 -rw-r--r-- 1 root staff 2096428 Aug  2 13:17 'Droid Sans Mono Nerd Font Complete Windows Compatible.otf'
```


Configure urxvt X11 settings at Xresources file:

* the first entry of URxvt.font comes first

```bash
$ cat ~/.config/X11/.Xresources
...
URxvt*font: \
            xft:DroidSansMono Nerd Font Mono:antialias=true:size=16, \
            ...
            xft:Monospace:style=Medium:antialias=true:minspace=False
URxvt*boldFont: \
            xft:DroidSansMono Nerd Font Mono:antialias=true:size=16, \
            ...
            xft:Monospace:style=Medium:antialias=true:minspace=False
! show boldness only by boldness and nothing else: intensityStyles: false
URxvt*intensityStyles: false
URxvt*borderLess: false
URxvt*externalBorder: 0
URxvt*internalBorder: 4
URxvt*scrollBar: false
URxvt*saveLines: 5000
URxvt*cursorBlink: false
URxvt*cursorUnderline: true
URxvt*letterSpace: -2
...
```

Refresh cache and update X11 database:

* if fonts are installed globally it needs sudo

```bash
~/Downloads$ sudo fc-cache -fv
...
/usr/local/share/fonts: caching, new cache contents: 0 fonts, 1 dirs
/usr/local/share/fonts/urxvt-sample: caching, new cache contents: 4 fonts, 0 dirs
...
fc-cache: succeeded

$ fc-list |grep Droid
/usr/local/share/fonts/urxvt-sample/Droid Sans Mono Nerd Font Complete.otf: \DroidSansMono Nerd Font:style=Book
/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf: Droid Sans Fallback:style=Regular
/usr/local/share/fonts/urxvt-sample/Droid Sans Mono Nerd Font Complete Mono Windows Compatible.otf: DroidSansMono NF:style=Book
/usr/local/share/fonts/urxvt-sample/Droid Sans Mono Nerd Font Complete Windows Compatible.otf: DroidSansMono NF:style=Book
/usr/local/share/fonts/urxvt-sample/Droid Sans Mono Nerd Font Complete Mono.otf: DroidSansMono Nerd Font Mono:style=Book

$ xrdb ~/.config/X11/.Xresources
```

## Verify and Test fonts

There is nice a nerd font cheat sheet to test font:

* <https://www.nerdfonts.com/cheat-sheet>

Simply call terminal emulator which should pick up new X11 config of `DroidSansMono Nerd Font Mono`:

 ![](uploads/02026def-d437-4c64-a89a-337add5098db/10d9bbef-65d6-4060-a39c-14c33b02ef1d/2022-08-02-134554_346x119_scrot%20(1).png)


Another nice tool is neofetch which prints out current system state including active font:

```bash
~$ neofetch
            .-/+oossssoo+/-.               michael@snake 
        `:+ssssssssssssssssss+:`           ------------- 
      -+ssssssssssssssssssyyssss+-         OS: Ubuntu 22.04 LTS x86_64 
    .ossssssssssssssssssdMMMNysssso.       Host: Librem 14 1.0 
   /ssssssssssshdmmNNmmyNMMMMhssssss/      Kernel: 5.15.0-41-generic 
  +ssssssssshmydMMMMMMMNddddyssssssss+     Uptime: 5 days, 20 hours, 8 mins 
 /sssssssshNMMMyhhyyyyhmNMMMNhssssssss/    Packages: 1818 (dpkg), 15 (snap) 
.ssssssssdMMMNhsssssssssshNMMMdssssssss.   Shell: zsh 5.8.1 
+sssshhhyNMMNyssssssssssssyNMMMysssssss+   Resolution: 1920x1080, 1920x1080, 1920x1080 
ossyNMMMNyMMhsssssssssssssshmmmhssssssso   WM: i3 
ossyNMMMNyMMhsssssssssssssshmmmhssssssso   Theme: Yaru [GTK3] 
+sssshhhyNMMNyssssssssssssyNMMMysssssss+   Icons: Yaru [GTK3] 
.ssssssssdMMMNhsssssssssshNMMMdssssssss.   Terminal: urxvt 
 /sssssssshNMMMyhhyyyyhdNMMMNhssssssss/    Terminal Font: DroidSansMono Nerd Font Mono 
  +sssssssssdmydMMMMMMMMddddyssssssss+     CPU: Intel i7-10710U (12) @ 4.700GHz 
   /ssssssssssshdmNNNNmyNMMMMhssssss/      GPU: Intel Comet Lake UHD Graphics 
    .ossssssssssssssssssdMMMNysssso.       Memory: 3811MiB / 64188MiB 
      -+sssssssssssssssssyyyssss+-
        `:+ssssssssssssssssss+:`                                   
            .-/+oossssoo+/-.                                       
```

# Install fonts at dotfiles repo

Copy fonts to dotfiles repo:

```bash
~/Downloads$  cp Droid\ Sans\ Mono\ Nerd\ Font\ Complete.otf ~/dotfiles/fonts
~/Downloads$  cp Droid\ Sans\ Mono\ Nerd\ Font\ Complete\ Mono.otf ~/dotfiles/fonts
```

The install script can be used to install fonts on new machine:

* XDG_DATA_HOME points to `~/.config/local/share/`

```bash
$ cat ./dotfiles/install.sh
...
#########
# Fonts #
#########

mkdir -p "$XDG_DATA_HOME"
cp -rf "$DOTFILES/fonts" "$XDG_DATA_HOME"
...
```

On system startup X11 `.xinitrc` script is picked up which updates X11 database and starts urxvt terminal daemon which should pick up fonts and colors defined at .Xresources file.

```bash
$ cat ~/.xinitrc
xrdb -merge "$HOME/.config/X11/.Xresources"
urxvtd -o -q -f
udiskie -A &
exec i3
```

The i3 window manager is configured to pick up font definition at:

```bash
$ cat ~/dotfiles/i3/config
...
font pango:DroidSansMonoForPowerline Nerd Font, FontAwesome, 9
...
```

SpaceVim IDE is configured by init.toml file at:

```bash
$ cat ~/dotfiles/spacevim/.SpaceVim.d/init.toml
...
font pango:DroidSansMonoForPowerline Nerd Font, FontAwesome, 9
...
```