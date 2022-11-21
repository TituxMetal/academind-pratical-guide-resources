# Base nodejs image
FROM node:lts-alpine as base

RUN apk add --no-cache libc6-compat > /dev/null 2>&1

WORKDIR /opt/

ENV PATH /opt/node_modules/.bin:$PATH

COPY ./package.json ./

RUN yarn config set network-timeout 6000000 -g

# Base nodejs with dev dependencies installed
FROM base as dev-deps

ARG NODE_ENV=development

RUN yarn install

# Base image with prisma + builds
FROM base as builder

COPY --from=dev-deps /opt/node_modules ./node_modules
COPY ./ ./

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

RUN yarn prisma:setup
RUN yarn build

# Base nodejs with only production dependencies installed
FROM base as production-deps

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

RUN yarn cache clean
RUN yarn install --production --ignore-scripts --prefer-offline

FROM base

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

COPY --from=production-deps /opt/node_modules /opt/node_modules
COPY --from=builder /opt/node_modules/.prisma /opt/node_modules/.prisma
COPY --from=builder /opt/node_modules/@prisma/client /opt/node_modules/@prisma/client
COPY --from=builder /opt/public /opt/public
COPY --from=builder /opt/build /opt/build

EXPOSE 3000

CMD ["yarn", "start"]
