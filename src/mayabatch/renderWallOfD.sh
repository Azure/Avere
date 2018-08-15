#!/bin/bash -ex

#
# The following script renders the Autodesk Wall of Death Scene.  
#
# Save this script to any Avere vFXT volume, for example:
#     /src/wallOfDRender.sh
#
# The following environment variables must be set:
#     FRAME_START=1
#     FRAME_END=1
#     MAYA_PROJECT_PATH=/nfs/default/scenes/autodeskWallOfDScene
#     SCENE_FILE=/nfs/default/scenes/autodeskWallOfDScene/scenes/SEQ001/SHOT001/anim/versions/SEQ001_SHOT001_anim_v010_Imported.ma
#     IMAGES_OUTPUT_BASE_PATH=/nfs/default/images
#     DEBUG_PATH=/nfs/default/debug
#     ADDITIONAL_FLAGS=" -of png "
#
# This is executed as the render job from batch, using the 
# following command line:
#
#     /bin/bash -c '/bin/bash [parameters('renderScriptPath')] ; err=$? ; exit $err'
#

# if doing real work, remove or set to false
IS_DEMO=true

function log_debug_info() {
    set
    mount
    whoami
    
    # add empty file named after this machine's ip to the mount folder for the job
    MOUNT_POINT=`mount | grep default | sed -e 's/^\([^:]*\):.*/\1/'`
    THIS_HOST=`hostname -i`
    DEBUG_TARGET_DIR=${DEBUG_PATH}/${AZ_BATCH_JOB_ID}/${MOUNT_POINT}
    mkdir -p ${DEBUG_TARGET_DIR}
    touch ${DEBUG_TARGET_DIR}/${THIS_HOST}
}

function stagger_on_first_task_round_algorithm1() {
    # stagger the first round of jobs over 6 minutes, but only for the first set of tasks
    TASK_COUNT_FOR_NODE=`find ${AZ_BATCH_NODE_ROOT_DIR}/workitems/${AZ_BATCH_JOB_ID}/. -maxdepth 3 -type d | grep wd | wc -l`
    if [ "${TASK_COUNT_FOR_NODE}" -le "${MAX_TASKS_PER_NODE}" ] ; then
        SLEEP_TIME=$(($RANDOM % 360))
        echo "staggering by sleeping for ${SLEEP_TIME} seconds (${TASK_COUNT_FOR_NODE} < ${MAX_TASKS_PER_NODE})"
        sleep ${SLEEP_TIME}
    else
        echo "no stagger because ${TASK_COUNT_FOR_NODE} >= ${MAX_TASKS_PER_NODE}"
    fi
}

function stagger_on_first_task_round_algorithm2() {
    # stagger the first round of jobs over 6 minutes, but only for the first set of tasks
    TASK_COUNT_FOR_NODE=`find ${AZ_BATCH_NODE_ROOT_DIR}/workitems/${AZ_BATCH_JOB_ID}/. -maxdepth 3 -type d | grep wd | wc -l`
    if [ "${TASK_COUNT_FOR_NODE}" -le "${MAX_TASKS_PER_NODE}" ] ; then
        NODE_ID=`echo $AZ_BATCH_NODE_ID | sed -e 's/^.*_\([0-9]*\)-.*/\1/'`
        SLEEP_TIME=$((($NODE_ID/5)*7))
        echo "staggering by sleeping for ${SLEEP_TIME} seconds (${TASK_COUNT_FOR_NODE} < ${MAX_TASKS_PER_NODE})"
        sleep ${SLEEP_TIME}
    else
        echo "no stagger because ${TASK_COUNT_FOR_NODE} >= ${MAX_TASKS_PER_NODE}"
    fi
}

function run_demo_code() {
    # clear client caches - good for demo, but not good for real job
    echo "clearing client cache by running '3 | sudo tee /proc/sys/vm/drop_caches > /dev/null'"
    echo     3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
}

function render_scene() {
    # render the scene
    echo "running command: /bin/maya2018.sh -r sw ${ADDITIONAL_FLAGS} -proj ${MAYA_PROJECT_PATH} -rd ${IMAGES_OUTPUT_BASE_PATH}/${AZ_BATCH_JOB_ID} -s ${FRAME_START} -e ${FRAME_END} ${SCENE_FILE}"
    /bin/maya2018.sh -r sw ${ADDITIONAL_FLAGS} -proj ${MAYA_PROJECT_PATH} -rd ${IMAGES_OUTPUT_BASE_PATH}/${AZ_BATCH_JOB_ID} -s ${FRAME_START} -e ${FRAME_END} ${SCENE_FILE}
}

function main() {
    
    log_debug_info

    #stagger_on_first_task_round_algorithm1
    stagger_on_first_task_round_algorithm2

    if [ "${IS_DEMO}" = true ] ; then
        run_demo_code
    fi

    render_scene

    # add extra render code here
}

main