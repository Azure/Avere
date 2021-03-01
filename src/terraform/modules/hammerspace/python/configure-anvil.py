#!/usr/local/bin/python2
import base64
import json
import logging
import ssl
import sys
import time
import urllib2

ANVIL_USERNAME = "admin"
MAX_RETRIES = 60
SLEEP_TIME = 10
# default export options
DEFAULT_EXPORTOPTIONS_SUBNET = "*"
DEFAULT_EXPORTOPTIONS_ACCESSPERMS = "RW"
DEFAULT_EXPORTOPTIONS_ROOTSSQUASH = False
DEFAULT_MAX_SHARE_SIZE = 0

def createAnvilNode(jsonObj):
    name = ""
    address = ""
    if hasattr(jsonObj, "keys") and "name" in jsonObj:
        name = jsonObj["name"]
    else:
        return None
    if hasattr(jsonObj, "keys") and "mgmtIpAddress" in jsonObj and "address" in jsonObj["mgmtIpAddress"]:
        address = jsonObj["mgmtIpAddress"]["address"]
    else:
        return None
    return AnvilNode(name, address)

def createAnvilVolume(jsonObj):
    name = ""
    address = ""
    if hasattr(jsonObj, "keys") and "name" in jsonObj:
        name = jsonObj["name"]
    else:
        return None
    return AnvilVolume(name)

def createAnvilShare(jsonObj):
    name = ""
    path = ""
    shareSizeLimit = 0
    exportOptions = []

    if hasattr(jsonObj, "keys"):
        if "name" in jsonObj:
            name = jsonObj["name"]
        else:
            return None
        if "path" in jsonObj:
            path = jsonObj["path"]
        else:
            return None
        if "shareSizeLimit" in jsonObj:
            shareSizeLimit = int(jsonObj["shareSizeLimit"])
        if "exportOptions" in jsonObj:
            for eo in exportOptions:
                anvilExportOption = createAnvilExportOption(eo)
                if anvilExportOption is not None:
                    exportOptions.append(anvilExportOption)
    else:
        return None
    return AnvilShare(name, path, shareSizeLimit, exportOptions)

def createAnvilExportOption(jsonObj):
    subnet = ""
    accessPermissions = ""
    rootSquash = False
    if hasattr(jsonObj, "keys"):
        if "subnet" in jsonObj:
            subnet = jsonObj["subnet"]
        else:
            return None
        if "accessPermissions" in jsonObj:
            accessPermissions = jsonObj["accessPermissions"]
        else:
            return None
        if "rootSquash" in jsonObj:
            rootSquash = bool(jsonObj["rootSquash"])
        else:
            return None
    else:
            return None
    return AnvilExportOptions(subnet, accessPermissions, rootSquash)

def createAnvilObjective(jsonObj):
    name = ""
    comment = ""
    expression = False
    if hasattr(jsonObj, "keys"):
        if "name" in jsonObj:
            name = jsonObj["name"]
        else:
            return None
        if "comment" in jsonObj:
            comment = jsonObj["comment"]
        else:
            return None
        if "expression" in jsonObj:
            expression = bool(jsonObj["expression"])
        else:
            return None
    else:
            return None
    return AnvilObjective(name, comment, expression)

class AnvilNode:
    def __init__(self, name, address):
        self.name=name
        self.address=address

    def __str__(self):
        return "node '{}', address '{}'".format(self.name, self.address)

class AnvilVolume:
    def __init__(self, name):
        self.name=name
        
    def __str__(self):
        return "volume '{}'".format(self.name)

class AnvilShare:
    def __init__(self, name, path, exportOptions, shareSizeLimit):
        self.name = name
        self.path = path
        self.exportOptions = exportOptions
        self.shareSizeLimit = 0

    # technique from https://stackoverflow.com/questions/3768895/how-to-make-a-class-json-serializable
    def toJSON(self):
        return json.dumps(self, default=lambda o: o.__dict__)
    
    def __str__(self):
        exportOptions = ""
        if len(exportOptions) > 0:
            exportOptions = string(self.exportOptions)
        return "name '{}', path '{}', exportOptions '{}', shareSizeLimit '{}'".format(self.name, self.path, exportOptions, self.shareSizeLimit)

