FROM ubuntu:22.04

# make 参数
# [Choice] 是否安装make, 默认不安装
ARG INSTALL_MAKE="false"

# python 参数
# [Choice] 是否安装python, 默认不安装
ARG INSTALL_PYTHON="false"

# rust 参数
# [Choice] 是否安装rust, 默认不安装
ARG INSTALL_RUST="false"

# go 参数
# [Choice] 是否安装go, 默认不安装
ARG INSTALL_GO="false"
# [Option] go 版本: 1.18, latest
# ARG GO_VERSION="latest"
# [Option] go 代理: https://proxy.golang.com.cn,direct
ARG GOPROXY

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
        openssh-server \
        language-pack-en \
        language-pack-zh-hans \
        language-pack-zh-hans-base

RUN locale-gen zh_CN.UTF-8
RUN update-locale LANG=zh_CN.UTF-8

# zsh
RUN apt install -y --no-install-recommends zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
RUN sed -i "s@ZSH_THEME=\".*\"@ZSH_THEME=\"powerlevel10k/powerlevel10k\"@g" /root/.zshrc
RUN usermod -s /bin/zsh root

# 安装环境包
# make
RUN \
    if [ "${INSTALL_MAKE}" = "true" ]; then \
        apt install -y --no-install-recommends make; \
    fi

# python
RUN \
    if [ "${INSTALL_PYTHON}" = "true" ]; then \
        apt install -y --no-install-recommends python3; \
    fi

# rust
RUN \
    if [ "${INSTALL_RUST}" = "true" ]; then \
        curl https://sh.rustup.rs --proto '=https' --tlsv1.2 -sSf | sh -s -- -y; \
        # 稳定(stable)工具链
        $HOME/.cargo/bin/rustup toolchain install "stable-$(arch)-unknown-linux-gnu"; \
        # 每晚(nightly)工具链
        $HOME/.cargo/bin/rustup toolchain install "nightly-$(arch)-unknown-linux-gnu"; \
        # 切换nightly为默认
        $HOME/.cargo/bin/rustup default nightly ; \
        $HOME/.cargo/bin/rustup target add "$(arch)-unknown-linux-gnu"; \
        # 更换cargo源
        echo "[source.crates-io]" >> $HOME/.cargo/config ; \
        echo "registry = 'https://github.com/rust-lang/crates.io-index'" >> $HOME/.cargo/config ; \
        echo "replace-with = 'ustc'" >> $HOME/.cargo/config ; \
        echo "" >> $HOME/.cargo/config ; \
        echo "[source.ustc]" >> $HOME/.cargo/config ; \
        echo "registry = 'https://mirrors.ustc.edu.cn/crates.io-index'" >> $HOME/.cargo/config ; \
    fi

# go
RUN \
    if [ "${INSTALL_GO}" = "true" ]; then \
        apt install -y --no-install-recommends golang-go; \
        if [ -n "${GOPROXY}" ]; then \
            go env -w GOPROXY=${GOPROXY}; \
        fi; \
    fi

# java
RUN \
    if [ "${INSTALL_JDK}" = "true" ]; then \
        if [ "USE_OPENJDK" = "true" ]; then \
            apt install -y --no-install-recommends openjdk-${JDK_VERSION}-jdk; \
        else \
            curl -O https://cdn.azul.com/zulu/bin/zulu-repo_1.0.0-3_all.deb; \
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9; \
            apt install -y --no-install-recommends ./zulu-repo_1.0.0-3_all.deb; \
            apt -q update; \
            \
            apt install -y --no-install-recommends zulu${JDK_VERSION}-jdk; \
        fi; \
        \
        if [ "${INSTALL_MAVEN}" = "true" ]; then \
            apt install -y --no-install-recommends maven; \
            sed -i "$(sed -n -e "/<mirrors>/=" /etc/maven/settings.xml)a\
\\\\\\\\\\\\    <mirror>\n\
\\\\\\\\\\\\      <id>huaweicloud<\/id>\n\
\\\\\\\\\\\\      <mirrorOf>*<\/mirrorOf>\n\
\\\\\\\\\\\\      <url>https://repo.huaweicloud.com/repository/maven/<\/url>\n\
\\\\\\\\\\\\    <\/mirror>\n\
            " /etc/maven/settings.xml; \
        fi; \
    fi

# node.js
RUN \
    if [ "${INSTALL_NODE}" = "true" ]; then \
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
        apt update -y --no-install-recommends; \
        apt install -y --no-install-recommends nodejs; \
        if [ "${INSTALL_NODE}" = "true" && "${INSTALL_YARN}" = "true" ]; then \
            npm i -g corepack; \
            corepack enable; \
            if [ ${NODE_VERSION} -ge 16 ] ; then \
                corepack prepare yarn@stable --activate; \
            else \
                yarn_version=`curl -fsSL "https://github.com/yarnpkg/berry/releases/latest" \
                | grep "Release" \
                | head -n 1 \
                | awk -F " " '{print $2}'` \
                corepack prepare yarn@$yarn_version --activate; \
            fi; \
        fi; \
    fi

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

RUN mkdir /data
WORKDIR /data
VOLUME /data

EXPOSE 8080
EXPOSE 22

RUN mkdir /run/sshd
# 启动 SSH 服务
CMD ["/usr/sbin/sshd", "-D"]
