################################
FROM ubuntu:latest AS prebuild
################################
WORKDIR /home/app

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}
ENV DEBIAN_FRONTEND noninteractive

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}


RUN apt-get update
#RUN apt-get install -y software-properties-common
#RUN apt-get update
RUN apt-get install -y python3 python3-distutils libpython3-dev python3-pip
RUN apt-get install -y python3-tk 
RUN apt-get install -y tk-dev
RUN apt-get install -y tcl-dev
RUN apt-get install -y git liblapacke-dev 
RUN apt-get install -y npm nodejs
RUN apt-get install -y cmake g++
# RUN apt-get install -y libglu1-mesa-dev libxmu-dev

ENV DEBIAN_FRONTEND=

# RUN apt-get install vim emacs -y
RUN pip3 install --no-cache-dir notebook==5.*
#RUN pip3 install --no-cache-dir jupyterlab
RUN pip3 install --no-cache-dir numpy scipy matplotlib
RUN pip3 install --no-cache-dir ipywidgets
RUN pip3 install --no-cache-dir psutil pytest

RUN chown -R ${NB_UID} ${HOME}
USER ${NB_USER}
WORKDIR ${HOME}
RUN mkdir ngsuite

################################
FROM prebuild AS build
################################

ENV NGS_VER master

WORKDIR ${HOME}/ngsuite
RUN git clone https://github.com/NGSolve/ngsolve.git ngsolve-src
WORKDIR ${HOME}/ngsuite/ngsolve-src
RUN git checkout master
RUN git submodule update --init --recursive
RUN mkdir ../ngsolve-build


WORKDIR ${HOME}/ngsuite/ngsolve-build

RUN cmake -DUSE_GUI=OFF -DUSE_NATIVE_ARCH=OFF -DCMAKE_INSTALL_PREFIX=${HOME}/ngsuite/ngsolve-inst ../ngsolve-src 
RUN make -j8
RUN make install
WORKDIR ${HOME}/ngsuite/ngsolve-build/ngsolve

#ENV NETGENDIR ${HOME}/ngsuite/ngsolve-inst/bin
#ENV PATH ${HOME}/ngsuite/ngsolve-inst/bin:${PATH}
#ENV PYTHONPATH ${HOME}/ngsuite/ngsolve-inst/lib/python3/dist-packages:${PYTHONPATH}
#RUN CTEST_OUTPUT_ON_FAILURE=1 ctest -v

WORKDIR ${HOME}/ngsuite
RUN cp -r ${HOME}/ngsuite/ngsolve-src/docs/i-tutorials ${HOME}
RUN rm -rf ngsolve-build
RUN rm -rf ngsolve-src

################################
FROM prebuild AS postbuild
################################

COPY --from=build ${HOME}/ngsuite/ngsolve-inst ${HOME}/ngsuite/ngsolve-inst

ENV NETGENDIR ${HOME}/ngsuite/ngsolve-inst/bin
ENV PATH ${HOME}/ngsuite/ngsolve-inst/bin:${PATH}
# RUN export PYTHONPATH_TMP=`python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib(1,0,''))"`
ENV PYTHONPATH ${HOME}/ngsuite/ngsolve-inst/lib/python3/dist-packages:${PYTHONPATH}

RUN pip3 install --user webgui_jupyter_widgets
RUN jupyter nbextension install --user --py webgui_jupyter_widgets
RUN jupyter nbextension enable --user --py webgui_jupyter_widgets
        
USER root
#RUN jupyter labextension install --clean /usr/lib/python3/dist-packages/ngsolve/labextension
RUN chown -R ${NB_UID} ${HOME}

ENV TINI_VERSION v0.6.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini
ENTRYPOINT ["/usr/bin/tini", "--"]
USER ${NB_USER}

WORKDIR /home/${NB_USER}
ENV PYTHONPATH ${PYTHONPATH}:/opt/netgen/lib/python3/dist-packages
RUN export
RUN python3 -c "import ngsolve"   

CMD ["jupyter", "notebook", "--port=8888", "--no-browser", "--ip=0.0.0.0", "--allow-root" ]
