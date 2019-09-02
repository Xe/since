FROM xena/nim:0.20.2 AS build
WORKDIR /since
COPY . .
RUN nimble update \
 && nimble build \
 && nimble test

FROM xena/alpine
COPY --from=build /since/bin/since /usr/local/bin
CMD since

