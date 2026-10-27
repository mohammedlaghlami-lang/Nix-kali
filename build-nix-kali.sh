#!/bin/bash
set -euo pipefail

NAME="NIX KALI"
HOST="nixkali"
VARIANT="nixkali"
OUT="$(pwd)/nixkali-out"

echo "[*] installing build deps..."
apt-get update
apt-get install -y git live-build cdebootstrap debootstrap devscripts fakeroot fakechroot python3-pil xorriso squashfs-tools zip

rm -rf "$OUT"; mkdir -p "$OUT"
WORK="$(pwd)/nixkali-build"
rm -rf "$WORK"; mkdir -p "$WORK"
cd "$WORK"

echo "[*] cloning live-build-config..."
git clone --depth 1 https://gitlab.com/kalilinux/build-scripts/live-build-config.git
cd live-build-config

echo "[*] creating variant: $VARIANT"
cp -r kali-config/variant-default "kali-config/variant-$VARIANT"

cat > "kali-config/variant-$VARIANT/package-lists/nixkali.list.chroot" <<'EOF'
kali-root-login
kali-defaults
kali-menu
kali-debtags
kali-archive-keyring
debian-installer-launcher
alsa-tools
locales-all
dconf-tools
openssh-server
nmap
sqlmap
hydra
john
hashcat
gobuster
nikto
wpscan
metasploit-framework
exploitdb
netcat-openbsd
tcpdump
masscan
python3
python3-pip
git
curl
jq
ripgrep
tmux
vim
EOF

echo "[*] generating wallpaper..."
python3 - "$NAME" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
W,H=1920,1080
img=Image.new("RGB",(W,H),(8,8,10)); d=ImageDraw.Draw(img)
def font(s):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        try: return ImageFont.truetype(p,s)
        except: pass
    return ImageFont.load_default()
t=sys.argv[1]; cx,cy=W//2,H//2
d.ellipse([cx-320,cy-320,cx+320,cy+320],outline=(210,30,50),width=3)
d.ellipse([cx-280,cy-280,cx+280,cy+280],outline=(210,30,50),width=1)
f=font(200); bb=d.textbbox((0,0),t,font=f)
d.text(((W-(bb[2]-bb[0]))//2,400),t,font=f,fill=(255,255,255))
d.rectangle([(W-900)//2,660,(W+900)//2,666],fill=(210,30,50))
img.save("/tmp/nixkali-wallpaper.png")
PY

WD="kali-config/common/includes.chroot/usr/share/wallpapers/nixkali/contents/images"
mkdir -p "$WD"; cp /tmp/nixkali-wallpaper.png "$WD/"

INC="kali-config/common/includes.chroot"
mkdir -p "$INC/etc"
echo "$HOST" > "$INC/etc/hostname"
printf '\n  %s — custom offensive build\n  worm edition\n\n' "$NAME" > "$INC/etc/motd"

mkdir -p kali-config/common/hooks
cat > kali-config/common/hooks/01-nixkali.chroot <<'HOOK'
#!/bin/sh
set -e
systemctl enable ssh || true
useradd -m -s /bin/bash -G sudo nix 2>/dev/null || true
echo "nix:nix" | chpasswd 2>/dev/null || true
HOOK
chmod +x kali-config/common/hooks/01-nixkali.chroot

echo "[*] building ISO — 40-120 min..."
lb clean --purge || true
./build.sh --variant "$VARIANT" --verbose

find . -name '*.iso' -exec mv {} "$OUT/" \;
echo "=========================================="
echo "  done: $OUT"
ls -lh "$OUT"
echo "=========================================="
