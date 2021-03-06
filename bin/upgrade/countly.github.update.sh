#!/bin/bash

set -ex

if [[ $EUID -ne 0 ]]; then
   echo "Please execute Countly update script with a superuser..." 1>&2
   exit 1
fi

echo "
   ______                  __  __
  / ____/___  __  ______  / /_/ /_  __
 / /   / __ \/ / / / __ \/ __/ / / / /
/ /___/ /_/ / /_/ / / / / /_/ / /_/ /
\____/\____/\__,_/_/ /_/\__/_/\__, /
              http://count.ly/____/

--------------------------------------
- Updating Countly code from Github  -
--------------------------------------

"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DT=`date +%Y.%m.%d_%H.%M.%S`
COUNTLY_DIR=`basename $(dirname $(dirname "${DIR}"))`
BACKUP_FILE="$COUNTLY_DIR.backup.$DT.tar.bz2"

if [ "$1" != "--no-backup" ]
then
	cd $DIR/../../..
	pwd
	echo "Backing up countly directory ($COUNTLY_DIR) to $BACKUP_FILE file"

	tar cjfv "$BACKUP_FILE" $(basename $COUNTLY_DIR)
fi

if ! type git >/dev/null 2>&1; then
    apt-get update && apt-get -y install git
fi

rm -rf /tmp/countly-github

git clone https://github.com/Countly/countly-server.git -b plugins /tmp/countly-github || (echo "Failed to checkout Countly core from Github" ; exit)

stop countly-supervisor

rsync -avh --exclude='.git/' --exclude='log/' /tmp/countly-github/ $DIR/../  || (echo "Failed to synchronize folder contents" ; exit)

rm -rf /tmp/countly-github

( cd $DIR/.. ; npm install -g grunt-cli --unsafe-perm ; npm install ) || (echo "Failed to install Node.js dependencies" ; exit)

if [ ! -f $DIR/../plugins/plugins.json ]; then
	cp $DIR/../plugins/plugins.default.json $DIR/../plugins/plugins.json
fi

bash $DIR/scripts/countly.install.plugins.sh

cd $DIR && grunt dist-all

if [ `getent passwd countly`x != 'x' ]; then
  chown -R countly:countly $DIR/..
fi

start countly-supervisor

echo "Countly has been successfully updated"
