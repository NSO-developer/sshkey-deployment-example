ARG NSO_IMG_NAME
FROM ${NSO_IMG_NAME}
USER root
RUN dnf --disableplugin subscription-manager install -y --nodocs \
    openssh-clients \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && python -m pip install --root-user-action=ignore --upgrade pip \
    && python -m pip install --root-user-action=ignore requests \
    && groupadd ncsadmin \
    && groupadd ncsoper \
    && useradd --create-home --home-dir /home/admin --no-user-group --no-log-init --groups ncsadmin --shell /bin/bash admin \
    && useradd --create-home --home-dir /home/oper --no-user-group --no-log-init --groups ncsoper --shell /bin/bash oper \
    && echo "oper:oper" | chpasswd
