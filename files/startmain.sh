#!/bin/bash

#
# Make the rings if they don't exist already
#

# These can be set with docker run -e VARIABLE=X at runtime
SWIFT_PART_POWER=${SWIFT_PART_POWER:-7}
SWIFT_PART_HOURS=${SWIFT_PART_HOURS:-1}
SWIFT_REPLICAS=${SWIFT_REPLICAS:-1}

# clear /srv/ folder
rm -rf /srv/*

if [ -e /srv/account.builder ]; then
	echo "Ring files already exist in /srv, copying them to /etc/swift..."
	cp /srv/*.builder /etc/swift/
	cp /srv/*.gz /etc/swift/
fi

# This comes from a volume, so need to chown it here, not sure of a better way
# to get it owned by Swift.
chown -R swift:swift /srv

# build ring

cd /etc/swift

# 2^& = 128 we are assuming just one drive
# 1 replica only

echo "No existing ring files, creating them..."

swift-ring-builder object.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/a 1
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/b 1
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/c 1
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/e 1
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/f 1
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/g 1
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/h 1
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/i 1


#swift-ring-builder object.builder add r1z1-127.0.0.1:6110/sdb1 1
#swift-ring-builder object.builder add r1z1-127.0.0.1:6110/sdc1 1

swift-ring-builder object.builder rebalance
swift-ring-builder container.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
swift-ring-builder container.builder add r1z1-127.0.0.1:6011/sdb1 1
swift-ring-builder container.builder add r1z1-127.0.0.1:6011/sdc1 1
swift-ring-builder container.builder add r1z1-127.0.0.1:6011/sdd1 1
swift-ring-builder container.builder add r1z1-127.0.0.1:6011/hello 1

#swift-ring-builder container.builder add r1z1-127.0.0.1:6111/sdb1 1
#swift-ring-builder container.builder add r1z1-127.0.0.1:6111/sdc1 1

swift-ring-builder container.builder rebalance
swift-ring-builder account.builder create ${SWIFT_PART_POWER} ${SWIFT_REPLICAS} ${SWIFT_PART_HOURS}
swift-ring-builder account.builder add r1z1-127.0.0.1:6012/sdb1 1
swift-ring-builder account.builder add r1z1-127.0.0.1:6012/sdc1 1
swift-ring-builder account.builder add r1z1-127.0.0.1:6012/sdd1 1
swift-ring-builder account.builder add r1z1-127.0.0.1:6012/hello 1

#swift-ring-builder account.builder add r1z1-127.0.0.1:6112/sdb1 1
#swift-ring-builder account.builder add r1z1-127.0.0.1:6112/sdc1 1

swift-ring-builder account.builder rebalance

# Back these up for later use
echo "Copying ring files to /srv to save them if it's a docker volume..."
mkdir /srv/ring
cp *.builder /srv/ring
cp *.gz /srv/ring



# If you are going to put an ssl terminator in front of the proxy, then I believe
# the storage_url_scheme should be set to https. So if this var isn't empty, set
# the default storage url to https.
if [ ! -z "${SWIFT_STORAGE_URL_SCHEME}" ]; then
	echo "Setting default_storage_scheme to https in proxy-server.conf..."
	sed -i -e "s/storage_url_scheme = default/storage_url_scheme = https/g" /etc/swift/proxy-server.conf
	grep "storage_url_scheme" /etc/swift/proxy-server.conf
fi

if [ ! -z "${SWIFT_SET_PASSWORDS}" ]; then
	echo "Setting passwords in /etc/swift/proxy-server.conf"
	PASS=`pwgen 12 1`
	sed -i -e "s/user_admin_admin = admin .admin .reseller_admin/user_admin_admin = $PASS .admin .reseller_admin/g" /etc/swift/proxy-server.conf
	sed -i -e "s/user_test_tester = testing .admin/user_test_tester = $PASS .admin/g" /etc/swift/proxy-server.conf
	sed -i -e "s/user_test2_tester2 = testing2 .admin/user_test2_tester2 = $PASS .admin/g" /etc/swift/proxy-server.conf
	sed -i -e "s/user_test_tester3 = testing3/user_test_tester3 = $PASS/g" /etc/swift/proxy-server.conf
	grep "user_test" /etc/swift/proxy-server.conf
fi

# Start supervisord
echo "Starting supervisord..."
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

#
# Tail the log file for "docker log $CONTAINER_ID"
#

# sleep waiting for rsyslog to come up under supervisord
sleep 3

service ssh restart
service rsync restart


# make version controll

cd ~/swift
cp /data/gitignore ~/swift/.gitignore
git config --global user.email "email@email.com"
git config --global user.name "swift_docker"
git init
git add .
git commit -m "init"


# bashrc
git clone https://github.com/ya790206/auto_config /auto_config
python /auto_config/init_bashrc.py
sed -i 's/exec tmux/ echo "S" /' ~/.bashrc

# disable capture_stdio for pdb.
echo 'def capture_stdio(logger, **kwargs): pass' >>   common/utils.py


# upload a image
swift -A http://127.0.0.1:8080/auth/v1.0 -U test:tester -K testing upload a ~/image


/bin/bash
