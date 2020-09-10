#!/bin/bash

# Cluster Clone Script
# ------- ----- ------
# This script is designed to duplicate the existing configuration of a cluster. It is ideal for "cloning" a cluster. If you need to
# setup another cluster SIMILAR to the original cluster, you will need to pay special attention to numerous variables 
# such as cluster/client/vserver/management/IPMI IPs and cluster name etc

# Changelog - 03/16 - changed cloud bucket variable.  It was "grep bucket" and is now "grep "\<bucket\>"" - Thanks KOber
# Changelog - 03/22 - added the command to upload the latest cluster_rebuild directory once this script finishes
# Changelog - 04/04 - when adding a junction with 'inheritPolicy' set to 'no', a policy needs provided - Thanks KOber
# Changelog - 05/07 - added Initial cluster object information
# Changelog - 05/24 - added Share ACL/ACE
# Changelog - 05/25 - Export rules with a "network" scope was not working
# Changelog - 07/03 - Removed licensing since the cluster ID changes. 
# Changelog - 07/03 - Configured Atmos core filer creation so $SERVERNAME =  $NETWORK (prior to this $BUCKET.$NETWORK was not correct)
# Changelog - 07/03 - Changed Cloud snapshots so that it only queries cloud core filers which were configured for snapshots, not all cloud core filers. 
# Changelog - 07/25 - Changed the cache policy search to explicitly exclude "Full Caching" so that cache policies named like "Full Caching with 1m WB" would not be excluded
# Changelog - 07/26 - Removed the commas for the corefiler.create section
# Changelog - 10/10 - use dbutil for any custom settings with note of "not in cluster" to keep things from being confusing
# Changelog - 10/31 - add simple vserver creation
# Changelog - 11/02 - added the ability to change a core filer's network. Thanks Bogacki
# to do - export rules for netgroups. This does not work due to an averecmd issue.  Engineering ticket 24116 was created to address this.  The script will output the netgroup rule
# Changelog - 04/25 - added functionality for AvereOS 4.6, 4.7 and 4.8
# Changelog - 05/02 - improved performance for getting CIFS shares
# Changelog - 05/14 - added the "createSubdir" setting when creating junctions
# Changelog - 05/30 - enabled mapping old vserver internal name to new vserver internal name (similar to mass custom settings). Thanks Griffith
# Changelog - 05/30 - modified commands to query syslog servers for code earlier than 4.7. Thanks Griffith
# Changelog - 06/07 - discovered custom settings for vserver and cpolicyActive/cpolicyAdmin would not be mapped properly on the new cluster. Fixed
# Changelog - 06/27 - added CIFS "Server Signing"
# Changelog - 08/10 - added 'force':'$FORCE' for NFS core filer creation
# Changelog - 08/17 - fixed a bug with cifs.addShare 
# Changelog - 11/12 - changed "echo "# "`echo $CLUSTER|grep name|grep -v clusterIPs` >> $OUTPUT" to "echo "# "`echo $CLUSTER|grep name|grep -v clusterIP` >> $OUTPUT"
# Changelog - 11/12 - changed "echo "# "`echo $CLUSTER|grep clusterIPs` >> $OUTPUT " to "echo "# "`echo $CLUSTER|grep clusterIP0` >> $OUTPUT"
# Changelog - 11/13 - changed "if [ $S3TYPE = "ECS" ] || [ $S3TYPE = "ATMOS" ]; then" to "if [[ $S3TYPE = "ECS" ]] || [[ $S3TYPE = "ATMOS" ]]; then"
# Changelog - 11/13 - cleaned up old comments
# Changelog - 11/13 - added the ability to add a network that is not the cluster network
# Changelog - 11/13 - ignored the vserverX.smbacldMassids custom settings since they are added automatically
# Changelog - 11/19 - added a 3 second pause after each core filer creation
# Changelog - 11/19 - fixed the cluster.addNetworkAddressRange to eliminate the last '}' typo
# Changelog - 12/13 - Changed the way we poll the directory services for 'default' and 'login'
# Changelog - 12/14 - excluded nodeMgmtIP when trying to collect the name of the cluster with cluster.get
# Changelog - 05/02 - added the trailing '}' for cluster.addClusterIPs
# Changelog - 2019/08/15 - Modified the vserver add to support vlans.  Also moved the section AFTER the core filer creation because a simple vserver can not be created without an existing core filer.  
#                          Added a section to indicate what version of config_restore is being executed
#                          Moved the custom setting section to be after the core filer creation to allow more time for the core filers to be added
#                          Removed some old comments
# Changelog - 2019/09/03 - To ignoreWarnings if a core filer already exists, the 'true' option was changed to 'True'
#                          When an Azure core filer is added, the Network name should match the Server Name (similar to ECS and ATMOS).  Added this conditional
# Changelog - 2019/09/26 - added corefiler.modify [corefiler_name] {'clientSuspend':'no'} after all core filers get created
# Changelog - 2020/03/19 - had to modify addJunction function because 'language' was an added option in newer code 6515549
#                          found a bug with generating the cache policy. it has been corrected
# Changelog - 2020/05/12 - when doing a cluster.get and DNSdomain is empty, it will return 'undefined'.  if doing a restore with this setting, it may cause
#                          problems with the DNS settings.  So the logic was added to convert 'undefined' to an empty set for cluster.modify
#                          Users other than 'admin' will have their passwords set to null. Meaning they do not have a password to log in. This should be
#                          set by the admin once the cluster is running

clear
TIMESTAMP=`date +%Y-%m-%d_%T`
OUTPUT_DIR="/support/Backups/cluster_rebuild_$TIMESTAMP"
mkdir -p $OUTPUT_DIR
export OUTPUT="$OUTPUT_DIR/1-config_restore.sh"
RELEASE=`averecmd cluster.get|grep activeImage|cut -c 51,53`

touch $OUTPUT_DIR/1-config_restore.sh
chmod 700 $OUTPUT_DIR/1-config_restore.sh

echo "#Initial cluster object information" >> $OUTPUT
IFS=$' ';CLUSTER=`averecmd --pretty cluster.get`
echo "# "`echo $CLUSTER|grep activeImage` >> $OUTPUT 
echo "# "`echo $CLUSTER|grep name|egrep -v 'clusterIP|nodeMgmtIP'` >> $OUTPUT 
echo "# "`echo $CLUSTER|grep mgmtIP` >> $OUTPUT 
echo "# "`echo $CLUSTER|grep default_router` >> $OUTPUT 
echo "# "`echo $CLUSTER|grep clusterIP0` >> $OUTPUT 
echo "# "`echo $CLUSTER|grep DNSserver` >> $OUTPUT 
echo "#  "`echo $CLUSTER|grep DNSdomain|cut -d { -f 2-` >> $OUTPUT 
echo "# "`echo $CLUSTER|grep NTPservers` >> $OUTPUT 
echo "#  "`grep "Changelog - " /support/Backups/config_restore.sh|tail -2|head -1|cut -d '-' -f 1,2` >> $OUTPUT
echo "" >> $OUTPUT
 
echo "#VLAN" |tee -a $OUTPUT
IFS=$'\n';for i in `lsu cluster.vlans|grep -v _|cut -d ':' -f 1`;do \
  if [ $i ]; then
    NAME=`lsu $i|grep "\<name\>"|cut -d ' ' -f 2`
    ROLES=`lsu $i|grep roles|cut -d ' ' -f 2`
    MTU=`lsu $i|grep mtu|cut -d ' ' -f 2`
    ROUTER=`averecmd --pretty cluster.getVLAN $NAME|grep router|cut -d "'" -f 4`
    TAG=`averecmd --pretty cluster.getVLAN $NAME|grep tag|cut -d "'" -f 4`
    echo "averecmd cluster.addVLAN $NAME $TAG $ROUTER $ROLES $MTU" >> $OUTPUT
  fi
done

