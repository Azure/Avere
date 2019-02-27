#!/bin/bash

# report all lines, and exit on error
set -x
set -e

ARM_TRUE="True"
WAIT_SECONDS=600
AZURE_HOME_DIR=/home/$CONTROLLER_ADMIN_USER_NAME
VFXT_INSTALL_TEMPLATE=$AZURE_HOME_DIR/vfxtinstall
CLOUD_BACKED_TEMPLATE=/create-cloudbacked-cluster
MINIMAL_TEMPLATE=/create-minimal-cluster
VFXT_LOG_FILE=$AZURE_HOME_DIR/vfxt.log

function retrycmd_if_failure() {
    retries=$1; max_wait_sleep=$2; shift && shift
    for i in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            return 1
        else
            sleep $(($RANDOM % $max_wait_sleep))
        fi
    done
    echo Executed \"$@\" $i times;
}

function wait_azure_home_dir() {
    counter=0
    while [ ! -d $AZURE_HOME_DIR ]; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge $WAIT_SECONDS ]; then
            echo "directory $AZURE_HOME_DIR not available after waiting $WAIT_SECONDS seconds"
            exit 1
        fi
    done
}

function wait_az_login_and_vnet() {
    # wait for RBAC assignments to be applied
    # unfortunately, the RBAC assignments take undetermined time past their associated resource completions to be assigned.  
    set +e
    if ! retrycmd_if_failure 120 5 az login --identity ; then
        echo "MANAGED IDENTITY FAILURE: failed to login after waiting 10 minutes, this is managed identity bug"
        exit 1
    fi
    if ! retrycmd_if_failure 12 5 az account set --subscription $SUBSCRIPTION_ID ; then
        echo "MANAGED IDENTITY FAILURE: failed to set subscription"
        exit 1
    fi
    if ! retrycmd_if_failure 120 5 az network vnet subnet list -g $NETWORK_RESOURCE_GROUP --vnet-name $NETWORK ; then
        echo "RBAC ASSIGNMENT FAILURE: failed to list vnet after waiting 10 minutes, this is rbac assignment bug"
        exit 1
    fi
    set -e
}

function configure_vfxt_template() {
    if [ "$CREATE_CLOUD_BACKED_CLUSTER" == "$ARM_TRUE" ]; then
        cp $CLOUD_BACKED_TEMPLATE $VFXT_INSTALL_TEMPLATE
    else
        cp $MINIMAL_TEMPLATE $VFXT_INSTALL_TEMPLATE
    fi

    # update the internal variables
    sed -i 's/^RESOURCE_GROUP/#RESOURCE_GROUP/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^LOCATION/#LOCATION/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^NETWORK/#NETWORK/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^SUBNET/#SUBNET/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^AVERE_CLUSTER_ROLE/#AVERE_CLUSTER_ROLE/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^STORAGE_ACCOUNT/#STORAGE_ACCOUNT/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^CACHE_SIZE/#CACHE_SIZE/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^CLUSTER_NAME/#CLUSTER_NAME/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^ADMIN_PASSWORD/#ADMIN_PASSWORD/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^INSTANCE_TYPE/#INSTANCE_TYPE/g' $VFXT_INSTALL_TEMPLATE
    # replace "--from-environment" with "--on-instance" since we are using 
    sed -i 's/ --from-environment / --on-instance /g' $VFXT_INSTALL_TEMPLATE
    sed -i "s:~/vfxt.log:$VFXT_LOG_FILE:g"  $VFXT_INSTALL_TEMPLATE
    # do not trace password in log, instead the command is captured in file ~/create_cluster_command.log, with password correctly redacted
    sed -i "s/^set -exu/set -eu/g"  $VFXT_INSTALL_TEMPLATE
}

