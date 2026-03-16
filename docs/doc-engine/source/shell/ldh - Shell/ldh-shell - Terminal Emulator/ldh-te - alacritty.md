# ldh-te - alacritty

* <https://alacritty.org/>

> # [About](https://alacritty.org/#About)
>
> Alacritty is a modern terminal emulator that comes with sensible defaults, but allows for extensive configuration. By integrating with other applications, rather than reimplementing their functionality, it manages to provide a flexible set of features with high performance. The supported platforms currently consist of BSD, Linux, macOS and Windows.
>
> The software is considered to be at a **beta** level of readiness; there are a few missing features and bugs to be fixed, but it is already used by many as a daily driver.

# Install

Following the manual installation instructions:

* <https://github.com/alacritty/alacritty/blob/master/INSTALL.md>

```bash
https://rustup.rs/

$ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# choose default installation -> option 1
```

Use rustup to make sure proper compiler installed:

```bash
$ rustup override set stable
info: override toolchain for '/home/ldcwem0/tools/alacritty' set to 'stable-x86_64-unknown-linux-gnu'

$ rustup update stable
info: syncing channel updates for 'stable-x86_64-unknown-linux-gnu'

  stable-x86_64-unknown-linux-gnu unchanged - rustc 1.89.0 (29483883e 2025-08-04)

info: checking for self-update
```

## Dependencies

```bash
$ sudo apt install cmake g++ pkg-config libfontconfig1-dev \
  libxcb-xfixes0-dev libxkbcommon-dev python3
```

## Compile

```bash
~/tools/alacritty$ cargo build --release
```

## Post Build

### Terminfo

