FROM thevlang/vlang:alpine

WORKDIR /app
COPY . .

EXPOSE 8080

ENTRYPOINT ["v", "-d", "veb", "run", "."]