echo |tee -a $OUTPUT
echo "#Cluster Networks - Address ranges" |tee -a $OUTPUT
echo |tee -a $OUTPUT
echo "#Cluster Networks - Non-cluster IP ranges, VLANS" |tee -a $OUTPUT
IFS=$'\n';for i in `averecmd cluster.listNetworks|awk '{print $1}'`; do \
  ADDRESSESPERNODE=`averecmd cluster.getNetwork $i|grep addressesPerNode|cut -d "'" -f 2`
  echo "averecmd cluster.addNetwork $i \"{'addressesPerNode':'$ADDRESSESPERNODE'}\"" >> $OUTPUT
  if [ $i = "cluster" ]; then \
    for j in `averecmd cluster.getNetwork $i|grep addressRange|grep -v addressRange0`; do \
      NETWORK_NAME=`echo $i`
      RANGE=`echo $j|cut -d "," -f 2-|rev|cut -c 3-|rev`
      echo "averecmd cluster.addClusterIPs \"{$RANGE}\"" >> $OUTPUT
      echo "averecmd cluster.addNetworkAddressRange $NETWORK_NAME \"{$RANGE}\"" >> $OUTPUT
    done
  else
    for j in `averecmd cluster.getNetwork $i|grep addressRange`; do \
      NETWORK_NAME=`echo $i`
      RANGE=`echo $j|cut -d "," -f 2-|rev|cut -c 3-|rev`
#      echo "averecmd cluster.addClusterIPs \"{$RANGE\"" >> $OUTPUT
      echo "averecmd cluster.addNetworkAddressRange $NETWORK_NAME \"{$RANGE}\"" >> $OUTPUT
    done
  fi
done

# Moving the VServer section after the core filer add section.  This is because simple vservers require a core filer name and a simple vserver can't be created without an exisiting core filer
#echo |tee -a $OUTPUT
#echo "#Manage VServers" |tee -a $OUTPUT
#IFS=$'\n';for i in `averecmd vserver.list`; do \
#  for j in `averecmd vserver.get $i`;do \
#    FIRST_IP=`echo $j |awk -F":" '{print $12}'|cut -d "'" -f 2`
#    LAST_IP=`echo $j|awk -F":" '{print $15}'|cut -d "'" -f 2`
#    NETMASK=`echo $j|awk -F":" '{print $13}'|cut -d "'" -f 2`
#    MASS=`echo $j|cut -d "'" -f 29`
#    TYPE=`echo $j|cut -d "'" -f 59`
#    if [ $TYPE == "simple" ]; then \
#      echo "averecmd vserver.create $i \"{'firstIP':'$FIRST_IP','netmask':'$NETMASK','lastIP':'$LAST_IP'}\" $MASS" >> $OUTPUT
#    else
#      echo "averecmd vserver.create $i \"{'firstIP':'$FIRST_IP','netmask':'$NETMASK','lastIP':'$LAST_IP'}\"" >> $OUTPUT
#    fi
#  done
#done

echo |tee -a $OUTPUT
echo "#Manage Caching Policies" |tee -a $OUTPUT
#IFS=$'\n';for i in `averecmd --pretty cachePolicy.list|egrep -v "'Clients Bypassing the Cluster'|'Read Caching'|'Read and Write Caching'|'Full Caching'|'Transitioning Clients Before or After a Migration'"|grep name|awk -F"'" '{print $4}'`;do \

IFS=$'\n';for i in `averecmd cachePolicy.list|egrep -v "'Clients Bypassing the Cluster'|'Read Caching'|'Read and Write Caching'|'Full Caching'|'Transitioning Clients Before or After a Migration'"|grep name|awk -F "name" '{print $2}'|cut -d "'" -f 3`; do \
  WRITEBACKDELAY=`averecmd cachePolicy.get $i|grep writebackDelay|awk -F"'" '{print $2}'`
  NAME=`averecmd cachePolicy.get $i|grep name|awk -F"'" '{print $2}'`
  LOCALDIRECTORIES=`averecmd cachePolicy.get $i|grep localDirectories|awk -F"'" '{print $2}'`
  CACHEMODE=`averecmd cachePolicy.get $i|grep cacheMode|awk -F"'" '{print $2}'`
  CHECKATTRIBUTES=`averecmd cachePolicy.get $i|grep checkAttributes|cut -d '{' -f 2|cut -d '}' -f 1`
  DESCRIPTION=`averecmd cachePolicy.get $i|grep description|awk -F"'" '{print $2}'`
  echo "averecmd cachePolicy.create \"$NAME\" $CACHEMODE $WRITEBACKDELAY \"{$CHECKATTRIBUTES}\" $LOCALDIRECTORIES {} \"\" \"$DESCRIPTION\"" >> $OUTPUT
done

echo |tee -a $OUTPUT
echo "#Manage Core Filers and Core Filer Details" |tee -a $OUTPUT

IFS=$'\n';for i in `averecmd corefiler.list`;do \
  TYPE=`averecmd --pretty corefiler.get $i|grep type|cut -d "'" -f 4`
  if [ $TYPE == "NFS" ]; then
    CORE_FILER=`averecmd --pretty corefiler.get $i|egrep "filerClass|\<name\>|\<network\>|\<networkName\>|policyName"`
    FILERCLASS=`echo $CORE_FILER|tr ',' '\n'|grep filerClass|cut -d "'" -f 4`
    NAME=`echo $CORE_FILER|tr ',' '\n'|grep '\<name\>'|cut -d "'" -f 4`
    NETWORK=`echo $CORE_FILER|tr ',' '\n'|grep '\<network\>'|cut -d "'" -f 4`
    NETWORKNAME=`echo $CORE_FILER|tr ',' '\n'|grep '\<networkName\>'|cut -d "'" -f 4`
    POLICYNAME=`echo $CORE_FILER|tr ',' '\n'|grep '\<policyName\>'|cut -d "'" -f 4`
    FORCE=True
    echo "averecmd corefiler.create \"$NAME\" \"$NETWORKNAME\" True \"{'filerClass':'$FILERCLASS', 'force':'$FORCE', 'cachePolicy':'$POLICYNAME'}\";sleep 3" >> $OUTPUT
	echo "averecmd corefiler.modify \"$NAME\" \"{'clientSuspend':'no'}\"">> $OUTPUT
  fi
  if [ "$NETWORK" != "cluster" ]; then 
    echo "averecmd corefiler.modifyNetwork \"$NAME\" \"$NETWORK\"" >> $OUTPUT
  fi

  if  [ $TYPE == "cloud" ]; then
    CORE_FILER=`averecmd --pretty corefiler.get $i`
    NAME=`echo $i`
    NETWORKNAME=`echo $CORE_FILER|tr ',' '\n'|grep '\<networkName\>'|cut -d "'" -f 4`
    CLOUDTYPE=`echo $CORE_FILER|tr ',' '\n'|grep '\<cloudType\>'|cut -d "'" -f 4`
    FORCE=True
    BUCKET=`echo $CORE_FILER|tr ',' '\n'|grep '\<bucket\>'|cut -d "'" -f 4`
    CLOUDCREDENTIAL=`echo $CORE_FILER|tr ',' '\n'|grep '\<cloudCredential\>'|cut -d "'" -f 4`
    CRYPTOMODE=`echo $CORE_FILER|tr ',' '\n'|grep '\<cryptoMode\>'|cut -d "'" -f 4`
    COMPRESSMODE=`echo $CORE_FILER|tr ',' '\n'|grep '\<compressMode\>'|cut -d "'" -f 4`
    CACHEPOLICYNAME=`echo $CORE_FILER|tr ',' '\n'|grep '\<policyName\>'|cut -d "'" -f 4`
    SSLVERIFY=`echo $CORE_FILER|tr ',' '\n'|grep '\<sslVerifyMode\>'|cut -d "'" -f 4`
    PORT=`echo $CORE_FILER|tr ',' '\n'|grep '\<port\>'|cut -d "'" -f 4`
    HTTPS=`echo $CORE_FILER|tr ',' '\n'|grep '\<https\>'|cut -d "'" -f 4`
    NETWORK=`echo $CORE_FILER|tr ',' '\n'|grep '\<network\>'|cut -d "'" -f 4`
    REGION=`echo $CORE_FILER|tr ',' '\n'|grep '\<region\>'|cut -d "'" -f 4`
    S3TYPE=`echo $CORE_FILER|tr ',' '\n'|grep '\<s3Type\>'|cut -d "'" -f 4`
    if [[ $S3TYPE = "ECS" ]] || [[ $S3TYPE = "ATMOS" ]] || [[ $CLOUDTYPE = "azure" ]]; then
      SERVERNAME=$NETWORKNAME
    else
      SERVERNAME=$BUCKET.$NETWORKNAME
    fi
    echo "averecmd corefiler.createCloudFiler \"$NAME\" \"{'cloudType':'$CLOUDTYPE', 'force':'$FORCE', 'bucket':'$BUCKET', 'cloudCredential':'$CLOUDCREDENTIAL', 'cryptoMode':'$CRYPTOMODE','compressMode':'$COMPRESSMODE', 'cachePolicyName':'$CACHEPOLICYNAME', 'sslVerifyMode':'$SSLVERIFY', 'port':'$PORT', 'https':'$HTTPS', 'networkName':'$NETWORKNAME', 'bucketContents':'used', 'region':'$REGION', 's3Type':'$S3TYPE', 'serverName':'$SERVERNAME'}\";sleep 3" >> $OUTPUT
    echo "averecmd corefiler.modify \"$NAME\" \"{'clientSuspend':'no'}\"">> $OUTPUT

    if [ $NETWORK != "cluster" ]; then 
      echo "averecmd corefiler.modifyNetwork \"$NAME\" \"$NETWORK\"" >> $OUTPUT
    fi
  fi
