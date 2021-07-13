FROM r-base

RUN apt update
RUN apt-get install -y libcurl4-openssl-dev libxml2-dev libssl-dev curl openssl
RUN Rscript -e "install.packages('devtools')" 
RUN Rscript -e "devtools::install_github('cemarks/ROpenLayers')"
RUN Rscript -e "install.packages('rjson')"
COPY makemap.R /makemap.R
RUN mkdir /data
RUN mkdir /output

ENTRYPOINT ["Rscript", "/makemap.R"]