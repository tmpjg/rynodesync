#!/bin/bash

####################
#### RINODESYNC ####
####################

#### Global Variables ####

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

FLIST="$SCRIPTPATH/files.lst"
FILES=$( cat $FLIST | sort )

SHADOW="$SCRIPTPATH/.shadow_sync"


#### Confs ####

source $SCRIPTPATH/rinodesync.conf

#### Prepare ####
#Prepare Shadow
if [[ ! -f $SHADOW ]]
then
    touch $SHADOW
fi

#### Script ####

echo "---- run start $( date ) ----"

# Shadow estructure => filename:inodre_remote:inode_local

#Get list remote inodes by filename - filename:inode

RINODES=$(ssh -q -T -i $SSHKEY $RUSER@$RHOST << EOF
for f in $( echo ${FILES} )
do 
     echo "\$f:\$(stat -c '%i' ${RPATH}/\$f)"
done
EOF
)

# test conn
RESULTRINODES=$?
if [[ $RESULTRINODES -ne 0 ]]
then
    echo "fail conn"
    exit 1
fi

# check changes, new files and rotatations
for r in $RINODES
do
    echo "##########################################################"
    FILEREMOTENAME=$( echo $r | cut -d ':' -f1 )
    echo "archivo remoto: $FILEREMOTENAME"
    RINODE=$( echo $r | cut -d ':' -f2 )
    FILEREMOTE="$RPATH/$FILEREMOTENAME"
    FLOCAL=$( grep ":$RINODE:" $SHADOW | cut -d ':' -f1 ) # get name by rinode
    if [[ $FLOCAL == "" ]]
    then 
        echo "new file"
        rsync -avt --inplace -e "ssh -q -T -i $SSHKEY" $RUSER@$RHOST:$FILEREMOTE $SCRIPTPATH/$FILEREMOTENAME # log ? 
        LINODE=$( stat -c '%i' $SCRIPTPATH/$FILEREMOTENAME )
        OLDFLOCALSHADOW=$( grep "$FILEREMOTENAME:" $SHADOW )
        sed -i "/$OLDFLOCALSHADOW/d" $SHADOW >/dev/null 2>&1
        echo "$FILEREMOTENAME:$RINODE:$LINODE" >> $SHADOW
    elif [[ $FLOCAL != $FILEREMOTENAME ]]
    then
        echo "rotated"
        echo "name by rinode: $FLOCAL"
        OLDFLOCALSHADOW=$( grep "$FILEREMOTENAME:" $SHADOW )
        echo "found on shadow as: $OLDFLOCALSHADOW"
        mv -f $SCRIPTPATH/$FLOCAL $SCRIPTPATH/$FILEREMOTENAME
        sed -i "/$OLDFLOCALSHADOW/d" $SHADOW >/dev/null 2>&1
        LINODE=$( stat -c '%i' $SCRIPTPATH/$FILEREMOTENAME )
        echo "$FILEREMOTENAME:$RINODE:$LINODE" >> $SHADOW
    else
        echo "no changes"
    fi
done

#sync
rsync -avt --inplace --files-from=$FLIST -e "ssh -q -T -i $SSHKEY" $RUSER@$RHOST:$RPATH/ $SCRIPTPATH/ 

echo "---- run end $( date ) ----"
