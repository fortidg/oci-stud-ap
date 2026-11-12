Content-Type: multipart/mixed; boundary="==OCI=="
MIME-Version: 1.0

--==OCI==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="config"

config system global
  set hostname ${fgt_vm_name}
  set admintimeout 480
  set admin-sport 8443
end

config system vdom-exception
    edit 1
        set object system.interface
    next
    edit 2
        set object firewall.vip
    next
    edit 3
        set object router.static
    next
end

config system admin
  edit admin
  set password ${fgt_password}
  end
end

config system sdn-connector
  edit oci-sdn
    set type oci
    set use-metadata-iam enable
  next
end

config system interface
  edit port1
    set vdom root
    set mode dhcp
    set alias mgmt
    set description mgmt
    set allowaccess https ssh fgfm
  next
end

config system interface
  edit port2
    set vdom root
    set alias untrusted
    set mode static
    set allowaccess ping https ssh fgfm probe-response
    set ip ${unt_float}/${port2_mask}
    set secondary-IP enable
    config secondaryip
    edit 1
    set ip ${port2_ip}/${port2_mask}
    next
    end
  next
end

config system interface
  edit port3
    set vdom root
    set alias trusted
    set mode static
    set ip ${tr_float}/${port3_mask}
    set allowaccess ping https ssh fgfm probe-response
    set mtu-override enable
    set mtu 9000
    set secondary-IP enable
    config secondaryip
    edit 1
    set ip ${port3_ip}/${port3_mask}
    next
    end

  next
end

config system interface
  edit port4
    set vdom root
    set alias hbdev
    set mode static
    set ip ${port4_ip}/${port4_mask}
    set allowaccess ping https ssh fgfm probe-response
  next
end
config router static
  edit 0
    set device port2
    set gateway ${untrusted_gateway_ip}
  next
end
config system ha
    set group-name "group1"
    set mode a-p
    set hbdev "port4" 50
    set session-pickup enable
    set ha-mgmt-status enable
    config ha-mgmt-interfaces
        edit 1
            set interface "port1"
            set gateway ${management_gateway_ip}
        next
    end
    set override disable
    set priority ${priority}
    set unicast-hb enable
    set unicast-hb-peerip ${peer_hbdev_ip}
    set password Fortinet1!

end
config firewall policy
    edit 1
        set name "trust traffic"
        set srcintf "port3"
        set dstintf "port3"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set nat enable
    next
end



--==OCI==--
