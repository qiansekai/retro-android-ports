# ported from pdx203-jellybean by @chardidathing
# KitKat adbd closes ep0 on every disconnect, and closing an ffs instance
# unbinds the whole gadget from the udc. Keep binding until it sticks.
UDC=/config/usb_gadget/g1/UDC
while true; do
    if [ -z "$(cat $UDC)" ]; then
        echo a600000.dwc3 > $UDC 2>/dev/null
        echo "usbudc: bind -> $(cat $UDC)" > /dev/kmsg
    fi
    sleep 2
done
