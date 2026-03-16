# Shell - Cheat Sheet

# TTY

| command | description |
|---------|-------------|
| ctrl+shift+\[f1-f6\] | navigate through TTY 1 to 6 (`/dev/pts1`, `/dev/pts2`,…) |
| tty     | print the file name of the terminal connected to standard input |
| fg, bg  | change program running in foreground or background |
| echo $0 |             |
| echo $? | prints out exit return value of last command<br>0 : success<br>> 0 : error |
| echo $! |             |
| shopt login_shell | prints out sh option `login_shell`  <br> which is off for a non login shell and on for a login shell |


## Special Script Parameter

### $!

reference the process ID of the most recently executed command in background.

### $$

reference the process ID of bash shell itself

### $#

expands to a number of positional parameters in decimal.

### $0

reference the name of the shell or shell script. so you can use this if you want to print the name of shell script.

\nExample: prints out `-bash` for login shell and  \n just `bash` name of the shell if not a login shell

### $-

get current option flags specified during the invocation, by the set built-in command or set by the bash shell itself. Though this bash parameter is rarely used.

### $?

exit status of the most recently executed command in the foreground.

**Use Cases:** check whether your bash script is completed successfully or not.

### $_

reference the absolute file name of the shell or bash script which is being executed as specified in the argument list. This bash parameter is also used to hold the name of mail file while checking emails.

Use Cases: 

* used to hold the name of mail file while checking emails

### $@

expand into positional parameters starting from one. When expansion occurs inside double-quotes, every parameter expands into separate words.

### $\*

Similar to $@ special bash parameter  only difference is when expansion occurs with double quotes, it expands to a single word with the value of each bash parameter separated by the first character of the IFS special environment variable.

## Special Characters

### #

comment a single line in bash script

### $$

reference process id of any command or bash script

### $name

print the value of variable "name" defined in the script.

Example:

```
$ test=hallo
$ $test
zsh: command not found: hallo
```

### $n

print the value of nth argument provided to bash script (n ranges from 0 to 9) e.g. $1 will print first argument.

### >

redirect output

### >>

Append to file

### <

redirect input

### \[\]

matching any characters enclosed

### ()

Execute in subshell

### \`\`

substitute output of enclosed command

### ""

Partial quote (allows variable and command expansion)

### ''

Full quote (no expansion)

### \\

Quote following character

### |

Pipe output of one command to another

### &

run any process in the background.

### ;

(semi colon ) is used to separate commands on same line

### \*

match any character(s) in filename

### ?

matching single character in filename

# sudo

| command | description |
|---------|-------------|
| visudo  | edit sudoer file /etc/sudoers with system editor |
| !!      | execute previous sudo command |

# Cursor/Commands

switch cursor to block:

```javascript
$ echo -e "\033[2 q"
```

switch cursor to pipe:

```javascript
$ echo -e "\033[6 q"
```

| command | description |
|---------|-------------|
| Ctrl+g  | clear screen <br> default:`Ctrl+l` but changed to be used by tmux navigating panes |
| ftmuxp  | uses fzf (fuzzy search) to list all existing tmuxp sessions <br> - open selected session <br> - create New Session <br> (command provided by dotfiles repo`zsh/scripts.sh`) |
| wikipedia <query> | terminal search for query at en.wikipedia site. <br> (command provided by dotfiles repo`zsh/scripts.sh`) |
| duckduckgo <query> | terminal search at duckduckgo.com internet search engine <br> (command provided by dotfiles repo`zsh/scripts.sh`) |

# ssh

## How to debug ssh error?

* usage scenarion git@github.com

```javascript
$ ssh -vvT git@github.com
...
debug1: Next authentication method: publickey
debug1: Trying private key: /home/michael/.ssh/id_rsa
debug1: Trying private key: /home/michael/.ssh/id_ecdsa
debug1: Trying private key: /home/michael/.ssh/id_ecdsa_sk
debug1: Trying private key: /home/michael/.ssh/id_ed25519
debug1: Trying private key: /home/michael/.ssh/id_ed25519_sk
debug1: Trying private key: /home/michael/.ssh/id_xmss
debug1: Trying private key: /home/michael/.ssh/id_dsa
debug2: we did not send a packet, disable method
debug1: No more authentication methods to try.
git@github.com: Permission denied (publickey).
```

Result was here I named my key pairs different to default. So need to specify it at .ssh/config

# Mount

## How to mount img file?

A img file is a binary representation of a iso image like a DVD (looping device), or a sd card image as block memory device with partitions...

Mount a iso image:

```javascript
> sudo mount -o loop /my.img /mnt/iso
```

Mount a sd-card img file:

* first convert it to loop device (kind of virtual file system) using `partx`
* then mount the loop device in our example the second partition which is the actual rootfs of Raspberry PI OS image

```bash
 > sudo partx -a -v ~/Downloads/2022-04-04-raspios-bullseye-armhf-lite.img                                                        
partition: none, disk: /home/michael/Downloads/2022-04-04-raspios-bullseye-armhf-lite.img, lower: 0, upper: 0
Trying to use '/dev/loop3' for the loop device
/dev/loop3: partition table type 'dos' detected
range recount: max partno=2, lower=0, upper=0
/dev/loop3: partition #1 added
/dev/loop3: partition #2 added
                                                                                                                                       
/mnt > lsblk                                                                                                                          
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
...
loop3         7:3    0   1.9G  0 loop 
├─loop3p1   259:4    0   256M  0 part 
└─loop3p2   259:5    0   1.6G  0 part 
...

> sudo mount /dev/loop3p2 /mnt/iso
```

Hint there is also a program called `losetup`helps to setup and control loop devices