done

echo |tee -a $OUTPUT
echo "#Manage VServers" |tee -a $OUTPUT
for VSERVER in `lsu vservers|grep -v _|cut -d ':' -f 1`; do \
  for j in `lsu $VSERVER|grep dataIP|cut -d ' ' -f 2`; do \
    FIRST_IP=`echo $j|cut -d ',' -f 1`
    LAST_IP=`echo $j|cut -d ',' -f 2|cut -d ';' -f 1`
    NETMASK=`echo $j|cut -d ',' -f 2|cut -d ':' -f 2`
    FIB=`echo $j|cut -d ' ' -f2|cut -d ',' -f 3|cut -d ':' -f 2`
    NAME=`lsu $VSERVER name|cut -d ' ' -f 2`
    VLAN=`averecmd --pretty vserver.get $NAME|grep vlan|cut -d "'" -f 4`
    TYPE=`averecmd --pretty vserver.get $NAME|grep type|cut -d "'" -f 4`
    MASS=`averecmd --pretty vserver.get $NAME|grep mass|cut -d "'" -f 4`
#    echo $j
#    echo "Name:     " $NAME
#    echo "First IP: " $FIRST_IP
#    echo "Last IP:  " $LAST_IP
#    echo "Netmask:  " $NETMASK
#    echo "FIB:      " $FIB
#    echo "VLAN:     " $VLAN
#    echo "Type:     " $TYPE
#    echo "Mass:     " $MASS
    if [[ $TYPE == "simple" ]]; then \
	  if  [[ $VLAN ]]; then \
        echo "averecmd vserver.create $NAME \"{'firstIP':'$FIRST_IP','netmask':'$NETMASK','vlan':'$VLAN','lastIP':'$LAST_IP'}\" $MASS" >> $OUTPUT
	  else
	    echo "averecmd vserver.create $NAME \"{'firstIP':'$FIRST_IP','netmask':'$NETMASK','lastIP':'$LAST_IP'}\" $MASS" >> $OUTPUT
	  fi
    elif [[ $TYPE != "simple" ]]; then \
      if [[ $VLAN ]]; then \
        echo "averecmd vserver.create $NAME \"{'firstIP':'$FIRST_IP','netmask':'$NETMASK','vlan':'$VLAN','lastIP':'$LAST_IP'}\"" >> $OUTPUT
      else
        echo "averecmd vserver.create $NAME \"{'firstIP':'$FIRST_IP','netmask':'$NETMASK','lastIP':'$LAST_IP'}\"" >> $OUTPUT
	  fi
    fi
#  echo
  done
done

echo |tee -a $OUTPUT
echo "#Custom settings are addressed with \"2-run_on_new_cluster_mass_mappings.sh\", \"3-run_on_new_cluster_new_custom_settings.sh\", \"4-run_on_new_cluster_new_custom_settings.sh\"" |tee -a $OUTPUT

#IFS=$'\n';for i in `name_mapping.py --custom|egrep -v 'Custom Settings:|----------------'`;do \
IFS=$'\n';for i in `name_mapping.py --custom|egrep -v 'Custom Settings:|----------------|smbacldMassids'`;do \
  NAME=`echo $i|cut -d ':' -f 1|awk '{print $1}'`
  CHECKCODE=`averecmd support.checkCode $NAME|grep check|cut -d "'" -f 2`
  VALUE=`echo $i|awk '{print $2}'`
  NOTE=`echo $i|cut -d '(' -f 2`;
  if [[ $NOTE = *"NOT in cluster.settings"* ]]; then \
    NAME2=`echo $NAME|tr . ' '`
    echo "dbutil.py set $NAME2 $VALUE -x" >> $OUTPUT_DIR/original_custom_settings.txt
  else
    echo "averecmd support.setCustomSetting $NAME $CHECKCODE $VALUE \"($NOTE\"" >> $OUTPUT_DIR/original_custom_settings.txt
  fi
done

echo |tee -a $OUTPUT
echo "#Cloud Snapshot Policies" |tee -a $OUTPUT
# New in 4.7
for i in `averecmd --pretty snapshot.listPolicies|grep corefilers|cut -d "'" -f 4`; do \
  if [ `averecmd --pretty corefiler.get $i|grep type|cut -d "'" -f 4` = "cloud" ]; then
    DEFAULTWEEKDAY=`averecmd snapshot.getFilerPolicy $i|grep defaultWeekDay|cut -d "'" -f 2`
    NAME=`averecmd snapshot.getFilerPolicy $i|grep name|cut -d "'" -f 2`
    DEFAULTMONTHDAY=`averecmd snapshot.getFilerPolicy $i|grep defaultMonthDay|cut -d "'" -f 2`
    DEFAULTTIME=`averecmd snapshot.getFilerPolicy $i|grep defaultTime|cut -d "'" -f 2`
    NOTE=`averecmd snapshot.getFilerPolicy $i|grep note|cut -d "'" -f 2`
    POLICY=`averecmd snapshot.getFilerPolicy $i|grep policy|cut -d "'" -f 2-|rev|cut -d "'" -f 2-|rev`
    if [ ! `averecmd snapshot.getFilerPolicy $i|grep snapType|cut -d "'" -f 2` ]; then
      SNAPTYPE=strict
    else 
      SNAPTYPE=`averecmd snapshot.getFilerPolicy $i|grep snapType|cut -d "'" -f 2`
    fi
    if [ "$POLICY" ]; then
      if [ "$RELEASE" -ge "48" ]; then
        echo "averecmd snapshot.createPolicy \"$NAME\" \"$POLICY\" \"{'note':'$NOTE','defaultTime':'$DEFAULTTIME', 'snapType':'$SNAPTYPE'}\"" >> $OUTPUT
      else
        echo "averecmd snapshot.createPolicy \"$NAME\" \"$POLICY\" \"{'note':'$NOTE','defaultTime':'$DEFAULTTIME'}\"" >> $OUTPUT
      fi
      echo "sleep 5" >> $OUTPUT
      echo "averecmd snapshot.modifyFilerPolicy $i \"$NAME\"" >> $OUTPUT
    fi
  fi
done

