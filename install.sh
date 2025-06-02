#!/bin/bash
set -e # خروج فوری در صورت بروز خطا

# --- پیکربندی ---
APP_NAME="neda"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME"

# URL دانلود فایل باینری از شاخه main، مسیر dist
# اگر می‌خواهید از GitHub Releases استفاده کنید، این بخش را تغییر دهید:
# RELEASE_BASE_URL="https://github.com/a3dmorteza/neda/releases/latest/download"
# DOWNLOAD_URL="$RELEASE_BASE_URL/$APP_NAME"
BINARY_REPO_BASE_URL="https://github.com/a3dmorteza/neda/raw/main"
DOWNLOAD_URL="$BINARY_REPO_BASE_URL/dist/$APP_NAME"

TMP_DOWNLOAD_PATH="/tmp/${APP_NAME}_download_$$" # $$ شناسه پروسه برای یکتایی است
OLD_VERSION_BACKUP_TEMP_PATH="" # مسیر پشتیبان موقت نسخه قبلی
ARCHIVE_DIR_BASE="/usr/local/share/${APP_NAME}_backups" # دایرکتوری آرشیو

# --- توابع ---
cleanup() {
  # این تابع توسط trap در زمان خروج، خطا یا سیگنال‌های وقفه فراخوانی می‌شود
  if [ -n "$TMP_DOWNLOAD_PATH" ] && [ -f "$TMP_DOWNLOAD_PATH" ]; then
    echo "پاکسازی فایل دانلود موقت: $TMP_DOWNLOAD_PATH"
    rm -f "$TMP_DOWNLOAD_PATH"
  fi
  # اگر OLD_VERSION_BACKUP_TEMP_PATH هنوز وجود دارد و به جایی منتقل نشده (یعنی خطا رخ داده)
  # منطق اصلی باید بازگردانی را انجام داده باشد، اما برای اطمینان بیشتر:
  if [ -n "$OLD_VERSION_BACKUP_TEMP_PATH" ] && [ -f "$OLD_VERSION_BACKUP_TEMP_PATH" ]; then
    echo "توجه: یک فایل پشتیبان موقت در $OLD_VERSION_BACKUP_TEMP_PATH باقی مانده است." >&2
    echo "اگر نصب ناموفق بود، باید به صورت دستی بررسی شود." >&2
  fi
}
trap cleanup EXIT ERR INT TERM

# --- منطق اصلی اسکریپت ---# 1. بررسی دسترسی root
if [ "$(id -u)" -ne 0 ]; then
  echo "این اسکریپت باید با دسترسی root اجرا شود. لطفاً از sudo استفاده کنید." >&2
  exit 1
fi

# بررسی اینکه آیا اسکریپت با sudo اجرا شده است یا خیر (اختیاری، id -u مهم‌تر است)
if [ -z "$SUDO_USER" ]; then
  echo "هشدار: متغیر SUDO_USER تنظیم نشده است، اما اسکریپت با دسترسی root در حال اجرا است. ادامه می‌دهیم."
fi

echo "شروع فرآیند نصب Neda..."

# 2. مدیریت نسخه قبلی در صورت وجود
if [ -f "$INSTALL_PATH" ]; then
  echo "نسخه قبلی Neda در مسیر $INSTALL_PATH یافت شد."
  BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  OLD_VERSION_BACKUP_TEMP_PATH="${INSTALL_PATH}.backup_tmp_${BACKUP_TIMESTAMP}"

  echo "ایجاد نسخه پشتیبان موقت از نسخه فعلی در مسیر: $OLD_VERSION_BACKUP_TEMP_PATH ..."
  if mv "$INSTALL_PATH" "$OLD_VERSION_BACKUP_TEMP_PATH"; then
    echo "پشتیبان‌گیری موقت با موفقیت انجام شد."
  else
    echo "خطا: انتقال نسخه فعلی $INSTALL_PATH به $OLD_VERSION_BACKUP_TEMP_PATH ناموفق بود. عملیات لغو شد." >&2
    # فایل اصلی هنوز در INSTALL_PATH است، پس نیازی به بازگردانی نیست
    exit 1
  fi
fi

