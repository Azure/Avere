#!/bin/bash -ex

#
# The following script render a generic maya scene.  
#
# Save this script to any Avere vFXT volume, for example:
#     /src/render.sh
#
# The following environment variables must be set:
#     JOB_ID="job1"
#     FRAME_START=1
#     FRAME_END=1
#     NFS_MOUNT_POINT=/nfs/default
#     MAYA_PROJECT_PATH=demoscene
#     SCENE_FILE=demoscene/kongSkeleton_walk.ma
#     IMAGES_OUTPUT_BASE_PATH=images
#     ADDITIONAL_FLAGS=" -of png "
#
# This is executed as the render job from batch, using the 
# following command line:
#
#     /bin/bash -c '/bin/bash [parameters('nfsMountPath')]/[parameters('renderScriptPath')] ; err=$? ; exit $err'
#

# if doing real work, remove or set to false
IS_DEMO=true

function render_scene() {
    if [ "${IS_DEMO}" = true ] ; then
        # clear client caches - good for demo, but not good for real job
        echo     3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    fi

    # render the scene
    echo "running command: /bin/maya2018.sh -r sw ${ADDITIONAL_FLAGS} -proj ${NFS_MOUNT_POINT}/${MAYA_PROJECT_PATH} -rd ${NFS_MOUNT_POINT}/${IMAGES_OUTPUT_BASE_PATH}/${JOB_ID} -s ${FRAME_START} -e ${FRAME_END} ${NFS_MOUNT_POINT}/${SCENE_FILE}"
    /bin/maya2018.sh -r sw ${ADDITIONAL_FLAGS} -proj ${NFS_MOUNT_POINT}/${MAYA_PROJECT_PATH} -rd ${NFS_MOUNT_POINT}/${IMAGES_OUTPUT_BASE_PATH}/${JOB_ID} -s ${FRAME_START} -e ${FRAME_END} ${NFS_MOUNT_POINT}/${SCENE_FILE}
}

function main() {
    render_scene

    # add extra render code here
}

main