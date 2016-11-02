#!/bin/bash

#DISTRO="jessie trusty precise"

echo "======================"
echo $(date)

echo "======================"

cd ~/repos/alignak-monitoring.github.io/
git pull

sudo rm -rf /tmp/build-dir/*
rm -rf ~/repos/alignak-monitoring.github.io/build/*

cd ~/repos/alignak-docker/
git pull
sed -i 's/TAG:.*/TAG: ""/g' docker-compose.yml
sudo docker-compose rm -f
sudo docker-compose up

cp -r /tmp/build-dir/* ~/repos/alignak-monitoring.github.io/build/

cd ~/repos/alignak-monitoring.github.io/
python gen_download.py

git add downloads.md build/
git commit -m "Weekly build update"
git push origin master

#for dis in $DISTRO; do
#  bash ~/repos/alignak-packaging/tools/repo-add-deb.sh deb $dis /tmp/build-dir/*/*$dis*.deb
#  bash alignak-packaging/tools/repo-rebuild-index.sh deb $dis
#done

#bash ~/repos/alignak-packaging/tools/repo-add-rpm.sh centos/7 /tmp/build-dir/centos_7/*.rpm

echo "======================"

