#!/usr/bin/env bash
# Fish function sourcing script for VPN DNS management
# Source this in your fish config or call directly

function fix-vpn-dns-browser --description 'Fix DNS and browser cache after VPN connect (Fedora + Liebherr VPN)'
    # Auto-detect or use passed interface
    set vpn_interface "$argv[1]"

    # If no argument, try auto-detect
    if test -z "$vpn_interface"
        set vpn_interface (ip link show 2>/dev/null | grep -E 'tun[0-9]+|ppp[0-9]+|cscotun' | head -1 | awk '{print $2}' | tr -d ':')
        if test -z "$vpn_interface"
            echo "Error: VPN interface not detected. Provide it: fix-vpn-dns-browser <interface>" >&2
            return 1
        end
    end

    echo "🔧 Fixing DNS and browser cache for VPN interface: $vpn_interface"

    # Call the shell script (make sure it's in PATH or run it directly)
    if command -v fix-vpn-dns-browser >/dev/null 2>&1
        # Script is in PATH
        fix-vpn-dns-browser "$vpn_interface" ""
    else if test -f "$HOME/.local/bin/fix-vpn-dns-browser"
        bash "$HOME/.local/bin/fix-vpn-dns-browser" "$vpn_interface" ""
    else if test -f "$HOME/dotfiles/shell/fix-vpn-dns-browser"
        bash "$HOME/dotfiles/shell/fix-vpn-dns-browser" "$vpn_interface" ""
    else
        echo "Error: fix-vpn-dns-browser script not found" >&2
        return 1
    end
end

# Also provide a quick test function for DNS
function test-vpn-dns --description 'Test if VPN DNS resolves correctly to corporate IP'
    echo "Testing VPN DNS resolution..."
    if resolvectl query controller.lis-github.liebherr.com 2>/dev/null
        set ip (resolvectl query controller.lis-github.liebherr.com 2>&1 | grep -oP '(?<=: )[0-9.]+' | head -1)
        echo "✓ Resolved to: $ip"
        if test "$ip" = "10.243.65.137"
            echo "✓ Correct corporate IP!"
            return 0
        else
            echo "✗ Wrong IP (expected 10.243.65.137)"
            return 1
        end
    else
        echo "✗ Resolution failed"
        return 1
    end
end

# Test browser DNS lookup too
function test-browser-dns --description 'Test if browser DNS is working (requires curl)'
    echo "Testing HTTPS connectivity to controller..."
    if command -v curl >/dev/null 2>&1
        if curl -I -s -m 5 https://controller.lis-github.liebherr.com/ >/dev/null 2>&1
            echo "✓ HTTPS connection successful"
            return 0
        else
            echo "✗ HTTPS connection failed"
            return 1
        end
    else
        echo "(curl not available; skipping HTTPS test)"
        return 0
    end
end
