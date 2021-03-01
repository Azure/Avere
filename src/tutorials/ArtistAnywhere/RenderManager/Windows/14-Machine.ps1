Set-Location -Path "C:\Users\Default\Downloads"

$databaseName = $databaseName.ToLower()

$pgAdmin = "host=$dataTierHost port=$dataTierPort sslmode=require user=$adminUsername password=$adminPassword dbname=postgres"
$dbAdmin = "host=$dataTierHost port=$dataTierPort sslmode=require user=$adminUsername password=$adminPassword dbname=$dbName"

#databaseExists=$(psql "$pgAdmin" -t -c "select datname from pg_catalog.pg_database where lower(datname) = '$dbName'")
