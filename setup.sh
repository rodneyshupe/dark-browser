#!/usr/bin/env bash

function swapcolor(){
    local file_path=$1

    if $(grep -e 'Color=0x0078c2' $file_path >/dev/null); then
        sudo cp ${file_path}{,.bak}
        sudo sed -i -e 's/Color=0x0078c2/Color=0x420b5d/g' ${file_path}
    fi
}

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
wget https://github.com/rodneyshupe/dark-browser/raw/main/wallpaper/dark-browser.png -q --output-document=dark-browser.png
sudo cp dark-browser.png /usr/share/lubuntu/wallpapers/ && rm dark-browser.png
echo "  Set new wallpaper..."
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
else
    export DISPLAY=$DISPLAY
fi
pcmanfm-qt --set-wallpaper=/usr/share/lubuntu/wallpapers/dark-browser.png --wallpaper-mode=center
echo "  NOTE: You may want to update theme using: lxqt-config-appearance"
echo 

echo "Change splash screen background color"
swapcolor /usr/share/plymouth/themes/default.plymouth
swapcolor /usr/share/plymouth/themes/lubuntu-logo/lubuntu-logo.plymouth
swapcolor /usr/share/plymouth/themes/lubuntu-logo/bgrt/bgrt.plymouth
sudo update-initramfs -u

echo "Change login screen background"
sudo cp /usr/share/sddm/themes/lubuntu/wall.jpg{,.bak}
wget https://github.com/rodneyshupe/dark-browser/raw/main/wallpaper/wall.jpg -q --output-document=wall.jpg
sudo cp wall.jpg /usr/share/sddm/themes/lubuntu/wall.jpg
rm wall.jpg

echo "Get VPN setup script..."
#get https://github.com/rodneyshupe/dark-browser/raw/main/privado-vpn.sh -q
chmod +x privado-vpn.sh
sudo mv privado-vpn.sh /opt/privado-vpn
sudo ln -s /opt/privado-vpn /usr/sbin/privado-vpn

/usr/sbin/privado-vpn install

echo "Add cron job to automatically rotate VPN server."
sudo crontab -l > crontab.list
if ! $(grep -e '^[0-9].*\/opt\/privado-vpn rotate' crontab.list); then
    echo "0 */2 * * * sudo /opt/privado-vpn rotate" >> crontab.list
    sudo crontab crontab.list >/dev/null
fi
if ! $(grep -e '^@reboot.*\/opt\/privado-vpn rotate' crontab.list); then
    echo "@reboot sleep 10; sudo /opt/privado-vpn rotate" >> crontab.list
    sudo crontab crontab.list >/dev/null
fi
rm crontab.list