echo |tee -a $OUTPUT
echo "#NFS" |tee -a $OUTPUT
N=0;IFS=$'\n';for i in `averecmd vserver.list`;do \
  for j in `averecmd nfs.get $i`; do \
    A_NFS[$N]=`echo $j|cut -d "'" -f 2`
    let "N=$N+1"
  done
  RWSIZE=`echo ${A_NFS[0]}`
  KERBEROS=`echo ${A_NFS[1]}`
  EXTENDEDGROUPS=`echo ${A_NFS[2]}`
  echo "averecmd nfs.modify $i \"{'kerberos':'$KERBEROS','extendedGroups':'$EXTENDEDGROUPS'}\"" >> $OUTPUT
done

echo |tee -a $OUTPUT
echo "#Namespace" |tee -a $OUTPUT
echo "sleep 5" >> $OUTPUT
#IFS=$'\n';for i in `averecmd vserver.list`;do \
#  for j in `averecmd vserver.listJunctions $i`;do \
#    SHARESUBDIR=`echo $j|cut -d "'" -f 4`
#    INHERITPOLICY=`echo $j|cut -d "'" -f 8`
#    SHARENAME=`echo $j|cut -d "'" -f 16`
#    ACCESS=`echo $j|cut -d "'" -f 24`
#    EXPORT=`echo $j|cut -d "'" -f 28`
#    SUBDIR=`echo $j|cut -d "'" -f 32`
#    if [ $SUBDIR ]; then
#      CREATESUBDIRS=yes
#    else
#      CREATESUBDIRS=no
#    fi
#    JUNCTION_PATH=`echo $j|cut -d "'" -f 40`
#    COREFILER=`echo $j|cut -d "'" -f 44`
#    if [ $INHERITPOLICY == "no" ]; then
#      POLICY=`echo $j|cut -d "'" -f 36`
#      echo "averecmd vserver.addJunction $i $JUNCTION_PATH $COREFILER $EXPORT \"{'sharesubdir': '$SHARESUBDIR', 'inheritPolicy': '$INHERITPOLICY', 'sharename': '$SHARENAME', 'access': '$ACCESS', 'subdir': '$SUBDIR', 'createSubdirs':'$CREATESUBDIRS', 'policy':'$POLICY'}\"" >> $OUTPUT
#    else
#      echo "averecmd vserver.addJunction $i $JUNCTION_PATH $COREFILER $EXPORT \"{'sharesubdir': '$SHARESUBDIR', 'inheritPolicy': '$INHERITPOLICY', 'sharename': '$SHARENAME', 'access': '$ACCESS', 'subdir': '$SUBDIR', 'createSubdirs':'$CREATESUBDIRS'}\"" >> $OUTPUT
#    fi
#  done
#done

IFS=$'\n';for i in `averecmd vserver.list`;do \
  for j in `averecmd vserver.listJunctions $i`;do \
    SHARESUBDIR=`echo $j|tr ',' '\n'|egrep "\<sharesubdir\>"|awk -F"'" '{print $4}'`
    INHERITPOLICY=`echo $j|tr ',' '\n'|egrep "\<inheritPolicy\>"|awk -F"'" '{print $4}'`
    SHARENAME=`echo $j|tr ',' '\n'|egrep "\<sharename\>"|awk -F"'" '{print $4}'`
    ACCESS=`echo $j|tr ',' '\n'|egrep "\<access\>"|awk -F"'" '{print $4}'`
    EXPORT=`echo $j|tr ',' '\n'|egrep "\<export\>"|awk -F"'" '{print $4}'`
    SUBDIR=`echo $j|tr ',' '\n'|egrep "\<subdir\>"|awk -F"'" '{print $4}'`
    if [ $SUBDIR ]; then
      CREATESUBDIRS=yes
    else
      CREATESUBDIRS=no
    fi
    JUNCTION_PATH=`echo $j|tr ',' '\n'|egrep "\<path\>"|awk -F"'" '{print $4}'`
    COREFILER=`echo $j|tr ',' '\n'|egrep "\<corefiler\>"|awk -F"'" '{print $4}'`
    if [ $INHERITPOLICY == "no" ]; then
      POLICY=`echo $j|tr ',' '\n'|egrep "\<policy\>"|awk -F"'" '{print $4}'`
      echo "averecmd vserver.addJunction $i $JUNCTION_PATH $COREFILER $EXPORT \"{'sharesubdir': '$SHARESUBDIR', 'inheritPolicy': '$INHERITPOLICY', 'sharename': '$SHARENAME', 'access': '$ACCESS', 'subdir': '$SUBDIR', 'createSubdirs':'$CREATESUBDIRS', 'policy':'$POLICY'}\"" >> $OUTPUT
    else
      echo "averecmd vserver.addJunction $i $JUNCTION_PATH $COREFILER $EXPORT \"{'sharesubdir': '$SHARESUBDIR', 'inheritPolicy': '$INHERITPOLICY', 'sharename': '$SHARENAME', 'access': '$ACCESS', 'subdir': '$SUBDIR', 'createSubdirs':'$CREATESUBDIRS'}\"" >> $OUTPUT
    fi
  done
done


echo |tee -a $OUTPUT
echo "#Directory Services and Kerberos" |tee -a $OUTPUT
A_DIRSERVICES=()
N=0;IFS=$'\n';for i in `averecmd dirServices.get default`;do \
  A_DIRSERVICES[$N]=`echo $i\|`
  let "N = $N + 1"
done

M=0;
MAX=`expr ${#A_DIRSERVICES[@]} - 1`
for i in ${A_DIRSERVICES[@]}; do \
if [[ $i != "rev"* ]] && [[ $i != "id"* ]]; then \
  SETTING=`echo $i|awk '{print $1}'`; 
  VALUE=`echo $i|cut -d "'" -f 2`; 
  if [ $M = "0" ]; then \
    echo "averecmd dirServices.modify 'default' \"{'$SETTING'":"'$VALUE'","" >> $OUTPUT;
  elif [ $VALUE ]; then \
    echo "'$SETTING'":"'$VALUE'","" >> $OUTPUT;
  fi
fi
let "M=$M+1"
done
echo "}\"" >> $OUTPUT


A_DIRSERVICES=()
N=0;IFS=$'\n';for i in `averecmd dirServices.get login`;do \
  A_DIRSERVICES[$N]=`echo $i\|`
  let "N = $N + 1"
done

M=0;
MAX=`expr ${#A_DIRSERVICES[@]} - 1`
for i in ${A_DIRSERVICES[@]}; do \
if [[ $i != "rev"* ]] && [[ $i != "id"* ]]; then \
  SETTING=`echo $i|awk '{print $1}'`; 
  VALUE=`echo $i|cut -d "'" -f 2`; 
  if [ $M = "0" ]; then \
    echo "averecmd dirServices.modify 'login' \"{'$SETTING'":"'$VALUE'","" >> $OUTPUT;
  elif [ $VALUE ]; then \
    echo "'$SETTING'":"'$VALUE'","" >> $OUTPUT;
  fi
fi
let "M=$M+1"
done
echo "}\"" >> $OUTPUT

