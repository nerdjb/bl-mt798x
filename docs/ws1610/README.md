# Huasifei WS1610 — hanwckf U-Boot (all-in-UBI)

Prebuilt U-Boot for the Huasifei WS1610, using the OpenWrt **all-in-UBI**
flash layout. This keeps existing WS1610 OpenWrt sysupgrade images bootable.

## Release images

| File | Size | Purpose |
|------|------|---------|
| `mt7981_huasifei_ws1610-fip-fixed-parts.bin` | 716616 bytes | BL31 + hanwckf U-Boot FIP. Write to the UBI `fip` volume. |
| `mt7981_huasifei_ws1610-bl2.bin` | 234936 bytes | Raw BL2/preloader at NAND offset `0x0`. **Advanced recovery only.** |

SHA256:

```text
82629811e52bcef2c3b7f806ee539248a8c848d7ceda9a1f73f2826d187d613d  mt7981_huasifei_ws1610-bl2.bin
4d64aa9de13235fcf83fba21f676957e30ee740197cc5160fc51295b854a81dc  mt7981_huasifei_ws1610-fip-fixed-parts.bin
```

The easy installer updates only the FIP. It does **not** touch BL2, factory
data, the FIT image, or `rootfs_data`.

## Requirements

- The router is already on the OpenWrt all-in-UBI layout:
  - raw `bl2` at `0x0`
  - UBI at `0x100000`
  - UBI volumes: `factory`, `fip`, `fit`, `ubootenv`, `ubootenv2`, `rootfs_data`
- SSH or serial access to the router.
- **Do not use the easy installer on the stock vendor layout.** Stock firmware
  has no UBI `fip` volume. Convert to all-in-UBI first.

## Option 1 — one-command install from the router (recommended)

Copy the installer and FIP to the router, then run it:

```sh
scp install.sh mt7981_huasifei_ws1610-fip-fixed-parts.bin root@192.168.1.1:/tmp/
ssh root@192.168.1.1
sh /tmp/install.sh --yes /tmp/mt7981_huasifei_ws1610-fip-fixed-parts.bin
```

The script:

1. checks that this is a WS1610 and that the UBI `fip` volume exists,
2. verifies the FIP SHA256,
3. backs up the old FIP to `/root/ws1610-fip-backup.bin` (or `/tmp`),
4. creates `rootfs_data` if it is missing,
5. writes the new FIP with `ubiupdatevol`,
6. reboots.

Your configuration and overlay are preserved.

If the router has internet access, you can omit the FIP argument and let the
script download it from GitHub:

```sh
wget -O /tmp/install.sh \
  https://github.com/nerdjb/bl-mt798x/releases/download/ws1610-v1/install.sh
sh /tmp/install.sh --yes
```

### Windows

Download `install.bat`, `install.sh`, and the FIP into the same folder, then
double-click `install.bat`. It uses the Windows OpenSSH client (`ssh`/`scp`).
Enable **OpenSSH Client** in *Settings → Optional Features* if needed.

## Option 2 — U-Boot web failsafe

1. Connect your PC to the **LAN** port (the 1G port, not the 2.5G WAN port).
2. Set the PC to `192.168.1.2/24`.
3. Reboot the router and stop the hanwckf U-Boot menu.
4. Select **Start Web failsafe**.
5. Open:

   ```text
   http://192.168.1.1/uboot.html
   ```

6. Upload `mt7981_huasifei_ws1610-fip-fixed-parts.bin`.
7. Reboot.

## Option 3 — serial + TFTP

At the hanwckf U-Boot menu, choose **Upgrade ATF FIP** (`mtkupgrade fip`).

Use:

```text
U-Boot IP:     192.168.1.1
TFTP server:   192.168.1.254
Netmask:       255.255.255.0
File name:     mt7981_huasifei_ws1610-fip-fixed-parts.bin
```

Serial settings: `115200 8n1`, 3.3 V.

## First install from stock vendor firmware

The stock layout is different:

```text
BL2        0x0000000
u-boot-env 0x0100000
Factory    0x0180000
FIP        0x0380000
ubi        0x0620000
...
```

There is no UBI volume at `0x100000` for the BL2 to find. Do not flash this FIP
directly on stock firmware.

Recommended path:

1. Back up every stock partition, especially `Factory` (MAC + WiFi calibration).
2. Use UART + `mtk_uartboot` to RAM-load OpenWrt U-Boot.
3. In OpenWrt U-Boot, initialize the all-in-UBI layout with `Factory.bin`.
4. Write recovery, production, and BL2 **last**.
5. Boot OpenWrt.
6. Use Option 1 above to replace the FIP with the hanwckf FIP.

See the OpenWrt WS1610 support commit and the vendor transition image for the
full conversion procedure.

## BL2 / recovery

The BL2 in this release is optional. The OpenWrt BL2 already supports UBI at
`0x100000`, so replacing only the FIP is enough for normal use.

If you need to write BL2:

- write it **last**, after `fip`, `fit`, and `recovery` are valid;
- use `mtkupgrade bl2` or the U-Boot menu;
- keep UART recovery ready.

UART recovery command:

```sh
sudo mtk_uartboot -s /dev/ttyUSB0 \
  -p mt7981-ram-ddr4-bl2.bin --aarch64 \
  -f openwrt-mediatek-filogic-huasifei_ws1610-ubi-bl31-uboot.fip
```

## Notes

- After the FIP update, hanwckf U-Boot boots the `fit` volume with
  `mtkboardboot`.
- If you want a clean hanwckf environment, enter the U-Boot console and run:

  ```text
  env default -a
  saveenv
  ```

- The U-Boot bootmenu provides:
  - `Upgrade firmware`
  - `Upgrade ATF BL2`
  - `Upgrade ATF FIP`
  - `Start Web failsafe`
- U-Boot networking uses `gmac1` and the internal PHY (LAN port).

## Build from source

```sh
git clone https://github.com/nerdjb/bl-mt798x.git
cd bl-mt798x
git checkout add-huasifei-ws1610
SOC=mt7981 BOARD=huasifei_ws1610 ./build.sh
```

Output:

```text
output/mt7981_huasifei_ws1610-bl2.bin
output/mt7981_huasifei_ws1610-fip-fixed-parts.bin
```
