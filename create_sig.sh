#! /usr/bin/env bash

SIG_NAME="CwSSIG"
sigfile="/tmp/mysig.json"
SIG_DIR="/opt/SIG"
DLI_SHARED_FS="/scratch/dli_userdata"
MY_EGO_TOP="/opt/ibm/spectrumcomputing"

touch_sig_json()
{
# create sig with egoadmin
rm -rf /tmp/$SIG_NAME.json
cat << EOF > /tmp/$SIG_NAME.json
{
"sparkversion": "1.6.1",
"consumerpath": "/",
"conductorinstancename": "$SIG_NAME",
"monitoringttl": "14d",
"parameters": {
"sparkms_batch_rg_param": "ComputeHosts",
"sparkms_notebook_rg_param": "ComputeHosts",
"driver_rg_param": "ComputeHosts",
"executor_rg_param": "ComputeHosts",
"execution_user": "egoadmin",
"deploy_home": "$SIG_DIR/$SIG_NAME",
"impersonate": "Admin",
"sparkss_rg_param": "ComputeHosts",
"driver_consumer_param": "sparkapp",
"executor_consumer_param": "sparkapp",
"sparkhs_rg_param": "ComputeHosts"
},
"notebooks": [

],
"dependentpkgs": [

],
"sparkparameters": {
"JAVA_HOME": "/usr/lib/jvm/java-8-openjdk-ppc64el/jre",
"SPARK_EGO_EXECUTOR_SLOTS_MAX": "1",
"SPARK_EGO_EXECUTOR_IDLE_TIMEOUT": "6000",
"SPARK_EGO_ENABLE_PREEMPTION": "false",
"spark.shuffle.service.enabled": "true",
"spark.shuffle.service.port": 7337,
"SPARK_EGO_LOGSERVICE_PORT": 28082,
"SPARK_EGO_CONF_DIR_EXTRA": "$DLI_SHARED_FS/conf",
"SPARK_EGO_APP_SCHEDULE_POLICY": "fifo"
}
}
EOF
}

wait_sig_status()
{
    sigid=$1
    stopsign=$2
    sigstatus=""
    while true
    do
        sigstatus=`curl --silent -k -u Admin:Admin -X GET "https://localhost:8643/platform/rest/conductor/v1/instances?fields=state&id=$sigid"`
        if echo "$sigstatus" | grep "$stopsign"; then
            break
        fi
        if echo "$sigstatus" | egrep "DEPLOY_ERROR|ERROR"; then
            break
        fi
        echo "waiting for sig $sigid to be $stopsign. current status: $sigstatus"
        sleep 5
    done
}

generate_sig()
{
signame="$1"
sigfile="$2"

curl -k -u Admin:Admin https://localhost:8643/platform/rest/conductor/v1/auth/logon
curl --silent -k -u Admin:Admin -X GET "https://localhost:8643/platform/rest/conductor/v1/instances?fields=name" | grep $signame
if [ "$?" -eq 0 ]; then
    echo "================================================================"
    echo "Spark Instance Group $signame is already created"
    echo "================================================================"
    echo ""
    return
fi

#rm -rf $SIG_DIR
#mkdir $SIG_DIR
#chmod 777 $SIG_DIR

echo "================================================================"
echo "Create Spark Instance Group: $signame with file $sigfile"
echo "================================================================"

sigid=`curl --silent -k -u Admin:Admin -H "Content-Type:application/json" -H "Accept:application/json" -X POST --data-binary @$sigfile  https://localhost:8643/platform/rest/conductor/v1/instances`
sigid=`echo $sigid | tr -d '"'`

echo "Spark instance $signame is created, id: $sigid"

wait_sig_status $sigid "REGISTERED"
echo ""

echo "================================================================"
echo "Deploy Spark Instance Group: $signame"
echo "================================================================"
# deploy spark instance group
curl -k -u Admin:Admin -X PUT https://localhost:8643/platform/rest/conductor/v1/instances/$sigid/deploy
wait_sig_status $sigid "READY"
echo ""

echo "================================================================"
echo "Modify Spark Consumer: $signame"
echo "================================================================"
cp $MY_EGO_TOP/kernel/conf/ConsumerTrees.xml $MY_EGO_TOP/kernel/conf/ConsumerTrees.xml.BAK
. $MY_EGO_TOP/profile.platform
egosh consumer modify /$signame-sparkapp -R false
echo ""

echo "================================================================"
echo "Start Spark Instance Group: $signame"
echo "================================================================"
# start spark instance group
curl -k -u Admin:Admin -X PUT https://localhost:8643/platform/rest/conductor/v1/instances/$sigid/start
wait_sig_status $sigid "STARTED"
echo ""
}

#main
touch_sig_json
generate_sig $SIG_NAME /tmp/$SIG_NAME.json
