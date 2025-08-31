#!/bin/bash
for size in 16 32 64 48 128 256 512 1024; do
    #inkscape -z -o $size.png -w $size -h $size icon.svg >/dev/null 2>/dev/null
    #convert chatgpt-3.png -resize ${size}x${size} app_icon_$size.png
echo "1"
done

for size in 32; do
    #inkscape -z -o ${size}x${size}.png -w $size -h $size tray-icon2.svg >/dev/null 2>/dev/null
    #inkscape -w 32 -h 32 32x32.png -o tray-ico2.svg
echo "svg"
done

for size in 16 32 64 48 128 256; do
    #inkscape -z -o $size.png -w $size -h $size icon.svg >/dev/null 2>/dev/null
    #convert chatgpt-3.png -resize ${size}x${size} app_icon_$size.png
    #convert chatgpt-3.png -resize ${size}x${size} ${size}x${size}.png
    echo "2"
done

# from ImageMagick
#convert 16.png 32.png 48.png 128.png 256.png -colors 256 icon.ico
#convert app_icon_16.png app_icon_32.png app_icon_48.png app_icon_128.png app_icon_256.png -colors 256 icon.ico
#/bin/rm 16.png 32.png 48.png 128.png 256.png
