#!/usr/bin/env python2
import base64
import json
import logging
import optparse
import os
import select
import ssl
import subprocess
import sys
import time
import urllib2

ANVIL_USERNAME = "admin"
MAX_RETRIES = 60
SLEEP_TIME = 10
# rest to try for 
REST_MAX_RETRIES = 6
REST_SLEEP_TIME = 10
# default export options
DEFAULT_EXPORTOPTIONS_SUBNET = "*"
DEFAULT_EXPORTOPTIONS_ACCESSPERMS = "RW"
DEFAULT_EXPORTOPTIONS_ROOTSSQUASH = False
DEFAULT_MAX_SHARE_SIZE = 0
PLATFORM_LOGS = "/var/log/pd/platform.log"

def verifyKey(key, jsonObj):
    return key in jsonObj and jsonObj[key] is not None

def createAnvilNode(jsonObj):
    name = ""
    address = ""
    if hasattr(jsonObj, "keys") and verifyKey("name",jsonObj):
        name = jsonObj["name"]
    else:
        return None
    if hasattr(jsonObj, "keys") and verifyKey("mgmtIpAddress",jsonObj) and verifyKey("address",jsonObj["mgmtIpAddress"]):
        address = jsonObj["mgmtIpAddress"]["address"]
    elif hasattr(jsonObj, "keys") and verifyKey("endpoint",jsonObj):
        address = jsonObj["endpoint"]
    else:
        return None
    return AnvilNode(name, address)

def createAnvilVolume(jsonObj):
    name = ""
    address = ""
    if hasattr(jsonObj, "keys") and verifyKey("name",jsonObj):
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
        if verifyKey("name",jsonObj):
            name = jsonObj["name"]
        else:
            return None
        if verifyKey("path",jsonObj):
            path = jsonObj["path"]
        else:
            return None
        if verifyKey("shareSizeLimit",jsonObj):
            shareSizeLimit = int(jsonObj["shareSizeLimit"])
        if verifyKey("exportOptions",jsonObj):
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
        if verifyKey("subnet",jsonObj):
            subnet = jsonObj["subnet"]
        else:
            return None
        if verifyKey("accessPermissions",jsonObj):
            accessPermissions = jsonObj["accessPermissions"]
        else:
            return None
        if verifyKey("rootSquash",jsonObj):
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
        if verifyKey("name",jsonObj):
            name = jsonObj["name"]
        else:
            return None
        if verifyKey("comment",jsonObj):
            comment = jsonObj["comment"]
        if verifyKey("expression",jsonObj):
            expression = jsonObj["expression"]
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
        nodeList = []
        if data is None:
            return nodeList
        jsonObj = json.loads(data)
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
        volumeList = []
        if data is None:
            return volumeList
        jsonObj = json.loads(data)
        for j in jsonObj:
            n = createAnvilVolume(j)
            if n is not None:
                volumeList.append(n)
            else:
                logging.error("unable to parse volume {}".format(j))
        return volumeList

    def getSharenames(self):
        logging.info("getting volumes")
        data = self.submitRetryableRequest(GetRequest, "shares", "")
        shareList = []
        if data is None:
            return shareList
        jsonObj = json.loads(data)
        for j in jsonObj:
            n = createAnvilShare(j)
            if n is not None:
                shareList.append(n)
            else:
                logging.error("unable to parse share {}".format(j))
        return shareList

    def getObjectives(self):
        logging.info("getting objectives")
        data = self.submitRetryableRequest(GetRequest, "objectives", "")
        objectives = {}
        if data is None:
            return objectives
        jsonObj = json.loads(data)
        for j in jsonObj:
            o = createAnvilObjective(j)
            if o is not None:
                objectives[o.name] = o
            else:
                logging.error("unable to parse objective {}".format(j))
        return objectives
    
    def getAD(self):
        logging.info("getting ad")
        data = self.submitRetryableRequest(GetRequest, "ad", "")
        if data is None:
            return data
        return json.loads(data)

    def putAD(self, uuid, jsonObj):
        logging.info("putting ad")
        jsonText = json.dumps(jsonObj)
        target = "ad/{}".format(uuid)
        logging.info("PUT to {} '{}'".format(target, jsonText))
        data = self.submitNonRetryableRequest(PutRequest, target, jsonText)

    def getLocalSite(self):
        logging.info("getting local site data")
        data = self.submitRetryableRequest(GetRequest, "sites/local", "")
        if data is None:
            return data
        return json.loads(data)

    def putSite(self, uuid, jsonObj):
        logging.info("putting local site data")
        jsonText = json.dumps(jsonObj)
        target = "sites/{}".format(uuid)
        logging.info("PUT to {} '{}'".format(target, jsonText))
        data = self.submitRetryableRequest(PutRequest, target, jsonText)

    def putAzureStorageAccount(self, storageAccount, storageAccountKey):
        logging.info("putting local site data")
        jsonObj = {"name":storageAccount,"nodeType":"AZURE","comment":"","mgmtIpAddress":{"address":""},"mgmtNodeCredentials":{"username":storageAccount,"password":storageAccountKey,"cert":""},"_type":"NODE","endpoint":None,"trustCertificate":False,"useVirtualHostNaming":False,"s3SigningType":None,"proxyInfo":None}
        jsonText = json.dumps(jsonObj)
        target = "nodes"
        logging.info("POST to {} ".format(target))
        data = self.submitNonRetryableRequest(PostRequest, target, jsonText)

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
        return self.submitRequest(request, resource, data, REST_MAX_RETRIES)

    def testConnection(self, retryable):
        if retryable:
            return self.submitRequest(GetRequest, "nodes", "", REST_MAX_RETRIES) != None
        else:
            return self.submitRequest(GetRequest, "nodes", "", 1) != None

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
                elif hasattr(e, 'code'):
                    logging.error("The server couldn't fulfill the request.  Error code {}".format(e.code))
            else:
                logging.info("response code {}".format(response.code))
                data = response.read()
                #logging.info("response data {}".format(data))
                response.close()
                return data
            if (i+1) != retryCount:
                logging.info("try {} of {}, sleeping for {} seconds".format(i+1, retryCount, REST_SLEEP_TIME))
                time.sleep(REST_SLEEP_TIME)

        return None

