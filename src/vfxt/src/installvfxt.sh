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
}

function patch_vfxt_py() {
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

function create_vfxt() {
    cd $AZURE_HOME_DIR
    # ensure the create cluster command is recorded for the future
    sleep 2 && ps -a -x -o cmd | egrep '[v]fxt.py' |  sed 's/--admin-password [^ ]*/--admin-password ***/' > create_cluster_command.log &
    $VFXT_INSTALL_TEMPLATE
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

    #echo "dump env vars for debugging"
    #dump_env_vars

    echo "configure vfxt install template"
    configure_vfxt_template

    echo "patch vfxt.py"
    patch_vfxt_py

    echo "create_vfxt"
    create_vfxt

    echo "print vfxt vars"
    print_vfxt_vars

    echo "installation complete"
}

main
