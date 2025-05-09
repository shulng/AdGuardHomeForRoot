#!/system/bin/sh

AGH_DIR="/data/adb/agh"
SCRIPT_DIR="$AGH_DIR/scripts"
MOD_PATH="/data/adb/modules/AdGuardHome"

update_description() {
  sed -i "s/description=\[.*\]/description=\[$1\]/" "$MOD_PATH/module.prop"
}

exec >$AGH_DIR/agh.log 2>&1

(
  wait_time=0
  while [ "$(getprop init.svc.bootanim)" != "stopped" ]; do
    echo "Waiting for system to finish booting... ($wait_time s)"
    sleep 5
    wait_time=$((wait_time + 5))
  done

  boot_delay=$(grep "^boot_delay=" "$AGH_DIR/scripts/config.sh" | sed 's/^boot_delay=//')
  echo "boot_delay: $boot_delay s"
  if [ "$boot_delay" -lt 0 ]; then
    echo "boot_delay must be greater than or equal to 0"
    update_description "🔴boot_delay must be greater than or equal to 0"
    exit 1
  elif [ "$boot_delay" -gt 0 ]; then
    echo "Waiting for $boot_delay s..."
    sleep "$boot_delay"
  fi

  enable_iptables=false
  enable_iptables=$(grep "^enable_iptables=" "$AGH_DIR/scripts/config.sh" | sed 's/^enable_iptables=//')
  echo "enable_iptables: $enable_iptables"

  if [ ! -f "$MOD_PATH/disable" ]; then
    echo "trying to start bin"
    $SCRIPT_DIR/service.sh start
    if [ $? -ne 0 ]; then
      update_description "🔴failed to start bin"
      exit 1
    fi
    if [ "$enable_iptables" = true ]; then
      echo "tyring to enable iptables"
      $SCRIPT_DIR/iptables.sh enable
      if [ $? -ne 0 ]; then
        update_description "🔴failed to enable iptables"
        exit 1
      fi
      echo "iptables is enabled"
      update_description "🟢bin is running \& iptables is enabled"
    else
      echo "iptables is disabled"
      update_description "🟢bin is running \& iptables is disabled"
    fi
  else
    echo "module is disabled"
    update_description "🔴module is disabled"
  fi

  echo "starting inotifyd"
  inotifyd $SCRIPT_DIR/inotify.sh $MOD_PATH:d,n &
  echo "inotifyd started, pid: $!"
) &
