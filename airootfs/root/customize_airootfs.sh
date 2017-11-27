#!/bin/bash

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

usermod -s /usr/bin/zsh root
cp -aT /etc/skel/ /root/
chmod 700 /root

! id admin && useradd -m -p "" -g users -G "adm,audio,log,network,rfkill,scanner,storage,optical,power,wheel" -s /usr/bin/zsh admin
cp -aT /etc/skel/ /home/admin
chown -R admin:users /home/admin
chown -R root:users /home/admin/Desktop/*.sh
chmod u+s /home/admin/Desktop/*.sh
chmod 700 /home/admin

sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/# \(%wheel ALL=(ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers

systemctl enable pacman-init.service choose-mirror.service
systemctl set-default multi-user.target
