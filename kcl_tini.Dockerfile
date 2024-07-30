FROM kcllang/kcl:v0.9.4
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
#ENTRYPOINT ["/tini", "--"]

