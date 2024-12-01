# Use the official Node.js image (alpine variant for smaller size)
FROM node:16-alpine

# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to install dependencies
COPY package*.json ./

# Install only production dependencies
RUN npm install --production

# Copy the rest of the application files
COPY . .

# Expose the application port (default 3000)
EXPOSE 3000

# Start the application with an environment variable for PORT
CMD ["node", "index.js"]





