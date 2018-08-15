#!/bin/bash -ex

#
# The following script render a generic maya scene.  
#
# Save this script to any Avere vFXT volume, for example:
#     /src/render.sh
#
# The following environment variables must be set:
#     FRAME_START=1
#     FRAME_END=1
#     MAYA_PROJECT_PATH=/nfs/default/demoscene
#     SCENE_FILE=/nfs/default/demoscene/kongSkeleton_walk.ma
#     IMAGES_OUTPUT_BASE_PATH=/nfs/default/images
#     ADDITIONAL_FLAGS=" -of png "
#
# This is executed as the render job from batch, using the 
# following command line:
#
#     /bin/bash -c '/bin/bash [parameters('renderScriptPath')] ; err=$? ; exit $err'
#

# if doing real work, remove or set to false
IS_DEMO=true

function render_scene() {
    if [ "${IS_DEMO}" = true ] ; then
        # clear client caches - good for demo, but not good for real job
        echo     3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    fi

    # render the scene
    echo "running command: /bin/maya2018.sh -r sw ${ADDITIONAL_FLAGS} -proj ${MAYA_PROJECT_PATH} -rd ${IMAGES_OUTPUT_BASE_PATH}/${AZ_BATCH_JOB_ID} -s ${FRAME_START} -e ${FRAME_END} ${SCENE_FILE}"
    /bin/maya2018.sh -r sw ${ADDITIONAL_FLAGS} -proj ${MAYA_PROJECT_PATH} -rd ${IMAGES_OUTPUT_BASE_PATH}/${AZ_BATCH_JOB_ID} -s ${FRAME_START} -e ${FRAME_END} ${SCENE_FILE}
}

function main() {
    render_scene

    # add extra render code here
}

main