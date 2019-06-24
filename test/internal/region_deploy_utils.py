#!/usr/bin/python3
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

###############################################################################
# NOTE: This file is for Microsoft Azure DevOps Pipeline use only. ############
###############################################################################

import datetime
import logging
import os
from argparse import ArgumentParser

from azure.common.credentials import ServicePrincipalCredentials
from azure.cosmosdb.table.models import EdmType, Entity, EntityProperty
from azure.cosmosdb.table.tableservice import TableService
from azure.mgmt.subscription import SubscriptionClient

# GLOBAL VARIABLES ############################################################
# Connection and table variables.
table_service = TableService(
    account_name=os.environ["PIPELINES_DATA_STORAGE_ACCOUNT"],
    account_key=os.environ["PIPELINES_DATA_STORAGE_ACCOUNT_KEY"]
)
table_name = os.environ["PIPELINES_DATA_TABLE_NAME"]
part_table_control = "tableControl"
part_deploy_region = "deployRegion"

# Regions to always exclude, include.
regions_to_exclude = [
    # 2019-03-08: currently in region build-out
    "australiacentral", "australiacentral2", "francesouth",
    "southafricanorth", "southafricawest",

    # 2019-06-24: not currently working with anhowe's sub
    "centralindia", "uaecentral", "uaenorth"

    # 2019-03-14: E32s VMs not available in this region
    "westcentralus",
]
regions_to_include = []

# Cooldown. Number of hours since last successful run in a region that need to
# pass before we deploy in that region again.
cooldown_hours = 48


# GET NEXT REGION NAME ########################################################
def get_next_region_name():
    # Number of regions available for deployment (in the table).
    num_regions = table_service.get_entity(
        table_name, part_table_control, "NumberOfRegions"
        ).VALUE.value
    logging.debug("num_regions: {}".format(num_regions))

    # Rowkey for the last region used (from the table).
    last_region_rowkey_used = get_last_region_rowkey_used()
    logging.debug("last_region_rowkey_used: {}".format(last_region_rowkey_used))

    # Use the next region in the table. If the last region used was the last
    #  region in the table, then this time use the first region in the table.
    curr_region_rowkey = last_region_rowkey_used + 1
    if curr_region_rowkey > num_regions:
        curr_region_rowkey = 1
    logging.debug("curr_region_rowkey: {}".format(curr_region_rowkey))

    # Cooldown. Select regions whose last successful run was > 48 hours ago
    # or haven't had a last successful run.
    orig_rowkey = curr_region_rowkey
    last_rowkey = curr_region_rowkey - 1
    if last_rowkey < 1:
        last_rowkey = num_regions
    logging.debug("last_rowkey = {}".format(last_rowkey))
    while (hours_since_last_success(curr_region_rowkey) < cooldown_hours and
           curr_region_rowkey != last_rowkey):
        logging.debug("INFO: {0:.2f} hours since last successful run in region {1}. Skipping.".format(
            hours_since_last_success(curr_region_rowkey),
            get_region_shortname(curr_region_rowkey)
        ))
        curr_region_rowkey += 1
        if curr_region_rowkey > num_regions:
            curr_region_rowkey = 1
    if curr_region_rowkey == last_rowkey:
        curr_region_rowkey = orig_rowkey
    logging.debug("curr_region_rowkey (after cooldown): {}".format(
        curr_region_rowkey))

    # Get the region shortname.
    region = get_region_shortname(curr_region_rowkey)
    logging.debug("region: {}".format(region))

    # Update LastRegionRowKeyUsed.
    table_service.update_entity(
        table_name, {
            "PartitionKey": part_table_control,
            "RowKey": "LastRegionRowKeyUsed",
            "VALUE":
                EntityProperty(EdmType.INT32, curr_region_rowkey)
        })

    return region


# UPDATE LAST SUCCESSFUL RUN FOR REGION #######################################
def update_last_successful_run_for_region(_region=None):
    region = _region or get_region_shortname(get_last_region_rowkey_used())

    # Get a particular entry matching the region shortname.
    region_entities = [x for x in table_service.query_entities(
        table_name,
        filter="PartitionKey eq '{}' and RegionShortname eq '{}'".format(
            part_deploy_region, region)
    )]

    if len(region_entities) > 1:
        logging.debug("WARNING: " +
                      "Found {} entities for {}. Using first entry.".format(
                          len(region_entities), region))
    region_entity = region_entities[0]
    logging.debug("region_entity (orig): {}".format(region_entity))

    # Add the current UTC time to the region entity.
    curr_utc_time = datetime.datetime.utcnow()
    region_entity["LastSuccessfulRun"] = curr_utc_time
    logging.debug("current UTC time: {}Z".format(curr_utc_time.isoformat()))

    # Remove the etag field.
    region_entity.pop("etag", None)
    logging.debug("region_entity (with time, no etag): {}".format(
        region_entity))

    # Update LastRegionRowKeyUsed.
    table_service.update_entity(table_name, region_entity)


