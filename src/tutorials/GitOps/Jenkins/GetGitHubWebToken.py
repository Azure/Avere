import sys
import jwt
import time

appId = sys.argv[1]
appKeyFile = sys.argv[2]
appTokenSeconds = sys.argv[3]
appTokenEncryption = sys.argv[4]

timeEpochSeconds = int(time.time())
appTokenPayload = {
  'iss': appId,
  'iat': timeEpochSeconds,
  'exp': timeEpochSeconds + int(appTokenSeconds)
}

appKey = open(appKeyFile, 'r').read()
appToken = jwt.encode(appTokenPayload, appKey, appTokenEncryption)
print(appToken.decode(), end='')
