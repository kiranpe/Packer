#!/bin/bash

set -ex

function print_color() {
  NC='\033[0m' # No Color

  case $1 in
    "green") COLOR='\033[0;32m' ;;
    "red") COLOR='\033[0;31m' ;;
    "yellow") COLOR='\033[0;33m';;
    "*") COLOR='\033[0m' ;;
  esac

  echo -e "${COLOR} $2 ${NC}"
}

export DEBIAN_FRONTEND=noninteractive

print_color "yellow" "Depreciating hive version to 2.1.1..."

sudo apt-get -y remove hive-jdbc hive
sudo mv /etc/apt/sources.list /etc/apt/sources.list.d /tmp

echo "deb http://storage.googleapis.com/goog-dataproc-bigtop-repo-europe-west1/1_2_deb9_20200212_010315-RC01 dataproc contrib
deb-src http://storage.googleapis.com/goog-dataproc-bigtop-repo-europe-west1/1_2_deb9_20200212_010315-RC01 dataproc contrib" | sudo tee -a /etc/apt/sources.list

sudo rm /var/lib/apt/lists/lock || true
sudo apt-get update -y || true
sudo apt-get install -y hive pig hive-hbase -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

sudo rm /etc/apt/sources.list
sudo mv /tmp/sources.list /tmp/sources.list.d /etc/apt

print_color "yellow" "Installing Spark2.3...."

gsutil cp gs://bucket/dataproc/spark-2.3.4-bin-without-hadoop.tgz spark-2.3.4-bin-without-hadoop.tgz
tar -xvf spark-2.3.4-bin-without-hadoop.tgz
sudo rm -R /usr/lib/spark
sudo cp -R spark-2.3.4-bin-without-hadoop /usr/lib/spark
sudo rm -R /usr/lib/spark/jars
sudo mkdir -p /usr/lib/spark/jars
mkdir -p temp_jars
gsutil cp gs://bucket/dataproc/spark2.3-jars.zip spark2.3-jars.zip
unzip spark2.3-jars.zip -d temp_jars
sudo cp temp_jars/spark2.3-jars/* /usr/lib/spark/jars
echo "export SPARK_DIST_CLASSPATH=$SPARK_DIST_CLASSPATH:$(hadoop classpath)" | sudo tee -a /etc/spark/conf.dist/spark-env.sh
sudo rm -R /usr/lib/spark/conf
sudo ln -s /etc/spark/conf.dist/ /usr/lib/spark/conf
sudo ln -s /etc/hive/conf.dist/hive-site.xml /etc/spark/conf.dist/hive-site.xml

print_color "yellow" "Installing Python Packages...."

py3_dist_loc="/usr/local/lib/python3.7/dist-packages"
py_path="/opt/conda/default/bin/python"

echo "[global]
index-url = https://pypi.org/api/pypi/" | sudo tee -a /etc/pip.conf

echo 'Acquire::CompressionTypes::Order:: "gz";' | sudo tee -a /etc/apt/apt.conf.d/02update
echo 'Acquire::http::Timeout "10";' | sudo tee -a /etc/apt/apt.conf.d/99timeout
echo 'Acquire::ftp::Timeout "10";' | sudo tee -a /etc/apt/apt.conf.d/99timeout
sudo -E apt-get update --allow-unauthenticated -y -o Dir::Etc::sourcelist="sources.list.d/main.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" || true

sudo -E apt-get autoclean && sudo -E apt-get update -y && sudo apt-get autoclean && sudo apt-get clean && sudo apt-get update -y || true
sudo -E apt-get --allow-unauthenticated -y install python-pip gcc python-dev python-tk curl
sudo -EH /usr/bin/python -m pip install --index-url https://pypi.org/api/pypi/ --ignore-installed pip setuptools wheel

sudo -E apt-get install openjdk-8-jdk -y

sudo -E apt-get install --allow-unauthenticated -y libpq-dev python-matplotlib

unset http_proxy
unset https_proxy

sudo mkdir -p /usr/local/lib/python2.7/ || true

gsutil cp gs://bucket/dataproc/py2.7-pack.tar.gz .

sudo tar xf py2.7-pack.tar.gz -C /usr/local/lib/python2.7/

/usr/bin/python --version

sudo /usr/bin/python -m pip list

print_color "yellow" "Installing Conda Pacakges...."

conda_tar="conda-dataproc-v1.10.0.tar.lz4"

sudo rm /var/lib/apt/lists/lock || true
sudo -E apt-get clean && sudo -E apt-get update -y || true
sudo -E apt-get install --allow-unauthenticated -y liblz4-tool lzop

cd /tmp/

print_color "yellow" "download conda tar..."
gsutil cp gs://bucket/dataproc/$conda_tar .

print_color "yellow" "decompressing conda tar..."
lz4 -dc $conda_tar | tar xf - --owner root --group root --no-same-owner && rm $conda_tar  || { echo "failed decompressing  conda archive" ; exit 1 ; }
sudo scp -r conda/* /opt/conda/ && sudo rm -rf conda
[[ -d /opt/conda/bin ]] || { echo "conda directory /opt/conda/bin does not exist after install" ; exit 1 ; }

export http_proxy=http://${PROXY_HOST}:3128
export https_proxy=http://${PROXY_HOST}:3128

packages="pandas google-cloud-storage google-cloud-pubsub redis matplotlib more-itertools numpy pandasql setuptools psycopg2-binary regex scipy statsmodels pandas-gbq"

/opt/conda/envs/python3/bin/pip install --index-url https://pypi.org/api/pypi/  --no-cache-dir --trusted-host=pypi.org --upgrade $packages