echo |tee -a $OUTPUT
for i in `averecmd vserver.list`; do \
  if [[ `averecmd cifs.getConfig $i|grep enabled|cut -d "'" -f 2` = "True" ]]; then \
    ENABLE_CIFS=True
    CIFSSERVERNAME=`averecmd cifs.getConfig $i|grep CIFSServerName|cut -d "'" -f 2`;
    echo "#CIFS for vServer \"$i\"" |tee -a $OUTPUT_DIR/1.5-run_on_new_cluster_before_custom_settings_restore_cifs.sh
    chmod 700 $OUTPUT_DIR/1.5-run_on_new_cluster_before_custom_settings_restore_cifs.sh
    CLIENT_NTLMSSP_DISABLE=`averecmd cifs.getOptions $i|grep client_ntlmssp_disable|cut -d "'" -f 2`;
    GUEST_ACCOUNT=`averecmd cifs.getOptions $i|grep guest_account|cut -d "'" -f 2`;
    SMB2=`averecmd cifs.getOptions $i|grep smb2|cut -d "'" -f 2`;
    SMB1=`averecmd cifs.getOptions $i|grep smb1|cut -d "'" -f 2`;
    NATIVE_IDENTITY=`averecmd cifs.getOptions $i|grep native_identity|cut -d "'" -f 2`;
    READ_ONLY_OPTIMIZED=`averecmd cifs.getOptions $i|grep read_only_optimized|cut -d "'" -f 2`;
    SERVER_SIGNING=`averecmd cifs.getOptions $i|grep server_signing|cut -d "'" -f 2`;
    echo "echo """ >> $OUTPUT
    echo "echo "We have identified vserver \\\"$i\\\" has CIFS enabled however the Avere does not retain passwords so we are unable to automatically enable CIFS."" >> $OUTPUT
    echo "echo "You will need to join the vserver \\\"$i\\\" to the domain with the following information and then run the \\\"1.5-run_on_new_cluster_before_custom_settings_restore_cifs.sh\\\" script."" >> $OUTPUT
    echo "echo """ >> $OUTPUT
    echo "echo "vserver is: "$i" >> $OUTPUT
    echo "echo "Enable CIFS: "$ENABLE_CIFS" >> $OUTPUT
    if [ $SMB1 ]; then \
      echo "echo "Enable SMB1: "$SMB1" >> $OUTPUT
    fi
    echo "echo "Enable SMB2: "$SMB2" >> $OUTPUT
    echo "echo "CIFS Server Name: "$CIFSSERVERNAME" >> $OUTPUT
    echo "echo "Enable Native Identity: "$NATIVE_IDENTITY" >> $OUTPUT
    echo "echo "Enable Read-only Optimized: "$READ_ONLY_OPTIMIZED" >> $OUTPUT
    echo "echo "Client NTLMSSP Disable: "$CLIENT_NTLMSSP_DISABLE" >> $OUTPUT
    if [ $SERVER_SIGNING ]; then \
      echo "echo "Server Signing "$SERVER_SIGNING" >> $OUTPUT
    fi
    echo "echo "Guest Account: "$GUEST_ACCOUNT" >> $OUTPUT
    echo "echo """ >> $OUTPUT
    echo "read -p \"Press enter AFTER \\\"$i\\\" has joined the domain\"" >> $OUTPUT
  else
    echo "echo """ >> $OUTPUT
    echo "#CIFS is not enabled for vServer \"$i\"" |tee -a $OUTPUT
  fi
done

echo |tee -a $OUTPUT

# This method of getting CIFS shares cut time down
IFS=$'\n';for i in `averecmd vserver.list`; do \
  for SHARENAME in `averecmd --pretty cifs.listShares $i|grep shareName|cut -d "'" -f 4`; do \
    IFS=$' '
    CIFS_SHARE=`averecmd cifs.getShare $i $SHARENAME`
    ACCESSCONTROL=`echo $CIFS_SHARE|grep accessControl|cut -d "'" -f 2`
    HOMEDIR=`echo $CIFS_SHARE|grep homeDir|cut -d "'" -f 2`
    EXPORT=`echo $CIFS_SHARE|grep export|cut -d "'" -f 2`
    SUFFIX=`echo $CIFS_SHARE|grep suffix|cut -d "'" -f 2`
    NAMESPACE=`averecmd --pretty vserver.get $i|grep type|cut -d "'" -f 4`
    if [ $HOMEDIR == "yes" ]; then \
      HOMEDIR=True
    fi
    if [ $NAMESPACE == "gns" ]; then \
      ACCESSCONTROL="''"
    fi
    if [ -z "$SUFFIX" ]; then \
      SUFFIX="''"
    fi
    FORCE_USER=`echo $CIFS_SHARE|grep "force user"|cut -d "'" -f 2`
    LEVEL2_OPLOCKS=`echo $CIFS_SHARE|grep "level2 oplocks"|cut -d "'" -f 2`
    STRICT_LOCKING=`echo $CIFS_SHARE|grep "strict locking"|cut -d "'" -f 2`
    READ_ONLY_OPTIMIZED=`echo $CIFS_SHARE|grep "read only optimized"|cut -d "'" -f 2`
    INHERIT_PERMISSIONS=`echo $CIFS_SHARE|grep "inherit permissions"|cut -d "'" -f 2`
    CREATE_MASK=`echo $CIFS_SHARE|grep "create mask"|cut -d "'" -f 2`
    BROWSEABLE=`echo $CIFS_SHARE|grep "browseable"|cut -d "'" -f 2`
    SECURITY_MASK=`echo $CIFS_SHARE|grep "security mask"|grep -v directory|cut -d "'" -f 2`
    DIRECTORY_MASK=`echo $CIFS_SHARE|grep "directory mask"|cut -d "'" -f 2`
    GUEST_OK=`echo $CIFS_SHARE|grep "guest ok"|cut -d "'" -f 2`
    FORCE_CREATE_MODE=`echo $CIFS_SHARE|grep "force create mode"|cut -d "'" -f 2`
    HIDE_UNREADABLE=`echo $CIFS_SHARE|grep "hide unreadable"|cut -d "'" -f 2`
    FORCE_DIRECTORY_MODE=`echo $CIFS_SHARE|grep "force directory mode"|cut -d "'" -f 2`
    READ_ONLY=`echo $CIFS_SHARE|grep "read only"|grep -v optimized|cut -d "'" -f 2`
    DIRECTORY_SECURITY_MASK=`echo $CIFS_SHARE|grep "\<directory security mask\>"|cut -d "'" -f 2`
    FORCE_DIRECTORY_SECURITY_MODE=`echo $CIFS_SHARE|grep "force directory security mode"|cut -d "'" -f 2`
    OPLOCKS=`echo $CIFS_SHARE|grep oplocks|grep -v level2|cut -d "'" -f 2`
    FORCE_GROUP=`echo $CIFS_SHARE|grep "force group"|cut -d "'" -f 2`
    FORCE_SECURITY_MODE=`echo $CIFS_SHARE|grep "force security mode"|cut -d "'" -f 2`
    echo "averecmd cifs.addShare $i $SHARENAME $EXPORT $SUFFIX $ACCESSCONTROL $HOMEDIR \"{'browseable':'$BROWSEABLE', 'inherit permissions':'$INHERIT_PERMISSIONS', 'read only':'$READ_ONLY', 'hide unreadable':'$HIDE_UNREADABLE', 'strict locking':'$STRICT_LOCKING', 'oplocks':'$OPLOCKS', 'level2 oplocks':'$LEVEL2_OPLOCKS', 'read only optimized':'$READ_ONLY_OPTIMIZED', 'guest ok':'$GUEST_OK', 'create mask':'$CREATE_MASK', 'security mask':'$SECURITY_MASK', 'directory mask':'$DIRECTORY_MASK', 'directory security mask':'$DIRECTORY_SECURITY_MASK', 'force create mode':'$FORCE_CREATE_MODE', 'force security mode':'$FORCE_SECURITY_MODE', 'force directory mode':'$FORCE_DIRECTORY_MODE', 'force directory security mode':'$FORCE_DIRECTORY_SECURITY_MODE', 'force user':'$FORCE_USER', 'force group':'$FORCE_GROUP'}\"" >> $OUTPUT_DIR/1.5-run_on_new_cluster_before_custom_settings_restore_cifs.sh
  done
done
echo "sleep 5" >> $OUTPUT_DIR/1.5-run_on_new_cluster_before_custom_settings_restore_cifs.sh