def listNodes(anvilRest):
    logging.info("listing nodes")
    nodes = anvilRest.getNodes()
    for n in nodes:
        logging.info("{}".format(n))

# technique from https://stackoverflow.com/a/12523371
class BootStorageWatcher:
    def __init__(self):
        self.fileScanned = False
        self.storageErrorSeen = False
        self.finished = False
        self.f = subprocess.Popen(['tail','-F',PLATFORM_LOGS],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        self.p = select.poll()
        self.p.register(self.f.stdout)
        self.targetMessage = "Anvil nodes require an additional storage device of at least 2 GB"
    
    def handleBootError(self):
        logging.info("error seen!")
        self.storageErrorSeen = True
        try:
            retcode = subprocess.call("/bin/systemctl try-restart pd-first-boot", shell=True)
            if retcode < 0:
                logging.error("Child was terminated by signal {}".format(-retcode))
            else:
                logging.info("Child returned {}".format(retcode))
        except OSError as e:
            logging.error("Execution failed {}".format(e))

    def scanFile(self):
        if self.fileScanned:
            return
        self.fileScanned = True
        with open(PLATFORM_LOGS, 'r') as f:
            for line in f:
                if self.targetMessage in line:
                    self.handleBootError()
                    break

    def fixIfErrorSeen(self):
        if not self.fileScanned:
            self.scanFile()

        if not self.finished and not self.storageErrorSeen:
            while self.p.poll(1):
                line = self.f.stdout.readline()
                if self.targetMessage in line:
                    self.handleBootError()
                    break
                    
    def finish(self):
        if not self.finished:
            self.finished = True
            self.p.unregister(self.f.stdout)
            self.f.kill()

def waitForRestPort(anvilRest):
    logging.info("waiting for the rest port to become avaible")
    if not anvilRest.testConnection(retryable=False):
        bootWatcher = BootStorageWatcher()
        bootWatcher.fixIfErrorSeen()

        for i in xrange(MAX_RETRIES):
            count = 0
            result = anvilRest.testConnection(retryable=True)
            if result:
                break
            bootWatcher.fixIfErrorSeen()
            logging.info("try {} of {} waiting for connection".format(i+1, MAX_RETRIES))

        bootWatcher.finish()

def waitForDSXStorage(anvilRest, dsxCount):
    logging.info("waiting for {} dsx node(s)".format(dsxCount))
    for i in xrange(MAX_RETRIES):
        count = 0
        nodes = anvilRest.getNodes()
        for n in nodes:
            if "dsx" in n.name:
                count = count + 1
        if count >= dsxCount:
            return True
        logging.info("try {} of {} waiting for {} dsx nodes, sleeping for {} seconds".format(i+1, MAX_RETRIES, dsxCount, SLEEP_TIME))
        time.sleep(SLEEP_TIME)
    return False

def waitForDSXVolumes(anvilRest, dsxCount):
    logging.info("waiting for {} dsx node(s)".format(dsxCount))
    for i in xrange(MAX_RETRIES):
        count = 0
        nodes = anvilRest.getVolumes()
        for n in nodes:
            if "dsx" in n.name:
                count = count + 1
        if count >= dsxCount:
            return True
        logging.info("try {} of {} waiting for {} dsx volumes, sleeping for {} seconds".format(i+1, MAX_RETRIES, dsxCount, SLEEP_TIME))
        time.sleep(SLEEP_TIME)
    return False

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

def joinDomain(anvilRest, adName, adUser, adPassword):
    logging.info("join domain '{}' with user '{}'".format(adName, adUser))
    adConfigData = anvilRest.getAD()
    if adConfigData is None:
        logging.error("nothing returned from AD")
        return
    if len(adConfigData) == 0 or not adConfigData[0].has_key('joined') or not adConfigData[0].has_key('uoid') or not adConfigData[0]['uoid'].has_key('uuid'):
        logging.error("missing keys returned from ad '{}'".format(adConfigData))
        return
    if adConfigData[0]['joined'] == True:
        logging.info("already domain joined")
        return
    
    uuid = adConfigData[0]['uoid']['uuid']
    adConfigData[0]['joined'] = True
    adConfigData[0]['domain'] = adName
    adConfigData[0]['username'] = adUser
    adConfigData[0]['password'] = adPassword
    anvilRest.putAD(uuid, adConfigData[0])

def updateSiteDisplayName(anvilRest, siteName):
    logging.info("updating site display name to '{}'".format(siteName))
    localSiteData = anvilRest.getLocalSite()
    if localSiteData is None:
        logging.error("nothing returned from local site data")
        return
    if len(localSiteData) == 0 or not localSiteData.has_key("uoid") or not localSiteData['uoid'].has_key('uuid') or not localSiteData.has_key('name'):
        logging.error("missing keys returned from localSiteData '{}'".format(localSiteData))
        return
    if localSiteData['name'] == siteName:
        logging.info("site name already set to {}".format(siteName))
        return
    uuid = localSiteData['uoid']['uuid']
    localSiteData['name'] = siteName
    anvilRest.putSite(uuid, localSiteData)

def waitForAzureStorage(anvilRest, storageAccount):
    logging.info("waiting for storage account {}".format(storageAccount))
    for i in xrange(MAX_RETRIES):
        count = 0
        nodes = anvilRest.getNodes()
        for n in nodes:
            if storageAccount in n.name:
                return
        logging.info("try {} of {} waiting for storage account {}".format(i+1, MAX_RETRIES, storageAccount))
        time.sleep(SLEEP_TIME)

def addAzureStorage(anvilRest, storageAccount, storageAccountKey, storageAccountContainer):
    logging.info("adding azure storage account '{}'".format(storageAccount))
    nodes = anvilRest.getNodes()
    for node in nodes:
        if node.name == storageAccount:
            logging.info("storage account already exists {}".format(storageAccount))
            return
    
    anvilRest.putAzureStorageAccount(storageAccount, storageAccountKey)
    waitForAzureStorage(anvilRest, storageAccount)
    # best effort run to add the volume
    if storageAccountContainer != "":
        #os.system("/bin/pdcli object-volume-add --native --no-compression --node-name {} --shared --logical-volume-name {}".format(storageAccount, storageAccountContainer))
        os.system("/bin/pdcli object-volume-add --no-compression --node-name {} --shared --logical-volume-name {}".format(storageAccount, storageAccountContainer))
    
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
    objectives.append(AnvilObjective("keeponline","Keep Live Files Online","IF IS_LIVE THEN {SLO('keep-online')}"))
    objectives.append(AnvilObjective("placeonsharedobjectvolume","Place Live Files On shared volumes","IF IS_LIVE THEN {SLO('place-on-shared-object-volumes')}"))

    for o in objectives:
        if not existingObjectives.has_key(o.name):
            anvilRest.createObjective(o)

def main():
    logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.DEBUG)

    # parse the options
    usage = "usage: %prog [options] ANVIL_ADDRESS ANVIL_PASSWORD DSX_COUNT"
    parser = optparse.OptionParser(usage)
    parser.add_option("-s", "--share-name", dest="sharename", help="print the sharename", default="")
    parser.add_option("-a", "--ad-name", dest="activeDirectoryName", help="the active directory to join", default="")
    parser.add_option("-u", "--ad-user", dest="activeDirectoryUser", help="the active directory user", default="")
    parser.add_option("-p", "--ad-password", dest="activeDirectoryPassword", help="the active directory password", default="")
    parser.add_option("-n", "--name", dest="name", help="the visible name of the site", default="")
    parser.add_option("--azure-account", dest="azureAccount", help="the azure storage account name", default="")
    parser.add_option("--azure-account-key", dest="azureAccountKey", help="the azure storage account key", default="")
    parser.add_option("--azure-account-container", dest="azureAccountContainer", help="the azure storage account container", default="")
    (options, args) = parser.parse_args()

    if len(args) < 3:
        parser.error("incorrect number of arguments")
        sys.exit(1)

    anvilAddress = args[0]
    anvilPassword = args[1]
    dsxCount = int(args[2])

    sharePath = options.sharename
    adName = options.activeDirectoryName
    adUser = options.activeDirectoryUser
    adPassword = options.activeDirectoryPassword
    siteName = options.name
    azureAccount = options.azureAccount
    azureAccountKey = options.azureAccountKey
    azureAccountContainer = options.azureAccountContainer
    
    # configure the rest API
    anvilRest = AnvilRest(anvilAddress, anvilPassword)

    # wait for the port
    waitForRestPort(anvilRest)
    
    # wait for the storage to be added
    success = waitForDSXStorage(anvilRest, dsxCount)
    if not success:
        logging.error("ERROR: timed out waiting for DSX Storage")
        sys.exit(2)

    # wait for the volumes to be added
    success = waitForDSXVolumes(anvilRest, dsxCount)
    if not success:
        logging.error("ERROR: timed out waiting for DSX volumes")
        sys.exit(3)

    # create a share
    if sharePath != "":
        addStorageShare(anvilRest, sharePath)

    # domain join
    if adName != "" and adUser != "" and adPassword != "":
        joinDomain(anvilRest, adName, adUser, adPassword)

    if siteName != "":
        updateSiteDisplayName(anvilRest, siteName)

    if azureAccount != "" and azureAccountKey != "":
        addAzureStorage(anvilRest, azureAccount, azureAccountKey, azureAccountContainer)

    # configure default objectives
    addDefaultObjectives(anvilRest)

    logging.info("complete")

if __name__ == "__main__":
    main()