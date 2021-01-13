// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
)

func GetRidGeneratorB64z() (string, error) {
	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	if _, err := gz.Write([]byte(ridGeneratorFile)); err != nil {
		return "", err
	}
	if err := gz.Close(); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(b.Bytes()), nil
}

const (

	// The following content is stored under static/generate-rid-avereflatfiles.py and
	// will need to be updated when that file changes.
	//
	// A better solution will be to use something like the following solutions:
	//   * solutions presented at top of https://github.com/golang/go/issues/35950
	//   * https://dev.to/koddr/the-easiest-way-to-embed-static-files-into-a-binary-file-in-your-golang-app-no-external-dependencies-43pc
	//
	// An even better solution native to the langauge is in the design process, and would be the preferred solution to embed this.
	//   https://github.com/golang/go/issues/41191 - a more permanent solution to embedding files
	//
	// The best solution will be to build this as a feature native the Avere directory services.
	//
	ridGeneratorFile = `#!/usr/local/bin/python
import ldap
import logging
import struct
import sys

DEFAULT_USER_FILE  = "avere-user.txt"
DEFAULT_GROUP_FILE = "avere-group.txt"

class User:
    def __init__(self, accountName, uid, gid, distinguishedName):
        self.accountName = accountName
        self.uid = uid
        self.gid = gid
        self.distinguishedName = distinguishedName

def initializeUserFromEntry(distinguishedName, entry, ridInteger):
    if distinguishedName == None:
        logging.debug("initializeUserFromEntry: returning None because the following results have no distinguished: {}".format(entry))
        return None
    if ('sAMAccountName' not in entry
        or len(entry['sAMAccountName']) == 0
        or len(entry['sAMAccountName'][0]) == 0
        or entry['sAMAccountName'][0][-1] == '$'
    ):
        logging.debug("initializeUserFromEntry: returning None because entry missing valid sAMAccountName or is hidden: {}".format(entry))
        return None
    if 'objectSid' not in entry or len(entry['objectSid']) == 0:
        logging.debug("initializeUserFromEntry: returning None because entry missing valid objectSid: {}".format(entry))
        return None
    if 'primaryGroupID' not in entry or len(entry['primaryGroupID']) == 0:
        logging.debug("initializeUserFromEntry: returning None because entry missing valid primaryGroupID: {}".format(entry))
        return None
    if 'distinguishedName' not in entry or len(entry['distinguishedName']) == 0:
        logging.debug("initializeUserFromEntry: returning None because entry missing valid distinguishedName: {}".format(entry))
        return None
    return User(
        entry['sAMAccountName'][0],
        getRid(entry['objectSid'][0], ridInteger),
        ridInteger + int(entry['primaryGroupID'][0]),
        entry['distinguishedName'][0])

class Group:
    def __init__(self, groupName, gid, members):
        self.groupName = groupName
        self.gid = gid
        self.members = members

def createMemberList(dnList, avereUsers, primaryGroupUsers):
    memberList = set()
    for dn in dnList:
        if dn in avereUsers:
            memberList.add(avereUsers[dn].accountName)
    for username in primaryGroupUsers:
        memberList.add(username)
    return sorted(memberList, key=lambda s: s.lower())

def initializeGroupFromEntry(distinguishedName, entry, ridInteger, avereUsers, usernamesWithGidKey):
    if distinguishedName == None:
        logging.debug("initializeGroupFromEntry: returning None because the following results have no distinguished: {}".format(entry))
        return None
    if ('sAMAccountName' not in entry
        or len(entry['sAMAccountName']) == 0
        or len(entry['sAMAccountName'][0]) == 0
        or entry['sAMAccountName'][0][-1] == '$'
    ):
        logging.debug("initializeGroupFromEntry: returning None because entry missing valid sAMAccountName or is hidden: {}".format(entry))
        return None
    if 'objectSid' not in entry or len(entry['objectSid']) == 0:
        logging.debug("initializeGroupFromEntry: returning None because entry missing valid objectSid: {}".format(entry))
        return None
    
    gid = getRid(entry['objectSid'][0], ridInteger)

    members       = []
    primaryGroups = []
    if gid in usernamesWithGidKey:
        primaryGroups = usernamesWithGidKey[gid]
    if 'member' in entry:
        members = entry['member']
    
    memberList = createMemberList(members, avereUsers, primaryGroups)
    if len(memberList) == 0:
        logging.info("initializeGroupFromEntry: no members, returning None for '{}'".format(entry['sAMAccountName'][0]))
        return None
    
    return Group(
        entry['sAMAccountName'][0],
        gid,
        memberList)

# need for SID conversion, from https://stackoverflow.com/questions/33188413/python-code-to-convert-from-objectsid-to-sid-representation
def convert(binary):
    version = struct.unpack('B', binary[0:1])[0]
    length = struct.unpack('B', binary[1:2])[0]
    authority = struct.unpack(b'>Q', b'\x00\x00' + binary[2:8])[0]
    string = 'S-%d-%d' % (version, authority)
    binary = binary[8:]
    for i in range(length):
        value = struct.unpack('<L', binary[4*i:4*(i+1)])[0]
        string += '-%d' % value
    return string

def getADConnection(dnsDomain, user, password):
    logging.info('getADConnection for {}@{}'.format(user, dnsDomain))
    conn = ldap.initialize("ldap://{}".format(dnsDomain))
    conn.protocol_version = 3
    conn.set_option(ldap.OPT_REFERRALS,0)
    conn.simple_bind_s('{}@{}'.format(user, dnsDomain),password)
    return conn

def getBaseDomainName(domainName):
    parts = domainName.strip(".").split(".")
    return "dc={}".format(",dc=".join(parts))

def getRid(objectSid, ridInteger):
    sid = convert(objectSid)
    parts = sid.split("-")
    return ridInteger + int(parts[-1])

def getUsers(conn, basedn, ridInteger):
    logging.info('get users for "{}"'.format(basedn))
    
    users               = {}
    usernamesWithGidKey = {}
    
    # paging technique from here: https://stackoverflow.com/questions/3378142/ldap-ldap-sizelimit-exceeded
    searchFilter = "(&(objectclass=user))"
    attributeList = ["sAMAccountName","objectSid","distinguishedName","primaryGroupID"]
    pageSize = 500
    resultsControl = ldap.controls.SimplePagedResultsControl(criticality=True, size=pageSize, cookie='')
    msgid = conn.search_ext(base=basedn, scope=ldap.SCOPE_SUBTREE, filterstr=searchFilter, attrlist=attributeList, serverctrls=[resultsControl])

    pages = 0
    while True: # loop over all of the pages using the same cookie, otherwise the search will fail
        pages += 1
        rtype, rdata, rmsgid, serverctrls = conn.result3(msgid)
        for dn, entry in rdata:
            user = initializeUserFromEntry(dn, entry, ridInteger)
            if user == None:
                continue
            users[user.distinguishedName] = user
            if user.gid not in usernamesWithGidKey:
                usernamesWithGidKey[user.gid]=[]
            usernamesWithGidKey[user.gid].append(user.accountName)
        # get the next page or exit loop
        pctrls = [c for c in serverctrls if c.controlType == ldap.controls.SimplePagedResultsControl.controlType]
        if pctrls:
            if pctrls[0].cookie: # Copy cookie from response control to request control
                resultsControl.cookie = pctrls[0].cookie
                msgid = conn.search_ext(base=basedn, scope=ldap.SCOPE_SUBTREE, filterstr=searchFilter, attrlist=attributeList, serverctrls=[resultsControl])
            else:
                break
        else:
            break
    
    logging.info("found {} user(s) in {} page(s)".format(len(users), pages))

    return users, usernamesWithGidKey 

def getGroups(conn, basedn, ridInteger, avereUsers, usernamesWithGidKey):
    logging.info('get groups for {}'.format(basedn))

    groups = {}
    
    # paging technique from here: https://stackoverflow.com/questions/3378142/ldap-ldap-sizelimit-exceeded
    searchFilter = "(&(objectclass=group))"
    attributeList = ["sAMAccountName","objectSid","distinguishedName","member"]
    pageSize = 500
    resultsControl = ldap.controls.SimplePagedResultsControl(criticality=True, size=pageSize, cookie='')
    msgid = conn.search_ext(base=basedn, scope=ldap.SCOPE_SUBTREE, filterstr=searchFilter, attrlist=attributeList, serverctrls=[resultsControl])

    pages = 0
    while True: # loop over all of the pages using the same cookie, otherwise the search will fail
        pages += 1
        rtype, rdata, rmsgid, serverctrls = conn.result3(msgid)
        for dn,entry in rdata:
            group = initializeGroupFromEntry(dn, entry, ridInteger, avereUsers, usernamesWithGidKey)
            if group == None:
                continue
            groups[group.groupName] = group
        # get the next page or exit loop
        pctrls = [c for c in serverctrls if c.controlType == ldap.controls.SimplePagedResultsControl.controlType]
        if pctrls:
            if pctrls[0].cookie: # Copy cookie from response control to request control
                resultsControl.cookie = pctrls[0].cookie
                msgid = conn.search_ext(base=basedn, scope=ldap.SCOPE_SUBTREE, filterstr=searchFilter, attrlist=attributeList, serverctrls=[resultsControl])
            else:
                break
        else:
            break
    
    logging.info("found {} group(s) in {} page(s)".format(len(groups), pages))

    return groups

def writeAvereFiles(conn, basedn, avereUsers, avereGroups, userFile, groupFile):
    logging.info("write file {} for {} user(s)".format(userFile,len(avereUsers)))

    with open(userFile,'w') as f:
        userKeys = sorted(avereUsers.keys(), key=lambda s: s.lower()) 
        for u in userKeys:
            accountName = avereUsers[u].accountName.decode('ascii')
            uid = avereUsers[u].uid
            gid = avereUsers[u].gid
            f.write("{}:*:{}:{}:::\n".format(accountName, uid, gid)) 
    
    logging.info("write file {} for {} group(s)".format(groupFile,len(avereGroups)))
    
    with open(groupFile,'w') as f:
        groupKeys = sorted(avereGroups.keys(), key=lambda s: s.lower()) 
        for g in groupKeys:
            groupName = avereGroups[g].groupName.decode('ascii')
            gid = avereGroups[g].gid
            avereGroupMembers = []
            for groupMember in avereGroups[g].members:
                avereGroupMembers.append(groupMember.decode('ascii'))
            f.write("{}:*:{}:{}\n".format(groupName,gid,",".join(avereGroupMembers))) 

def usage():
    logging.info("usage: {} AD_DOMAIN USER PASSWORD RID_INTEGER [USER_FILENAME] [GROUP_FILENAME]".format(sys.argv[0]))

def main():
    logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.DEBUG)

    if len(sys.argv) <= 4:
        logging.error("ERROR: incorrect number of arguments")
        usage()
        sys.exit(1)
    dnsDomain  = sys.argv[1]
    user       = sys.argv[2]
    password   = sys.argv[3]
    ridInteger = int(sys.argv[4])
    userFile   = DEFAULT_USER_FILE if len(sys.argv) <= 5 else sys.argv[5]
    groupFile  = DEFAULT_GROUP_FILE if len(sys.argv) <= 6 else sys.argv[6]
    basedn     = getBaseDomainName(dnsDomain)

    conn = getADConnection(dnsDomain, user, password)
    avereUsers, usernamesWithGidKey = getUsers(conn, basedn, ridInteger)
    avereGroups = getGroups(conn, basedn, ridInteger, avereUsers, usernamesWithGidKey)
    writeAvereFiles(conn, basedn, avereUsers, avereGroups, userFile, groupFile)

if __name__ == "__main__":
    main()
`
)
