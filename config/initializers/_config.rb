VirtualizationServer.config.load! # will load config/app.yml or raise if it does not exist

User.load_storage VirtualizationServer.config.users