if [ $ENABLE_CIFS == "True" ]; then
  echo "#CIFS shares" |tee -a $OUTPUT_DIR/1.5-run_on_new_cluster_before_custom_settings_restore_cifs.sh
  IFS=$'\n';for i in `averecmd vserver.list`; do \
    for j in `averecmd --pretty cifs.listShares $i|grep shareName|cut -d "'" -f 4`; do \
      HOMEDIR=`averecmd --pretty cifs.getShare $i $j|grep homeDir|cut -d "'" -f 4`
      if [ $HOMEDIR == "no" ]; then
        echo "averecmd cifs.removeShareAce $i $j \"{'id':'Everyone', 'type':'ALLOW', 'perm':'FULL'}\"" >> $OUTPUT_DIR/1.5-run_on_new_cluster_before_custom_settings_restore_cifs.sh
        for SHARE in `averecmd cifs.getShareAcl $i $j`; do \
          TYPE=`echo $SHARE|cut -d "'" -f 4`
          ID=`echo $SHARE|cut -d "'" -f 8`
          PERM=`echo $SHARE|cut -d "'" -f 12`
          echo "averecmd cifs.addShareAce $i $j \"{'id':'$ID', 'type':'$TYPE', 'perm':'$PERM'}\"" >> $OUTPUT_DIR/1.5-run_on_new_cluster_before_custom_settings_restore_cifs.sh
        done
      fi
    done
  done
fi

echo |tee -a $OUTPUT
echo "#Vserver Details" |tee -a $OUTPUT
for i in `averecmd vserver.list`; do \
  HOTCLIENTENABLED=`averecmd --pretty vserver.get $i|grep hotClientEnabled|cut -d "'" -f 4`
  HOTCLIENTPERIOD=`averecmd --pretty vserver.get $i|grep hotClientPeriod|cut -d "'" -f 4`
  HOTCLIENTLIMIT=`averecmd --pretty vserver.get $i|grep hotClientLimit|cut -d "'" -f 4`
  CLIENTSUSPENDSTATUS=`averecmd --pretty vserver.get $i|grep clientSuspendStatus|cut -d "'" -f 4`
  if [ $HOTCLIENTENABLED == yes ]; then \
    echo "averecmd stats.enableHotCollection $i $HOTCLIENTLIMIT $HOTCLIENTPERIOD" >> $OUTPUT
  else
    echo "#Nothing to do for $i" >> $OUTPUT
  fi
done

echo |tee -a $OUTPUT
echo "#Export Policies" |tee -a $OUTPUT
for i in `averecmd vserver.list`; do \
  for j in `averecmd nfs.listPolicies $i`; do \
    if [ $j != "default" ]; then \
      echo "averecmd nfs.addPolicy $i $j" >> $OUTPUT
    fi
  done
done


echo |tee -a $OUTPUT
echo "#Export Rules" |tee -a $OUTPUT
IFS=$'\n';for VSERVER in `averecmd vserver.list`; do \
  for POLICY in `averecmd nfs.listPolicies $VSERVER`; do \
    for RULE in `averecmd nfs.listRules $VSERVER $POLICY`; do \
      if [ `echo $RULE|grep netgroup` ]; then
        echo "" >> $OUTPUT
        echo "#We can't restore netgroup policies at this time so please note the following..." >> $OUTPUT
        echo "#  "`echo $RULE|grep netgroup` >> $OUTPUT
        echo "" >> $OUTPUT
      else
        if [ `echo $RULE |grep -v netgroup|grep '*'` ]; then \
          FILTER=0.0.0.0
        else 
          FILTER=`echo $RULE|tr ',' '\n'|grep filter|cut -d "'" -f 4`
        fi
        if [[ $FILTER = *"/"* ]]; then \
          NETMASK=/`echo $FILTER|cut -d '/' -f 2`
          FILTER=`echo $FILTER|cut -d '/' -f 1`
        fi
        ACCESS=`echo $RULE|tr ',' '\n'|grep access|cut -d "'" -f 4`
        ANONUID=`echo $RULE|tr ',' '\n'|grep anonuid|cut -d "'" -f 4`
        if [ -z $ANONUID ]; then \
          ANONUID=0;
        fi
        PERMISSION=`echo $RULE|tr ',' '\n'|grep access|cut -d "'" -f 4`
        AUTHKRB=`echo $RULE|tr ',' '\n'|grep authKrb|cut -d "'" -f 4`
        AUTHSYS=`echo $RULE|tr ',' '\n'|grep authSys|cut -d "'" -f 4`
        SCOPE=`echo $RULE|tr ',' '\n'|grep scope|cut -d "'" -f 4`
        SQUASH=`echo $RULE|tr ',' '\n'|grep squash|cut -d "'" -f 4`
        SUBDIR=`echo $RULE|tr ',' '\n'|grep subdir|cut -d "'" -f 4`
        SUID=`echo $RULE|tr ',' '\n'|grep suid|cut -d "'" -f 4`
        if [[ $FILTER == "0.0.0.0" ]]; then \
          FILTER="*"
        fi
        if [[ $POLICY == "default" && $SCOPE == "default" && $FILTER == "*" ]]; then \
          echo "NEW_ID=\`averecmd --pretty nfs.listRules $VSERVER default 0.0.0.0 |grep \"\\<id\\>\"|cut -d \"'\" -f 4\`" >> $OUTPUT
          echo "averecmd nfs.modifyRule \$NEW_ID \"{'scope':'$SCOPE' , 'access':'$PERMISSION' , 'anonuid':'$ANONUID'}\"" >> $OUTPUT
        elif [ $SCOPE = "network" ]; then \
          echo "averecmd nfs.addRule '$VSERVER' '$POLICY' '$SCOPE' '$FILTER$NETMASK' '$PERMISSION' '$SQUASH' '$ANONUID' '$SUID' '$SUBDIR' \"{'authKrb':'$AUTHKRB', 'authSys':'$AUTHSYS'}\"" >> $OUTPUT
        else
          echo "averecmd nfs.addRule '$VSERVER' '$POLICY' '$SCOPE' '$FILTER' '$PERMISSION' '$SQUASH' '$ANONUID' '$SUID' '$SUBDIR' \"{'authKrb':'$AUTHKRB', 'authSys':'$AUTHSYS'}\"" >> $OUTPUT
        fi
      fi
    done
  done
done

echo |tee -a $OUTPUT
echo "#Cloud Encryption Settings" |tee -a $OUTPUT
echo "#Nothing to do here since we already added the encryption type when creating the core filer" |tee -a $OUTPUT

echo |tee -a $OUTPUT
echo "#General Setup, Administrative Network, Proxy Configuration, FXT Nodes" |tee -a $OUTPUT

#Unable to set the following options: advancedNetworking, MTU, ha, default router, dirmgrDistributionState, clusterIPNumPerNode, proxyuser, proxyurl
#Also excluding "mgmtIP" and "ClusterIPs" because those values are part of the initial setup process

# This will empty the array
A_CLUSTER=();
# This will fill up the array with values
#N=0;IFS=$'\n';for i in `averecmd cluster.get|egrep -v 'alternateImage|activeImage|dirmgrDistributionState|avereDataParameters|clusterIPs|mgmtIP'`;do   A_CLUSTER[$N]=`echo $i`;   let "N = $N + 1"; done
N=0;IFS=$'\n';for i in `averecmd cluster.get|egrep -v 'alternateImage|activeImage|dirmgrDistributionState|avereDataParameters|clusterIPs|mgmtIP|advancedNetworking|default_mtu|proxyurl|default_router|proxyuser|netmask|\<ha\>|clusterIPNumPerNode'`;do   A_CLUSTER[$N]=`echo $i`;   let "N = $N + 1"; done
N=0; MAX=`expr ${#A_CLUSTER[@]} - 1`; 
for i in ${A_CLUSTER[@]}; do \
if [[ $i != "rev"* ]] && [[ $i != "id"* ]]; then \
  SETTING=`echo $i|awk '{print $1}'`; 
  VALUE=`echo $i|awk -F \= '{print $2}'`; 

  if [[ $SETTING = "DNSdomain" ]] && [[ $VALUE = *"undefined"* ]]; then \
    VALUE="''"
  fi

  if [ $N = "0" ]; then \
    echo "averecmd cluster.modify \"{'$SETTING'":"$VALUE",""  >> $OUTPUT;
  elif [ $N = "$MAX" ]; then \
    echo "'$SETTING'":"$VALUE}\""  >> $OUTPUT;
  else
    echo "'$SETTING'":"$VALUE","" >> $OUTPUT;
  fi
