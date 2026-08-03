FROM rocketchat/rocket.chat:8.6.1

# No custom modifications needed - Rocket.Chat itself is stateless, all data
# (messages, users, uploaded files via GridFS) lives in MongoDB. No volume,
# no non-root permission fix required for this service.

EXPOSE 3000
