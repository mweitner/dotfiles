Based on your Ubuntu output, you are using the GlobalProtect-openconnect client (often referred to as gpclient or gpservice). The logs reveal that your connection relies on SAML authentication (the webview URL in your log) and likely a specific GlobalProtect Portal URL.

Since you cannot find a complex config file, it is because this client stores most of its state in a local database or uses the command-line arguments you provided.

1. The Critical Connection Details
From your log, these are the pieces you need to carry over to Fedora:

Portal URL: lis01.vpn.liebherr.com

Protocol: GlobalProtect (GP).

Authentication: SAML (This requires the gpclient GUI or a specific openconnect version that supports —protocol=gp).


Special Flag: --hip (This is for Host Information Profile, required by many corporate environments).

Legacy Support: Your ~/.config/gpgui/openssl.cnf shows you need UnsafeLegacyServerConnect. This is common when connecting to older VPN gateways that haven't updated their SSL/TLS handshakes.

2. How to replicate this on Fedora
Since you are on Fedora and using Sway, you want the Wayland-compatible version of this tool.

Step A: Install the Client
On Fedora, you can install the same gpclient you were using on Ubuntu. It is often available via Copr or as a flatpak, but for your minimal setup, the CLI version is best:

Bash
sudo dnf install openconnect
# You may need to build or install the specific gpclient 
# if you want the exact same GUI behavior.
Step B: Apply the "Legacy SSL" Fix
Without this, your connection will likely fail with a "SSL Alert" error on Fedora's newer OpenSSL version.

Create the directory: mkdir -p ~/.config/gpclient

Create the file ~/.config/gpclient/openssl.cnf and paste the content you found:

Ini, TOML
openssl_conf = openssl_init
[openssl_init]
ssl_conf = ssl_sect
[ssl_sect]
system_default = system_default_sect
[system_default_sect]
Options = UnsafeLegacyServerConnect
Step C: The CLI Connection Command
You can trigger the connection in your foot terminal (running fish)  using the same syntax you used on Ubuntu:

Bash
sudo gpclient connect lis01.vpn.liebherr.com --hip
3. Sway Integration (The Scratchpad)
In your Sway config, you already have a placeholder for this. To make sure the SAML auth window (which pops up during login) behaves correctly, ensure this line is in your ~/.config/sway/config:

Plaintext
# Ensure the VPN auth window floats and centers
for_window [instance="gpclient"] floating enable, move position center 
bindsym $mod+Shift+v [instance="gpclient"] scratchpad show 
Next Step for you:
Since you are using fish now, would you like me to create a fish function called vpn-on that automatically sets the OPENSSL_CONF environment variable and starts this connection for you?