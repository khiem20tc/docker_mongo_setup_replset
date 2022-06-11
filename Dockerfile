FROM mongo:5.0.6

RUN mkdir -p /var/log/mongodb && \
 touch /var/log/mongodb/mongod.log && \
 chown -R mongodb:mongodb /var/log/mongodb && \
 touch /etc/secret.kf && \
 chmod 400 /etc/secret.kf && \
 chown mongodb:mongodb /etc/secret.kf 

CMD ["mongod"]