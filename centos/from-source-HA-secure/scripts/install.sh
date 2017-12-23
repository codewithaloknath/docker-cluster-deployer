#!/bin/env bash
SCRIPT_NAME=$(basename $BASH_SOURCE)
DIR=$(dirname $BASH_SOURCE);
DIR=$(cd $DIR && pwd);

function usage() {
    echo "Usage: ./install.sh <COMMAND> [options]"
    echo
    echo "setupusers  --group=<GROUP> --users=<USERS>"
    echo      "create users and map to specified group"
}

function createUser(){
    username=$1;
    groupname=$2;
    useradd -d /home/$username -m -g $groupname $username

    su -c 'ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" \
    && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys \
    && echo "HashKnownHosts no" >> ~/.ssh/config \
    && echo "StrictHostKeyChecking no" >> ~/.ssh/config' $username
}

function createGroup(){
    groupname=$1;
    groupadd $groupname
}

function setupUsers(){
    local USERS;
    local GROUP;
    while [ "$1" != "" ]; do
        PARAM=$(echo $1 | awk -F= '{print $1}')
        VALUE=$(echo $1 | awk -F= '{print $2}')
        case $PARAM in
            -h | --help)
                usage
                exit
                ;;
            --group)
                GROUP=$VALUE
                ;;
            --users)
                USERS=$VALUE
                ;;
            *)
                echo "ERROR: unknown parameter \"$PARAM\""
                usage
                exit 1
                ;;
        esac
        shift
    done

    createGroup $GROUP
    for user in $(echo $USERS|tr ',' '\n'); do
       createUser $user $GROUP
    done
}

function initHdfsDirs(){
    $HADOOP_HOME/bin/hdfs dfs -chmod 755 /
    $HADOOP_HOME/bin/hdfs dfs -mkdir /tmp
    $HADOOP_HOME/bin/hdfs dfs -chmod +rwxt /tmp
    $HADOOP_HOME/bin/hdfs dfs -chown hdfs:hadoop /tmp
    $HADOOP_HOME/bin/hdfs dfs -mkdir /user
    $HADOOP_HOME/bin/hdfs dfs -chmod 755 /user
    $HADOOP_HOME/bin/hdfs dfs -chown hdfs:hadoop /user
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /yarn/app-logs
    $HADOOP_HOME/bin/hdfs dfs -chown -R yarn:hadoop /yarn
    $HADOOP_HOME/bin/hdfs dfs -chmod +rwxt /yarn/app-logs
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /mapred/jobhistory/intermediate-done
    $HADOOP_HOME/bin/hdfs dfs -chmod +rwxt /mapred/jobhistory/intermediate-done
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /mapred/jobhistory/done
    $HADOOP_HOME/bin/hdfs dfs -chown -R mapred:hadoop /mapred
    $HADOOP_HOME/bin/hdfs dfs -chmod +rwxt /mapred/jobhistory/done
    $HADOOP_HOME/bin/hdfs dfs -ls -R /
}

#Setup the SSL prerequirements
# CA is created outside and kept static, it will be available in /root/scripts directory for signing certificate
#1. Create the certificate for each node
#2. Sign the certificate with the CA
#3. Add the Signed certificate and CA certificate to keystore of each node
function setupSsl(){
    password=${1:-hadoopkeystorepass}
    ssldir=$HOME/scripts/ssl
    mkdir -p $ssldir
    #1 Generate the key
    keytool -keystore $ssldir/keystore -alias $(hostname) -validity 7 -genkey -keyalg RSA -keysize 2048 -storepass $password -keypass $password -dname "CN=$(hostname), OU=ASF, O=ASF, L=BGLR, S=KAR, C=IN"
    #2 Export the key as certificate
    keytool -keystore $ssldir/keystore -alias $(hostname) -certreq -storepass $password -keypass $password -file $ssldir/$(hostname).cert
    #3 Add CA certificate to truststore
    keytool -keystore $ssldir/truststore -alias CARoot -import -file $ssldir/ca.cert -noprompt -storepass $password -keypass $password
    #4 Sign the certificate with CA certificate
    openssl x509 -req -CA $ssldir/ca.cert -CAkey $ssldir/ca.key -in $ssldir/$(hostname).cert -out $ssldir/$(hostname).cert.signed -days 7 -CAcreateserial -passin pass:capassword
    #5 Import CA certicate and signed certificate to keystore
    keytool -keystore $ssldir/keystore -alias CARoot -import -file $ssldir/ca.cert -noprompt -storepass $password -keypass $password
    keytool -keystore $ssldir/keystore -alias $(hostname) -import -file $ssldir/$(hostname).cert.signed -noprompt -storepass $password -keypass $password
    #6 copy the keystore and truststore to hadoop conf directory and limit the permissions to only owner and hadoop special group
    cp $ssldir/keystore $ssldir/truststore $HADOOP_HOME/etc/hadoop
    chown hdfs:hadoop $HADOOP_HOME/etc/hadoop/keystore $HADOOP_HOME/etc/hadoop/truststore
    chmod 660 $HADOOP_HOME/etc/hadoop/keystore $HADOOP_HOME/etc/hadoop/truststore
}

