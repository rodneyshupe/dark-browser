#!/usr/bin/env bash

echo "Download Tor Browser"
link="$(curl -sSL https://www.torproject.org/download/ | grep --only-matching 'href=".*tor-browser-linux64.*\_ALL.tar.xz"' | head -1 | sed -e 's/^href="\(.*\)"$/\1/')"
if [[ $link =~ ^/ ]]; then
    if [[ $link =~ ^// ]]; then
        link="https:$link"
    else
        link="https://www.torproject.org$link"
    fi
fi
curl -L "$link" --output "tor-browser-linux64-latest_ALL.tar.xz"
tar -xf "tor-browser-linux64-latest_ALL.tar.xz"
chmod +x tor-browser/start-tor-browser.desktop
sudo mv tor-browser /opt/
echo "$(cd /opt/tor-browser; ./start-tor-browser.desktop --register-app)"


echo "Changing Wallpaper"
echo "  Download wallpaper..."
wget https://github.com/rodneyshupe/dark-browser/raw/main/wallpaper/dark-browser.png -q
sudo cp dark-browser.png /usr/share/lubuntu/wallpapers/
echo "  Set new wallpaper..."
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi
pcmanfm-qt --set-wallpaper=/usr/share/lubuntu/wallpapers/dark-browser.png --wallpaper-mode=center
echo "  NOTE: You may want to update theme using: lxqt-config-appearance"


echo "Get VPN setup script..."
# Download vpn script and execute setup
wget https://github.com/rodneyshupe/dark-browser/raw/main/privado-vpn.sh -q
chmod +x privado-vpn.sh
sudo mv privado-vpn.sh /opt/privado-vpn
sudo ln -s /opt/privado-vpn /usr/sbin/privado-vpn
/usr/sbin/privado-vpn install