fi
let "N=$N+1"
done

echo  |tee -a $OUTPUT
echo "#Cluster networks are addressed in the cluster section" |tee -a $OUTPUT

echo |tee -a $OUTPUT
echo "#Proxy configuration is addressed in the cluster section" |tee -a $OUTPUT

echo |tee -a $OUTPUT
echo "#High Availability" |tee -a $OUTPUT
echo "#We are always enabling cluster HA because we don't support non-HA clusters"
N=0;IFS=$'\n';for i in `averecmd cluster.getHADataParameters`; do \
  A_HADATA[$N]=`echo $i|cut -d "'" -f 2`
  let "N=$N+1"
done
DATAEXPORT=`echo ${A_HADATA[0]}`
COREFILER=`echo ${A_HADATA[1]}`
MASS=`echo ${A_HADATA[2]}`
DATADIR=`echo ${A_HADATA[3]}`
echo "averecmd cluster.enableHA" >> $OUTPUT
if [ $MASS ]; then
  echo "averecmd cluster.setHADataParameters $COREFILER $DATAEXPORT $DATADIR" >> $OUTPUT
fi

echo |tee -a $OUTPUT
echo "#Monitoring" |tee -a $OUTPUT
N=0;IFS=$'\n';for i in `averecmd monitoring.emailSettings`; do \
  A_EMAILMONITORING[$N]=`echo $i|cut -d "'" -f 2-|rev|cut -d "'" -f 2-|rev`
  let "N=$N+1"
done
RECIPIENTS=`echo ${A_EMAILMONITORING[0]}`
ENABLED=`echo ${A_EMAILMONITORING[1]}`
REV=`echo ${A_EMAILMONITORING[2]}`
MORECONTEXT=`echo ${A_EMAILMONITORING[3]}`
MAILFROMADDRESS=`echo ${A_EMAILMONITORING[4]}`
ID=`echo ${A_EMAILMONITORING[5]}`
MAILSERVER=`echo ${A_EMAILMONITORING[6]}`
if [ -z $MAILSERVER ]; then \
  echo "#Monitoring is not configured" >> $OUTPUT
else
  echo "averecmd monitoring.modifyEmailSettings \"{'mailFromAddress':'$MAILFROMADDRESS', 'mailServer':'$MAILSERVER', 'recipients':'$RECIPIENTS'}\"" >> $OUTPUT
fi

echo |tee -a $OUTPUT
echo "#Client Facing Network" |tee -a $OUTPUT
IFS=$'\n';for i in `averecmd vserver.list`;do \
  for j in `averecmd vserver.listClientIPHomes $i`; do \
    NODE=`echo $j|awk -F"'" '{print $4}'`
    IP=`echo $j|awk -F"'" '{print $8}'`
    HOME=`echo $j|awk -F"'" '{print $12}'`
    if [ $HOME != None ]; then \
      echo "averecmd vserver.modifyClientIPHomes $i \"{'$IP':'$HOME'}\"" >> $OUTPUT
    fi
  done
done

echo |tee -a $OUTPUT
echo "#Monitoring - Logs" |tee -a $OUTPUT

if [ $RELEASE -lt "47" ]; then \
#  PRE47
  SYSLOGSERVER=`averecmd monitoring.syslogServer`
  if [ $SYSLOGSERVER ]; then \
    echo "averecmd monitoring.setSyslogServer $SYSLOGSERVER" >> $OUTPUT
  else
    echo "#A syslog server has not been set" >> $OUTPUT
  fi
else
#  POST47
  if [ `averecmd monitoring.getSyslogServer` ]; then \
    REMOVESYSLOGSERVER=`averecmd monitoring.getSyslogSettings|grep remoteSyslogServer|cut -d "'" -f 2`
    FORWARDING_OPTIONS=`averecmd monitoring.getSyslogSettings|grep forwarding_options|cut -d "'" -f 2-8`
    echo "averecmd monitoring.setSyslogServer $REMOVESYSLOGSERVER \"$FORWARDING_OPTIONS\"" >> $OUTPUT
  else 
    FORWARDING_OPTIONS=`averecmd monitoring.getSyslogSettings|grep forwarding_options|cut -d "'" -f 2-8`
    echo "averecmd monitoring.setSyslogServer '' \"$FORWARDING_OPTIONS\"" >> $OUTPUT
  fi
fi

echo |tee -a $OUTPUT
echo "#Monitoring - SNMP monitoring" |tee -a $OUTPUT
N=0;IFS=$'\n';for i in `averecmd monitoring.snmpSettings|awk '{print $3}'`;do \
  A_SNMP[$N]=`echo $i`
  let "N=$N+1"
done
if [[ ${A_SNMP[0]} == *"yes"* ]]; then \
  ENABLE=`echo ${A_SNMP[0]}`
  READCOMMUNITYSTRING=`echo ${A_SNMP[1]}`
  TRAPHOST=`echo ${A_SNMP[2]}`
  REV=`echo ${A_SNMP[3]}`
  CONTACT=`echo ${A_SNMP[4]}`
  LOCATION=`echo ${A_SNMP[5]}`
  TRAPPORT=`echo ${A_SNMP[6]}`
  ID=`echo ${A_SNMP[7]}`
  echo "averecmd monitoring.modifySnmpSettings \"{'enable':$ENABLE, 'contact':$CONTACT, 'location':$LOCATION, 'trapHost':$TRAPHOST, 'trapPort':$TRAPPORT, 'readCommunityString':$READCOMMUNITYSTRING}\"" >> $OUTPUT
else
  echo "#SNMP monitoring has not been set" >> $OUTPUT
fi

echo |tee -a $OUTPUT
echo "#Schedules" |tee -a $OUTPUT
IFS=$'\n';for i in `averecmd cluster.listSchedules`; do \
  NAME=`echo $i|cut -d "'" -f 18`
  MINUTES=`echo $i|cut -d "'" -f 10`
  HOURS=`echo $i|cut -d "'" -f 6`
  DAYS=`echo $i|cut -d "'" -f 14`
  echo "averecmd cluster.addSchedule $NAME \"[{'hours':'$HOURS', 'minutes':'$MINUTES', 'days':'$DAYS'}]\"" >> $OUTPUT
done

echo |tee -a $OUTPUT
echo "#IPMI" |tee -a $OUTPUT
echo "#Note: If you see something like \"Caught Exception: Couldn't fetch attribute\" that means IPMI is not configured"
IFS=$'\n';for i in `lsu nodes|grep -v _|cut -d ':' -f 1`; do \
  for j in `lsu $i ipmi`;do \
    if [[ $j != *"Couldn't fetch attribute"* ]]; then \
      MODE=`echo $j|awk '{print $3}'|cut -d '=' -f 2`
      ADDRESS=`echo $j|awk '{print $4}'|cut -d '=' -f 2`
      NETMASK=`echo $j|awk '{print $5}'|cut -d '=' -f 2`
      ROUTER=`echo $j|awk '{print $6}'|cut -d '=' -f 2`
      NAME=`lsu $i name`
      echo "averecmd node.modifyIPMI $NAME $MODE \"{'address':'$ADDRESS', 'netmask':'$NETMASK', 'router':'$ROUTER'}\"" >> $OUTPUT
    else 
      echo "IPMI is not configured for node "`lsu $i name` >> $OUTPUT
    fi
  done
done

echo |tee -a $OUTPUT
echo "#Support - Customer Info and Secure Proactive Support (SPS)" |tee -a $OUTPUT
# This will empty the array
A_SUPPORT=();
# This will fill up the array with values
N=0;IFS=$'\n';for i in `averecmd support.get|egrep -v 'remoteCommandEnabledTime|tested|priorRemoteCommandLevel'`;do   A_SUPPORT[$N]=`echo $i`;   let "N = $N + 1"; done