```bash
~/tools/alacritty$ infocmp alacritty
#       Reconstructed via infocmp from file: /usr/share/terminfo/a/alacritty
alacritty|alacritty terminal emulator,
        am, bce, ccc, hs, mc5i, mir, msgr, npc, xenl,
        colors#0x100, cols#80, it#8, lines#24, pairs#0x10000,
        acsc=``aaffggiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz{{||}}~~,
        bel=^G, blink=\E[5m, bold=\E[1m, cbt=\E[Z, civis=\E[?25l,
        clear=\E[H\E[2J, cnorm=\E[?12l\E[?25h, cr=\r,
        csr=\E[%i%p1%d;%p2%dr, cub=\E[%p1%dD, cub1=^H,
        cud=\E[%p1%dB, cud1=\n, cuf=\E[%p1%dC, cuf1=\E[C,
        cup=\E[%i%p1%d;%p2%dH, cuu=\E[%p1%dA, cuu1=\E[A,
        cvvis=\E[?12;25h, dch=\E[%p1%dP, dch1=\E[P, dim=\E[2m,
        dl=\E[%p1%dM, dl1=\E[M, dsl=\E]2;\007, ech=\E[%p1%dX,
        ed=\E[J, el=\E[K, el1=\E[1K, flash=\E[?5h$<100/>\E[?5l,
        fsl=^G, home=\E[H, hpa=\E[%i%p1%dG, ht=^I, hts=\EH,
        ich=\E[%p1%d@, il=\E[%p1%dL, il1=\E[L, ind=\n,
        indn=\E[%p1%dS,
        initc=\E]4;%p1%d;rgb:%p2%{255}%*%{1000}%/%2.2X/%p3%{255}%*%{1000}%/%2.2X/%p4%{255}%*%{1000}%/%2.2X\E\\,
        invis=\E[8m, is2=\E[!p\E[?3;4l\E[4l\E>, kDC=\E[3;2~,
        kEND=\E[1;2F, kHOM=\E[1;2H, kIC=\E[2;2~, kLFT=\E[1;2D,
        kNXT=\E[6;2~, kPRV=\E[5;2~, kRIT=\E[1;2C, kb2=\EOE, kbs=^?,
        kcbt=\E[Z, kcub1=\EOD, kcud1=\EOB, kcuf1=\EOC, kcuu1=\EOA,
        kdch1=\E[3~, kend=\EOF, kent=\EOM, kf1=\EOP, kf10=\E[21~,
        kf11=\E[23~, kf12=\E[24~, kf13=\E[1;2P, kf14=\E[1;2Q,
        kf15=\E[1;2R, kf16=\E[1;2S, kf17=\E[15;2~, kf18=\E[17;2~,
        kf19=\E[18;2~, kf2=\EOQ, kf20=\E[19;2~, kf21=\E[20;2~,
        kf22=\E[21;2~, kf23=\E[23;2~, kf24=\E[24;2~,
        kf25=\E[1;5P, kf26=\E[1;5Q, kf27=\E[1;5R, kf28=\E[1;5S,
        kf29=\E[15;5~, kf3=\EOR, kf30=\E[17;5~, kf31=\E[18;5~,
        kf32=\E[19;5~, kf33=\E[20;5~, kf34=\E[21;5~,
        kf35=\E[23;5~, kf36=\E[24;5~, kf37=\E[1;6P, kf38=\E[1;6Q,
        kf39=\E[1;6R, kf4=\EOS, kf40=\E[1;6S, kf41=\E[15;6~,
        kf42=\E[17;6~, kf43=\E[18;6~, kf44=\E[19;6~,
        kf45=\E[20;6~, kf46=\E[21;6~, kf47=\E[23;6~,
        kf48=\E[24;6~, kf49=\E[1;3P, kf5=\E[15~, kf50=\E[1;3Q,
        kf51=\E[1;3R, kf52=\E[1;3S, kf53=\E[15;3~, kf54=\E[17;3~,
        kf55=\E[18;3~, kf56=\E[19;3~, kf57=\E[20;3~,
        kf58=\E[21;3~, kf59=\E[23;3~, kf6=\E[17~, kf60=\E[24;3~,
        kf61=\E[1;4P, kf62=\E[1;4Q, kf63=\E[1;4R, kf7=\E[18~,
        kf8=\E[19~, kf9=\E[20~, khome=\EOH, kich1=\E[2~,
        kind=\E[1;2B, kmous=\E[<, knp=\E[6~, kpp=\E[5~,
        kri=\E[1;2A, mc0=\E[i, mc4=\E[4i, mc5=\E[5i, meml=\El,
        memu=\Em, oc=\E]104\007, op=\E[39;49m, rc=\E8,
        rep=%p1%c\E[%p2%{1}%-%db, rev=\E[7m, ri=\EM,
        rin=\E[%p1%dT, ritm=\E[23m, rmacs=\E(B, rmam=\E[?7l,
        rmcup=\E[?1049l\E[23;0;0t, rmir=\E[4l, rmkx=\E[?1l\E>,
        rmm=\E[?1034l, rmso=\E[27m, rmul=\E[24m,
        rs1=\Ec\E]104\007, rs2=\E[!p\E[?3;4l\E[4l\E>, sc=\E7,
        setab=\E[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m,
        setaf=\E[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m,
        sgr=%?%p9%t\E(0%e\E(B%;\E[0%?%p6%t;1%;%?%p5%t;2%;%?%p2%t;4%;%?%p1%p3%|%t;7%;%?%p4%t;5%;%?%p7%t;8%;m,
        sgr0=\E(B\E[m, sitm=\E[3m, smacs=\E(0, smam=\E[?7h,
        smcup=\E[?1049h\E[22;0;0t, smir=\E[4h, smkx=\E[?1h\E=,
        smm=\E[?1034h, smso=\E[7m, smul=\E[4m, tbc=\E[3g,
        tsl=\E]2;, u6=\E[%i%d;%dR, u7=\E[6n,
        u8=\E[?%[;0123456789]c, u9=\E[c, vpa=\E[%i%p1%dd,
```

If it is not present already, you can install it globally with the following command:

`$ sudo tic -xe alacritty,alacritty-direct extra/alacritty.info`

## Desktop Install

Verify current system installation:

