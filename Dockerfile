FROM ubuntu:22.04

# make 参数
# [Choice] 是否安装make, 默认不安装
ARG INSTALL_MAKE="false"

# java 参数
# [Choice] 是否安装jdk, 默认不安装
ARG INSTALL_JDK="false"
# [Choice] 是否安装openjdk, 如果不安装, 则默认安装zulujdk
ARG USE_OPENJDK="false"
# [Choice] jdk 版本: 8, 11, 17
ARG JDK_VERSION="17"
# [Option] 安装 Maven, 默认不安装
ARG INSTALL_MAVEN="false"

# node.js 参数
# [Choice] 是否安装jdk, 默认不安装
ARG INSTALL_NODE="false"
# [Choice] node.js 版本: 14, 16, 18
ARG NODE_VERSION="16"
# [Option] 安装 yarn, 默认不安装
ARG INSTALL_YARN="false"

# 时区
ENV TZ="Asia/Shanghai"

RUN sed -i "s@http://.*archive.ubuntu.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list
RUN sed -i "s@http://.*security.ubuntu.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list
RUN sed -i "s@http://.*ports.ubuntu.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list

# 必要的软件包
RUN apt update && apt upgrade -y --no-install-recommends
RUN apt install -y --no-install-recommends \
        ca-certificates \
        netbase \
        net-tools \
        gnupg \
        wget \
        curl \
        iputils-ping \
        netcat \
        telnet \
        git \
        sudo \
        unzip \
        openssh-server \
        language-pack-en \
        language-pack-zh-hans \
        language-pack-zh-hans-base

RUN locale-gen zh_CN.UTF-8
RUN update-locale LANG=zh_CN.UTF-8

# zsh
RUN apt install -y --no-install-recommends zsh
RUN wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O - | sh
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
RUN sed -i "s@ZSH_THEME=\".*\"@ZSH_THEME=\"powerlevel10k/powerlevel10k\"@g" /root/.zshrc
RUN usermod -s /bin/zsh root

# protoc
RUN wget https://github.com/protocolbuffers/protobuf/releases/download/v3.20.1/protoc-3.20.1-linux-x86_64.zip -O protoc.zip
RUN unzip protoc.zip -d protoc.d
RUN cp protoc.d/bin/protoc /usr/local/bin/
RUN cp -r protoc.d/include/google /usr/local/include/
RUN rm -rf protoc.zip protoc.d

RUN curl -O https://cdn.azul.com/zulu/bin/zulu-repo_1.0.0-3_all.deb
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9
RUN apt install -y --no-install-recommends ./zulu-repo_1.0.0-3_all.deb
RUN rm zulu-repo_1.0.0-3_all.deb

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

RUN apt update -y --no-install-recommends

# 安装环境包
RUN apt install -y --no-install-recommends \
        make \
        zulu${JDK_VERSION}-jdk \
        maven \
        nodejs

# maven 源
RUN apt install -y --no-install-recommends maven; \
        sed -i "$(sed -n -e "/<mirrors>/=" /etc/maven/settings.xml)a\
\\\\\\\\    <mirror>\n\
\\\\\\\\      <id>huaweicloud<\/id>\n\
\\\\\\\\      <mirrorOf>*<\/mirrorOf>\n\
\\\\\\\\      <url>https://repo.huaweicloud.com/repository/maven/<\/url>\n\
\\\\\\\\    <\/mirror>\n\
        " /etc/maven/settings.xml

RUN npm config set registry https://registry.npmmirror.com
RUN npm install -g pnpm
RUN pnpm config set registry https://registry.npmmirror.com
RUN npm install -g \
        husky \
        lint-staged

# 清理过时的密钥格式
RUN for key in $( \
        apt-key --keyring /etc/apt/trusted.gpg list \
        | grep -E "(([ ]{1,2}(([0-9A-F]{4}))){10})" \
        | tr -d " " \
        | grep -E "([0-9A-F]){8}\b" \
    ); do \
        k=$(echo $key | tr '\n' ' ' | tail -c 9) ; \
        apt-key export $k | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/imported-from-trusted-gpg-$K.gpg ; \
    done

RUN apt autoremove -y && apt autoclean -y && apt clean

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN echo "root:root" | chpasswd

RUN mkdir /data
WORKDIR /data
VOLUME /data

EXPOSE 22
EXPOSE 18000-18009

RUN mkdir /run/sshd
# 启动 SSH 服务
CMD ["/usr/sbin/sshd", "-D"]
