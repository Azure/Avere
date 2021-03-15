param (
    [string] $dataTierHost,
    [int] $dataTierPort,
    [string] $adminUsername,
    [string] $adminPassword,
    [string] $databaseName,
    [string] $databaseUsername,
    [string] $databasePassword
)

Set-Location -Path "C:\Program Files\PostgreSQL\12\bin"
$openCuePath = "C:\Users\Public\Downloads\OpenCue-v0.8.8"

$dbName = $databaseName.ToLower()

$pgAdmin = "host=$dataTierHost port=$dataTierPort sslmode=require user=$adminUsername password=$adminPassword dbname=postgres"
$dbAdmin = "host=$dataTierHost port=$dataTierPort sslmode=require user=$adminUsername password=$adminPassword dbname=$dbName"

$dbExists = .\psql -t -c "select datname from pg_catalog.pg_database where lower(datname) = '$dbName';" $pgAdmin
if (!$dbExists) {
    .\psql -c "create database $dbName;" $pgAdmin
    .\psql -c "create user $databaseUsername with password '$databasePassword';" $dbAdmin
    .\psql -c "alter default privileges in schema public grant all privileges on tables to $databaseUsername;" $dbAdmin
    .\psql -f "$openCuePath\opencue-bot-schema.sql" $dbAdmin
    .\psql -f "$openCuePath\opencue-bot-data.sql" $dbAdmin
}

# $serviceName = "OpenCue Render Manager"
# $serviceApp = "java -jar $openCuePath\opencue-bot.jar --datasource.cue-data-source.jdbc-url=jdbc:postgresql://rendermanager.postgres.database.azure.com:5432/opencue?sslmode=require --datasource.cue-data-source.username=wrangler --datasource.cue-data-source.password=P@ssword1234"
# New-Service -Name $serviceName -BinaryPathName $serviceApp

# $serviceName = "OpenCue Render Manager"
# $dbUrl = "jdbc:postgresql://${dataTierHost}:${dataTierPort}/${dbName}?sslmode=require"
# New-Service -Name $serviceName -BinaryPathName "java -jar opencue-bot.jar --datasource.cue-data-source.jdbc-url=$dbUrl --datasource.cue-data-source.username=$databaseUsername --datasource.cue-data-source.password=$databasePassword"
# Start-Service -Name $serviceName