N=0; MAX=`expr ${#A_SUPPORT[@]} - 1`; 
for i in ${A_SUPPORT[@]}; do \
if [[ $i != "rev"* ]] && [[ $i != "id"* ]]; then \
  SETTING=`echo $i|awk '{print $1}'`; 
  VALUE=`echo $i|awk -F \' '{print $2}'`; 
  if [ $N = "0" ]; then \
    echo "averecmd support.modify \"{'$SETTING'":"'$VALUE'","" >> $OUTPUT;
  elif [ $N = "$MAX" ]; then \
    echo "'$SETTING'":"'$VALUE'}\"" >> $OUTPUT;
  else
    echo "'$SETTING'":"'$VALUE'","" >> $OUTPUT;
  fi
fi
let "N=$N+1"
done

# Moving cusom settings section after core filer add to give the core filers more time to be created
#echo |tee -a $OUTPUT
#echo "#Custom settings are addressed with \"2-run_on_new_cluster_mass_mappings.sh\", \"3-run_on_new_cluster_new_custom_settings.sh\", \"4-run_on_new_cluster_new_custom_settings.sh\"" |tee -a $OUTPUT
#
##IFS=$'\n';for i in `name_mapping.py --custom|egrep -v 'Custom Settings:|----------------'`;do \
#IFS=$'\n';for i in `name_mapping.py --custom|egrep -v 'Custom Settings:|----------------|smbacldMassids'`;do \
#  NAME=`echo $i|cut -d ':' -f 1|awk '{print $1}'`
#  CHECKCODE=`averecmd support.checkCode $NAME|grep check|cut -d "'" -f 2`
#  VALUE=`echo $i|awk '{print $2}'`
#  NOTE=`echo $i|cut -d '(' -f 2`;
#  if [[ $NOTE = *"NOT in cluster.settings"* ]]; then \
#    NAME2=`echo $NAME|tr . ' '`
#    echo "dbutil.py set $NAME2 $VALUE -x" >> $OUTPUT_DIR/original_custom_settings.txt
#  else
#    echo "averecmd support.setCustomSetting $NAME $CHECKCODE $VALUE \"($NOTE\"" >> $OUTPUT_DIR/original_custom_settings.txt
#  fi
#done

#vserver mapping
# Convert current mass to new mass
for i in `lsu masses|grep -v _|cut -d ':' -f 1`; do \
  NAME=`lsu $i name|cut -d ' ' -f 2` 
  if [[ $NAME != "127.0.0"* ]]; then \
    echo "********$i:$NAME" >> $OUTPUT_DIR/masses.txt
  fi
done  

for VSERVER in `lsu vservers|grep -v _|cut -d ':' -f 1`; do \
  VSERVER_NAME=`lsu $VSERVER name|cut -d ' ' -f 2`
  echo "********$VSERVER:$VSERVER_NAME" >> $OUTPUT_DIR/masses.txt
done

# Read core filer name and the new mass number....THESE STEP NEEDS TO BE PERFORMED ON THE NEW CLUSTER AND RUN FROM THE SAME DIR WHERE masses.txt EXISTS.
echo "N=0;while read -r line; do \\" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "ARRAY[\$N]=\`echo \$line|cut -c 9-\`" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "INTERNAL_NAME=\`echo \${ARRAY[\$N]}|cut -d ':' -f 1\`" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "ADMINISTRATIVE_NAME=\`echo \${ARRAY[\$N]}|cut -d ':' -f 2\`" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "if [[ \$INTERNAL_NAME = \"mass\"* ]]; then \\" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "NEW_VALUE=\`averecmd --pretty corefiler.get \$ADMINISTRATIVE_NAME|grep internalName|cut -d \"'\" -f 4\`" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "elif [[ \$INTERNAL_NAME = \"vserver\"* ]]; then \\" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "for i in \`lsu vservers|grep -v _|cut -d ':' -f 1\`; do \\" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "if [[ \`lsu \$i|grep \$ADMINISTRATIVE_NAME\` ]]; then \\" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "NEW_VALUE=\`lsu \$i __name|cut -d ' ' -f 2\`" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "fi" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "done" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "fi" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "let \"N=\$N+1\"" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "echo \$INTERNAL_NAME:\$ADMINISTRATIVE_NAME:\$NEW_VALUE >> mass_mapping.txt" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
echo "done < masses.txt" >> $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh
chmod 700 $OUTPUT_DIR/2-run_on_new_cluster_mass_mappings.sh

echo "while read line; do \\" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  NAME=\`echo \$line|cut -d ' ' -f 3|cut -d '.' -f 1\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  if [[ \$NAME != *\"mass\"* ]] && [[ \$NAME != \"vserver\"* ]]; then \\" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    line2=\`echo \$line\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  fi" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  if [[ \$NAME = \"cloudmass\"* ]]; then \\" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    NAME=\`echo \$NAME| cut -c 6-\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  fi" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  if [ \"\$line\" != \"\$line2\" ]; then \\" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    NEW=\`grep \"\$NAME:\" mass_mapping.txt |cut -d ':' -f 3\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    line2=\`echo \$line|sed \"s/\$NAME/\$NEW/\"\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  fi" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  if [[ \$NAME = \"cpolicyAdmin\"* ]]; then \\" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    tmp=\`echo \$NAME|cut -c 13-\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    NEW=\`grep \"mass\$tmp:\" mass_mapping.txt |cut -d ':' -f 3\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    NEW_ADMIN=cpolicyAdmin\`echo \$NEW|cut -c 5-\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    line2=\`echo \$line|sed \"s/\$NAME/\$NEW_ADMIN/\"\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  fi" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  if [[ \$NAME = \"cpolicyActive\"* ]]; then \\" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    tmp=\`echo \$NAME|cut -c 14-\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    NEW=\`grep \"mass\$tmp:\" mass_mapping.txt |cut -d ':' -f 3\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    NEW_ACTIVE=cpolicyActive\`echo \$NEW|cut -c 5-\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "    line2=\`echo \$line|sed \"s/\$NAME/\$NEW_ACTIVE/\"\`" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  fi" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  echo \$line2 >> 4-run_on_new_cluster_new_custom_settings.sh" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "  line2=''" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "done < original_custom_settings.txt" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
echo "chmod 700 4-run_on_new_cluster_new_custom_settings.sh" >> $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh
chmod 700 $OUTPUT_DIR/3-run_on_new_cluster_new_custom_settings.sh

echo |tee -a $OUTPUT
echo "#Certificates" |tee -a $OUTPUT
echo "#Nothing to do here since we don't store the certificates" |tee -a $OUTPUT

echo |tee -a $OUTPUT
echo "#KMIP Servers" |tee -a $OUTPUT
echo "#Nothing to do here due to password requirments" |tee -a $OUTPUT

echo |tee -a $OUTPUT
echo "#Users" |tee -a $OUTPUT
echo "#Note: recreated users will all have the their password set to null so please log into the GUI and set them appropriately" |tee -a $OUTPUT
N=0;IFS=$'\n';for i in `averecmd admin.listUsers`; do \
  NAME=`echo $i|cut -d "'" -f 4`
  PERMISSION=`echo $i|cut -d "'" -f 8`
  if [ $NAME != "admin" ]; then
#    echo "averecmd admin.addUser $NAME $PERMISSION tiered2010" >> $OUTPUT
    echo "averecmd admin.addUser $NAME $PERMISSION ''" >> $OUTPUT
  fi
done

echo |tee -a $OUTPUT
echo "#Login Services" |tee -a $OUTPUT
echo "#Nothing to do here since it was addressed when completing the \"Directory Services\" section" |tee -a $OUTPUT
echo |tee -a $OUTPUT

echo "#Hidden Alerts" |tee -a $OUTPUT
echo "#Nothing to do here since there are no xmlrpc commands to find this" |tee -a $OUTPUT
echo |tee -a $OUTPUT

echo "####Administration section...DONE####" |tee -a $OUTPUT
/support/lib/python/support/data_upload.py -C $OUTPUT_DIR