function patch_vfxt_py1() {
    VFXTPYDIR=$(dirname $(pydoc vFXT | grep usr | tr -d '[:blank:]'))
    MSAZURE_PATCH_FILE="$VFXTPYDIR/p"
    MSAZURE_TARGET_FILE="$VFXTPYDIR/msazure.py"
    /bin/cat <<EOM >$MSAZURE_PATCH_FILE
diff --git a/vFXT/msazure.py b/vFXT/msazure.py
index 4e72fd73..b660d9bb 100644
--- a/vFXT/msazure.py
+++ b/vFXT/msazure.py
@@ -2596,13 +2596,17 @@ class Service(ServiceBase):
             association_id = str(uuid.uuid4())
             try:
                 scope = self._resource_group_scope()
-                # if we span resource groups, the scope must be on the subscription
-                if self.network_resource_group != self.resource_group:
-                    scope = self._subscription_scope()
                 r = conn.role_assignments.create(scope, association_id, body)
                 if not r:
-                    raise Exception("Failed to assign role {} to principal {}".format(role_name, principal))
+                    raise Exception("Failed to assign role {} to principal {} for resource group {}".format(role_name, principal, self.resource_group))
                 log.debug("Assigned role {} with principal {} to scope {}: {}".format(role_name, principal, scope, body))
+                # if we span resource groups, the scope must be assigned to both resource groups
+                if self.network_resource_group != self.resource_group:
+                    network_scope = self._resource_group_scope(self.network_resource_group)
+                    network_association_id = str(uuid.uuid4())
+                    r2 = conn.role_assignments.create(network_scope, network_association_id, body)
+                    if not r2:
+                        raise Exception("Failed to assign role {} to principal {} for resource group {}".format(role_name, principal, self.network_resource_group))
                 return r
             except Exception as e:
                 log.debug(e)
EOM

    # don't exit if the patch was already applied
    set +e
    patch --quiet --forward $MSAZURE_TARGET_FILE $MSAZURE_PATCH_FILE
    set -e
    rm -f $MSAZURE_PATCH_FILE
    rm -f $VFXTPYDIR/*\.pyc
    rm -f $VFXTPYDIR/*\.orig
    rm -f $VFXTPYDIR/*\.rej
}

function patch_vfxt_py2() {
    VFXTPYDIR=$(dirname $(pydoc vFXT | grep usr | tr -d '[:blank:]'))
    MSAZURE_PATCH_FILE="$VFXTPYDIR/p"
    MSAZURE_TARGET_FILE="$VFXTPYDIR/msazure.py"
    /bin/cat <<EOM >$MSAZURE_PATCH_FILE
diff --git a/vFXT/msazure.py b/vFXT/msazure.py
index 4e72fd73..b660d9bb 100644
--- a/vFXT/msazure.py
+++ b/vFXT/msazure.py
@@ -558,7 +558,7 @@
                         endpoint_data = json.loads(response.read())
                         for endpoint_name in endpoint_data['cloudEndpoint']:
                             endpoint = endpoint_data['cloudEndpoint'][endpoint_name]
-                            if instance_data['compute']['location'] in endpoint['locations']:
+                            if instance_data['compute']['location'].lower() in [_.lower() for _ in endpoint['locations']]: # force lowercase comparision
                                 instance_data['endpoint'] = endpoint
                                 instance_data['token_resource'] = 'https://{}'.format(endpoint['endpoint']) # Always assume URL format
                         break
EOM

    # don't exit if the patch was already applied
    set +e
    patch --quiet --forward $MSAZURE_TARGET_FILE $MSAZURE_PATCH_FILE
    set -e
    rm -f $MSAZURE_PATCH_FILE
    rm -f $VFXTPYDIR/*\.pyc
    rm -f $VFXTPYDIR/*\.orig
    rm -f $VFXTPYDIR/*\.rej
}

function create_vfxt() {
    #######################################################
    # do not trace passwords
    #######################################################
    set -x
    #######################################################

    cd $AZURE_HOME_DIR
    # enable cloud trace during installation
    if [ "${ENABLE_CLOUD_TRACE_DEBUG}" == "${ARM_TRUE}" ] ; then
        nohup /bin/bash /opt/avere/enablecloudtrace.sh > $AZURE_HOME_DIR/enablecloudtrace.log 2>&1 &
    fi
    # ensure the create cluster command is recorded for the future
    sleep 2 && ps -a -x -o cmd | egrep '[v]fxt.py' |  sed 's/--admin-password [^ ]*/--admin-password ***/' > create_cluster_command.log &
    $VFXT_INSTALL_TEMPLATE
    
    #######################################################
    # re-enable tracing
    #######################################################
    set +x
    #######################################################
}

function print_vfxt_vars() {
    echo "VSERVER_IPS=$(sed -n "s/^.*Creating vserver vserver (\(.*\)\/255.255.255.255).*$/\1/p" $VFXT_LOG_FILE)"
    echo "MGMT_IP=$(sed -n "s/^.*management address: \(.*\)/\1/p" $VFXT_LOG_FILE)"
}

function dump_env_vars() {
    echo "start env dump"
    echo $(pwd)
    echo "export RESOURCE_GROUP=$RESOURCE_GROUP"
    echo "export LOCATION=$LOCATION"
    echo "export NETWORK_RESOURCE_GROUP=$NETWORK_RESOURCE_GROUP"
    echo "export NETWORK=$NETWORK"
    echo "export SUBNET=$SUBNET"
    echo "export AVERE_CLUSTER_ROLE=$AVERE_CLUSTER_ROLE"
    echo "export CREATE_CLOUD_BACKED_CLUSTER=$CREATE_CLOUD_BACKED_CLUSTER"
    echo "export STORAGE_ACCOUNT=$STORAGE_ACCOUNT"
    echo "export CACHE_SIZE=$CACHE_SIZE"
    echo "export CLUSTER_NAME=$CLUSTER_NAME"
    echo "export INSTANCE_TYPE=$INSTANCE_TYPE"
    echo "export ADMIN_PASSWORD=$ADMIN_PASSWORD"
    echo "finish env dump"
}

function main() {
    echo "wait azure home dir"
    wait_azure_home_dir

    echo "wait az login"
    wait_az_login_and_vnet

    #echo "dump env vars for debugging"
    #dump_env_vars

    echo "configure vfxt install template"
    configure_vfxt_template

    echo "patch vfxt.py"
    patch_vfxt_py1
    patch_vfxt_py2

    echo "create_vfxt"
    create_vfxt

    echo "print vfxt vars"
    print_vfxt_vars

    echo "installation complete"
}

main
