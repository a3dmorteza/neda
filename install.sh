#!/bin/bash
set -e

# بررسی اینکه اسکریپت با دسترسی root اجرا شود
if [ "$USER" -ne "root" ]; then
  echo "Please run as root by using sudo."
  exit 1
fi

# بررسی اینکه آیا اسکریپت با sudo اجرا شده است یا خیر
if [ -z "$SUDO_USER" ]; then
  echo "This script must be run with sudo."
  exit 1
fi

echo "Starting Neda installation..."

# 1. دانلود فایل باینری
echo "Downloading Neda binary..."
BASE_URL="https://github.com/a3dmorteza/neda/releases/latest/download"
wget -q "$BASE_URL/neda" -O /usr/local/bin/neda

# 2. تنظیم مجوز اجرا
echo "Setting executable permissions..."
chmod +x /usr/local/bin/neda

# پیکربندی neda
/usr/local/bin/neda configure
/usr/local/bin/neda server:initialize
/usr/local/bin/neda server:start
/usr/local/bin/neda server:trust