class AnvilExportOptions:
    def __init__(self, subnet, accessPermissions, rootSquash):
        self.subnet = subnet
        self.accessPermissions = accessPermissions
        self.rootSquash = rootSquash
    
    def __str__(self):
        return "subnet '{}', perms '{}', rootSquash '{}'".format(self.subnet, self.accessPermissions, self.rootSquash)

class AnvilObjective:
    def __init__(self, name, comment, expression):
        self.name = name
        self.comment = comment
        self.expression = expression
    
    # technique from https://stackoverflow.com/questions/3768895/how-to-make-a-class-json-serializable
    def toJSON(self):
        return json.dumps(self, default=lambda o: o.__dict__)

    def __str__(self):
        return "name '{}', comment '{}', expression '{}'".format(self.name, self.comment, self.expression)

# approach from https://stackoverflow.com/questions/21243834/doing-put-using-python-urllib2
class GetRequest(urllib2.Request):
    '''class to handling gettting with urllib2'''

    def get_method(self, *args, **kwargs):
        return 'GET'

class PutRequest(urllib2.Request):
    '''class to handling putting with urllib2'''

    def get_method(self, *args, **kwargs):
        return 'PUT'

class PostRequest(urllib2.Request):
    '''class to handling putting with urllib2'''

    def get_method(self, *args, **kwargs):
        return 'POST'

class AnvilRest:
    def __init__(self, anvilAddress, anvilPassword):
        self.username = ANVIL_USERNAME
        self.anvilAddress = anvilAddress
        self.anvilPassword = anvilPassword
        self.passwordManagerInitiliazed = False

    def addShareName(self, shareName):
        logging.info("add share name")
        shareNames = getShareNames()
        for s in shareNames:
            if s.name == shareName:
                logging.info("share {} already exists, skipping adding".format(shareName))

    def getNodes(self):
        logging.info("getting nodes")
        data = self.submitRetryableRequest(GetRequest, "nodes", "")
        jsonObj = json.loads(data)
        nodeList = []
        for j in jsonObj:
            n = createAnvilNode(j)
            if n is not None:
                nodeList.append(n)
            else:
                logging.error("unable to parse node {}".format(j))
        return nodeList

    def getVolumes(self):
        logging.info("getting volumes")
        data = self.submitRetryableRequest(GetRequest, "base-storage-volumes", "")
        jsonObj = json.loads(data)
        volumeList = []
        for j in jsonObj:
            n = createAnvilVolume(j)
            if n is not None:
                volumeList.append(n)
            else:
                logging.error("unable to parse node {}".format(j))
        return volumeList
    
    def getSharenames(self):
        logging.info("getting volumes")
        data = self.submitRetryableRequest(GetRequest, "shares", "")
        jsonObj = json.loads(data)
        shareList = []
        for j in jsonObj:
            n = createAnvilShare(j)
            if n is not None:
                shareList.append(n)
            else:
                logging.error("unable to parse node {}".format(j))
        return shareList

    def getObjectives(self):
        logging.info("getting objectives")
        data = self.submitRetryableRequest(GetRequest, "objectives", "")
        jsonObj = json.loads(data)
        objectives = {}
        for j in jsonObj:
            o = createAnvilObjective(j)
            if o is not None:
                objectives[o.name] = o
            else:
                logging.error("unable to parse node {}".format(j))
        return objectives

    def createShare(self, anvilShare):
        logging.info("creating share path '{}'".format(anvilShare))
        jsonText = anvilShare.toJSON()
        data = self.submitNonRetryableRequest(PostRequest, "shares", jsonText)

    def createObjective(self, anvilObjective):
        logging.info("creating share path '{}'".format(anvilObjective))
        jsonText = anvilObjective.toJSON()
        data = self.submitNonRetryableRequest(PostRequest, "objectives", jsonText)

    def getBaseURL(self):
        return "https://{}:8443".format(self.anvilAddress)
    
    def getRestBaseURL(self):
        return "{}/mgmt/v1.2/rest/".format(self.getBaseURL())

    def submitNonRetryableRequest(self, request, resource, data):
        return self.submitRequest(request, resource, data, 1)

    def submitRetryableRequest(self, request, resource, data):
        return self.submitRequest(request, resource, data, MAX_RETRIES)

    def submitRequest(self, request, resource, data, retryCount):
        #self.configurePasswordManager()
        url = self.getRestBaseURL() + resource

        # configures the headers correctly
        headers = {}
        headers["Content-Type"] = "application/json"
        headers["Accept"] = "application/json"
        headers["X-Admin"] = self.username
        headers["Authorization"] = "Basic {}".format(base64.b64encode('%s:%s' % (self.username, self.anvilPassword)))

        request = request(url, data=data, headers=headers)
        sslContext = ssl._create_unverified_context()
        for i in xrange(retryCount):
            try:
                response = urllib2.urlopen(request, context=sslContext)
            except urllib2.URLError as e:
                if hasattr(e, 'reason'):
                    logging.error("We failed to reach a server.  Reason {}".format(e.reason))
                    logging.info("{} {}".format(self.username, self.anvilPassword))
                elif hasattr(e, 'code'):
                    logging.error("The server couldn't fulfill the request.  Error code {}".format(e.code))
            else:
                logging.info("response code {}".format(response.code))
                data = response.read()
                #logging.info("response data {}".format(data))
                response.close()
                return data
            logging.info("try {} of {}, sleeping for {} seconds".format(i, MAX_RETRIES, SLEEP_TIME))
            if (i+1) != MAX_RETRIES:
                time.sleep(SLEEP_TIME)

        return None

