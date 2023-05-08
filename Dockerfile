FROM confluentinc/cp-kafka:7.3.0

COPY /logbasedcdc/config /config
COPY /logbasedcdc/plugins /plugins