# UPDATE AVAILABLE REGION NAMES ###############################################
def update_available_region_names():
    # Authenticate to Azure Subscription Manager
    sub_client = SubscriptionClient(
        ServicePrincipalCredentials(
            client_id=os.environ["AZURE_CLIENT_ID"],
            secret=os.environ["AZURE_CLIENT_SECRET"],
            tenant=os.environ["AZURE_TENANT_ID"]
        )
    )

    # Get the list of locations accessible to this subscription.
    sub_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    locations = sorted([x.name for x in sub_client.subscriptions.list_locations(sub_id)] + regions_to_include)
    locations = [x for x in locations if x not in regions_to_exclude]

    # Get entities for all of the regions.
    old_entities = table_service.query_entities(
        table_name, filter="PartitionKey eq '{}'".format(part_deploy_region)
    )
    old_entities_dict = {x.RegionShortname: x for x in old_entities}

    # Create a new list of entities for the table.
    new_entities = []
    for i, loc in enumerate(locations):
        # Remove this region from the original list and table.
        old_entity = old_entities_dict.pop(loc, {})

        # Save the last successful run timestamp (if it exists).
        last_succ_run = None
        if "LastSuccessfulRun" in old_entity:
            last_succ_run = old_entity.LastSuccessfulRun

        # Create a new entity for this region (re-indexed).
        new_entities.append(Entity(
            PartitionKey=part_deploy_region,
            RowKey=str(i+1),
            RegionShortname=loc,
            LastSuccessfulRun=last_succ_run
        ))
    logging.debug("new_entities = {}".format(new_entities))

    # If there are any entries left in old_entities_dict, then that means
    # some regions that were live before are no longer live.
    if len(old_entities_dict):
        logging.debug("WARNING: The following regions seem to have been decomissioned:")
        for k, v in old_entities_dict.items():
            logging.debug("\t{}".format(k))

    # Delete the old entities.
    for oe in old_entities:
        table_service.delete_entity(table_name, oe.PartitionKey, oe.RowKey)

    # Add the new entities.
    for ne in new_entities:
        table_service.insert_entity(table_name, ne)

    # Update the last region RowKey (the number of new entities).
    last_rowkey_entity = table_service.get_entity(
        table_name, part_table_control, "NumberOfRegions"
    )
    last_rowkey_entity.pop("etag", None)
    last_rowkey_entity.pop("Timestamp", None)
    last_rowkey_entity.VALUE = EntityProperty(
        EdmType.INT32, len(new_entities))
    logging.debug("last_rowkey_entity = {}".format(last_rowkey_entity))
    table_service.update_entity(table_name, last_rowkey_entity)


# HELPER FUNCTIONS ############################################################
def get_last_region_rowkey_used():
    return table_service.get_entity(
        table_name, part_table_control, "LastRegionRowKeyUsed"
        ).VALUE.value


def get_region_shortname(rowkey):
    return table_service.get_entity(
        table_name, part_deploy_region, str(rowkey)
        ).RegionShortname


def hours_since_last_success(rowkey):
    last_succ_run = table_service.get_entity(
        table_name, part_deploy_region, str(rowkey))
    if "LastSuccessfulRun" not in last_succ_run:
        return 999

    last_succ_run = last_succ_run.LastSuccessfulRun.replace(tzinfo=None)
    now = datetime.datetime.utcnow()
    return (now - last_succ_run).total_seconds() / 60 / 60


# IF MAIN #####################################################################
if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("-l", "--update_region_list",
                        action="store_true", default=False,
                        help="Update the list of regions available.")

    parser.add_argument("-r", "--get_next_region",
                        action="store_true", default=False,
                        help="Get the name of the next region in which to run.")

    parser.add_argument("-s", "--update_last_success",
                        action="store_true", default=False,
                        help="Update the last successful run timestamp for " +
                             "the current region (table's LastRowKeyUsed).")

    parser.add_argument("--last_success_region", default=None,
                        help="If specified, update the last successful run " +
                        "timestamp for the specified region instead of the " +
                        "current region (table's LastRowKeyUsed).")

    parser.add_argument("-c", "--cooldown-hours", type=int,
                        default=cooldown_hours,
                        help="Number of hours since last successful run " +
                             "needed before running in the next region. " +
                             "(default {}; 0 to disable cooldown)".format(cooldown_hours))

    parser.add_argument("-d", "--debug", action="store_true", default=False,
                        help="Turn on debugging output.")

    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(level=logging.DEBUG)

    cooldown_hours = args.cooldown_hours
    logging.debug("cooldown_hours = {}".format(cooldown_hours))

    if args.update_region_list:
        logging.debug("> update_available_region_names")
        update_available_region_names()

    if args.get_next_region:
        logging.debug("> get_next_region_name")
        print(get_next_region_name())
    elif args.update_last_success:
        logging.debug("> update_last_successful_run_for_region")
        update_last_successful_run_for_region(args.last_success_region)