```bash
$ ls -lsa /usr/share/pixmaps
total 436
  4 drwxr-xr-x   4 root    root      4096 Aug 23 06:13 .
 12 drwxr-xr-x 347 root    root     12288 Sep  8 11:18 ..
  4 -rw-r--r--   1 root    root      1483 Feb 20  2022 debian-logo.png
  8 -rw-r--r--   1 root    root      4485 Jul 19  2024 display-im6.q16.xpm
  4 drwxr-xr-x   2 root    root      4096 Jun 20 15:21 evolution-data-server
  4 drwxr-xr-x   3 root    root      4096 Jun 20 15:22 faces
  8 -rw-r--r--   1 root    root      7293 Mar 19  2024 fish.png
  4 -rw-r--r--   1 root    root      3344 Mar 23  2022 htop.png
  4 -rw-r--r--   1 root    root      2253 Dec 28  2022 language-selector.png
  4 -rw-r--r--   1 root    root      1309 Mar  4  2018 mcedit.xpm
  4 -rw-r--r--   1 root    root      1349 Mar  4  2018 mc.xpm
  8 -rw-r--r--   1 root    root      4942 Feb 13  2017 monodoc.xpm
 20 -rw-r--r--   1 root    root     18371 Jun 29  2021 mono-runtime-common.png
  8 -rw-r--r--   1 root    root      4779 Jul 16 22:29 openjdk-11.xpm
  8 -rw-r--r--   1 root    root      4855 Jul 16 00:32 openjdk-8-app.xpm
  8 -rw-r--r--   1 root    root      4779 Jul 16 00:32 openjdk-8.xpm
  4 -rw-r--r--   1 root    root       842 Feb  6  2021 pstree16.xpm
  4 -rw-r--r--   1 root    root      1674 Feb  6  2021 pstree32.xpm
  8 -rw-r--r--   1 root    root      7286 Nov 23  2013 python3.10.xpm
  8 -rw-r--r--   1 root    root      7286 Dec  4  2024 python3.9.xpm
  0 lrwxrwxrwx   1 root    root        14 Aug  8  2024 python3.xpm -> python3.10.xpm
 44 -rw-rw-r--   1 ldcwem0 ldcwem0  44852 May 27 08:37 QfinderPro.png
  8 -rw-r--r--   1 root    root      6507 Mar 30  2022 qutebrowser.xpm
  8 -rw-r--r--   1 root    root      4642 Sep  5  2024 ubuntu-logo-dark.png
  8 -rw-r--r--   1 root    root      5278 Sep  5  2024 ubuntu-logo-icon.png
  4 -rw-r--r--   1 root    root      1488 May 31  2021 urxvt_16x16.xpm
  0 lrwxrwxrwx   1 root    root         9 Feb  6  2022 urxvt_32x32.xpm -> urxvt.xpm
  8 -rw-r--r--   1 root    root      6923 May 31  2021 urxvt_48x48.xpm
  4 -rw-r--r--   1 root    root      3931 May 31  2021 urxvt.xpm
216 -rw-r--r--   1 root    root    220706 Nov 13  2024 vscode.png

$ which desktop-file-install
/usr/bin/desktop-file-install

$ which udpate-desktop-database
udpate-desktop-database not found

$ which update-desktop-database
/usr/bin/update-desktop-database

$ ls -lsa extra/linux
total 16
4 drwxrwxr-x 2 ldcwem0 ldcwem0 4096 Sep  8 14:05 .
4 drwxrwxr-x 8 ldcwem0 ldcwem0 4096 Sep  8 14:05 ..
4 -rw-rw-r-- 1 ldcwem0 ldcwem0  338 Sep  8 14:05 Alacritty.desktop
4 -rw-rw-r-- 1 ldcwem0 ldcwem0 1555 Sep  8 14:05 org.alacritty.Alacritty.appdata.xml

$ ls -lsa /usr/share/xsessions
total 32
 4 drwxr-xr-x   2 root root  4096 Jun 23 08:46 .
12 drwxr-xr-x 347 root root 12288 Sep  8 11:18 ..
 4 -rw-r--r--   1 root root   197 Nov  3  2021 i3.desktop
 4 -rw-r--r--   1 root root   174 Nov  3  2021 i3-with-shmlog.desktop.bak
 4 -rw-r--r--   1 root root   292 Apr  7  2022 ubuntu.desktop.bak
 4 -rw-r--r--   1 root root   300 Apr  7  2022 ubuntu-xorg.desktop.bak
```

Install alacritty:

```bash
~/tools/alacritty$ sudo cp target/release/alacritty /usr/local/bin
~/tools/alacritty$ sudo cp extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg
~/tools/alacritty$ sudo desktop-file-install extra/linux/Alacritty.desktop
~/tools/alacritty$ sudo update-desktop-database
```

## Manual Installation

```bash
~/tools/alacritty$ sudo mkdir -p /usr/local/share/man/man1
~/tools/alacritty$ sudo mkdir -p /usr/local/share/man/man5
~/tools/alacritty$ scdoc < extra/man/alacritty.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty.1.gz > /dev/null
~/tools/alacritty$ scdoc < extra/man/alacritty-msg.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty-msg.1.gz > /dev/null
~/tools/alacritty$ scdoc < extra/man/alacritty.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty.5.gz > /dev/null
~/tools/alacritty$ scdoc < extra/man/alacritty-bindings.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty-bindings.5.gz > /dev/null
```

## Shell Completions

### zsh

On my system there is the external folder at dotfiles symlinked. That means I simply copy the alacritty completion to that dotfiles folder:

* $ZDOTDIR