def listNodes(anvilRest):
    logging.info("listing nodes")
    nodes = anvilRest.getNodes()
    for n in nodes:
        logging.info("{}".format(n))

def waitForDSXStorage(anvilRest, dsxCount):
    logging.info("waiting for {} dsx node(s)".format(dsxCount))
    for i in xrange(MAX_RETRIES):
        count = 0
        nodes = anvilRest.getNodes()
        for n in nodes:
            if "dsx" in n.name:
                count = count + 1
        if count >= dsxCount:
            return
        logging.info("try {} of {} waiting for {} dsx nodes, sleeping for {} seconds".format(i, MAX_RETRIES, dsxCount, SLEEP_TIME))
        time.sleep(SLEEP_TIME)

def waitForDSXVolumes(anvilRest, dsxCount):
    logging.info("waiting for {} dsx node(s)".format(dsxCount))
    for i in xrange(MAX_RETRIES):
        count = 0
        nodes = anvilRest.getVolumes()
        for n in nodes:
            if "dsx" in n.name:
                count = count + 1
        if count >= dsxCount:
            return
        logging.info("try {} of {} waiting for {} dsx volumes, sleeping for {} seconds".format(i, MAX_RETRIES, dsxCount, SLEEP_TIME))
        time.sleep(SLEEP_TIME)

def addStorageShare(anvilRest, sharePath):
    logging.info("add storage share '{}'".format(sharePath))
    shareNames = anvilRest.getSharenames()
    for share in shareNames:
        logging.info("existing share: {}".format(share))
        if share.path == sharePath:
            logging.info("Share '{}' already exists, no need to add".format(sharePath))
            return

    logging.info("add storage share '{}'".format(sharePath))
    name = sharePath.replace("/","")
    exportOptions = [AnvilExportOptions(DEFAULT_EXPORTOPTIONS_SUBNET, DEFAULT_EXPORTOPTIONS_ACCESSPERMS, DEFAULT_EXPORTOPTIONS_ROOTSSQUASH)]
    anvilSharePath = AnvilShare(name, sharePath, exportOptions, DEFAULT_MAX_SHARE_SIZE)
    anvilRest.createShare(anvilSharePath)

