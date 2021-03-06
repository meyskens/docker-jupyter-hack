## Based on the work of https://github.com/jupyter/docker-stacks/tree/master/datascience-notebook
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

ARG BASE_CONTAINER=jupyter/datascience-notebook
FROM $BASE_CONTAINER

LABEL maintainer="Maartje Eyskens <maartje@eyskens.me>"

USER root
WORKDIR /opt

## Go notebook
ENV GOPATH /go
ENV GOROOT=/usr/local/go
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH
RUN apt-get update && apt-get install -y wget tar gnupg2
RUN wget -O go.tar.gz https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz && \
    tar -xf go.tar.gz && mv go /usr/local

RUN echo "deb http://download.opensuse.org/repositories/network:/messaging:/zeromq:/release-stable/Debian_9.0/ ./" >> /etc/apt/sources.list
RUN wget https://download.opensuse.org/repositories/network:/messaging:/zeromq:/release-stable/Debian_9.0/Release.key -O- | sudo apt-key add && \
    apt-get install -y libzmq3-dev pkg-config


RUN go get -u github.com/gopherdata/gophernotes && \
    mkdir -p $CONDA_DIR/share/jupyter/kernels/gophernotes && \
    cp $GOPATH/src/github.com/gopherdata/gophernotes/kernel/* $CONDA_DIR/share/jupyter/kernels/gophernotes

## Ruby notebook
RUN apt-get install -y libtool libffi-dev ruby ruby-dev make git autoconf pkg-config && \
    git clone https://github.com/zeromq/czmq && \
    cd czmq && \
    ./autogen.sh && ./configure && sudo make && sudo make install
RUN gem install cztop iruby && \
    IPYTHONDIR=$CONDA_DIR/share/jupyter/ iruby register --force

## Javascript notebook
RUN apt-get install -y nodejs npm && \
    sudo npm install -g ijavascript
RUN ijsinstall --install=global

## PHP notebook
RUN apt-get install -y php7.2 php7.2-zmq wget
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"  && \
    php -r "if (hash_file('sha384', 'composer-setup.php') === '93b54496392c062774670ac18b134c3b3a95e5a5e5c8f1a9f115f203b75bf9a129d5daa8ba6a13e2cc8a1da0806388a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"  && \
    php composer-setup.php  && \
    php -r "unlink('composer-setup.php');"
RUN mv composer.phar /usr/local/bin/composer
RUN wget https://litipk.github.io/Jupyter-PHP-Installer/dist/jupyter-php-installer.phar && \
    php ./jupyter-php-installer.phar install

## Java notebook
RUN apt-get -y install software-properties-common && \
    add-apt-repository -y ppa:linuxuprising/java && \
    apt-get update && \
    echo oracle-java9-installer shared/accepted-oracle-license-v1-2 select true | /usr/bin/debconf-set-selections && \
    apt-get -y install oracle-java11-installer oracle-java11-set-default openjdk-11-jdk
ENV PATH=/usr/lib/jvm/java-11-openjdk-amd64/bin/:$PATH
#RUN mkdir $CONDA_DIR/share/jupyter/kernels/java/
#RUN git clone https://github.com/SpencerPark/IJava.git && \
#    cd IJava/ && \
#    chmod u+x gradlew && ./gradlew installKernel &&\
#    mv /home/jovyan/.local/share/jupyter/kernels/java/* $CONDA_DIR/share/jupyter/kernels/java/
RUN conda config --add channels conda-forge
RUN conda create --yes --name java_env scijava-jupyter-kernel
#RUN conda activate java_env

RUN rm -fr /home/jovyan/.local

## Verify install
WORKDIR /home/$NB_USER
USER $NB_USER
RUN jupyter kernelspec list