```bash
$ echo $ZDOTDIR
/home/ldcwem0/.config/zsh
```

* zsh installation at dotfiles
  * $FPATH points to /home/ldcwem0/.config/zsh/external, which is a symbolic link to dotfiles

```bash
$ find /home/ldcwem0/dotfiles -iname "*zsh*"
/home/ldcwem0/dotfiles/zsh
/home/ldcwem0/dotfiles/zsh/.zshenv
/home/ldcwem0/dotfiles/zsh/external/bd.zsh
/home/ldcwem0/dotfiles/zsh/external/completion.zsh
/home/ldcwem0/dotfiles/zsh/.zshrc

$ echo $FPATH
/home/ldcwem0/.config/zsh/external:/usr/local/share/zsh/site-functions:/usr/share/zsh/vendor-functions:/usr/share/zsh/vendor-completions:/usr/share/zsh/functions/Calendar:/usr/share/zsh/functions/Chpwd:/usr/share/zsh/functions/Completion:/usr/share/zsh/functions/Completion/AIX:/usr/share/zsh/functions/Completion/BSD:/usr/share/zsh/functions/Completion/Base:/usr/share/zsh/functions/Completion/Cygwin:/usr/share/zsh/functions/Completion/Darwin:/usr/share/zsh/functions/Completion/Debian:/usr/share/zsh/functions/Completion/Linux:/usr/share/zsh/functions/Completion/Mandriva:/usr/share/zsh/functions/Completion/Redhat:/usr/share/zsh/functions/Completion/Solaris:/usr/share/zsh/functions/Completion/Unix:/usr/share/zsh/functions/Completion/X:/usr/share/zsh/functions/Completion/Zsh:/usr/share/zsh/functions/Completion/openSUSE:/usr/share/zsh/functions/Exceptions:/usr/share/zsh/functions/MIME:/usr/share/zsh/functions/Math:/usr/share/zsh/functions/Misc:/usr/share/zsh/functions/Newuser:/usr/share/zsh/functions/Prompts:/usr/share/zsh/functions/TCP:/usr/share/zsh/functions/VCS_Info:/usr/share/zsh/functions/VCS_Info/Backends:/usr/share/zsh/functions/Zftp:/usr/share/zsh/functions/Zle
```

* …

```bash
$ ls -lsa ~/.config/zsh
total 624
  4 drwxr-xr-x  2 ldcwem0 ldcwem0   4096 Sep  8 14:07 .
  4 drwxrwxr-x 70 ldcwem0 ldcwem0   4096 Sep  8 10:57 ..
  0 lrwxrwxrwx  1 ldcwem0 ldcwem0     34 Oct  4  2022 aliases -> /home/ldcwem0/dotfiles/zsh/aliases
  0 lrwxrwxrwx  1 ldcwem0 ldcwem0     35 Oct  4  2022 external -> /home/ldcwem0/dotfiles/zsh/external
 52 -rw-rw-r--  1 ldcwem0 ldcwem0  49820 Jun 10  2024 .zcompdump
 92 -rw-------  1 ldcwem0 ldcwem0  90956 Sep  8 14:04 .zhistory
472 -rw-------  1 ldcwem0 ldcwem0 482589 Aug 18 15:18 .zsh_history
  0 lrwxrwxrwx  1 ldcwem0 ldcwem0     33 Oct  4  2022 .zshrc -> /home/ldcwem0/dotfiles/zsh/.zshrc
```

Install it:

```bash
~/tools/alacritty$ cp extra/completions/_alacritty \
  /home/ldcwem0/dotfiles/zsh/external/

$ ls -lsa /home/ldcwem0/dotfiles/zsh/external
total 40
 4 drwxr-xr-x 2 ldcwem0 ldcwem0  4096 Sep  8 14:33 .
 4 drwxrwxr-x 3 ldcwem0 ldcwem0  4096 Mar 12  2024 ..
12 -rw-rw-r-- 1 ldcwem0 ldcwem0 11267 Sep  8 14:33 _alacritty
 4 -rw-rw-r-- 1 ldcwem0 ldcwem0  1530 Oct  4  2022 bd.zsh
 8 -rw-rw-r-- 1 ldcwem0 ldcwem0  5008 Oct  4  2022 completion.zsh
 4 -rw-rw-r-- 1 ldcwem0 ldcwem0   623 Oct  4  2022 cursor_mode
 4 -rw-rw-r-- 1 ldcwem0 ldcwem0  4056 Oct  4  2022 prompt_purification_setup
```