# 3. دانلود نسخه جدید
echo "درحال دانلود فایل باینری Neda از $DOWNLOAD_URL به $TMP_DOWNLOAD_PATH ..."
if wget --progress=dot:giga -q "$DOWNLOAD_URL" -O "$TMP_DOWNLOAD_PATH"; then
  echo "دانلود با موفقیت انجام شد."

  # 4. نصب نسخه جدید
  echo "درحال نصب Neda در مسیر $INSTALL_PATH ..."
  if mv "$TMP_DOWNLOAD_PATH" "$INSTALL_PATH"; then
    chmod +x "$INSTALL_PATH"
    echo "Neda با موفقیت در $INSTALL_PATH نصب شد و مجوزهای اجرایی تنظیم گردید."

    # 5. آرشیو کردن نسخه قدیمی (اگر پشتیبان موقت وجود دارد)
    if [ -n "$OLD_VERSION_BACKUP_TEMP_PATH" ] && [ -f "$OLD_VERSION_BACKUP_TEMP_PATH" ]; then
      mkdir -p "$ARCHIVE_DIR_BASE"
      # استخراج timestamp از نام فایل پشتیبان موقت
      # مثال: neda.backup_tmp_20231027_103045 -> 20231027_103045
      TIMESTAMP_FROM_BACKUP=$(basename "$OLD_VERSION_BACKUP_TEMP_PATH" | sed -n "s/.*backup_tmp_\(.*\)/\1/p")
      ARCHIVED_FILE_NAME="${APP_NAME}_${TIMESTAMP_FROM_BACKUP}" # نام فایل آرشیو شده
      ARCHIVED_FILE_PATH="$ARCHIVE_DIR_BASE/$ARCHIVED_FILE_NAME"

      echo "درحال آرشیو کردن نسخه قدیمی از $OLD_VERSION_BACKUP_TEMP_PATH به $ARCHIVED_FILE_PATH ..."
      if mv "$OLD_VERSION_BACKUP_TEMP_PATH" "$ARCHIVED_FILE_PATH"; then
        echo "نسخه قدیمی با موفقیت در $ARCHIVED_FILE_PATH آرشیو شد."
        OLD_VERSION_BACKUP_TEMP_PATH="" # پاک کردن متغیر چون عملیات انجام شده
      else
        echo "هشدار: آرشیو کردن نسخه قدیمی از $OLD_VERSION_BACKUP_TEMP_PATH به $ARCHIVED_FILE_PATH ناموفق بود." >&2
        echo "فایل پشتیبان موقت هنوز در $OLD_VERSION_BACKUP_TEMP_PATH موجود است." >&2
      fi
    fi

    # 6. پیکربندی Neda
    echo "درحال پیکربندی Neda..."
    # اجرای دستورات پیکربندی در یک subshell با بررسی خطا برای هر دستور
    (
      set -e
      echo "اجرای: $INSTALL_PATH configure"
      "$INSTALL_PATH" configure
      echo "اجرای: $INSTALL_PATH server:initialize"
      "$INSTALL_PATH" server:initialize
      echo "اجرای: $INSTALL_PATH server:start"
      "$INSTALL_PATH" server:start
      echo "اجرای: $INSTALL_PATH server:trust"
      "$INSTALL_PATH" server:trust
    )
    if [ $? -eq 0 ]; then
      echo "پیکربندی Neda با موفقیت انجام شد."
      echo "نصب و راه‌اندازی Neda کامل شد!"
    else
      echo "خطا: پیکربندی Neda ناموفق بود." >&2
      echo "فایل باینری Neda در $INSTALL_PATH نصب شده است، اما در پیکربندی مشکلی رخ داده است." >&2
      # در این حالت، نسخه جدید نصب شده است اما پیکربندی مشکل دارد.
      # تصمیم با شماست که آیا در این حالت هم باید به نسخه قبلی بازگردید یا خیر.
      # طبق درخواست اولیه، بازگردانی فقط در صورت شکست دانلود/انتقال فایل است.
      exit 1 # نشان‌دهنده خطای پیکربندی
    fi

  else # اگر انتقال فایل دانلود شده به مسیر نهایی ناموفق بود
    echo "خطا: انتقال فایل دانلود شده از $TMP_DOWNLOAD_PATH به $INSTALL_PATH ناموفق بود." >&2
    if [ -n "$OLD_VERSION_BACKUP_TEMP_PATH" ] && [ -f "$OLD_VERSION_BACKUP_TEMP_PATH" ]; then
      echo "درحال بازگردانی نسخه قبلی از $OLD_VERSION_BACKUP_TEMP_PATH ..."
      if mv "$OLD_VERSION_BACKUP_TEMP_PATH" "$INSTALL_PATH"; then
        echo "نسخه قبلی با موفقیت به $INSTALL_PATH بازگردانده شد."
        OLD_VERSION_BACKUP_TEMP_PATH="" # پاک کردن متغیر
      else
        echo "خطای بحرانی: بازگرداندن نسخه قبلی از $OLD_VERSION_BACKUP_TEMP_PATH به $INSTALL_PATH ناموفق بود!" >&2
        echo "سیستم شما ممکن است در وضعیت ناپایداری باشد. فایل پشتیبان موقت در $OLD_VERSION_BACKUP_TEMP_PATH است." >&2
      fi
    fi
    rm -f "$TMP_DOWNLOAD_PATH" # پاک کردن فایل دانلود ناموفق
    exit 1
  fi
else # اگر دانلود ناموفق بود
  echo "خطا: دانلود از $DOWNLOAD_URL ناموفق بود." >&2
  if [ -n "$OLD_VERSION_BACKUP_TEMP_PATH" ] && [ -f "$OLD_VERSION_BACKUP_TEMP_PATH" ]; then
    echo "درحال بازگردانی نسخه قبلی از $OLD_VERSION_BACKUP_TEMP_PATH ..."
    if mv "$OLD_VERSION_BACKUP_TEMP_PATH" "$INSTALL_PATH"; then
      echo "نسخه قبلی با موفقیت به $INSTALL_PATH بازگردانده شد."
      OLD_VERSION_BACKUP_TEMP_PATH="" # پاک کردن متغیر
    else
      echo "خطای بحرانی: بازگرداندن نسخه قبلی از $OLD_VERSION_BACKUP_TEMP_PATH به $INSTALL_PATH ناموفق بود!" >&2
      echo "سیستم شما ممکن است در وضعیت ناپایداری باشد. فایل پشتیبان موقت در $OLD_VERSION_BACKUP_TEMP_PATH است." >&2
    fi
  fi
  # فایل TMP_DOWNLOAD_PATH ممکن است وجود نداشته باشد یا ناقص باشد، rm -f امن است.
  rm -f "$TMP_DOWNLOAD_PATH"
  exit 1
fi

exit 0