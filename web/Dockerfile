FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run generate:api
RUN npm run build

FROM node:22-alpine AS run
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -S vapen && adduser -S vapen -G vapen
COPY --from=build /app/build ./build
COPY --from=build /app/package.json ./
COPY --from=build /app/package-lock.json ./
RUN npm ci --omit=dev && chown -R vapen:vapen /app
USER vapen
EXPOSE 3000
ENV PORT=3000
ENV HOST=0.0.0.0
CMD ["node", "build"]
