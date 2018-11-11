## Based on the work of https://github.com/jupyter/docker-stacks/tree/master/datascience-notebook
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

ARG BASE_CONTAINER=jupyter/scipy-notebook
FROM $BASE_CONTAINER

LABEL maintainer="Maartje Eyskens <maartje@eyskens.me>"

USER root

## Datascience notebook

# R pre-requisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    tzdata \
    gfortran \
    gcc && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.0.0

RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "bea4570d7358016d8ed29d2c15787dbefaea3e746c570763e7ad6040f17831f3 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

USER $NB_UID

# R packages including IRKernel which gets installed globally.
RUN conda install --quiet --yes \
    'rpy2=2.8*' \
    'r-base=3.4.1' \
    'r-irkernel=0.8*' \
    'r-plyr=1.8*' \
    'r-devtools=1.13*' \
    'r-tidyverse=1.1*' \
    'r-shiny=1.0*' \
    'r-rmarkdown=1.8*' \
    'r-forecast=8.2*' \
    'r-rsqlite=2.0*' \
    'r-reshape2=1.4*' \
    'r-nycflights13=0.2*' \
    'r-caret=6.0*' \
    'r-rcurl=1.95*' \
    'r-crayon=1.3*' \
    'r-randomforest=4.6*' \
    'r-htmltools=0.3*' \
    'r-sparklyr=0.7*' \
    'r-htmlwidgets=1.0*' \
    'r-hexbin=1.27*' && \
    conda clean -tipsy && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Add Julia packages. Only add HDF5 if this is not a test-only build since
# it takes roughly half the entire build time of all of the images on Travis
# to add this one package and often causes Travis to timeout.
#
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'import Pkg; Pkg.update()' && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("HDF5")') && \
    julia -e 'import Pkg; Pkg.add("Gadfly")' && \
    julia -e 'import Pkg; Pkg.add("RDatasets")' && \
    julia -e 'import Pkg; Pkg.add("IJulia")' && \
    # Precompile Julia packages \
    julia -e 'using IJulia' && \
    # move kernelspec out of home \
    mv $HOME/.local/share/jupyter/kernels/julia* $CONDA_DIR/share/jupyter/kernels/ && \
    chmod -R go+rx $CONDA_DIR/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions $JULIA_PKGDIR $CONDA_DIR/share/jupyter

USER root
WORKDIR /opt

## Go notebook
ENV GOPATH /go
ENV GOROOT=/usr/local/go
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH
RUN apt-get update && apt-get install -y wget tar gnupg2
RUN wget -O go.tar.gz https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz && \
    tar -xvf go.tar.gz && mv go /usr/local

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
    iruby register --force

## Javascript notebook
RUN apt-get install -y nodejs npm && \
    sudo npm install -g ijavascript
RUN ijsinstall

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
RUN java -version
RUN git clone https://github.com/SpencerPark/IJava.git && \
    cd IJava/ && \
    chmod u+x gradlew && ./gradlew installKernel

## Verify install
WORKDIR /home/$NB_USER
USER $NB_USER
RUN jupyter kernelspec list