function setupSslUsingOpenSsl(){
    password=${1:-hadoopkeystorepass}
    ssldir=$HOME/scripts/ssl
    mkdir -p $ssldir
    #1 Generate the key
    openssl req -newkey rsa:2048 -x509 -keyout $ssldir/selfkey.pem -out $ssldir/selfcert.pem -days 3650 -subj "/C=IN/ST=Karnataka/O=ASF/OU=Apache  Hadoop/CN=$(hostname)" -passout pass:$password
    #2 Export the key
    openssl pkcs12 -export -in $ssldir/selfcert.pem -inkey $ssldir/selfkey.pem -out $ssldir/identity.p12 -name $(hostname) -password pass:$password
    #3 Import to keystore
    keytool -keystore $ssldir/keystore -alias $(hostname) -validity 7 -genkey -storepass $password -keypass $password -dname "CN=$(hostname), OU=ASF, O=ASF, L=BGLR, S=KAR, C=IN"
    #### CA Sighning part ### 
    #2 Export the key as certificate
    #keytool -keystore $ssldir/keystore -alias $(hostname) -certreq -storepass $password -keypass $password -file $ssldir/$(hostname).cert
    #3 Add CA certificate to truststore
    #keytool -keystore $ssldir/truststore -alias CARoot -import -file $ssldir/ca.cert -noprompt -storepass $password -keypass $password
    #4 Sign the certificate with CA certificate
    #openssl x509 -req -CA $ssldir/ca.cert -CAkey $ssldir/ca.key -in $ssldir/$(hostname).cert -out $ssldir/$(hostname).cert.signed -days 7 -CAcreateserial
    #5 Import CA certicate and signed certificate to keystore
    #keytool -keystore $ssldir/keystore -alias CARoot -import -file $ssldir/ca.cert -noprompt -storepass $password -keypass $password
    #keytool -keystore $ssldir/keystore -alias $(hostname) -import -file $ssldir/$(hostname).cert.signed -noprompt -storepass $password -keypass $password
    #6 copy the keystore and truststore to hadoop conf directory and limit the permissions to only owner and hadoop special group
    keytool -alias $(hostname) -import --file $ssldir/selfcert.pem -keystore $ssldir/truststore -noprompt -storepass $password
    cp $ssldir/keystore $ssldir/truststore $HADOOP_HOME/etc/hadoop
    chown hdfs:hadoop $HADOOP_HOME/etc/hadoop/keystore $HADOOP_HOME/etc/hadoop/truststore
    chmod 660 $HADOOP_HOME/etc/hadoop/keystore $HADOOP_HOME/etc/hadoop/truststore
}

function main(){
    COMMAND=$1;
    shift
    case $COMMAND in
        "setupusers")
            setupUsers $@
            ;;
        "init-hdfs-dirs")
            initHdfsDirs $@
            ;;
        "setup-ssl")
            setupSsl $@
            ;;
        *)
            echo "ERROR: Unknown command \"$COMMAND\""
            usage
            exit 1
    esac
}

main $@