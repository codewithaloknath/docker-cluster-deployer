cd hadoop
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.0/hadoop-3.3.0.tar.gz

cd ../derby/
wget https://archive.apache.org/dist/db/derby/db-derby-10.14.2.0/db-derby-10.14.2.0-bin.tar.gz

cd ../hive/
wget https://downloads.apache.org/hive/hive-3.1.2/apache-hive-3.1.2-bin.tar.gz

cd ../olk/
wget https://download.openlookeng.io/1.3.0/hetu-server-1.3.0.tar.gz --no-check-certificate

cd ..

path=`pwd`
echo export HADOOP_PACKAGE=$path/hadoop/hadoop-3.3.0.tar.gz >> config
echo export DERBY_PACKAGE=$path/derby/db-derby-10.14.2.0-bin.tar.gz >> config
echo export HIVE_PACKAGE=$path/hive/apache-hive-3.1.2-bin.tar.gz >> config
echo export OLK_PACKAGE=$path/olk/hetu-server-1.3.0.tar.gz >> config
