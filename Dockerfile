FROM openkbs/jdk-mvn-py3

MAINTAINER drsnowbird@openkbs.org

##### update ubuntu
RUN apt-get update \
  && apt-get install -yq --no-install-recommends pwgen sudo ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*


#### -----------------------------
#### ---- Specifications      ----
#### -----------------------------
ARG INSTALL_BASE=${INSTALL_BASE:-/opt}

ENV TOMCAT_MAJOR_VERSION=${TOMCAT_MAJOR_VERSION:-9}
ENV TOMCAT_MINOR_VERSION=${TOMCAT_MINOR_VERSION:-9.0.14}

ENV CATALINA_HOME=${INSTALL_BASE}/tomcat
ENV TOMCAT_HOME=${CATALINA_HOME}/

ARG TOMCAT_HTTPS_ENABLED=${TOMCAT_HTTPS_ENABLED:-0}
ENV TOMCAT_HTTPS_ENABLED=${TOMCAT_HTTPS_ENABLED}

ARG CATALINA_WEBAPPS=${CATALINA_WEBAPPS:-${CATALINA_HOME}/webapps}
ENV CATALINA_WEBAPPS=${CATALINA_WEBAPPS}

## -- Tomcat Console admin password --
ENV TOMCAT_PASSWORD=${TOMCAT_PASSWORD:-password12345}

## -- Tomcat HTTPS Keystore password --
###################################################################################################
#### Use Blank password to trigger the Strong Random password for HTTPS -- Highly Recommended! ####
###################################################################################################
ARG KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:-}
ENV KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:-}

## -- 5.) Product Download Mirror site: -- ##
# https://downloads.sourceforge.net/project/bigdata/bigdata/2.1.4/blazegraph.tar.gz
# https://downloads.sourceforge.net/project/blazegraph/blazegraph/2.1.4/blazegraph.tar.gz
ARG PRODUCT_MIRROR_SITE_URL=${PRODUCT_MIRROR_SITE_URL:-https://downloads.sourceforge.net/project}

#### -----------------------------
#### ---- Download / Install  ----
#### -----------------------------

WORKDIR ${INSTALL_BASE}

#### ---- Download URL ---- 
ENV DOWNLOAD_BASE_URL=http://www-us.apache.org/dist
#ENV DOWNLOAD_BASE_URL=http://mirrors.advancedhosters.com/apache
#ENV DOWNLOAD_BASE_URL=http://apache.cs.utah.edu

# e.g. http://mirrors.advancedhosters.com/apache/tomcat/tomcat-9/v9.0.14/bin/apache-tomcat-9.0.14.tar.gz
# e.g. http://apache.cs.utah.edu/tomcat/tomcat-9/v9.0.14/bin/apache-tomcat-9.0.14.tar.gz
#
RUN wget --no-check-certificate ${DOWNLOAD_BASE_URL}/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_MINOR_VERSION}/bin/apache-tomcat-${TOMCAT_MINOR_VERSION}.tar.gz && \
    ## wget -qO- ${DOWNLOAD_BASE_URL}/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_MINOR_VERSION}/bin/apache-tomcat-${TOMCAT_MINOR_VERSION}.tar.gz.md5 | md5sum -c - && \
    tar zxf apache-tomcat-*.tar.gz && \
    rm apache-tomcat-*.tar.gz && \
    mv apache-tomcat* tomcat

#### -----------------------------
#### ---- Configuration/Setup ----
#### -----------------------------
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

COPY bin/create_tomcat_admin_user.sh ${CATALINA_HOME}/create_tomcat_admin_user.sh
COPY bin/setup-https-tomcat.sh ${CATALINA_HOME}/setup-https-tomcat.sh

## -- Modify Manager access -- (Don't turn this for production)
COPY config/webapps_manager_META-INF_context.xml ${CATALINA_HOME}/webapps/manager/META-INF/context.xml

#### ------------------------
#### ---- user: Non-Root ----
#### ------------------------
ENV USER_NAME=${USER_NAME:-tomcat}
ENV HOME=/home/${USER_NAME}

ARG USER_ID=${USER_ID:-1000}
ENV USER_ID=${USER_ID}

ARG GROUP_ID=${GROUP_ID:-1000}
ENV GROUP_ID=${GROUP_ID}

RUN \
    groupadd -g ${GROUP_ID} ${USER_NAME} && \
    useradd -d ${HOME} -s /bin/bash -u ${USER_ID} -g ${USER_NAME} ${USER_NAME} && \
    usermod -aG root ${USER_NAME} && \
    export uid=${USER_ID} gid=${GROUP_ID} && \
    mkdir -p ${HOME} && \
    mkdir -p ${HOME}/workspace && \
    mkdir -p /etc/sudoers.d && \
    echo "${USER_NAME}:x:${USER_ID}:${GROUP_ID}:${USER_NAME},,,:${HOME}:/bin/bash" >> /etc/passwd && \
    echo "${USER_NAME}:x:${USER_ID}:" >> /etc/group && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER_NAME} && \
    chmod 0440 /etc/sudoers.d/${USER_NAME} && \
    chown ${USER_NAME}:${USER_NAME} -R ${HOME} && \
    apt-get clean all
    
#### ------------------------
#### ---- Ports  :       ----
#### ------------------------
ENV TOMCAT_PORT_HTTP=${TOMCAT_PORT_HTTP:-8080}
ENV TOMCAT_PORT_HTTPS=${TOMCAT_PORT_HTTPS:-8443}
EXPOSE ${TOMCAT_PORT_HTTP}
EXPOSE ${TOMCAT_PORT_HTTPS}

#### ------------------------
#### ---- Start Tomcat:  ----
#### ------------------------

RUN chown -R ${USER_NAME}:${USER_NAME} ${CATALINA_HOME} /docker-entrypoint.sh
USER ${USER_NAME}
WORKDIR ${HOME}

ENTRYPOINT ["/docker-entrypoint.sh"]

