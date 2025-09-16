FROM node:20-alpine

WORKDIR /usr/src/app

# Copy all project files
COPY package*.json ./

# Install all dependencies (including dev dependencies)
RUN npm ci

# Copy entire project
COPY . .

# Build the project if you have a build step
#RUN npm run start

# Expose port
EXPOSE 3000

# Start command
CMD ["npm", "start"]
