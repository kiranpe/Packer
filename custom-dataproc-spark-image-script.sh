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

print_color "yellow" "Installing Python3 Packages,,,,,,"

py3_dist_loc="/usr/local/lib/python3.7/dist-packages"
py_path="/opt/conda/default/bin/python"


echo "[global]
index-url = https://pypi.org/api/pypi/pypi-remote/simple" | sudo tee -a /etc/pip.conf

echo "deb https://pypi.org/artifactory/debian-main-remote stretch main" | sudo tee -a /etc/apt/sources.list.d/main.list
echo "deb https://pypi.org/artifactory/maria-db-debian stretch main" | sudo tee -a /etc/apt/sources.list.d/main.list
echo 'Acquire::CompressionTypes::Order:: "gz";' | sudo tee -a /etc/apt/apt.conf.d/02update
echo 'Acquire::http::Timeout "10";' | sudo tee -a /etc/apt/apt.conf.d/99timeout
echo 'Acquire::ftp::Timeout "10";' | sudo tee -a /etc/apt/apt.conf.d/99timeout
sudo -E apt-get update --allow-unauthenticated -y -o Dir::Etc::sourcelist="sources.list.d/main.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" || true

sudo -E apt-get update -y && sudo apt-get update -y || true
sudo -E apt-get --allow-unauthenticated -y install python3-pip python3-dev python3-tk
sudo -EH python3 -m pip install --upgrade pip && sudo -EH apt-get update && sudo apt-get update || true

sudo -EH pip3 install --index-url https://pypi.org/api/pypi/pypi-remote/simple --ignore-installed pip setuptools wheel

sudo -E apt-get install openjdk-8-jdk -y

sudo -E apt-get install --allow-unauthenticated -y \
  python3-matplotlib \
  libpq-dev \
  libssl-dev \
  libcrypto* \
  default-libmysqlclient-dev \
  libzmq3-dev \
  libzmq3*

sudo -EH pip3 install -r /tmp/requirements.txt --target=$py3_dist_loc

unset http_proxy
unset https_proxy

sudo mkdir -p /usr/local/lib/python3.7/ || true

echo "export PYTHONPATH=$py3_dist_loc" | sudo tee -a /etc/profile

source /etc/profile

python3 --version

sudo -EH pip3 list