def addDefaultObjectives(anvilRest):
    logging.info("add default objectives")
    existingObjectives = anvilRest.getObjectives()

    objectives = []
    objectives.append(AnvilObjective("Undelete files to cloud","Store undelete files in cloud","IF IS_UNDELETE THEN {SLO('place-on-shared-object-volumes')}"))
    objectives.append(AnvilObjective("Most recent snapshot local and in cloud","Keep the most recent snapshot local and in cloud","IF VERSION==2 THEN {SLO('keep-online'),SLO('place-on-shared-object-volumes')}"))
    objectives.append(AnvilObjective("Old snapshots in the cloud","Move old snapshots to cloud","IF VERSION>2 THEN {SLO('place-on-shared-object-volumes')}"))
    objectives.append(AnvilObjective("Move un-used PDF files to cloud","Move un-used PDF files to cloud","IF MATCH_EXTENSION(\"pdf\",NAME)&&LAST_USE_AGE>5*MINUTES THEN {SLO('place-on-shared-object-volumes')}"))
    objectives.append(AnvilObjective("Archive files with keyword","Archive files with keyword archive","IF HAS_KEYWORD(\"archive\") THEN {SLO('place-on-shared-object-volumes')}"))
    objectives.append(AnvilObjective("Archive Directory","Archive Directory","IF FNMATCH(\"*/archive/*\",PATH) THEN {SLO('place-on-shared-object-volumes')}"))
    objectives.append(AnvilObjective("Recently used with local copy","Keep most recently used files with a local copy","IF LAST_USE_AGE<2DAYS THEN {SLO('keep-online')}"))
    objectives.append(AnvilObjective("Tag for local copy","Files with keyword local have a local copy","IF HAS_KEYWORD(\"local\") THEN {SLO('keep-online')}"))
    objectives.append(AnvilObjective("File clones in cloud","Move file clones to cloud","IF FNMATCH(\"*/.fsnapshot/*\",PATH) THEN {SLO('place-on-shared-object-volumes')}"))
    objectives.append(AnvilObjective("WORM protection after 10 minutes","Turn on WORM protection after 10 minutes","IF MODIFY_AGE >10MINUTES THEN {SLO('deny-write'),SLO('deny-delete')}"))
    objectives.append(AnvilObjective("Prevent file deletion after 10 minutes","Prevent file deletion only after 10 minutes","IF MODIFY_AGE>10MINUTES THEN {SLO('deny-delete')}"))
    objectives.append(AnvilObjective("Block file access until keyword is set","Block file access until keyword scanned is set"," IF NOT HAS_KEYWORD(\"scanned\") THEN {SLO('block-read')}"))

    for o in objectives:
        if not existingObjectives.has_key(o.name):
            anvilRest.createObjective(o)

def usage():
    logging.info("usage: {} ANVIL_ADDRESS ANVIL_PASSWORD DSX_COUNT SHARENAME".format(sys.argv[0]))

def main():
    logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.DEBUG)

    if len(sys.argv) <= 4:
        logging.error("ERROR: incorrect number of arguments")
        usage()
        sys.exit(1)
    anvilAddress = sys.argv[1]
    anvilPassword = sys.argv[2]
    dsxCount = int(sys.argv[3])
    sharePath = sys.argv[4]
    
    anvilRest = AnvilRest(anvilAddress, anvilPassword)

    # wait for the storage to be added
    waitForDSXStorage(anvilRest, dsxCount)

    # wait for the volumes to be added
    waitForDSXVolumes(anvilRest, dsxCount)

    # create a share
    addStorageShare(anvilRest, sharePath)

    # configure default objectives
    addDefaultObjectives(anvilRest)

    logging.info("complete")

if __name__ == "__main__":
    main()